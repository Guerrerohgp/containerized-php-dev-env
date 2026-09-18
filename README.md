# Containerized PHP Development Environment (Docker/Podman)

A generic, configurable Docker and Podman development environment for PHP projects. Supports multiple PHP versions, databases (MySQL &amp; PostgreSQL), and works across macOS, Linux, and Windows.

> **WARNING:** This is a development environment only. Do NOT use in production. See [SECURITY.md](SECURITY.md) for details.

## Features

- **Debian Slim Base**: Official PHP-FPM images, including legacy PHP 7.4; PHP 8.2 by default
- **Dual Database Support**: MySQL 8.0 and PostgreSQL 16 running simultaneously
- **Built-in Services**: Redis, Mailpit (email testing), SSL proxy
- **Container Engines**: Docker and Podman with automatic Compose detection
- **Cross-Platform**: Works on macOS, Linux, and Windows
- **Framework Agnostic**: Laravel, WordPress, Zend, generic PHP
- **WP-CLI &amp; Composer**: Pre-installed in container
- **Xdebug Ready**: Pre-configured for debugging

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS/Windows) or Docker Engine (Linux), with Docker Compose v2.0+; **or [Podman](https://podman.io/) with a Compose provider** (see [Podman Support](#podman-support))
- Ports 8080, 8081, 8443, 3306, 5432, 6379, 1025, 8025 available by default

## Quick Start

```bash
# 1. Clone or copy this project
git clone https://github.com/Guerrerohgp/phplocaldocker.git my-project
cd my-project

# 2. Create environment file
cp .env.example .env

# 3. Build and start containers
./sail build
./sail ssl
./sail up

# 4. Open in browser
open http://localhost:8080
```

**Windows (CMD):**

```cmd
copy .env.example .env
sail.bat build
sail.bat ssl
sail.bat up
```

## Podman Support

Podman is supported by `./sail` (macOS/Linux) and `sail.bat` (Windows CMD), using the same `docker-compose.yml` as Docker.

Install Podman and a Compose provider: either `podman-compose`, or a provider available through `podman compose`. The latter delegates to an external Compose tool; installing Podman alone does not supply Compose. See the [Podman Compose documentation](https://docs.podman.io/en/latest/markdown/podman-compose.1.html).

On macOS and Windows, create a [Podman machine](https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html) if you do not already have one, then start it:

```bash
podman machine init   # First-time setup only
podman machine start # If the machine is stopped
```

From the project directory, follow [Quick Start](#quick-start), including `./sail ssl` (or `sail.bat ssl`) before starting the stack: the HTTPS proxy requires the generated certificates. Open [http://localhost:8080](http://localhost:8080) for HTTP; HTTPS uses port 8443 with a self-signed certificate.

Both launchers detect Compose commands in this order:

1. `podman-compose`
2. `podman compose`
3. `docker-compose`
4. `docker compose`

When both engines are installed, Podman takes priority. In the Bash launcher, you can explicitly select a command through the shell environment:

```bash
DOCKER_COMPOSE="podman compose" ./sail up
DOCKER_COMPOSE="docker compose" ./sail up
```

In Windows CMD, select a command for the current session:

```cmd
set "DOCKER_COMPOSE=podman compose"
sail.bat up
```

Use `set "DOCKER_COMPOSE="` to return to automatic detection. The variable keeps its historical name for both engines. Backup and restore commands launched through either Sail launcher inherit the selection.

The default host ports (`APP_PORT=8080`, `SSL_PORT=8443`) avoid privileged ports for rootless Podman. Bind mounts include the shared SELinux label option (`:z`). Container startup, bind-mount write permissions, and Xdebug host connectivity should be verified on your target platform; these depend on the runtime and host configuration.

## Configuration

Edit the `.env` file to customize your setup:

### Project Settings


| Variable         | Default      | Description                |
| ---------------- | ------------ | -------------------------- |
| `PROJECT_NAME`   | `myapp`      | Project identifier         |
| `PROJECT_DOMAIN` | `myapp.test` | Domain for SSL certificate |


### PHP Settings


| Variable                  | Default | Description                             |
| ------------------------- | ------- | --------------------------------------- |
| `PHP_VERSION`             | `8.2`   | PHP version: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5   |
| `NODE_VERSION`            | `20`    | Node.js version                         |
| `PHP_POST_MAX_SIZE`       | `100M`  | Maximum POST data size                  |
| `PHP_UPLOAD_MAX_FILESIZE` | `100M`  | Maximum upload file size                |
| `PHP_MAX_EXECUTION_TIME`  | `300`   | Maximum script execution time (seconds) |
| `PHP_SHORT_OPEN_TAG`      | `On`    | Enable short open tags (`<?`)           |


### App Image Base

The app automatically selects an official Debian-based PHP-FPM image using `PHP_VERSION`:

| PHP version | Debian base |
|-------------|-------------|
| 7.4, 8.0 | Bullseye (`php:<version>-fpm-bullseye`) |
| 8.1, 8.2 (default), 8.3, 8.4, 8.5 | Bookworm Slim (`php:<version>-fpm-bookworm`) |

To use PHP 7.4, set `PHP_VERSION=7.4` in `.env`, then run `./sail build app` and `./sail up --force-recreate app` (or the equivalent `sail.bat` commands). No separate Debian setting is needed. Legacy PHP versions use archived images; compatibility here does not imply ongoing upstream security support. Bullseye package sources are pinned to Debian’s 2026-09-01 snapshot in `docker/php/bullseye-sources.list`, since the live security mirror can no longer serve all indexed packages.

PHP extensions are installed with the version-pinned [PHP extension installer](https://github.com/mlocati/docker-php-extension-installer), which removes temporary build dependencies. PHP 7.4, 8.0, and 8.1 use explicitly selected compatible Xdebug versions. Node.js/npm are copied from the matching `node:${NODE_VERSION}-bookworm-slim` image. Composer, WP-CLI, Nginx, Supervisor, and Xdebug remain included.

CLI and FPM share `/usr/local/etc/php/conf.d/`. FPM configuration is in `/usr/local/etc/php-fpm.d/`, and Nginx connects to FPM on `127.0.0.1:9000` inside the app container.

Rebuild and recreate the app after switching from the Ubuntu image:

```bash
./sail build app
./sail up --force-recreate app
```

To validate a standalone default build without starting databases or publishing ports:

```bash
docker build -t phplocaldocker-smoke docker/php
bash tests/image-smoke.sh phplocaldocker-smoke docker 8.2

# Validate the legacy PHP path too
docker build --build-arg PHP_VERSION=7.4 -t phplocaldocker-smoke:7.4 docker/php
bash tests/image-smoke.sh phplocaldocker-smoke:7.4 docker 7.4
```

For Podman, use `podman build` and pass `podman` as the test script's second argument. The test checks default PHP settings, extensions, development tools, and Nginx-to-FPM requests. Final image size depends on the selected versions and included tools.

### Database Settings


| Variable            | Default  | Description              |
| ------------------- | -------- | ------------------------ |
| `MYSQL_VERSION`     | `8.0`    | MySQL version            |
| `DB_DATABASE`       | `myapp`  | MySQL database name      |
| `DB_USERNAME`       | `myapp`  | MySQL username           |
| `DB_PASSWORD`       | `secret` | MySQL password           |
| `POSTGRES_VERSION`  | `16`     | PostgreSQL version       |
| `POSTGRES_DB`       | `myapp`  | PostgreSQL database name |
| `POSTGRES_USER`     | `myapp`  | PostgreSQL username      |
| `POSTGRES_PASSWORD` | `secret` | PostgreSQL password      |


### Port Mappings


| Service      | Default Port | Env Variable                     |
| ------------ | ------------ | -------------------------------- |
| HTTP         | 8080         | `APP_PORT`                       |
| HTTPS        | 8443         | `SSL_PORT`                       |
| HMR          | 8081         | `HMR_PORT`                       |
| MySQL        | 3306         | `FORWARD_DB_PORT`                |
| PostgreSQL   | 5432         | `FORWARD_POSTGRES_PORT`          |
| Redis        | 6379         | `FORWARD_REDIS_PORT`             |
| Mailpit SMTP | 1025         | `FORWARD_MAILPIT_PORT`           |
| Mailpit Web  | 8025         | `FORWARD_MAILPIT_DASHBOARD_PORT` |


## Commands

### Container Management

```bash
./sail up          # Start containers
./sail down        # Stop containers
./sail build       # Build containers
./sail ps          # List running containers
./sail logs        # View container logs
./sail stop        # Stop containers
./sail restart     # Restart containers
```

### Development

```bash
./sail shell       # Open bash shell in app container
./sail php -v      # Run PHP commands
./sail composer install    # Run Composer
./sail artisan migrate     # Run Laravel Artisan
./sail wp plugin list      # Run WP-CLI
```

### Database

```bash
./sail mysql       # Open MySQL CLI
./sail psql        # Open PostgreSQL CLI
./sail redis       # Open Redis CLI
```

### Backup &amp; Restore

```bash
./sail backup                          # Backup all databases
./sail restore --list                  # List available backups
./sail restore <mysql> <postgres>      # Restore both databases
./sail restore --mysql <file>          # Restore MySQL only
./sail restore --postgres <file>       # Restore PostgreSQL only
```

**Windows (CMD):**

```cmd
sail.bat backup
sail.bat restore --list
sail.bat restore myapp_mysql_20240115_120000.sql myapp_postgres_20240115_120000.sql
```

Backups are stored in the `backups/` directory with timestamps in the format:

- `myapp_mysql_YYYYMMDD_HHMMSS.sql.gz`
- `myapp_postgres_YYYYMMDD_HHMMSS.sql`

### Utilities

```bash
./sail ssl         # Generate SSL certificates
./sail mailpit     # View Mailpit logs
./sail help        # Show all commands
```

## Services

### PHP Application (`app`)

- Nginx web server
- PHP-FPM
- Composer
- WP-CLI
- Node.js &amp; npm

### MySQL (`mysql`)

Default connection:

```
Host: mysql
Port: 3306
Database: myapp
Username: myapp
Password: secret
```

Testing database: `testing` (auto-created)

### PostgreSQL (`postgres`)

Default connection:

```
Host: postgres
Port: 5432
Database: myapp
Username: myapp
Password: secret
```

Testing database: `testing` (auto-created)

### Redis (`redis`)

```
Host: redis
Port: 6379
```

### Mailpit (`mailpit`)

Email testing tool with web UI at [http://localhost:8025](http://localhost:8025)

- SMTP: localhost:1025
- Web UI: [http://localhost:8025](http://localhost:8025)

### SSL Proxy (`ssl-proxy`)

HTTPS termination at host port 8443 (`SSL_PORT`), proxies to app container.

## SSL Certificates

Generate self-signed SSL certificates:

```bash
./sail ssl
```

Then trust the certificate on your system:

**macOS:**

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain docker/ssl/certs/myapp.test.crt
```

**Linux (Debian/Ubuntu):**

```bash
sudo cp docker/ssl/certs/myapp.test.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**Windows (PowerShell as Admin):**

```powershell
Import-Certificate -FilePath "docker\ssl\certs\myapp.test.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

## Framework Setup

### Laravel

1. Create new project:

```bash
./sail composer create-project laravel/laravel .
```

2. Configure `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_DATABASE=myapp
DB_USERNAME=myapp
DB_PASSWORD=secret

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_HOST=redis

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
```

### WordPress

1. Download WordPress:

```bash
./sail wp core download
```

2. Configure `wp-config.php`:

```php
define('DB_NAME', 'myapp');
define('DB_USER', 'myapp');
define('DB_PASSWORD', 'secret');
define('DB_HOST', 'mysql');
```

### Zend / Laminas

```bash
./sail composer create-project laminas/laminas-mvc-skeleton .
```

## Platform-Specific Notes

### macOS

- Use Docker Desktop or Podman with a running Podman machine (see [Podman Support](#podman-support))
- File system performance is optimized by default
- Use `./sail` for all commands

### Linux

- Use Docker 20.10+ (for `host.docker.internal` support) or Podman with a Compose provider
- Docker Engine users may need `sudo` or membership in the Docker group:

```bash
sudo usermod -aG docker $USER
```

### Windows

- Use Docker Desktop with WSL2 backend or Podman with a running Podman machine
- Use `sail.bat` in CMD
- Or use `./sail` inside WSL with the chosen engine configured there

## Troubleshooting

### Compose Fallback

If the `sail` script fails due to environment issues (like line ending conflicts or missing shell permissions), you can use native Compose commands. For Podman, replace `docker compose` below with `podman-compose` or `podman compose`:


| Sail Command          | Docker Compose Equivalent                                                                                                                                                                                 |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./sail up`           | `docker compose up -d`                                                                                                                                                                                    |
| `./sail down`         | `docker compose down`                                                                                                                                                                                     |
| `./sail build`        | `docker compose build --build-arg WWWGROUP=$(id -g) --build-arg PHP_POST_MAX_SIZE=100M --build-arg PHP_UPLOAD_MAX_FILESIZE=100M --build-arg PHP_MAX_EXECUTION_TIME=300 --build-arg PHP_SHORT_OPEN_TAG=On` |
| `./sail ps`           | `docker compose ps`                                                                                                                                                                                       |
| `./sail logs`         | `docker compose logs -f`                                                                                                                                                                                  |
| `./sail shell`        | `docker compose exec app bash`                                                                                                                                                                            |
| `./sail php ...`      | `docker compose exec app php ...`                                                                                                                                                                         |
| `./sail composer ...` | `docker compose exec app composer ...`                                                                                                                                                                    |
| `./sail artisan ...`  | `docker compose exec app php artisan ...`                                                                                                                                                                 |
| `./sail wp ...`       | `docker compose exec app wp ...`                                                                                                                                                                          |


### Script Permissions &amp; Line Endings

If you encounter `Permission denied` or `Command not found` when running `./sail`:

```bash
# Fix execution permissions
chmod +x sail docker/scripts/*.sh docker/ssl/*.sh docker/php/start-container

# If scripts have Windows (CRLF) line endings on Linux/macOS
# You can fix them using the 'tr' command:
tr -d '\r' < sail > sail.tmp && mv sail.tmp sail && chmod +x sail
```

### Port Already in Use

If the default HTTP port 8080 is already in use:

```bash
# Check what's using port 8080
lsof -i :8080

# Change port in .env
APP_PORT=8082
```

### MySQL Access Denied

Reset MySQL data:

```bash
./sail down
docker volume rm phplocaldocker_sail-mysql
./sail up
```

### PHP-FPM Not Starting

Check container logs:

```bash
./sail shell
php-fpm -t
```

### Clear All Docker Data

```bash
./sail down -v  # Remove containers and volumes
docker system prune -a  # Clean all unused Docker resources
```

## File Structure

```
├── .env                    # Environment configuration
├── .env.example            # Configuration template
├── .gitignore              # Git ignore rules
├── .dockerignore           # Docker build ignore rules
├── docker-compose.yml      # Docker services definition
├── sail                    # CLI tool (macOS/Linux)
├── sail.bat                # CLI tool (Windows)
├── SECURITY.md             # Security guidelines
├── public/                 # Web root
│   └── index.php
├── backups/                # Database backups (auto-created)
└── docker/
    ├── mysql/
    │   └── create-testing-database.sh
    ├── php/
    │   ├── Dockerfile
    │   ├── bullseye-sources.list # Frozen package sources for legacy PHP
    │   ├── php.ini
    │   ├── xdebug.ini
    │   ├── supervisord.conf
    │   ├── nginx-default
    │   ├── fpm-env.conf
    │   └── start-container
    ├── postgres/
    │   └── create-testing-database.sh
    ├── scripts/
    │   ├── backup.sh       # Database backup (macOS/Linux)
    │   ├── backup.bat      # Database backup (Windows)
    │   ├── restore.sh      # Database restore (macOS/Linux)
    │   └── restore.bat     # Database restore (Windows)
    └── ssl/
        ├── nginx.conf
        ├── generate-certs.sh
        ├── generate-certs.bat
        └── certs/
            └── .gitkeep
```

## License

MIT License