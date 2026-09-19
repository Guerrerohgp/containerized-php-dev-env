@echo off
setlocal enabledelayedexpansion

if defined DOCKER_COMPOSE goto compose_ready
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

:compose_ready
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
    set "SAIL_RUN=%DOCKER_COMPOSE% up -d"
    goto forward_arguments
)
if "%1"=="down" (
    set "SAIL_RUN=%DOCKER_COMPOSE% down"
    goto forward_arguments
)
if "%1"=="build" (
    if "%WWWGROUP%"=="" set WWWGROUP=1000
    if "%PHP_POST_MAX_SIZE%"=="" set PHP_POST_MAX_SIZE=100M
    if "%PHP_UPLOAD_MAX_FILESIZE%"=="" set PHP_UPLOAD_MAX_FILESIZE=100M
    if "%PHP_MAX_EXECUTION_TIME%"=="" set PHP_MAX_EXECUTION_TIME=300
    if "%PHP_SHORT_OPEN_TAG%"=="" set PHP_SHORT_OPEN_TAG=On
    set "SAIL_RUN=%DOCKER_COMPOSE% build --build-arg WWWGROUP=!WWWGROUP! --build-arg PHP_POST_MAX_SIZE=!PHP_POST_MAX_SIZE! --build-arg PHP_UPLOAD_MAX_FILESIZE=!PHP_UPLOAD_MAX_FILESIZE! --build-arg PHP_MAX_EXECUTION_TIME=!PHP_MAX_EXECUTION_TIME! --build-arg PHP_SHORT_OPEN_TAG=!PHP_SHORT_OPEN_TAG!"
    goto forward_arguments
)
if "%1"=="ps" (
    set "SAIL_RUN=%DOCKER_COMPOSE% ps"
    goto forward_arguments
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
    set "SAIL_RUN=%DOCKER_COMPOSE% logs -f"
    goto forward_arguments
)
if "%1"=="wp" (
    set "SAIL_RUN=%DOCKER_COMPOSE% exec app wp"
    goto forward_arguments
)
if "%1"=="composer" (
    set "SAIL_RUN=%DOCKER_COMPOSE% exec app composer"
    goto forward_arguments
)
if "%1"=="artisan" (
    set "SAIL_RUN=%DOCKER_COMPOSE% exec app php artisan"
    goto forward_arguments
)
if "%1"=="php" (
    set "SAIL_RUN=%DOCKER_COMPOSE% exec app php"
    goto forward_arguments
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
    set "SAIL_RUN=%DOCKER_COMPOSE% logs -f mailpit"
    goto forward_arguments
)
if "%1"=="stop" (
    set "SAIL_RUN=%DOCKER_COMPOSE% stop"
    goto forward_arguments
)
if "%1"=="restart" (
    set "SAIL_RUN=%DOCKER_COMPOSE% restart"
    goto forward_arguments
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
    set "SAIL_RUN=call docker\scripts\restore.bat"
    goto forward_arguments
)

echo Unknown command: %1
echo Run 'dev help' for available commands.
exit /b 1

rem SHIFT does not change %*. Collect only the arguments after the Dev command.
:forward_arguments
setlocal disabledelayedexpansion
set "SAIL_ARGS="
:collect_arguments
shift
if "%1"=="" goto run_command
set SAIL_ARGS=%SAIL_ARGS% %1
goto collect_arguments
:run_command
%SAIL_RUN% %SAIL_ARGS%
endlocal
goto end

:help
echo Dev - Docker and Podman management for PHP projects
echo.
echo Usage: dev [command]
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
