@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..\
set BACKUP_DIR=%PROJECT_ROOT%backups

for %%i in ("%PROJECT_ROOT%.") do set PROJECT_ROOT=%%~dpi
for %%i in ("%BACKUP_DIR%.") do set BACKUP_DIR=%%~dpi

set COMPOSE_HTTP_TIMEOUT=86400
set COMPOSE_TTY=0

if "%DOCKER_COMPOSE%"=="" set DOCKER_COMPOSE=docker compose

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

if "%DB_USERNAME%"=="" set DB_USERNAME=myapp
if "%DB_PASSWORD%"=="" set DB_PASSWORD=secret
if "%POSTGRES_USER%"=="" set POSTGRES_USER=myapp

if "%1"=="" goto list
if "%1"=="--list" goto list
if "%1"=="-l" goto list
if "%1"=="--help" goto help
if "%1"=="-h" goto help
if "%1"=="--mysql" goto restore_mysql
if "%1"=="--postgres" goto restore_postgres
goto restore_both

:list
echo Available backups in %BACKUP_DIR%:
echo.
echo MySQL backups:
dir /b "%BACKUP_DIR%*_mysql_*.sql*" 2>nul || echo   No MySQL backups found
echo.
echo PostgreSQL backups:
dir /b "%BACKUP_DIR%*_postgres_*.sql*" 2>nul || echo   No PostgreSQL backups found
goto end

:help
echo Restore databases from backup
echo.
echo Usage:
echo   sail restore                      List available backups
echo   sail restore ^<mysql^> ^<postgres^>   Restore both databases
echo   sail restore --mysql ^<file^>       Restore MySQL only
echo   sail restore --postgres ^<file^>    Restore PostgreSQL only
echo   sail restore --list               List all backups
echo.
echo Note: Large database restores may take a long time.
echo       Timeouts have been disabled to prevent interruption.
goto end

:restore_mysql
set BACKUP_FILE=%~2
if not exist "%BACKUP_FILE%" (
    if exist "%BACKUP_DIR%%~2" (
        set BACKUP_FILE=%BACKUP_DIR%%~2
    )
)
if not exist "%BACKUP_FILE%" (
    echo Error: Backup file not found: %~2
    exit /b 1
)
echo Restoring MySQL from: %BACKUP_FILE%
echo This may take a while for large databases...
echo Waiting for MySQL to be ready...
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 mysql mysql --user=%DB_USERNAME% --password=%DB_PASSWORD% --connect-timeout=28800 --wait --init-command="SET SESSION wait_timeout=28800, interactive_timeout=28800, net_read_timeout=28800, net_write_timeout=28800" < "%BACKUP_FILE%"
if %errorlevel% equ 0 (
    echo MySQL restore complete!
) else (
    echo Error: MySQL restore failed
    exit /b 1
)
goto end

:restore_postgres
set BACKUP_FILE=%~2
if not exist "%BACKUP_FILE%" (
    if exist "%BACKUP_DIR%%~2" (
        set BACKUP_FILE=%BACKUP_DIR%%~2
    )
)
if not exist "%BACKUP_FILE%" (
    echo Error: Backup file not found: %~2
    exit /b 1
)
echo Restoring PostgreSQL from: %BACKUP_FILE%
echo This may take a while for large databases...
set PGOPTIONS=-c statement_timeout=0 -c lock_timeout=0
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 -e PGOPTIONS=%PGOPTIONS% postgres psql --username=%POSTGRES_USER% --dbname=postgres -v ON_ERROR_STOP=1 -v statement_timeout=0 -v lock_timeout=0 < "%BACKUP_FILE%"
if %errorlevel% equ 0 (
    echo PostgreSQL restore complete!
) else (
    echo Error: PostgreSQL restore failed
    exit /b 1
)
goto end

:restore_both
set MYSQL_BACKUP=%~1
set POSTGRES_BACKUP=%~2

if "%MYSQL_BACKUP%"=="" (
    echo Usage: sail restore ^<mysql_backup^> ^<postgres_backup^>
    echo.
    goto list
)

if not exist "%MYSQL_BACKUP%" (
    if exist "%BACKUP_DIR%%~1" (
        set MYSQL_BACKUP=%BACKUP_DIR%%~1
    )
)

if not exist "%POSTGRES_BACKUP%" (
    if exist "%BACKUP_DIR%%~2" (
        set POSTGRES_BACKUP=%BACKUP_DIR%%~2
    )
)

echo.
echo Restoring MySQL from: %MYSQL_BACKUP%
echo This may take a while for large databases...
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 mysql mysql --user=%DB_USERNAME% --password=%DB_PASSWORD% --connect-timeout=28800 --wait --init-command="SET SESSION wait_timeout=28800, interactive_timeout=28800, net_read_timeout=28800, net_write_timeout=28800" < "%MYSQL_BACKUP%"
if %errorlevel% equ 0 (
    echo MySQL restore complete!
) else (
    echo Error: MySQL restore failed
    exit /b 1
)

echo.
echo Restoring PostgreSQL from: %POSTGRES_BACKUP%
echo This may take a while for large databases...
set PGOPTIONS=-c statement_timeout=0 -c lock_timeout=0
%DOCKER_COMPOSE% exec -T -e COMPOSE_HTTP_TIMEOUT=86400 -e PGOPTIONS=%PGOPTIONS% postgres psql --username=%POSTGRES_USER% --dbname=postgres -v ON_ERROR_STOP=1 -v statement_timeout=0 -v lock_timeout=0 < "%POSTGRES_BACKUP%"
if %errorlevel% equ 0 (
    echo PostgreSQL restore complete!
) else (
    echo Error: PostgreSQL restore failed
    exit /b 1
)

:end
endlocal
