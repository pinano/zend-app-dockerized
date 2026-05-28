# Monitoring with Zabbix Agent 2 (Host)

This guide explains how to configure your Docker server (host) to monitor the different Zend Framework-based stacks with Zabbix 7 using **Zabbix Agent 2**.

By using Zabbix Agent 2 from the host, you can access both system-level resources and Docker socket metrics, allowing detailed monitoring of each container's health, CPU, RAM, and specific services such as **MariaDB**, **PHP-FPM**, and web availability (**Healthcheck**).

## 1. Installing Zabbix Agent 2 on the Server (Host)

First, install the Zabbix 7.0 repository according to your distribution (e.g., Ubuntu/Debian):

```bash
# Example for Ubuntu 24.04:
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo apt update
```

Install the agent and the Docker plugin (the plugin is included, but in some distros it is a separate package `zabbix-agent2-plugin-*`, review it according to your system. Generally, installing the base agent is sufficient):

```bash
sudo apt install zabbix-agent2 zabbix-agent2-plugin-docker zabbix-agent2-plugin-mysql
```

Add the `zabbix` user to the `docker` group so that the agent can read container metrics through the Docker socket:

```bash
sudo usermod -aG docker zabbix
```

## 2. Agent Configuration (`/etc/zabbix/zabbix_agent2.conf`)

Edit the Zabbix Agent 2 configuration file, specifying the IP of your Zabbix server and the hostname of the current server:

```ini
Server=IP_ZABBIX_SERVER
ServerActive=IP_ZABBIX_SERVER
Hostname=YourDockerServerHostName
```

Restart and enable the service:

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

> **Important!** Since you added the `zabbix` user to the `docker` group, you must ensure you restart the `zabbix-agent2` service *after* adding the group, otherwise it will not have permissions to read the socket.

## 3. Configuration in the Zabbix 7 Web Interface

Go to your Zabbix web interface and add a new Host:

1. **Host name**: Must match exactly the `Hostname` field configured in `zabbix_agent2.conf`.
2. **Interfaces**: Add an interface of type **Agent**, specifying the IP or DNS of your Docker server.
3. **Templates**: Apply the following templates:
    - **Linux by Zabbix agent** (base OS monitoring)
    - **Docker by Zabbix agent 2** (will automatically discover each container, measuring CPU, RAM, Restart loops, etc.)

Save the Host. After a few minutes, Zabbix will automatically discover each project thanks to Docker.

You will see containers such as `[PROJECT_NAME]-app`, `[PROJECT_NAME]-db`, etc. independently in the Discovery section.

---

## 4. Advanced Stack Monitoring (Optional but very useful)

Since this is a multi-stack architecture, Docker gives you generic metrics, but you can extract valuable data from within:

### A. Monitor App Healthcheck (Per Project)
In the Host you created, go to **Web Scenarios** or add an **Item of type HTTP Agent**.
- **URL**: `https://your-stack-domain.com/healthcheck.php` (if Traefik already exposes the service).
- **Required status codes**: `200`.
- This will alert you if PHP, the database, or Apache fails and the endpoint code returns 500.

### B. Monitor MariaDB (`[PROJECT_NAME]-db`)

The `MySQL by Zabbix agent 2` template requires a database user in MariaDB. Since you use multiple databases per project, you can create the user by connecting to each container:

```bash
docker exec -it [PROJECT_NAME]-db mysql -u root -p[YOUR_ROOT_PASS]
```
Execute:
```sql
CREATE USER 'zbx_monitor'@'%' IDENTIFIED BY '<STRONG_PASSWORD>';
GRANT PROCESS, SHOW DATABASES, SHOW VIEW, REPLICATION CLIENT ON *.* TO 'zbx_monitor'@'%';
FLUSH PRIVILEGES;
```

For Zabbix to connect from the host to the container, use Macro items on your Zabbix Server in the "Macros" tab of the created host:
- `{$MYSQL.DSN}` = `tcp://localhost:33<PROJECT_ID>` (By default, each stack binds MariaDB using the `PROJECT_ID` in `.env`, e.g., `33999`).
- `{$MYSQL.USER}` = `zbx_monitor`
- `{$MYSQL.PASSWORD}` = `<STRONG_PASSWORD>`

> **Note:** Since there are multiple MariaDB containers on different ports, Zabbix Agent 2 can have a multi-database profile by passing the URI in the Key, or by duplicating the Host in Zabbix, assigning it the MySQL template but specifying the corresponding ports for each client.

### C. PHP-FPM Metrics
To enable PHP-FPM status metrics (requires configuration override):
1. Ensure you have `pm.status_path = /status` active in the `/usr/local/etc/php-fpm.d/zz-docker.conf` file of your container.
2. Apply the `PHP-FPM by HTTP` template or host the proxy in the Zabbix interface.

## Summary of Benefits
1. You only maintain a single agent installed on the host server.
2. You take advantage of the Zabbix 7.0 Low-Level Discovery (LLD) system, which will automatically create CPU, Memory usage, and state (Running/Restarting) items for each new tenant/project you deploy on this server.
3. Minimal resource consumption inside the containers (let the agent read from the host rather than the container).
