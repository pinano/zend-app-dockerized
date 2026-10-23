#!/usr/bin/env bash
# ===================================================================================
# Interactive .env File Initializer
# ===================================================================================

set -euo pipefail

# ANSI Color Codes (conditional on interactive TTY)
if [[ -t 1 ]]; then
    BOLD="\033[1m"
    CYAN="\033[36m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    GRAY="\033[90m"
    RESET="\033[0m"
else
    BOLD=""
    CYAN=""
    GREEN=""
    YELLOW=""
    GRAY=""
    RESET=""
fi

# Clear screen or print header
echo -e "${BOLD}${CYAN}========================================================"
echo -e "      Docker Stack Environment Initializer"
echo -e "========================================================${RESET}"

ENV_FILE=".env"
DIST_FILE=".env.dist"

# Check if .env.dist exists
if [[ ! -f "$DIST_FILE" ]]; then
    echo -e "${BOLD}${YELLOW}❌ Error: ${DIST_FILE} not found! Please run this script from the project root.${RESET}"
    exit 1
fi

# Check if .env already exists
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${BOLD}${YELLOW}⚠️  A .env file already exists in this directory.${RESET}"
    read -r -p "Do you want to overwrite it and reinitialize? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[yY](es)?$ ]]; then
        echo -e "${GREEN}Aborted. Your existing .env file has been left untouched.${RESET}"
        exit 0
    fi
fi

# Copy dist file to .env
echo -e "${GRAY}Copying ${DIST_FILE} to ${ENV_FILE}...${RESET}"
cp "$DIST_FILE" "$ENV_FILE"

# Helper: Generate random password
generate_random_password() {
    python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || \
    openssl rand -base64 12 | tr -d '+/=' | cut -c1-16 || \
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16
}

# Helper: Update value in .env
set_env_var() {
    local key="$1"
    local val="$2"
    local escaped_val
    escaped_val=$(printf '%s' "$val" | sed -e 's/[\\/&|]/\\&/g')
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|^[[:space:]]*${key}=.*|${key}=${escaped_val}|" "$ENV_FILE"
    else
        sed -i "s|^[[:space:]]*${key}=.*|${key}=${escaped_val}|" "$ENV_FILE"
    fi
}

# Helper: Prompt standard variable
prompt_var() {
    local var_ref="$1"
    local key="$2"
    local default_val="$3"
    local description="$4"
    local user_input
    
    echo -e "\n${BOLD}${CYAN}👉 ${key}${RESET}"
    if [[ -n "$description" ]]; then
        echo -e "${GRAY}${description}${RESET}"
    fi
    
    read -r -p "Enter value [${default_val}]: " user_input
    local final_val="${user_input:-$default_val}"
    
    set_env_var "$key" "$final_val"
    echo -e "${GREEN}✓ ${key} set to: ${final_val}${RESET}"
    
    # Store in variable (via indirect reference)
    eval "${var_ref}=\"\$final_val\""
}

# Helper: Prompt password
prompt_password() {
    local var_ref="$1"
    local key="$2"
    local description="$3"
    local default_val
    default_val=$(generate_random_password)
    local user_input
    
    echo -e "\n${BOLD}${CYAN}👉 ${key}${RESET}"
    if [[ -n "$description" ]]; then
        echo -e "${GRAY}${description}${RESET}"
    fi
    
    read -r -p "Enter password [${default_val}]: " user_input
    local final_val="${user_input:-$default_val}"
    
    set_env_var "$key" "$final_val"
    echo -e "${GREEN}✓ ${key} set to: ${final_val}${RESET}"
    
    eval "${var_ref}=\"\$final_val\""
}

# --- Default Value Calculations ---
dir_name=$(basename "$(pwd)")
if [[ "$dir_name" == "docker" ]]; then
    dir_name=$(basename "$(dirname "$(pwd)")")
fi
default_pid="999"
default_pname="$dir_name"

if [[ "$dir_name" =~ ^([0-9]+)-(.*)$ ]]; then
    default_pid="${BASH_REMATCH[1]}"
    default_pname="${BASH_REMATCH[2]}"
else
    default_pname=$(echo "$dir_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/[^a-z0-9-]//g')
fi
default_pname=$(echo "$default_pname" | tr '_' '-')

# Load existing PHP_VERSION and MARIADB_VERSION in dist as default fallbacks
dist_php=$(grep '^PHP_VERSION=' "$DIST_FILE" | cut -d'=' -f2 | tr -d '"'\''\r ' || echo "8.5")
dist_mariadb=$(grep '^MARIADB_VERSION=' "$DIST_FILE" | cut -d'=' -f2 | tr -d '"'\''\r ' || echo "12.3.3")

# --- Prompts ---

# 1. PROJECT_ID
while true; do
    prompt_var "PROJECT_ID" "PROJECT_ID" "$default_pid" "A unique numeric identifier for the project between 1 and 999 (e.g. 101, 999). Used to namespace port assignments (33xxx / 22xxx)."
    if [[ "$PROJECT_ID" =~ ^[0-9]+$ ]] && [ "$PROJECT_ID" -ge 1 ] && [ "$PROJECT_ID" -le 999 ]; then
        break
    else
        echo -e "${BOLD}${YELLOW}❌ Error: PROJECT_ID must be a numeric integer between 1 and 999 to stay within valid TCP port ranges (33xxx / 22xxx <= 65535).${RESET}"
    fi
done

# 2. PROJECT_NAME
while true; do
    prompt_var "PROJECT_NAME" "PROJECT_NAME" "$default_pname" "The name of the project. Used for container names, networks, and Traefik domains. Use lowercase letters, numbers, and hyphens (-) only. Do NOT use underscores (_)."
    if [[ "$PROJECT_NAME" =~ _ ]]; then
        echo -e "${BOLD}${YELLOW}❌ Error: PROJECT_NAME cannot contain underscores (_). Use hyphens (-) instead (e.g., 'my-app' instead of 'my_app').${RESET}"
    elif [[ ! "$PROJECT_NAME" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${BOLD}${YELLOW}❌ Error: PROJECT_NAME must contain only lowercase alphanumeric characters and hyphens (-).${RESET}"
    else
        break
    fi
done

# 3. APP_ENV
prompt_var "APP_ENV" "APP_ENV" "development" "Application environment mode. Options: development, staging, production."

# 3b. APP_ENV_ZEND_INI (Optional)
echo -e "\n${BOLD}${CYAN}👉 APP_ENV_ZEND_INI (Optional)${RESET}"
echo -e "${GRAY}Custom section in application.ini (e.g., dev-juanjo). Press Enter to leave empty and use APP_ENV:${RESET}"
read -r -p "Enter Zend application.ini environment []: " user_zend_ini
if [[ -n "$user_zend_ini" ]]; then
    set_env_var "APP_ENV_ZEND_INI" "$user_zend_ini"
    echo -e "${GREEN}✓ APP_ENV_ZEND_INI set to: ${user_zend_ini}${RESET}"
else
    set_env_var "APP_ENV_ZEND_INI" ""
    echo -e "${GREEN}✓ APP_ENV_ZEND_INI left empty (will default to APP_ENV)${RESET}"
fi

# 4. PHP_VERSION
prompt_var "PHP_VERSION" "PHP_VERSION" "$dist_php" "The PHP execution engine version to run in the application container (e.g., 5.6, 7.4, 8.5)."

# 5. MARIADB_VERSION
echo -e "\n${BOLD}${CYAN}👉 MARIADB_VERSION${RESET}"
echo -e "${GRAY}Select the MariaDB database engine version for this project:${RESET}"
echo -e "  ${BOLD}1)${RESET} 12.3.3   ${GRAY}(Latest rolling release)${RESET}"
echo -e "  ${BOLD}2)${RESET} 10.2.44  ${GRAY}(Legacy MariaDB 10.2.X - Maximum ZF1 / MySQL 5.x compatibility)${RESET}"
echo -e "  ${BOLD}3)${RESET} 11.4     ${GRAY}(Current Long Term Support - LTS)${RESET}"
echo -e "  ${BOLD}4)${RESET} 10.11    ${GRAY}(LTS - High compatibility with legacy MySQL 5.7 apps)${RESET}"
echo -e "  ${GRAY}Or type any custom MariaDB tag (e.g., 10.6, 10.5, etc.)${RESET}"

read -r -p "Select option [1-4] or enter version [${dist_mariadb}]: " user_mdb_input
case "${user_mdb_input:-$dist_mariadb}" in
    1) MARIADB_VERSION="12.3.3" ;;
    2) MARIADB_VERSION="10.2.44" ;;
    3) MARIADB_VERSION="11.4" ;;
    4) MARIADB_VERSION="10.11" ;;
    *) MARIADB_VERSION="${user_mdb_input:-$dist_mariadb}" ;;
esac
set_env_var "MARIADB_VERSION" "$MARIADB_VERSION"
echo -e "${GREEN}✓ MARIADB_VERSION set to: ${MARIADB_VERSION}${RESET}"

# 6. COMPOSE_PROFILES
prompt_var "COMPOSE_PROFILES" "COMPOSE_PROFILES" "sftp" "Orchestration profiles to enable. 'sftp' starts an SFTP container for secure remote file access. Use 'none' to disable auxiliary services, or separate multiple with commas."

# 7. DB_NAME
prompt_var "DB_NAME" "DB_NAME" "$PROJECT_NAME" "The name of the database schema to automatically create on startup."

# 8. DB_USER
prompt_var "DB_USER" "DB_USER" "$PROJECT_NAME" "The credentials username for application database access."

# 9. DB_PASS
prompt_password "DB_PASS" "DB_PASS" "The secure password for the database user account."

# 10. DB_ROOT_PASS
prompt_password "DB_ROOT_PASS" "DB_ROOT_PASS" "The root superuser administration password for MariaDB."

# 11. SFTP_USER
prompt_var "SFTP_USER" "SFTP_USER" "$PROJECT_NAME" "The authorized username allowed to log in and upload files via SFTP."

# 12. SFTP_PASS
prompt_password "SFTP_PASS" "SFTP_PASS" "The SFTP authentication credentials password."

echo -e "\n${BOLD}${GREEN}========================================================"
echo -e "   ✓ .env file has been initialized successfully!"
echo -e "========================================================${RESET}"
echo -e "${GRAY}Please review the created .env file before starting the containers.${RESET}\n"
