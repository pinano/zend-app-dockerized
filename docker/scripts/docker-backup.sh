#!/usr/bin/env bash
# ===================================================================================
# Docker App Backup Script
# ===================================================================================
# This script discovers projects in a specified root directory, parses their .env
# files for database configuration, performs an incremental project backup, and
# takes a full database dump. It organizes backups under a Dropbox folder by
# Proxmox host and hostname, and enforces a retention policy defined in settings
#
# Recommended path in production: /Dropbox/scripts/docker-backup.sh
# Recommended cron job: 0 2 * * * /Dropbox/scripts/docker-backup.sh > /home/sistemas/scripts/docker-backup.log 2>&1
# ===================================================================================

set -euo pipefail

# --- Logging Helpers ---
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# --- Send Telegram Notification ---
send_telegram_message() {
    local message="$1"
    
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        return
    fi
    
    log_info "Sending Telegram notification..."
    if command -v curl &> /dev/null; then
        local response
        # Use connect-timeout, max-time, and catch exit codes to prevent crashing under set -e
        response=$(curl -s -S -w "\n%{http_code}" --connect-timeout 10 --max-time 30 \
            -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${message}" 2>&1) || {
            log_warn "curl command failed (network, DNS, or host down). Cannot reach Telegram API."
            return 0
        }
        
        local http_code
        http_code=$(echo "$response" | tail -n1)
        if [[ "$http_code" -eq 200 ]]; then
            log_info "Telegram notification sent successfully."
        else
            log_warn "Failed to send Telegram notification (HTTP Status: ${http_code})."
            log_warn "Telegram API response detail: $(echo "$response" | head -n-1)"
        fi
    else
        log_warn "curl command not found. Cannot send Telegram notification."
    fi
}

# --- Load Configuration ---
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONF_FILE="${SCRIPT_DIR}/docker-backup.conf"

# Fallback to default production config path if not in the script's directory
if [[ ! -f "$CONF_FILE" ]]; then
    CONF_FILE="/home/sistemas/scripts/docker-backup.conf"
fi

if [[ ! -f "$CONF_FILE" ]]; then
    log_error "Configuration file not found! Searched: ${SCRIPT_DIR}/docker-backup.conf and /home/sistemas/scripts/docker-backup.conf"
    log_error "Please copy the template docker-backup.conf next to this script or to /home/sistemas/scripts/."
    exit 1
fi

log_info "Loading configuration from ${CONF_FILE}..."
# shellcheck source=/dev/null
source "$CONF_FILE"

# --- Set Default Values if not defined in config ---
PROXMOX_HOST="${PROXMOX_HOST:-pve-node-01}"
BACKUP_ROOT_DIR="${BACKUP_ROOT_DIR:-/Dropbox}"
PROJECTS_ROOT_DIR="${PROJECTS_ROOT_DIR:-/home/sistemas/docker}"
METADATA_DIR="${METADATA_DIR:-/home/sistemas/scripts/docker-backup-metadata}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
EXCLUDE_PATHS="${EXCLUDE_PATHS:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

CANARY_FILE="${CANARY_FILE:-}"
LOCK_FILE="${LOCK_FILE:-/tmp/docker-backup.lock}"
TEMP_DIR="${TEMP_DIR:-/tmp}"
DB_TIMEOUT="${DB_TIMEOUT:-1h}"
TAR_TIMEOUT="${TAR_TIMEOUT:-2h}"

# --- Setup Target Directories ---
MY_HOSTNAME=$(hostname)
TARGET_DIR="${BACKUP_ROOT_DIR}/${PROXMOX_HOST}/${MY_HOSTNAME}"
PROJECT_TARGET_DIR="${TARGET_DIR}/project"
DB_TARGET_DIR="${TARGET_DIR}/db"

# --- Single Instance Lock (flock) ---
if [[ -n "$LOCK_FILE" ]]; then
    # Open the lockfile on descriptor 9
    exec 9>"$LOCK_FILE"
    # Attempt non-blocking write lock
    if ! flock -n 9; then
        log_error "Another instance of docker-backup.sh is already running (lock active: ${LOCK_FILE}). Exiting."
        exit 1
    fi
fi

# --- Mount & Canary Failsafe Verification ---
# 1. Verify BACKUP_ROOT_DIR is indeed a mount point (checks LXC mp0 mount is active)
if ! mountpoint -q "$BACKUP_ROOT_DIR"; then
    log_error "Backup root directory is not a mount point: ${BACKUP_ROOT_DIR}"
    log_error "LXC mount (mp0) might be inactive. Aborting backup to prevent local disk filling up."
    send_telegram_message "⚠️ <b>[${PROXMOX_HOST}/${MY_HOSTNAME}] Backup Aborted!</b>\n\nError: Backup root directory <code>${BACKUP_ROOT_DIR}</code> is not a mount point. Check LXC bind-mount (mp0)."
    exit 1
fi

# 2. Verify Canary File (checks Host own Dropbox mount is active)
if [[ -n "$CANARY_FILE" && ! -f "$CANARY_FILE" ]]; then
    log_error "Dropbox mount check failed: Canary file not found at ${CANARY_FILE}"
    log_error "Host Dropbox daemon may be stopped or unmounted. Aborting backup to prevent writing to root storage."
    send_telegram_message "⚠️ <b>[${PROXMOX_HOST}/${MY_HOSTNAME}] Backup Aborted!</b>\n\nError: Canary file not found at <code>${CANARY_FILE}</code>. Host Dropbox daemon may be down."
    exit 1
fi

log_info "Target Directory: ${TARGET_DIR}"
mkdir -p "$PROJECT_TARGET_DIR" "$DB_TARGET_DIR" "$METADATA_DIR"

# --- Telegram/Error Tracking ---
BACKUP_REPORT=""
HAS_ERRORS=0

# --- Env Parser Helper ---
# Safely extracts keys from a .env file, removing quotes and whitespace
parse_env_var() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        grep -E "^[[:space:]]*${key}=" "$file" | head -n 1 | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["\x27]//' -e 's/["\x27]$//'
    fi
}

# --- Process Backup for a single project ---
process_project_backup() {
    local project_dir="$1"
    local project_dir_basename
    project_dir_basename=$(basename "$project_dir")

    log_info "--------------------------------------------------------"
    log_info "Processing project: ${project_dir_basename}"

    # 1. Parse Project settings from its local .env file
    local env_file="${project_dir}/.env"
    local project_name
    project_name=$(parse_env_var "$env_file" "PROJECT_NAME")
    project_name="${project_name:-$project_dir_basename}" # Fallback to folder name if empty

    local project_id
    project_id=$(parse_env_var "$env_file" "PROJECT_ID")

    local db_name
    db_name=$(parse_env_var "$env_file" "DB_NAME")
    local db_user
    db_user=$(parse_env_var "$env_file" "DB_USER")
    local db_pass
    db_pass=$(parse_env_var "$env_file" "DB_PASS")

    # Define prefix for filenames and reports (e.g. "999-projectname")
    local backup_prefix="${project_name}"
    if [[ -n "${project_id:-}" ]]; then
        backup_prefix="${project_id}-${project_name}"
    fi

    log_info "Resolved Project Name: ${project_name} (ID: ${project_id:-None})"

    # Status tracking for Telegram report
    local proj_status="OK"
    local db_status="SKIPPED"

    # 2. Project Files Backup (Incremental / tar --listed-incremental)
    # Monthly snar filename creates a natural FULL backup on the 1st of the month
    local snar_file="${METADATA_DIR}/${backup_prefix}-$(date +%Y-%m).snar"
    local backup_type="incr"
    if [[ ! -f "$snar_file" ]]; then
        backup_type="full"
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local project_backup_file="${PROJECT_TARGET_DIR}/${backup_prefix}-project-${timestamp}-${backup_type}.tar.gz"

    # Build tar exclude arguments dynamically
    local exclude_args=()
    # Always exclude .git and mariadb_data relative to the project directory
    exclude_args+=( "--exclude=${project_dir_basename}/.git" )
    exclude_args+=( "--exclude=${project_dir_basename}/mariadb_data" )

    # Parse and add custom user excludes
    if [[ -n "$EXCLUDE_PATHS" ]]; then
        IFS=',' read -ra ADDR <<< "$EXCLUDE_PATHS"
        for path in "${ADDR[@]}"; do
            # Trim leading/trailing slashes
            local clean_path
            clean_path=$(echo "$path" | sed -e 's/^\///' -e 's/\/$//')
            if [[ -n "$clean_path" ]]; then
                exclude_args+=( "--exclude=${project_dir_basename}/${clean_path}" )
            fi
        done
    fi

    log_info "Creating project files backup (${backup_type})..."
    if timeout "$TAR_TIMEOUT" tar -czg "$snar_file" \
        "${exclude_args[@]}" \
        -f "$project_backup_file" \
        -C "$(dirname "$project_dir")" \
        "$project_dir_basename"; then
        log_info "Project files backup completed successfully: $(basename "$project_backup_file")"
    else
        log_error "Failed to create project files backup for ${project_name}!"
        proj_status="ERROR"
        HAS_ERRORS=1
    fi

    # 3. Database Backup (Full Daily)
    local db_container="${project_name}-db"
    
    # Check if database is configured, and if docker container is running
    if [[ -z "$db_name" || -z "$db_user" || -z "$db_pass" ]]; then
        log_info "No database configured (DB_NAME/DB_USER/DB_PASS not set in .env). Skipping database backup."
        db_status="N/A"
    elif ! command -v docker &> /dev/null; then
        log_warn "Docker command not found on host. Skipping database backup."
        db_status="SKIPPED (No Docker)"
    elif ! docker ps --format '{{.Names}}' | grep -q "^${db_container}$"; then
        log_warn "Database container '${db_container}' is not running. Skipping database backup."
        db_status="SKIPPED (Stopped)"
    else
        log_info "Creating full database dump..."
        
        # Create a temporary folder to store the SQL dump file before archiving
        local temp_db_dir
        temp_db_dir=$(mktemp -d "${TEMP_DIR}/docker-backup-db-XXXXXX")
        local temp_sql_file="${temp_db_dir}/${backup_prefix}-db.sql"
        local db_backup_file="${DB_TARGET_DIR}/${backup_prefix}-db-${timestamp}.tar.gz"

        # Stream the dump securely from the container. Credentials are passed
        # via stdin here-string to prevent exposing them in host shell process lists (ps aux).
        if timeout "$DB_TIMEOUT" docker exec -i "$db_container" sh -c '
            read -r DUMP_USER
            read -r DUMP_PASS
            read -r DUMP_DB
            if command -v mariadb-dump >/dev/null 2>&1; then
                exec mariadb-dump --single-transaction --quick --skip-ssl --max_allowed_packet=512M --init-command="SET SESSION net_write_timeout=86400,net_read_timeout=86400" -u"$DUMP_USER" -p"$DUMP_PASS" "$DUMP_DB"
            else
                exec mysqldump --single-transaction --quick --skip-ssl --max_allowed_packet=512M --init-command="SET SESSION net_write_timeout=86400,net_read_timeout=86400" -u"$DUMP_USER" -p"$DUMP_PASS" "$DUMP_DB"
            fi
        ' <<< "$(printf "%s\n%s\n%s\n" "$db_user" "$db_pass" "$db_name")" > "$temp_sql_file"; then
            
            # Compress the dump SQL file into a tar.gz package
            if tar -czf "$db_backup_file" -C "$temp_db_dir" "${backup_prefix}-db.sql"; then
                log_info "Database backup completed successfully: $(basename "$db_backup_file")"
                db_status="OK"
            else
                log_error "Failed to compress database SQL file!"
                db_status="ERROR (Compress)"
                HAS_ERRORS=1
            fi
        else
            log_error "Failed to dump database from container ${db_container}!"
            db_status="ERROR (Dump)"
            HAS_ERRORS=1
        fi
        
        # Clean up temporary directory and files
        rm -rf "$temp_db_dir"
    fi

    # 4. Enforce Retention (Keep last RETENTION_DAYS backups, i.e., delete on day RETENTION_DAYS+1)
    # Using -mtime +$((RETENTION_DAYS - 1)) deletes files older than RETENTION_DAYS days.
    # E.g. with RETENTION_DAYS=7, files modified 7 or more days ago are deleted, preserving 7 days of copies.
    local mtime_val=$((RETENTION_DAYS - 1))
    
    log_info "Enforcing retention policy (${RETENTION_DAYS} days) for ${project_name}..."
    find "$PROJECT_TARGET_DIR" -type f -name "${backup_prefix}-project-*.tar.gz" -mtime +"${mtime_val}" -delete 2>/dev/null || true
    find "$DB_TARGET_DIR" -type f -name "${backup_prefix}-db-*.tar.gz" -mtime +"${mtime_val}" -delete 2>/dev/null || true

    # Append status line to the Telegram report
    BACKUP_REPORT="${BACKUP_REPORT}
• <b>${backup_prefix}</b> (Files: ${proj_status} | DB: ${db_status})"
}

# --- Main Logic ---
log_info "========================================================"
log_info "Starting Docker Projects Backup Script"
log_info "========================================================"

if [[ ! -d "$PROJECTS_ROOT_DIR" ]]; then
    log_error "Projects root directory not found: ${PROJECTS_ROOT_DIR}"
    exit 1
fi

# Iterate over all directories under the projects root
for project_path in "${PROJECTS_ROOT_DIR}"/*; do
    if [[ ! -d "$project_path" ]]; then
        continue
    fi
    
    # Process only directories containing a .env file (signature of a setup project)
    if [[ -f "${project_path}/.env" ]]; then
        process_project_backup "$project_path"
    else
        log_info "Skipping directory (no .env file found): $(basename "$project_path")"
    fi
done

# Clean up metadata files (.snar) older than 60 days to prevent clutter
log_info "Cleaning up old backup metadata files..."
find "$METADATA_DIR" -type f -name "*.snar" -mtime +60 -delete 2>/dev/null || true

# --- Send Telegram Summary Notification ---
if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    status_emoji="🟢"
    status_text="Completed successfully"
    if [[ "$HAS_ERRORS" -eq 1 ]]; then
        status_emoji="🔴"
        status_text="Completed with ERRORS"
    fi

    if [[ -z "${BACKUP_REPORT:-}" ]]; then
        BACKUP_REPORT="\n• No projects found to backup."
    fi

    msg=$(printf "🚀 <b>[%s/%s] Projects Backup</b>\n\nStatus: %s %s\n\n<b>Project details:</b>%s" \
        "$PROXMOX_HOST" "$MY_HOSTNAME" "$status_emoji" "$status_text" "$BACKUP_REPORT")

    send_telegram_message "$msg"
fi

log_info "========================================================"
log_info "Backup process completed successfully!"
log_info "========================================================"
