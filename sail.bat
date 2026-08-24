@echo off
setlocal enabledelayedexpansion

set DOCKER_COMPOSE=
where podman-compose >nul 2>nul
if %errorlevel% equ 0 (
    set DOCKER_COMPOSE=podman-compose
) else (
    podman compose version >nul 2>nul
    if !errorlevel! equ 0 (
        set DOCKER_COMPOSE=podman compose
    ) else (
        where docker-compose >nul 2>nul
        if !errorlevel! equ 0 (
            set DOCKER_COMPOSE=docker-compose
        ) else (
            docker compose version >nul 2>nul
            if !errorlevel! equ 0 (
                set DOCKER_COMPOSE=docker compose
            ) else (
                echo No container compose tool installed (podman-compose or docker-compose).
                exit /b 1
            )
        )
    )
)

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="--help" goto help
if "%1"=="-h" goto help

if exist .env (
    for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
        set "line=%%a"
        if "!line:~0,1!" neq "#" (
            set "value=%%b"
            if defined value (
                for /f "tokens=* delims=" %%c in ("!value!") do (
                    set "value=%%c"
                )
                set "value=!value:"=!"
                set "value=!value:'=!"
                set "%%a=!value!"
            )
        )
    )
)

set PROJECT_NAME=%PROJECT_NAME%
if "%PROJECT_NAME%"=="" set PROJECT_NAME=myapp

set PROJECT_DOMAIN=%PROJECT_DOMAIN%
if "%PROJECT_DOMAIN%"=="" set PROJECT_DOMAIN=myapp.test

if "%1"=="up" (
    %DOCKER_COMPOSE% up -d
    goto end
)
if "%1"=="down" (
    %DOCKER_COMPOSE% down
    goto end
)
if "%1"=="build" (
    if "%WWWGROUP%"=="" set WWWGROUP=1000
    if "%PHP_POST_MAX_SIZE%"=="" set PHP_POST_MAX_SIZE=100M
    if "%PHP_UPLOAD_MAX_FILESIZE%"=="" set PHP_UPLOAD_MAX_FILESIZE=100M
    if "%PHP_MAX_EXECUTION_TIME%"=="" set PHP_MAX_EXECUTION_TIME=300
    if "%PHP_SHORT_OPEN_TAG%"=="" set PHP_SHORT_OPEN_TAG=On
    %DOCKER_COMPOSE% build --build-arg WWWGROUP=%WWWGROUP% --build-arg PHP_POST_MAX_SIZE=%PHP_POST_MAX_SIZE% --build-arg PHP_UPLOAD_MAX_FILESIZE=%PHP_UPLOAD_MAX_FILESIZE% --build-arg PHP_MAX_EXECUTION_TIME=%PHP_MAX_EXECUTION_TIME% --build-arg PHP_SHORT_OPEN_TAG=%PHP_SHORT_OPEN_TAG%
    goto end
)
if "%1"=="ps" (
    %DOCKER_COMPOSE% ps
    goto end
)
if "%1"=="shell" (
    %DOCKER_COMPOSE% exec app bash
    goto end
)
if "%1"=="bash" (
    %DOCKER_COMPOSE% exec app bash
    goto end
)
if "%1"=="logs" (
    %DOCKER_COMPOSE% logs -f
    goto end
)
if "%1"=="wp" (
    shift
    %DOCKER_COMPOSE% exec app wp %*
    goto end
)
if "%1"=="composer" (
    shift
    %DOCKER_COMPOSE% exec app composer %*
    goto end
)
if "%1"=="artisan" (
    shift
    %DOCKER_COMPOSE% exec app php artisan %*
    goto end
)
if "%1"=="php" (
    shift
    %DOCKER_COMPOSE% exec app php %*
    goto end
)
if "%1"=="mysql" (
    %DOCKER_COMPOSE% exec mysql mysql -u%DB_USERNAME% -p%DB_PASSWORD% %DB_DATABASE%
    goto end
)
if "%1"=="psql" (
    %DOCKER_COMPOSE% exec postgres psql -U %POSTGRES_USER% -d %POSTGRES_DB%
    goto end
)
if "%1"=="redis" (
    %DOCKER_COMPOSE% exec redis redis-cli
    goto end
)
if "%1"=="mailpit" (
    %DOCKER_COMPOSE% logs -f mailpit
    goto end
)
if "%1"=="stop" (
    %DOCKER_COMPOSE% stop
    goto end
)
if "%1"=="restart" (
    %DOCKER_COMPOSE% restart
    goto end
)
if "%1"=="ssl" (
    call docker\ssl\generate-certs.bat
    goto end
)
if "%1"=="backup" (
    call docker\scripts\backup.bat
    goto end
)
if "%1"=="restore" (
    shift
    call docker\scripts\restore.bat %*
    goto end
)

echo Unknown command: %1
echo Run 'sail help' for available commands.
exit /b 1

:help
echo Sail - Docker management for PHP projects
echo.
echo Usage: sail [command]
echo.
echo Commands:
echo   up          Start the containers
echo   down        Stop the containers
echo   build       Build the containers
echo   ps          List running containers
echo   shell       Open a bash shell in the app container
echo   logs        Show container logs
echo   wp          Run WP-CLI commands
echo   composer    Run Composer commands
echo   artisan     Run artisan commands (Laravel)
echo   php         Run PHP commands
echo   mysql       Open MySQL CLI
echo   psql        Open PostgreSQL CLI
echo   redis       Open Redis CLI
echo   mailpit     Show Mailpit logs
echo   stop        Stop the containers
echo   restart     Restart the containers
echo   ssl         Generate SSL certificates
echo   backup      Backup all databases
echo   restore     Restore databases
echo   help        Show this help message

:end
endlocal
