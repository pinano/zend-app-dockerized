# Monitorización con Zabbix Agent 2 (Host)

Esta guía explica cómo configurar tu servidor Docker (host) para monitorizar los distintos stacks basados en Zend Framework con Zabbix 7 utilizando **Zabbix Agent 2**.

Al utilizar Zabbix Agent 2 desde el host, podrás acceder tanto a los recursos a nivel de sistema como a las métricas del socket de Docker, permitiendo una monitorización detallada de la salud de cada contenedor, CPU, RAM y de servicios específicos como **MariaDB**, **PHP-FPM** y la disponibilidad web (**Healthcheck**).

## 1. Instalación de Zabbix Agent 2 en el Servidor (Host)

Primero, instala el repositorio de Zabbix 7.0 acorde a tu distribución (ej. Ubuntu/Debian):

```bash
# Ejemplo para Ubuntu 24.04:
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo apt update
```

Instala el agente y el plugin de Docker (el plugin viene incluido, pero en algunas distros es un paquete separado `zabbix-agent2-plugin-*`, revísalo según tu sistema. Generalmente basta con instalar el agente base):

```bash
sudo apt install zabbix-agent2 zabbix-agent2-plugin-docker zabbix-agent2-plugin-mysql
```

Añade el usuario `zabbix` al grupo `docker` para que el agente pueda leer las métricas de los contenedores a través del socket de Docker:

```bash
sudo usermod -aG docker zabbix
```

## 2. Configuración del Agente (`/etc/zabbix/zabbix_agent2.conf`)

Edita el fichero de configuración de Zabbix Agent 2 indicando la IP de tu servidor Zabbix y el hostname del servidor actual:

```ini
Server=IP_ZABBIX_SERVER
ServerActive=IP_ZABBIX_SERVER
Hostname=NombreDeEsteServidorDocker
```

Reinicia y activa el servicio:

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

> **¡Importante!** Como has añadido el usuario `zabbix` al grupo `docker`, debes asegurarte de haber reiniciado el servicio `zabbix-agent2` *después* de añadir el grupo, de lo contrario no tendrá permisos para leer el socket.

## 3. Configuración en la interfaz de Zabbix 7

Ve a tu servidor Zabbix web y añade un nuevo Host:

1. **Host name**: Debe coincidir exactamente con el campo `Hostname` que configuraste en `zabbix_agent2.conf`.
2. **Interfaces**: Añade una interfaz de tipo **Agent**, especificando la IP o DNS de tu servidor Docker.
3. **Templates**: Aplica los siguientes templates:
    - **Linux by Zabbix agent** (monitorización base del SO)
    - **Docker by Zabbix agent 2** (descubrirá cada contenedor automáticamente midiendo CPU, RAM, Restart loops, etc.)

Guarda el Host. Pasados unos minutos, Zabbix descubrirá cada proyecto automáticamente gracias a Docker. 

Verás contenedores como `[PROJECT_NAME]-app`, `[PROJECT_NAME]-db`, etc. de manera independiente en la sección de Discovery.

---

## 4. Monitorización avanzada por stack (Opcional pero muy útil)

Dado que es una arquitectura multi-stack, Docker te da métricas genéricas, pero puedes extraer datos valiosos desde dentro:

### A. Monitorizar Healthcheck de la app (Por cada proyecto)
En el Host que has creado, dirígete a **Web Scenarios** o añade un **Item tipo HTTP Agent**.
- **URL**: `https://dominio-del-stack.com/healthcheck.php` (si Traefik ya expone el servicio).
- **Required status codes**: `200`.
- Esto te alertará si PHP, la base de datos o Apache fallan y el código del endpoint devuelve 500.

### B. Monitorizar MariaDB (`[PROJECT_NAME]-db`)

El template `MySQL by Zabbix agent 2` requiere un usuario de base de datos en MariaDB. Como usas múltiples bases de datos por proyecto, puedes crear el usuario conectándote a cada contenedor:

```bash
docker exec -it [PROJECT_NAME]-db mysql -u root -p[TU_ROOT_PASS]
```
Ejecuta:
```sql
CREATE USER 'zbx_monitor'@'%' IDENTIFIED BY '<STRONG_PASSWORD>';
GRANT PROCESS, SHOW DATABASES, SHOW VIEW, REPLICATION CLIENT ON *.* TO 'zbx_monitor'@'%';
FLUSH PRIVILEGES;
```

Para que Zabbix conecte desde el *host* hacia el contenedor, usa items Macro en tu Zabbix Server en la pestaña "Macros" del host creado:
- `{$MYSQL.DSN}` = `tcp://localhost:33<PROJECT_ID>` (Por defecto cada stack hace bind de MariaDB usando el PROJECT_ID en `.env`, ej. `33999`).
- `{$MYSQL.USER}` = `zbx_monitor`
- `{$MYSQL.PASSWORD}` = `<STRONG_PASSWORD>`

> **Nota:** Al haber varios contenedores de MariaDB en distintos puertos, Zabbix Agent 2 puede tener un perfil multi-base de datos pasándole la URI en la Key, o duplicando el Host en Zabbix asignándole el template de MySQL pero especificando los puertos correspondientes de cada cliente.

### C. FPM Metrics
Para habilitar stats de FPM (requerirá un override en configuración):
1. Asegúrate de tener `pm.status_path = /status` activo en el archivo `/usr/local/etc/php-fpm.d/zz-docker.conf` de tu contenedor.
2. Aplica el Template `PHP-FPM by HTTP` u hostea el proxy en la interfaz Zabbix.

## Resumen de Beneficios
1. Sólo mantienes un agente instalado en el servidor anfitrión.
2. Te aprovechas del sistema *Low-Level Discovery (LLD)* de Zabbix 7.0 que creará Items de CPU, uso de Memoria y estado (Running/Restarting) de **forma automática** por cada nuevo inquilino/proyecto que despliegues en este servidor.
3. Consumo mínimo de recursos en los contenedores (deja que el agente lea del host y no del contenedor).
