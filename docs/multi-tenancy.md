# Multi-Tenancy on Single Host

This stack is designed to be easily replicable, allowing you to host dozens of legacy Zend Framework 1.x applications on a single server without port collisions or dependency hell.

## Scenario: Running 30+ Legacy ZF1 Apps

Running multiple applications on the same server requires careful resource management and a centralized router (reverse proxy) to direct traffic based on domains rather than ports.

### Step 1: Central Proxy (Traefik)
Do not expose the `8080` port directly to the host for every project. Instead, keep all traffic inside Docker networks.
This stack comes pre-configured for **Traefik**, a modern reverse proxy that automatically discovers Docker containers.
By relying on the labels provided in `docker-compose.yml`, Traefik will route `yourdomain.com` directly to the correct container.

### Step 2: Use Isolated Docker Networks
Each project establishes its own `backnet` (e.g., `projecta_backnet`, `projectb_backnet`). This ensures that:
- Project A cannot access Project B's database.
- Database credentials can be identical across projects without risk of cross-contamination if networks are isolated.

### Step 3: Resource Allocation
When running multiple applications, it's critical to prevent a single buggy application from consuming all the server's CPU or RAM.
Always use the predefined sizing profiles when setting up a new tenant:
- Run `make size-small` for low-traffic sites to cap memory and CPU usage aggressively.
- Run `make size-show` periodically to audit custom allocations.

### Step 4: Avoid Port Collisions
By default, the `docker-compose.yml` only exposes the MariaDB and SFTP ports directly to the `127.0.0.1` host interface for debugging purposes.
If you are running multiple projects, you **must** change `DB_HOST_PORT` and `SFTP_PORT` in your `.env` file for each project to ensure they don't collide.
* Example Project A: `DB_HOST_PORT=33001`
* Example Project B: `DB_HOST_PORT=33002`
