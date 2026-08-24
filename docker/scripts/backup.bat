@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..\
set BACKUP_DIR=%PROJECT_ROOT%backups

for %%i in ("%PROJECT_ROOT%.") do set PROJECT_ROOT=%%~dpi
for %%i in ("%BACKUP_DIR%.") do set BACKUP_DIR=%%~dpi

set COMPOSE_HTTP_TIMEOUT=86400
set COMPOSE_TTY=0

if exist "%PROJECT_ROOT%.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%PROJECT_ROOT%.env") do (
        set "line=%%a"
        if "!line:~0,1!" neq "#" (
            set "value=%%b"
            if defined value (
                set "value=!value:"=!"
                set "value=!value:'=!"
                set "%%a=!value!"
            )
        )
    )
)

if "%PROJECT_NAME%"=="" set PROJECT_NAME=myapp
if "%DB_DATABASE%"=="" set DB_DATABASE=myapp
if "%DB_USERNAME%"=="" set DB_USERNAME=myapp
if "%DB_PASSWORD%"=="" set DB_PASSWORD=secret
if "%POSTGRES_DB%"=="" set POSTGRES_DB=myapp
if "%POSTGRES_USER%"=="" set POSTGRES_USER=myapp
if "%POSTGRES_PASSWORD%"=="" set POSTGRES_PASSWORD=secret

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo Starting backup for project: %PROJECT_NAME%
echo Timestamp: %TIMESTAMP%
echo.
echo Note: This may take a while for large databases.
echo.

set MYSQL_BACKUP=%BACKUP_DIR%%PROJECT_NAME%_mysql_%TIMESTAMP%.sql
set POSTGRES_BACKUP=%BACKUP_DIR%%PROJECT_NAME%_postgres_%TIMESTAMP%.sql

if "%DOCKER_COMPOSE%"=="" set DOCKER_COMPOSE=docker compose

echo Backing up MySQL database: %DB_DATABASE%
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 mysql mysqldump --user=%DB_USERNAME% --password=%DB_PASSWORD% --no-tablespaces --single-transaction --routines --triggers --add-drop-database --databases %DB_DATABASE% > "%MYSQL_BACKUP%" 2>nul
if %errorlevel% equ 0 (
    echo MySQL backup saved: %MYSQL_BACKUP%
) else (
    echo Warning: MySQL backup may have issues
)

echo.
echo Backing up PostgreSQL database: %POSTGRES_DB%
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 postgres pg_dump --username=%POSTGRES_USER% --dbname=%POSTGRES_DB% --clean --create > "%POSTGRES_BACKUP%"
if %errorlevel% equ 0 (
    echo PostgreSQL backup saved: %POSTGRES_BACKUP%
) else (
    echo Warning: PostgreSQL backup may have issues
)

echo.
echo Backup complete!
echo Files saved to: %BACKUP_DIR%

endlocal
