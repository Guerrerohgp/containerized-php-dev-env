#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "Error: .env.example not found in $PROJECT_ROOT"
    exit 1
fi

echo ""
echo "============================================="
echo "  Plod - PHP Project Setup Wizard"
echo "============================================="
echo ""

ask() {
    local prompt="$1"
    local default="$2"
    local result
    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -r -p "$prompt: " result
        echo "$result"
    fi
}

choose() {
    local prompt="$1"
    local default="$2"
    shift 2
    local options=("$@")
    local i=1
    echo "$prompt"
    for opt in "${options[@]}"; do
        if [ "$opt" = "$default" ]; then
            echo "  $i) $opt (default)"
        else
            echo "  $i) $opt"
        fi
        i=$((i + 1))
    done
    local choice
    read -r -p "Choose [${default}]: " choice
    if [ -z "$choice" ]; then
        echo "$default"
        return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        echo "${options[$((choice - 1))]}"
    else
        echo "$default"
    fi
}

echo "--- Project Settings ---"
echo ""
PROJECT_NAME=$(ask "Project name" "myapp")
PROJECT_DOMAIN=$(ask "Project domain" "${PROJECT_NAME}.test")

echo ""
echo "--- PHP Configuration ---"
echo ""
PHP_VERSION=$(choose "Select PHP version:" "8.2" "7.4" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5")
NODE_VERSION=$(choose "Select Node.js version:" "20" "18" "20" "22")

echo ""
echo "--- Framework ---"
echo ""
FRAMEWORK=$(choose "Select a framework (or skip to set up manually):" "none" "none" "laravel" "wordpress" "laminas")

echo ""
echo "--- Databases ---"
echo ""
DB_CHOICE=$(choose "Which database(s) do you need?" "mysql" "mysql" "postgres" "both")
case "$DB_CHOICE" in
    mysql)
        ENABLE_MYSQL="true"
        ENABLE_POSTGRES="false"
        ;;
    postgres)
        ENABLE_MYSQL="false"
        ENABLE_POSTGRES="true"
        ;;
    both)
        ENABLE_MYSQL="true"
        ENABLE_POSTGRES="true"
        ;;
esac

echo ""
echo "--- Additional Services ---"
echo ""
ENABLE_REDIS=$(choose "Enable Redis?" "true" "true" "false")
ENABLE_MAILPIT=$(choose "Enable Mailpit (email testing)?" "true" "true" "false")
ENABLE_SSL=$(choose "Enable SSL proxy?" "true" "true" "false")

echo ""
echo "--- Port Configuration ---"
echo ""
APP_PORT=$(ask "HTTP port" "80")

echo ""
echo "============================================="
echo "  Generating configuration..."
echo "============================================="
echo ""

cp "$ENV_EXAMPLE" "$ENV_FILE"

sed_replace() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
    else
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    fi
}

sed_replace "$ENV_FILE" "PROJECT_NAME" "$PROJECT_NAME"
sed_replace "$ENV_FILE" "PROJECT_DOMAIN" "$PROJECT_DOMAIN"
sed_replace "$ENV_FILE" "PHP_VERSION" "$PHP_VERSION"
sed_replace "$ENV_FILE" "NODE_VERSION" "$NODE_VERSION"
sed_replace "$ENV_FILE" "APP_PORT" "$APP_PORT"
sed_replace "$ENV_FILE" "REDIS_ENABLED" "$ENABLE_REDIS"
sed_replace "$ENV_FILE" "MAILPIT_ENABLED" "$ENABLE_MAILPIT"
sed_replace "$ENV_FILE" "SSL_ENABLED" "$ENABLE_SSL"

COMPOSE_PROJECT_NAME="${PROJECT_NAME}"
sed_replace "$ENV_FILE" "COMPOSE_PROJECT_NAME" "$COMPOSE_PROJECT_NAME"

PROFILES=""
if [ "$ENABLE_MYSQL" = "true" ]; then
    PROFILES="mysql"
fi
if [ "$ENABLE_POSTGRES" = "true" ]; then
    if [ -n "$PROFILES" ]; then
        PROFILES="$PROFILES,postgres"
    else
        PROFILES="postgres"
    fi
fi
if [ "$ENABLE_REDIS" = "true" ]; then
    if [ -n "$PROFILES" ]; then
        PROFILES="$PROFILES,redis"
    else
        PROFILES="redis"
    fi
fi
if [ "$ENABLE_MAILPIT" = "true" ]; then
    if [ -n "$PROFILES" ]; then
        PROFILES="$PROFILES,mailpit"
    else
        PROFILES="mailpit"
    fi
fi
if [ "$ENABLE_SSL" = "true" ]; then
    if [ -n "$PROFILES" ]; then
        PROFILES="$PROFILES,ssl"
    else
        PROFILES="ssl"
    fi
fi

sed_replace "$ENV_FILE" "COMPOSE_PROFILES" "$PROFILES"

echo ".env file created successfully."
echo ""
echo "Active profiles: $PROFILES"
echo ""

echo "============================================="
echo "  Building containers..."
echo "============================================="
echo ""

cd "$PROJECT_ROOT"

DOCKER_COMPOSE="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        echo "Error: docker-compose is not installed."
        exit 1
    fi
fi

export COMPOSE_PROFILES="$PROFILES"

$DOCKER_COMPOSE build --build-arg WWWGROUP="${WWWGROUP:-1000}" \
    --build-arg PHP_POST_MAX_SIZE=100M \
    --build-arg PHP_UPLOAD_MAX_FILESIZE=100M \
    --build-arg PHP_MAX_EXECUTION_TIME=300 \
    --build-arg PHP_SHORT_OPEN_TAG=Off

echo ""
echo "============================================="
echo "  Starting containers..."
echo "============================================="
echo ""

$DOCKER_COMPOSE up -d

echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "  Project:   $PROJECT_NAME"
echo "  Domain:    $PROJECT_DOMAIN"
echo "  PHP:       $PHP_VERSION"
echo "  Node:      $NODE_VERSION"
echo "  URL:       http://localhost:${APP_PORT}"
echo ""

if [ "$ENABLE_SSL" = "true" ]; then
    echo "  To generate SSL certificates:"
    echo "    ./plod ssl"
    echo ""
fi

case "$FRAMEWORK" in
    laravel)
        echo "  Installing Laravel..."
        echo ""
        $DOCKER_COMPOSE exec -T app composer create-project laravel/laravel . --prefer-dist --no-interaction
        echo ""
        echo "  Laravel installed! Configure your .env:"
        echo "    DB_HOST=mysql"
        echo "    DB_DATABASE=myapp"
        echo "    DB_USERNAME=myapp"
        echo "    DB_PASSWORD=secret"
        echo "    CACHE_DRIVER=redis"
        echo "    MAIL_MAILER=smtp"
        echo "    MAIL_HOST=mailpit"
        echo "    MAIL_PORT=1025"
        echo ""
        ;;
    wordpress)
        echo "  Installing WordPress..."
        echo ""
        $DOCKER_COMPOSE exec -T app wp core download --allow-root
        echo ""
        echo "  WordPress downloaded! Configure wp-config.php with:"
        echo "    DB_NAME: myapp"
        echo "    DB_USER: myapp"
        echo "    DB_PASSWORD: secret"
        echo "    DB_HOST: mysql"
        echo ""
        ;;
    laminas)
        echo "  Installing Laminas..."
        echo ""
        $DOCKER_COMPOSE exec -T app composer create-project laminas/laminas-mvc-skeleton . --prefer-dist --no-interaction
        echo ""
        echo "  Laminas installed!"
        echo ""
        ;;
    none)
        echo "  No framework selected. Start building in the public/ directory."
        echo ""
        ;;
esac

echo "  Useful commands:"
echo "    ./plod shell       - Open a shell in the container"
echo "    ./plod composer    - Run Composer commands"
echo "    ./plod npm install - Install Node dependencies"
echo "    ./plod logs        - View container logs"
echo "    ./plod help        - See all commands"
echo ""
