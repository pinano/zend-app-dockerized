# Sizing Guide: Multi-Tenancy on LXC

This guide helps you configure each Docker stack based on its traffic profile. Designed for running dozens of Zend Framework 1.x applications on a single LXC container.

---

## 1. Application Profiles

| Parameter | Small | Medium | Large |
|-----------|-------|--------|-------|
| **Traffic** | < 500 visits/day | 500–5.000 visits/day | > 5.000 visits/day |
| `APP_CPUS` | 0.5 | 1.0 | 2.0 |
| `APP_MEMORY` | 256M | 512M | 1G |
| `APP_MEMORY_RESERVATION` | 64M | 128M | 256M |
| `CRON_CPUS` | 0.1 | 0.25 | 0.5 |
| `CRON_MEMORY` | 128M | 256M | 512M |
| `DB_CPUS` | 0.5 | 2.0 | 4.0 |
| `DB_MEMORY` | 512M | 1G | 2G |
| `DB_INNODB_BUFFER_POOL_SIZE` | 128M | 256M | 512M |
| `DB_MAX_CONNECTIONS` | 50 | 100 | 300 |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | 128 | 256 | 512 |

Copy these values to your project's `.env` file according to its traffic profile.

---

## 2. Capacity Planning

### Per-Stack Memory Footprint (approximate)

| Component | Small | Medium | Large |
|-----------|-------|--------|-------|
| App (PHP-FPM + Apache) | ~200M | ~400M | ~700M |
| Cron (CLI) | ~80M | ~150M | ~300M |
| MariaDB | ~400M | ~800M | ~1.5G |
| SFTP | ~20M | ~20M | ~20M |
| Redis (optional) | ~50M | ~100M | ~200M |
| **Total per stack** | **~750M** | **~1.5G** | **~2.7G** |

### Example: 24 cores / 64 GB LXC Host

Reserve ~4GB for the host OS + Docker + Traefik = **~60 GB available** for stacks.

| Scenario | Stacks | Total RAM | Total CPUs |
|----------|--------|-----------|------------|
| All Small | ~60 | ~45G | ~30 (overcommit OK) |
| Mixed: 30 Small + 10 Medium + 3 Large | 43 | ~46G | ~34 |
| All Medium | ~35 | ~52G | ~24 |
| All Large | ~18 | ~49G | ~24 |

> [!TIP]
> CPU limits can be **overcommitted** safely because most stacks are idle most of the time. Memory limits **cannot** — Docker will kill containers that exceed their limit (OOM).

---

## 3. Key Tuning Rules

### MariaDB Buffer Pool
The `DB_INNODB_BUFFER_POOL_SIZE` is the **most impactful** tuning parameter. Set it to **50-70%** of `DB_MEMORY`:

```
DB_MEMORY=1G     → DB_INNODB_BUFFER_POOL_SIZE=512M-700M
DB_MEMORY=512M   → DB_INNODB_BUFFER_POOL_SIZE=256M-350M
```

### OPcache Memory
`PHP_OPCACHE_MEMORY_CONSUMPTION` should match the application size:
- Small ZF1 app (~500 PHP files): **128** MB is enough
- Medium ZF1 app (~2000 PHP files): **256** MB
- Large ZF1 app (~5000+ PHP files): **512** MB

### Max Connections
`DB_MAX_CONNECTIONS` should account for:
- Each Apache worker (PHP-FPM child) holds one DB connection
- Cron jobs running in parallel
- Rule of thumb: **2x** the number of concurrent PHP processes

---

## 4. Monitoring

### Quick Health Check
```bash
# Real-time resource usage for all stacks on the host
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

### Per-Stack Deep Dive
```bash
# Check a specific project's containers
docker stats $(docker ps --filter "name=myproject" -q)
```

### Detect Over-Provisioning
If `MemUsage` is consistently below 30% of `MemLimit`, the stack is over-provisioned. Consider reducing `APP_MEMORY` and `DB_MEMORY` to free resources for other stacks.

### Detect Under-Provisioning
If you see OOM kills in `docker events` or `dmesg`, the stack needs more memory:
```bash
# Check for OOM events
docker events --filter event=oom --since 24h
```
