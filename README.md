# Containerized PHP Development Environment (Docker/Podman)

A generic, configurable Docker and Podman development environment for PHP projects. Supports multiple PHP versions, databases (MySQL &amp; PostgreSQL), and works across macOS, Linux, and Windows.

> **WARNING:** This is a development environment only. Do NOT use in production. See [SECURITY.md](SECURITY.md) for details.

## Features

- **Debian Slim Base**: Official PHP-FPM images, including legacy PHP 7.4; PHP 8.5 by default
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
git clone https://github.com/Guerrerohgp/containerized-php-dev-env.git my-project
cd my-project

# 2. Create environment file
cp .env.example .env

# 3. Build and start containers
./dev build
./dev ssl
./dev up

# 4. Open in browser
open http://localhost:8080
```

**Windows (CMD):**

```cmd
copy .env.example .env
dev.bat build
dev.bat ssl
dev.bat up
```

## Podman Support

Podman is supported by `./dev` (macOS/Linux) and `dev.bat` (Windows CMD), using the same `docker-compose.yml` as Docker.

Install Podman and a Compose provider: either `podman-compose`, or a provider available through `podman compose`. The latter delegates to an external Compose tool; installing Podman alone does not supply Compose. See the [Podman Compose documentation](https://docs.podman.io/en/latest/markdown/podman-compose.1.html).

On macOS and Windows, create a [Podman machine](https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html) if you do not already have one, then start it:

```bash
podman machine init   # First-time setup only
podman machine start # If the machine is stopped
```

From the project directory, follow [Quick Start](#quick-start), including `./dev ssl` (or `dev.bat ssl`) before starting the stack: the HTTPS proxy requires the generated certificates. Open [http://localhost:8080](http://localhost:8080) for HTTP; HTTPS uses port 8443 with a self-signed certificate.

Both launchers detect Compose commands in this order:

1. `podman-compose`
2. `podman compose`
3. `docker-compose`
4. `docker compose`

When both engines are installed, Podman takes priority. In the Bash launcher, you can explicitly select a command through the shell environment:

```bash
DOCKER_COMPOSE="podman compose" ./dev up
DOCKER_COMPOSE="docker compose" ./dev up
```

In Windows CMD, select a command for the current session:

```cmd
set "DOCKER_COMPOSE=podman compose"
dev.bat up
```

Use `set "DOCKER_COMPOSE="` to return to automatic detection. The variable keeps its historical name for both engines. Backup and restore commands launched through either Dev launcher inherit the selection.

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
| `PHP_VERSION`             | `8.5`   | PHP version: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5   |
| `NODE_VERSION`            | `20`    | Node.js version                         |
| `PHP_POST_MAX_SIZE`       | `100M`  | Maximum POST data size                  |
| `PHP_UPLOAD_MAX_FILESIZE` | `100M`  | Maximum upload file size                |
| `PHP_MAX_EXECUTION_TIME`  | `300`   | Maximum script execution time (seconds) |
| `PHP_SHORT_OPEN_TAG`      | `On`    | Enable short open tags (`<?`)           |


### App Image Base

The default is **PHP 8.5**, the latest stable branch reviewed as of September 2026. PHP has no separate upstream LTS edition: its [support policy](https://www.php.net/supported-versions.php) provides two years of active support followed by two years of security support. PHP 8.5 has active support through December 31, 2027 and security support through December 31, 2029.

The default stays on the explicit `8.5` branch to receive patch updates when the base image is refreshed, without silently moving to a future minor release. Existing `.env` files keep their selected version; set `PHP_VERSION=8.5` to opt in, then rebuild with `./dev build --pull app` and recreate with `./dev up --force-recreate app`.

The app automatically selects an official Debian-based PHP-FPM image using `PHP_VERSION`:

| PHP version | Debian base |
|-------------|-------------|
| 7.4, 8.0 | Bullseye (`php:<version>-fpm-bullseye`) |
| 8.1, 8.2, 8.3, 8.4, 8.5 (default) | Bookworm Slim (`php:<version>-fpm-bookworm`) |

To use PHP 7.4, set `PHP_VERSION=7.4` in `.env`, then run `./dev build app` and `./dev up --force-recreate app` (or the equivalent `dev.bat` commands). No separate Debian setting is needed. Legacy PHP versions use archived images; compatibility here does not imply ongoing upstream security support. Bullseye package sources are pinned to Debian’s 2026-09-01 snapshot in `docker/php/bullseye-sources.list`, since the live security mirror can no longer serve all indexed packages.

PHP extensions are installed with the version-pinned [PHP extension installer](https://github.com/mlocati/docker-php-extension-installer), which removes temporary build dependencies. PHP 7.4, 8.0, and 8.1 use explicitly selected compatible Xdebug versions. Node.js/npm are copied from the matching `node:${NODE_VERSION}-bookworm-slim` image. Composer, WP-CLI, Nginx, Supervisor, and Xdebug remain included.

CLI and FPM share `/usr/local/etc/php/conf.d/`. FPM configuration is in `/usr/local/etc/php-fpm.d/`, and Nginx connects to FPM on `127.0.0.1:9000` inside the app container.

Rebuild and recreate the app after switching from the Ubuntu image:

```bash
./dev build app
./dev up --force-recreate app
```

To check the default image version and FPM configuration without starting databases or publishing ports:

```bash
docker build -t phplocaldocker-smoke docker/php
docker run --rm --entrypoint php phplocaldocker-smoke -v
docker run --rm --entrypoint php-fpm phplocaldocker-smoke -t

# Check the legacy PHP version too
docker build --build-arg PHP_VERSION=7.4 -t phplocaldocker-smoke:7.4 docker/php
docker run --rm --entrypoint php phplocaldocker-smoke:7.4 -v
```

For Podman, replace `docker` with `podman` in these commands. Final image size depends on the selected versions and included tools.

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
./dev up          # Start containers
./dev down        # Stop containers
./dev build       # Build containers
./dev ps          # List running containers
./dev logs        # View container logs
./dev stop        # Stop containers
./dev restart     # Restart containers
```

### Development

```bash
./dev shell       # Open bash shell in app container
./dev php -v      # Run PHP commands
./dev composer install    # Run Composer
./dev artisan migrate     # Run Laravel Artisan
./dev wp plugin list      # Run WP-CLI
```

### Database

```bash
./dev mysql       # Open MySQL CLI
./dev psql        # Open PostgreSQL CLI
./dev redis       # Open Redis CLI
```

### Backup &amp; Restore

```bash
./dev backup                          # Backup all databases
./dev restore --list                  # List available backups
./dev restore <mysql> <postgres>      # Restore both databases
./dev restore --mysql <file>          # Restore MySQL only
./dev restore --postgres <file>       # Restore PostgreSQL only
```

**Windows (CMD):**

```cmd
dev.bat backup
dev.bat restore --list
dev.bat restore myapp_mysql_20240115_120000.sql myapp_postgres_20240115_120000.sql
```

Backups are stored in the `backups/` directory with timestamps in the format:

- `myapp_mysql_YYYYMMDD_HHMMSS.sql.gz`
- `myapp_postgres_YYYYMMDD_HHMMSS.sql`

### Utilities

```bash
./dev ssl         # Generate SSL certificates
./dev mailpit     # View Mailpit logs
./dev help        # Show all commands
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
./dev ssl
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
./dev composer create-project laravel/laravel .
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
./dev wp core download
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
./dev composer create-project laminas/laminas-mvc-skeleton .
```

## Platform-Specific Notes

### macOS

- Use Docker Desktop or Podman with a running Podman machine (see [Podman Support](#podman-support))
- File system performance is optimized by default
- Use `./dev` for all commands

### Linux

- Use Docker 20.10+ (for `host.docker.internal` support) or Podman with a Compose provider
- Docker Engine users may need `sudo` or membership in the Docker group:

```bash
sudo usermod -aG docker $USER
```

### Windows

- Use Docker Desktop with WSL2 backend or Podman with a running Podman machine
- Use `dev.bat` in CMD
- Or use `./dev` inside WSL with the chosen engine configured there

## Troubleshooting

### Compose Fallback

If the `dev` script fails due to environment issues (like line ending conflicts or missing shell permissions), you can use native Compose commands. For Podman, replace `docker compose` below with `podman-compose` or `podman compose`:


| Dev Command          | Docker Compose Equivalent                                                                                                                                                                                 |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./dev up`           | `docker compose up -d`                                                                                                                                                                                    |
| `./dev down`         | `docker compose down`                                                                                                                                                                                     |
| `./dev build`        | `docker compose build --build-arg WWWGROUP=$(id -g) --build-arg PHP_POST_MAX_SIZE=100M --build-arg PHP_UPLOAD_MAX_FILESIZE=100M --build-arg PHP_MAX_EXECUTION_TIME=300 --build-arg PHP_SHORT_OPEN_TAG=On` |
| `./dev ps`           | `docker compose ps`                                                                                                                                                                                       |
| `./dev logs`         | `docker compose logs -f`                                                                                                                                                                                  |
| `./dev shell`        | `docker compose exec app bash`                                                                                                                                                                            |
| `./dev php ...`      | `docker compose exec app php ...`                                                                                                                                                                         |
| `./dev composer ...` | `docker compose exec app composer ...`                                                                                                                                                                    |
| `./dev artisan ...`  | `docker compose exec app php artisan ...`                                                                                                                                                                 |
| `./dev wp ...`       | `docker compose exec app wp ...`                                                                                                                                                                          |


### Script Permissions &amp; Line Endings

If you encounter `Permission denied` or `Command not found` when running `./dev`:

```bash
# Fix execution permissions
chmod +x dev docker/scripts/*.sh docker/ssl/*.sh docker/php/start-container

# If scripts have Windows (CRLF) line endings on Linux/macOS
# You can fix them using the 'tr' command:
tr -d '\r' < dev > dev.tmp && mv dev.tmp dev && chmod +x dev
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
./dev down
docker volume rm phplocaldocker_sail-mysql
./dev up
```

### PHP-FPM Not Starting

Check container logs:

```bash
./dev shell
php-fpm -t
```

### Clear All Docker Data

```bash
./dev down -v  # Remove containers and volumes
docker system prune -a  # Clean all unused Docker resources
```

## File Structure

```
├── .env                    # Environment configuration
├── .env.example            # Configuration template
├── .gitignore              # Git ignore rules
├── .dockerignore           # Docker build ignore rules
├── docker-compose.yml      # Docker services definition
├── dev                    # CLI tool (macOS/Linux)
├── dev.bat                # CLI tool (Windows)
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
