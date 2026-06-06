# PHP Docker Development Environment

A generic, configurable Docker development environment for PHP projects. Supports multiple PHP versions, databases (MySQL & PostgreSQL), and works across macOS, Linux, and Windows.

> **WARNING:** This is a development environment only. Do NOT use in production. See [SECURITY.md](SECURITY.md) for details.

## Features

- **One-Command Setup**: `./plod init` walks you through project configuration and scaffolding
- **Multiple PHP Versions**: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
- **Dual Database Support**: MySQL 8.0 and PostgreSQL 16 (selectable via profiles)
- **Built-in Services**: Redis, Mailpit (email testing), SSL proxy with SAN certificates
- **Cross-Platform**: Works on macOS, Linux, and Windows
- **Framework Agnostic**: Laravel, WordPress, Laminas, or plain PHP
- **Full Dev Toolchain**: Composer, WP-CLI, npm/yarn/pnpm, Node.js pre-installed
- **Xdebug Ready**: Pre-configured for debugging
- **Service Profiles**: Only start the services you need

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS/Windows) or Docker Engine (Linux)
- Docker Compose v2.0+

## Installation

### Global Install (Recommended)

Install `plod` as a global command so you can start new projects from any directory:

**macOS/Linux:**
```bash
git clone https://github.com/Guerrerohgp/phplocaldocker.git
cd phplocaldocker
./install.sh
```

**Windows (CMD as Administrator):**
```cmd
git clone https://github.com/Guerrerohgp/phplocaldocker.git
cd phplocaldocker
install.bat
```

After installation, you can use `plod` from anywhere:
```bash
mkdir my-project && cd my-project
plod init
```

### Uninstall

**macOS/Linux:**
```bash
rm /usr/local/bin/plod
rm -rf ~/.plod
```

**Windows:**
```cmd
rmdir /s /q "%LOCALAPPDATA%\plod"
REM Remove %LOCALAPPDATA%\plod\bin from PATH
```

## Updating & Upgrading

### Update Global Template

Pull the latest version of plod from the repository to update the global template:

```bash
plod update
```

This downloads the latest template files to `~/.plod` (or `%LOCALAPPDATA%\plod` on Windows). New projects created with `plod init` will use the updated template.

### Upgrade an Existing Project

Update an existing project's plod files to match the latest global template:

```bash
cd my-project
plod upgrade
```

**What gets updated:**
- `docker/` directory (Dockerfile, configs, scripts)
- `docker-compose.yml`
- `plod` and `plod.bat`
- `.env.example`, `.gitignore`, `.gitattributes`, `.dockerignore`

**What is preserved (never modified):**
- `.env` (your configuration)
- `public/` (your application code)
- `backups/` (database backups)
- `vendor/`, `node_modules/` (dependencies)
- Any other project source code

After upgrading, `.env.example` is backed up to `.env.example.bak` so you can review and merge any new configuration options. Then rebuild containers:

```bash
plod build
plod up
```

## Quick Start

### Interactive Setup (Recommended)

**With global install:**
```bash
mkdir my-project && cd my-project
plod init
```

**Without global install:**
```bash
# 1. Clone or copy this project
git clone https://github.com/Guerrerohgp/phplocaldocker.git my-project
cd my-project

# 2. Run the setup wizard
./plod init
```

The wizard will ask you for:
- Project name and domain
- PHP version (7.4, 8.0 - 8.5)
- Node.js version (18, 20, 22)
- Framework (Laravel, WordPress, Laminas, or none)
- Which databases to enable (MySQL, PostgreSQL, or both)
- Which services to enable (Redis, Mailpit, SSL)

It then generates your `.env`, builds containers, starts services, and optionally scaffolds your framework.

**Windows (CMD):**
```cmd
REM With global install:
mkdir my-project && cd my-project
plod init

REM Without global install:
git clone https://github.com/Guerrerohgp/phplocaldocker.git my-project
cd my-project
plod.bat init
```

### Manual Setup

```bash
# 1. Clone or copy this project
git clone https://github.com/Guerrerohgp/phplocaldocker.git my-project
cd my-project

# 2. Create environment file
cp .env.example .env

# 3. Edit .env to configure profiles and settings
# COMPOSE_PROFILES=mysql,redis,mailpit,ssl

# 4. Build and start containers
./plod build
./plod up

# 5. Open in browser
open http://localhost
```

**Windows (CMD):**
```cmd
copy .env.example .env
plod.bat build
plod.bat up
```

## Configuration

Edit the `.env` file to customize your setup:

### Project Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROJECT_NAME` | `myapp` | Docker Compose project name (prevents conflicts between projects) |
| `PROJECT_NAME` | `myapp` | Project identifier |
| `PROJECT_DOMAIN` | `myapp.test` | Domain for SSL certificate |

### Service Profiles

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROFILES` | `mysql,postgres,redis,mailpit,ssl` | Comma-separated list of services to enable |

Available profiles: `mysql`, `postgres`, `redis`, `mailpit`, `ssl`

Example for a minimal Laravel setup:
```env
COMPOSE_PROFILES=mysql,redis,mailpit
```

### PHP Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_VERSION` | `8.2` | PHP version (7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5) |
| `NODE_VERSION` | `20` | Node.js version (18, 20, 22) |
| `PHP_POST_MAX_SIZE` | `100M` | Maximum POST data size |
| `PHP_UPLOAD_MAX_FILESIZE` | `100M` | Maximum upload file size |
| `PHP_MAX_EXECUTION_TIME` | `300` | Maximum script execution time (seconds) |
| `PHP_SHORT_OPEN_TAG` | `Off` | Enable short open tags (`<?`) |

### Database Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSQL_VERSION` | `8.0` | MySQL version |
| `DB_DATABASE` | `myapp` | MySQL database name |
| `DB_USERNAME` | `myapp` | MySQL username |
| `DB_PASSWORD` | `secret` | MySQL password |
| `POSTGRES_VERSION` | `16` | PostgreSQL version |
| `POSTGRES_DB` | `myapp` | PostgreSQL database name |
| `POSTGRES_USER` | `myapp` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `secret` | PostgreSQL password |

### Port Mappings

| Service | Default Port | Env Variable |
|---------|-------------|--------------|
| HTTP | 80 | `APP_PORT` |
| HTTPS | 443 | `FORWARD_SSL_PORT` |
| MySQL | 3306 | `FORWARD_DB_PORT` |
| PostgreSQL | 5432 | `FORWARD_POSTGRES_PORT` |
| Redis | 6379 | `FORWARD_REDIS_PORT` |
| Mailpit SMTP | 1025 | `FORWARD_MAILPIT_PORT` |
| Mailpit Web | 8025 | `FORWARD_MAILPIT_DASHBOARD_PORT` |

## Commands

### Setup

```bash
./plod init          # Interactive project setup wizard
```

### Container Management

```bash
./plod up            # Start containers
./plod up --build    # Build and start containers in one step
./plod down          # Stop and remove containers
./plod down -v       # Stop, remove containers AND volumes (deletes data!)
./plod build         # Build containers
./plod ps            # List running containers
./plod logs          # View container logs
./plod stop          # Stop containers
./plod restart       # Restart containers
```

### Development

```bash
./plod shell         # Open bash shell in app container
./plod php -v        # Run PHP commands
./plod composer install    # Run Composer
./plod artisan migrate     # Run Laravel Artisan
./plod wp plugin list      # Run WP-CLI
./plod npm install         # Run npm
./plod yarn install        # Run yarn
./plod pnpm install        # Run pnpm
./plod node -v             # Run Node.js
./plod test                # Run PHPUnit tests
```

### Database

```bash
./plod mysql         # Open MySQL CLI
./plod psql          # Open PostgreSQL CLI
./plod redis         # Open Redis CLI
```

### Backup & Restore

```bash
./plod backup                          # Backup all databases
./plod restore --list                  # List available backups
./plod restore <mysql> <postgres>      # Restore both databases
./plod restore --mysql <file>          # Restore MySQL only
./plod restore --postgres <file>       # Restore PostgreSQL only
```

**Windows (CMD):**
```cmd
plod.bat backup
plod.bat restore --list
plod.bat restore myapp_mysql_20240115_120000.sql myapp_postgres_20240115_120000.sql
```

Backups are stored in the `backups/` directory with timestamps in the format:
- `myapp_mysql_YYYYMMDD_HHMMSS.sql.gz`
- `myapp_postgres_YYYYMMDD_HHMMSS.sql`

### Utilities

```bash
./plod ssl           # Generate SSL certificates (with SANs)
./plod mailpit       # View Mailpit logs
./plod update        # Update global plod template to latest version
./plod upgrade       # Upgrade this project's plod files from global template
./plod help          # Show all commands
```

## Services

### PHP Application (`app`)

- Nginx web server
- PHP-FPM
- Composer
- WP-CLI
- Node.js & npm/yarn/pnpm

### MySQL (`mysql`) - Profile: `mysql`

Default connection:
```
Host: mysql
Port: 3306
Database: myapp
Username: myapp
Password: secret
```

Testing database: `testing` (auto-created)

### PostgreSQL (`postgres`) - Profile: `postgres`

Default connection:
```
Host: postgres
Port: 5432
Database: myapp
Username: myapp
Password: secret
```

Testing database: `testing` (auto-created)

### Redis (`redis`) - Profile: `redis`

```
Host: redis
Port: 6379
```

### Mailpit (`mailpit`) - Profile: `mailpit`

Email testing tool with web UI at http://localhost:8025

- SMTP: localhost:1025
- Web UI: http://localhost:8025

### SSL Proxy (`ssl-proxy`) - Profile: `ssl`

HTTPS termination at port 443, proxies to app container. Supports WebSocket connections for HMR.

## SSL Certificates

Generate self-signed SSL certificates with Subject Alternative Names (SANs):

```bash
./plod ssl
```

Certificates include SANs for: `your-domain.test`, `*.your-domain.test`, `localhost`, `127.0.0.1`, `::1`

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

Using the wizard:
```bash
./plod init
# Select "laravel" when prompted for framework
```

Manual:
```bash
./plod composer create-project laravel/laravel .
```

Configure `.env`:
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

Using the wizard:
```bash
./plod init
# Select "wordpress" when prompted for framework
```

Manual:
```bash
./plod wp core download
```

Configure `wp-config.php`:
```php
define('DB_NAME', 'myapp');
define('DB_USER', 'myapp');
define('DB_PASSWORD', 'secret');
define('DB_HOST', 'mysql');
```

### Laminas

Using the wizard:
```bash
./plod init
# Select "laminas" when prompted for framework
```

Manual:
```bash
./plod composer create-project laminas/laminas-mvc-skeleton .
```

## Multi-Project Support

Each project uses `COMPOSE_PROJECT_NAME` to isolate containers and volumes. This means you can run multiple PHP projects simultaneously without conflicts.

```env
# Project A
COMPOSE_PROJECT_NAME=project-a

# Project B
COMPOSE_PROJECT_NAME=project-b
```

Docker images are also namespaced: `project-a-plod-8.2/app` vs `project-b-plod-8.2/app`.

## Platform-Specific Notes

### macOS

- Requires Docker Desktop
- File system performance is optimized by default
- Use `./plod` for all commands

### Linux

- Requires Docker 20.10+ (for `host.docker.internal` support)
- May need `sudo` or add user to docker group:
```bash
sudo usermod -aG docker $USER
```

### Windows

- Requires Docker Desktop with WSL2 backend
- Use `plod.bat` in CMD
- Or use `./plod` in PowerShell/WSL

## Troubleshooting

### Docker Compose Fallback

If the `plod` script fails, you can always use native Docker Compose commands:

| Plod Command | Docker Compose Equivalent |
|--------------|---------------------------|
| `./plod up` | `docker compose up -d` |
| `./plod down` | `docker compose down` |
| `./plod build` | `docker compose build --build-arg WWWGROUP=$(id -g) --build-arg PHP_POST_MAX_SIZE=100M --build-arg PHP_UPLOAD_MAX_FILESIZE=100M --build-arg PHP_MAX_EXECUTION_TIME=300 --build-arg PHP_SHORT_OPEN_TAG=Off` |
| `./plod ps` | `docker compose ps` |
| `./plod logs` | `docker compose logs -f` |
| `./plod shell` | `docker compose exec app bash` |
| `./plod php ...` | `docker compose exec app php ...` |
| `./plod composer ...` | `docker compose exec app composer ...` |
| `./plod artisan ...` | `docker compose exec app php artisan ...` |
| `./plod wp ...` | `docker compose exec app wp ...` |
| `./plod npm ...` | `docker compose exec app npm ...` |

### Script Permissions & Line Endings

If you encounter `Permission denied` or `Command not found` when running `./plod`:

```bash
# Fix execution permissions
chmod +x plod docker/scripts/*.sh docker/ssl/*.sh docker/php/start-container

# If scripts have Windows (CRLF) line endings on Linux/macOS
tr -d '\r' < plod > plod.tmp && mv plod.tmp plod && chmod +x plod
```

### Port Already in Use

If port 80 is already in use:

```bash
# Check what's using port 80
lsof -i :80

# Change port in .env
APP_PORT=8080
```

### MySQL Access Denied

Reset MySQL data:

```bash
./plod down -v
./plod up
```

### PHP-FPM Not Starting

Check container logs:

```bash
docker compose exec app php-fpm${PHP_VERSION} -t
```

### Clear All Docker Data

```bash
./plod down -v  # Remove containers and volumes
docker system prune -a  # Clean all unused Docker resources
```

## File Structure

```
├── .env                    # Environment configuration
├── .env.example            # Configuration template
├── .gitignore              # Git ignore rules
├── .dockerignore           # Docker build ignore rules
├── docker-compose.yml      # Docker services definition
├── install.sh              # Global installer (macOS/Linux)
├── install.bat             # Global installer (Windows)
├── plod                    # CLI tool (macOS/Linux)
├── plod.bat                # CLI tool (Windows)
├── SECURITY.md             # Security guidelines
├── public/                 # Web root
│   └── index.php           # Landing page
├── backups/                # Database backups (auto-created)
└── docker/
    ├── mysql/
    │   └── create-testing-database.sh
    ├── php/
    │   ├── Dockerfile
    │   ├── php.ini
    │   ├── xdebug.ini
    │   ├── supervisord.conf
    │   ├── nginx-default
    │   ├── fpm-env.conf
    │   └── start-container
    ├── postgres/
    │   └── create-testing-database.sh
    ├── scripts/
    │   ├── init.sh         # Setup wizard (macOS/Linux)
    │   ├── init.bat        # Setup wizard (Windows)
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
