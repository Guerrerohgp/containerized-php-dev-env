#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"

load_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        # Export each line in .env, ignoring comments and handling quotes and carriage returns
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                # Remove possible carriage returns and quotes
                value=$(echo "$value" | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
                export "$key=$value"
            fi
        done < "$PROJECT_ROOT/.env"
    fi
}

load_env

PROJECT_NAME="${PROJECT_NAME:-myapp}"
DB_DATABASE="${DB_DATABASE:-myapp}"
DB_USERNAME="${DB_USERNAME:-myapp}"
DB_PASSWORD="${DB_PASSWORD:-secret}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-myapp}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-secret}"

export COMPOSE_HTTP_TIMEOUT=86400
export COMPOSE_TTY=0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "Starting backup for project: $PROJECT_NAME"
echo "Timestamp: $TIMESTAMP"
echo ""

MYSQL_BACKUP="$BACKUP_DIR/${PROJECT_NAME}_mysql_${TIMESTAMP}.sql"
POSTGRES_BACKUP="$BACKUP_DIR/${PROJECT_NAME}_postgres_${TIMESTAMP}.sql"

echo "Backing up MySQL database: $DB_DATABASE"
echo "This may take a while for large databases..."
docker compose exec \
    -T \
    -e COMPOSE_HTTP_TIMEOUT=86400 \
    mysql mysqldump \
    --user="$DB_USERNAME" \
    --password="$DB_PASSWORD" \
    --no-tablespaces \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-database \
    --databases "$DB_DATABASE" \
    > "$MYSQL_BACKUP" 2>/dev/null

gzip "$MYSQL_BACKUP"
echo "MySQL backup saved: ${MYSQL_BACKUP}.gz"

echo ""
echo "Backing up PostgreSQL database: $POSTGRES_DB"
echo "This may take a while for large databases..."
docker compose exec \
    -T \
    -e COMPOSE_HTTP_TIMEOUT=86400 \
    postgres pg_dump \
    --username="$POSTGRES_USER" \
    --dbname="$POSTGRES_DB" \
    --clean \
    --create \
    > "$POSTGRES_BACKUP"

gzip "$POSTGRES_BACKUP"
echo "PostgreSQL backup saved: ${POSTGRES_BACKUP}.gz"

echo ""
echo "Backup complete!"
echo "Files saved to: $BACKUP_DIR"
echo ""
echo "To restore, run: ./plod restore ${PROJECT_NAME}_mysql_${TIMESTAMP}.sql.gz ${PROJECT_NAME}_postgres_${TIMESTAMP}.sql.gz"
