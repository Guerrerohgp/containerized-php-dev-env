@echo off
setlocal enabledelayedexpansion

set DOCKER_COMPOSE=docker-compose

where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
    docker compose version >nul 2>nul
    if !errorlevel! equ 0 (
        set DOCKER_COMPOSE=docker compose
    ) else (
        echo docker-compose is not installed.
        exit /b 1
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

if "%1"=="init" (
    call docker\scripts\init.bat
    goto end
)
if "%1"=="up" (
    if "%2"=="--build" (
        if "%WWWGROUP%"=="" set WWWGROUP=1000
        if "%PHP_POST_MAX_SIZE%"=="" set PHP_POST_MAX_SIZE=100M
        if "%PHP_UPLOAD_MAX_FILESIZE%"=="" set PHP_UPLOAD_MAX_FILESIZE=100M
        if "%PHP_MAX_EXECUTION_TIME%"=="" set PHP_MAX_EXECUTION_TIME=300
        if "%PHP_SHORT_OPEN_TAG%"=="" set PHP_SHORT_OPEN_TAG=Off
        %DOCKER_COMPOSE% build --build-arg WWWGROUP=%WWWGROUP% --build-arg PHP_POST_MAX_SIZE=%PHP_POST_MAX_SIZE% --build-arg PHP_UPLOAD_MAX_FILESIZE=%PHP_UPLOAD_MAX_FILESIZE% --build-arg PHP_MAX_EXECUTION_TIME=%PHP_MAX_EXECUTION_TIME% --build-arg PHP_SHORT_OPEN_TAG=%PHP_SHORT_OPEN_TAG%
    )
    %DOCKER_COMPOSE% up -d
    goto end
)
if "%1"=="down" (
    shift
    %DOCKER_COMPOSE% down %*
    goto end
)
if "%1"=="build" (
    if "%WWWGROUP%"=="" set WWWGROUP=1000
    if "%PHP_POST_MAX_SIZE%"=="" set PHP_POST_MAX_SIZE=100M
    if "%PHP_UPLOAD_MAX_FILESIZE%"=="" set PHP_UPLOAD_MAX_FILESIZE=100M
    if "%PHP_MAX_EXECUTION_TIME%"=="" set PHP_MAX_EXECUTION_TIME=300
    if "%PHP_SHORT_OPEN_TAG%"=="" set PHP_SHORT_OPEN_TAG=Off
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
if "%1"=="npm" (
    shift
    %DOCKER_COMPOSE% exec app npm %*
    goto end
)
if "%1"=="yarn" (
    shift
    %DOCKER_COMPOSE% exec app yarn %*
    goto end
)
if "%1"=="pnpm" (
    shift
    %DOCKER_COMPOSE% exec app pnpm %*
    goto end
)
if "%1"=="node" (
    shift
    %DOCKER_COMPOSE% exec app node %*
    goto end
)
if "%1"=="test" (
    shift
    %DOCKER_COMPOSE% exec app php vendor/bin/phpunit %*
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
if "%1"=="update" (
    call :do_update
    goto end
)
if "%1"=="upgrade" (
    call :do_upgrade
    goto end
)

echo Unknown command: %1
echo Run 'plod help' for available commands.
exit /b 1

:help
echo Plod - Docker management for PHP projects
echo.
echo Usage: plod [command] [options]
echo.
echo Setup:
echo   init          Interactive project setup wizard
echo.
echo Container Management:
echo   up            Start the containers
echo   down          Stop and remove containers
echo   build         Build the containers
echo   ps            List running containers
echo   logs          Show container logs
echo   stop          Stop the containers
echo   restart       Restart the containers
echo.
echo Development:
echo   shell         Open a bash shell in the app container
echo   php           Run PHP commands
echo   composer      Run Composer commands
echo   artisan       Run artisan commands (Laravel)
echo   wp            Run WP-CLI commands
echo   npm           Run npm commands
echo   yarn          Run yarn commands
echo   pnpm          Run pnpm commands
echo   node          Run node commands
echo   test          Run PHPUnit tests
echo.
echo Database:
echo   mysql         Open MySQL CLI
echo   psql          Open PostgreSQL CLI
echo   redis         Open Redis CLI
echo.
echo Utilities:
echo   ssl           Generate SSL certificates
echo   mailpit       Show Mailpit logs
echo   backup        Backup all databases
echo   restore       Restore databases
echo   update        Update global plod template to latest version
echo   upgrade       Upgrade this project's plod files from global template
echo   help          Show this help message

goto end

:do_update
set "PLOD_HOME_DIR=%LOCALAPPDATA%\plod"
if not exist "%PLOD_HOME_DIR%" (
    echo Error: Plod global template is not installed.
    echo Run install.bat first, or clone the repo and run install.bat
    exit /b 1
)
set "REPO_URL=https://github.com/Guerrerohgp/phplocaldocker.git"
if exist "%PLOD_HOME_DIR%\.plod-repo" set /p REPO_URL=<"%PLOD_HOME_DIR%\.plod-repo"
set "OLD_VERSION=unknown"
if exist "%PLOD_HOME_DIR%\.plod-version" set /p OLD_VERSION=<"%PLOD_HOME_DIR%\.plod-version"
echo.
echo =============================================
echo   Updating Plod
echo =============================================
echo.
echo   Repository: %REPO_URL%
echo   Current version: %OLD_VERSION:~0,8%
echo.
set "TMP_DIR=%TEMP%\plod_update_%RANDOM%"
echo Cloning latest version...
git clone --depth 1 "%REPO_URL%" "%TMP_DIR%" >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Failed to clone repository.
    exit /b 1
)
set "NEW_VERSION=unknown"
for /f "tokens=*" %%i in ('git -C "%TMP_DIR%" rev-parse HEAD 2^>nul') do set "NEW_VERSION=%%i"
if "%OLD_VERSION%"=="%NEW_VERSION%" (
    echo.
    echo Already up to date.
    rmdir /s /q "%TMP_DIR%" >nul 2>&1
    exit /b 0
)
echo Updating template files...
rmdir /s /q "%PLOD_HOME_DIR%\docker" >nul 2>&1
xcopy /E /I /Q /Y "%TMP_DIR%\docker" "%PLOD_HOME_DIR%\docker" >nul
copy /Y "%TMP_DIR%\docker-compose.yml" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\.env.example" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\.gitignore" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\.gitattributes" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\.dockerignore" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\plod" "%PLOD_HOME_DIR%\" >nul
copy /Y "%TMP_DIR%\plod.bat" "%PLOD_HOME_DIR%\" >nul
rmdir /s /q "%PLOD_HOME_DIR%\public" >nul 2>&1
xcopy /E /I /Q /Y "%TMP_DIR%\public" "%PLOD_HOME_DIR%\public" >nul
if exist "%TMP_DIR%\README.md" copy /Y "%TMP_DIR%\README.md" "%PLOD_HOME_DIR%\" >nul
if exist "%TMP_DIR%\LICENSE" copy /Y "%TMP_DIR%\LICENSE" "%PLOD_HOME_DIR%\" >nul
if exist "%TMP_DIR%\SECURITY.md" copy /Y "%TMP_DIR%\SECURITY.md" "%PLOD_HOME_DIR%\" >nul
echo %REPO_URL%> "%PLOD_HOME_DIR%\.plod-repo"
echo %NEW_VERSION%> "%PLOD_HOME_DIR%\.plod-version"
rmdir /s /q "%TMP_DIR%" >nul 2>&1
echo.
echo =============================================
echo   Update Complete!
echo =============================================
echo.
echo   Previous version: %OLD_VERSION:~0,8%
echo   New version:      %NEW_VERSION:~0,8%
echo.
echo   To update this project, run:
echo     plod upgrade
echo.
exit /b 0

:do_upgrade
set "PLOD_HOME_DIR=%LOCALAPPDATA%\plod"
if not exist "%PLOD_HOME_DIR%" (
    echo Error: Plod global template is not installed.
    echo Run install.bat first, or clone the repo and run install.bat
    exit /b 1
)
set "TEMPLATE_VERSION=unknown"
if exist "%PLOD_HOME_DIR%\.plod-version" set /p TEMPLATE_VERSION=<"%PLOD_HOME_DIR%\.plod-version"
echo.
echo =============================================
echo   Upgrading Project
echo =============================================
echo.
echo   Directory: %CD%
echo   Template version: %TEMPLATE_VERSION:~0,8%
echo.
echo   This will update plod template files in your project.
echo   Your .env, public/, backups/, and source code will NOT be modified.
echo.
set /p "confirm=Continue? [Y/n]: "
if /i "%confirm%"=="n" (
    echo Upgrade cancelled.
    exit /b 0
)
echo.
echo Updating template files...
rmdir /s /q "%CD%\docker" >nul 2>&1
xcopy /E /I /Q /Y "%PLOD_HOME_DIR%\docker" "%CD%\docker" >nul
copy /Y "%PLOD_HOME_DIR%\docker-compose.yml" "%CD%\" >nul
copy /Y "%PLOD_HOME_DIR%\.dockerignore" "%CD%\" >nul
copy /Y "%PLOD_HOME_DIR%\plod" "%CD%\" >nul
copy /Y "%PLOD_HOME_DIR%\plod.bat" "%CD%\" >nul
if exist "%CD%\.env.example" (
    copy /Y "%CD%\.env.example" "%CD%\.env.example.bak" >nul
    echo   Backed up .env.example -^> .env.example.bak
)
copy /Y "%PLOD_HOME_DIR%\.env.example" "%CD%\" >nul
copy /Y "%PLOD_HOME_DIR%\.gitignore" "%CD%\" >nul
copy /Y "%PLOD_HOME_DIR%\.gitattributes" "%CD%\" >nul
if exist "%PLOD_HOME_DIR%\README.md" copy /Y "%PLOD_HOME_DIR%\README.md" "%CD%\" >nul
if exist "%PLOD_HOME_DIR%\LICENSE" copy /Y "%PLOD_HOME_DIR%\LICENSE" "%CD%\" >nul
if exist "%PLOD_HOME_DIR%\SECURITY.md" copy /Y "%PLOD_HOME_DIR%\SECURITY.md" "%CD%\" >nul
echo.
echo =============================================
echo   Upgrade Complete!
echo =============================================
echo.
echo   Template files updated to version %TEMPLATE_VERSION:~0,8%.
echo   Your .env, public/, backups/, and source code were preserved.
echo.
echo   If your docker-compose.yml or .env.example changed significantly,
echo   review the .env.example.bak backup and merge any custom settings.
echo.
echo   Run 'plod build' to rebuild containers with the new configuration.
echo.
exit /b 0

:end
endlocal
