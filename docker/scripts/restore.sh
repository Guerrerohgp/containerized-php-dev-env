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

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    echo ""
    echo "MySQL backups:"
    ls -lh "$BACKUP_DIR"/*_mysql_*.sql.gz 2>/dev/null || echo "  No MySQL backups found"
    echo ""
    echo "PostgreSQL backups:"
    ls -lh "$BACKUP_DIR"/*_postgres_*.sql.gz 2>/dev/null || echo "  No PostgreSQL backups found"
    echo ""
}

restore_mysql() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        if [[ -f "$BACKUP_DIR/$backup_file" ]]; then
            backup_file="$BACKUP_DIR/$backup_file"
        elif [[ -f "$BACKUP_DIR/${backup_file}.gz" ]]; then
            backup_file="$BACKUP_DIR/${backup_file}.gz"
        else
            echo "Error: Backup file not found: $backup_file"
            exit 1
        fi
    fi
    
    echo "Restoring MySQL from: $backup_file"
    echo "This may take a while for large databases..."
    
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | ${DOCKER_COMPOSE:-docker compose} exec \
            -T \
            -e COMPOSE_HTTP_TIMEOUT=86400 \
            mysql mysql \
            --user="$DB_USERNAME" \
            --password="$DB_PASSWORD" \
            --connect-timeout=28800 \
            --wait \
            --init-command="SET SESSION wait_timeout=28800, interactive_timeout=28800, net_read_timeout=28800, net_write_timeout=28800"
    else
        ${DOCKER_COMPOSE:-docker compose} exec \
            -T \
            -e COMPOSE_HTTP_TIMEOUT=86400 \
            mysql mysql \
            --user="$DB_USERNAME" \
            --password="$DB_PASSWORD" \
            --connect-timeout=28800 \
            --wait \
            --init-command="SET SESSION wait_timeout=28800, interactive_timeout=28800, net_read_timeout=28800, net_write_timeout=28800" \
            < "$backup_file"
    fi
    
    echo "MySQL restore complete!"
}

restore_postgres() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        if [[ -f "$BACKUP_DIR/$backup_file" ]]; then
            backup_file="$BACKUP_DIR/$backup_file"
        elif [[ -f "$BACKUP_DIR/${backup_file}.gz" ]]; then
            backup_file="$BACKUP_DIR/${backup_file}.gz"
        else
            echo "Error: Backup file not found: $backup_file"
            exit 1
        fi
    fi
    
    echo "Restoring PostgreSQL from: $backup_file"
    echo "This may take a while for large databases..."
    
    local psql_opts="-v ON_ERROR_STOP=1 -v statement_timeout=0 -v lock_timeout=0"
    
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | ${DOCKER_COMPOSE:-docker compose} exec \
            -T \
            -e COMPOSE_HTTP_TIMEOUT=86400 \
            -e PGTZ=UTC \
            postgres psql \
            --username="$POSTGRES_USER" \
            --dbname="postgres" \
            $psql_opts
    else
        ${DOCKER_COMPOSE:-docker compose} exec \
            -T \
            -e COMPOSE_HTTP_TIMEOUT=86400 \
            -e PGTZ=UTC \
            postgres psql \
            --username="$POSTGRES_USER" \
            --dbname="postgres" \
            $psql_opts \
            < "$backup_file"
    fi
    
    echo "PostgreSQL restore complete!"
}

restore_both() {
    local mysql_backup="$1"
    local postgres_backup="$2"
    
    if [[ -z "$mysql_backup" ]] || [[ -z "$postgres_backup" ]]; then
        echo "Usage: ./sail restore <mysql_backup> <postgres_backup>"
        echo ""
        list_backups
        exit 1
    fi
    
    restore_mysql "$mysql_backup"
    echo ""
    restore_postgres "$postgres_backup"
}

if [[ "$1" == "--list" ]] || [[ "$1" == "-l" ]]; then
    list_backups
    exit 0
fi

if [[ "$1" == "--mysql" ]]; then
    restore_mysql "$2"
    exit 0
fi

if [[ "$1" == "--postgres" ]]; then
    restore_postgres "$2"
    exit 0
fi

restore_both "$1" "$2"
