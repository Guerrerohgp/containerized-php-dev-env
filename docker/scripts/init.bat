@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..
set ENV_FILE=%PROJECT_ROOT%\.env
set ENV_EXAMPLE=%PROJECT_ROOT%\.env.example

if not exist "%ENV_EXAMPLE%" (
    echo Error: .env.example not found in %PROJECT_ROOT%
    exit /b 1
)

echo.
echo =============================================
echo   Plod - PHP Project Setup Wizard
echo =============================================
echo.

echo --- Project Settings ---
echo.

set /p "PROJECT_NAME=Project name [myapp]: "
if "%PROJECT_NAME%"=="" set PROJECT_NAME=myapp

set /p "PROJECT_DOMAIN=Project domain [%PROJECT_NAME%.test]: "
if "%PROJECT_DOMAIN%"=="" set PROJECT_DOMAIN=%PROJECT_NAME%.test

echo.
echo --- PHP Configuration ---
echo.

echo Select PHP version:
echo   1^) 7.4
echo   2^) 8.0
echo   3^) 8.1
echo   4^) 8.2 (default)
echo   5^) 8.3
echo   6^) 8.4
echo   7^) 8.5
set /p "PHP_CHOICE=Choose [4]: "
if "%PHP_CHOICE%"=="" set PHP_CHOICE=4
if "%PHP_CHOICE%"=="1" set PHP_VERSION=7.4
if "%PHP_CHOICE%"=="2" set PHP_VERSION=8.0
if "%PHP_CHOICE%"=="3" set PHP_VERSION=8.1
if "%PHP_CHOICE%"=="4" set PHP_VERSION=8.2
if "%PHP_CHOICE%"=="5" set PHP_VERSION=8.3
if "%PHP_CHOICE%"=="6" set PHP_VERSION=8.4
if "%PHP_CHOICE%"=="7" set PHP_VERSION=8.5
if not defined PHP_VERSION set PHP_VERSION=8.2

echo.
echo Select Node.js version:
echo   1^) 18
echo   2^) 20 (default)
echo   3^) 22
set /p "NODE_CHOICE=Choose [2]: "
if "%NODE_CHOICE%"=="" set NODE_CHOICE=2
if "%NODE_CHOICE%"=="1" set NODE_VERSION=18
if "%NODE_CHOICE%"=="2" set NODE_VERSION=20
if "%NODE_CHOICE%"=="3" set NODE_VERSION=22
if not defined NODE_VERSION set NODE_VERSION=20

echo.
echo --- Framework ---
echo.

echo Select a framework:
echo   1^) None (set up manually)
echo   2^) Laravel
echo   3^) WordPress
echo   4^) Laminas
set /p "FW_CHOICE=Choose [1]: "
if "%FW_CHOICE%"=="" set FW_CHOICE=1
set FRAMEWORK=none
if "%FW_CHOICE%"=="2" set FRAMEWORK=laravel
if "%FW_CHOICE%"=="3" set FRAMEWORK=wordpress
if "%FW_CHOICE%"=="4" set FRAMEWORK=laminas

echo.
echo --- Databases ---
echo.

echo Which database(s) do you need?
echo   1^) MySQL (default)
echo   2^) PostgreSQL
echo   3^) Both
set /p "DB_CHOICE=Choose [1]: "
if "%DB_CHOICE%"=="" set DB_CHOICE=1
set ENABLE_MYSQL=true
set ENABLE_POSTGRES=false
if "%DB_CHOICE%"=="2" (
    set ENABLE_MYSQL=false
    set ENABLE_POSTGRES=true
)
if "%DB_CHOICE%"=="3" (
    set ENABLE_MYSQL=true
    set ENABLE_POSTGRES=true
)

echo.
echo --- Additional Services ---
echo.

set /p "ENABLE_REDIS=Enable Redis? (true/false) [true]: "
if "%ENABLE_REDIS%"=="" set ENABLE_REDIS=true

set /p "ENABLE_MAILPIT=Enable Mailpit? (true/false) [true]: "
if "%ENABLE_MAILPIT%"=="" set ENABLE_MAILPIT=true

set /p "ENABLE_SSL=Enable SSL proxy? (true/false) [true]: "
if "%ENABLE_SSL%"=="" set ENABLE_SSL=true

echo.
echo --- Port Configuration ---
echo.

set /p "APP_PORT=HTTP port [80]: "
if "%APP_PORT%"=="" set APP_PORT=80

echo.
echo =============================================
echo   Generating configuration...
echo =============================================
echo.

copy /Y "%ENV_EXAMPLE%" "%ENV_FILE%" >nul

set "COMPOSE_PROJECT_NAME=%PROJECT_NAME%"

set "PROFILES="
if "%ENABLE_MYSQL%"=="true" set "PROFILES=mysql"
if "%ENABLE_POSTGRES%"=="true" (
    if defined PROFILES (
        set "PROFILES=!PROFILES!,postgres"
    ) else (
        set "PROFILES=postgres"
    )
)
if "%ENABLE_REDIS%"=="true" (
    if defined PROFILES (
        set "PROFILES=!PROFILES!,redis"
    ) else (
        set "PROFILES=redis"
    )
)
if "%ENABLE_MAILPIT%"=="true" (
    if defined PROFILES (
        set "PROFILES=!PROFILES!,mailpit"
    ) else (
        set "PROFILES=mailpit"
    )
)
if "%ENABLE_SSL%"=="true" (
    if defined PROFILES (
        set "PROFILES=!PROFILES!,ssl"
    ) else (
        set "PROFILES=ssl"
    )
)

powershell -Command "(Get-Content '%ENV_FILE%') -replace '^PROJECT_NAME=.*','PROJECT_NAME=%PROJECT_NAME%' -replace '^PROJECT_DOMAIN=.*','PROJECT_DOMAIN=%PROJECT_DOMAIN%' -replace '^PHP_VERSION=.*','PHP_VERSION=%PHP_VERSION%' -replace '^NODE_VERSION=.*','NODE_VERSION=%NODE_VERSION%' -replace '^APP_PORT=.*','APP_PORT=%APP_PORT%' -replace '^REDIS_ENABLED=.*','REDIS_ENABLED=%ENABLE_REDIS%' -replace '^MAILPIT_ENABLED=.*','MAILPIT_ENABLED=%ENABLE_MAILPIT%' -replace '^SSL_ENABLED=.*','SSL_ENABLED=%ENABLE_SSL%' -replace '^COMPOSE_PROJECT_NAME=.*','COMPOSE_PROJECT_NAME=%COMPOSE_PROJECT_NAME%' -replace '^COMPOSE_PROFILES=.*','COMPOSE_PROFILES=%PROFILES%' | Set-Content '%ENV_FILE%'"

echo .env file created successfully.
echo.
echo Active profiles: %PROFILES%
echo.

echo =============================================
echo   Building containers...
echo =============================================
echo.

set DOCKER_COMPOSE=docker-compose
where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
    docker compose version >nul 2>nul
    if !errorlevel! equ 0 (
        set DOCKER_COMPOSE=docker compose
    ) else (
        echo Error: docker-compose is not installed.
        exit /b 1
    )
)

set COMPOSE_PROFILES=%PROFILES%

%DOCKER_COMPOSE% build --build-arg WWWGROUP=1000 --build-arg PHP_POST_MAX_SIZE=100M --build-arg PHP_UPLOAD_MAX_FILESIZE=100M --build-arg PHP_MAX_EXECUTION_TIME=300 --build-arg PHP_SHORT_OPEN_TAG=Off

echo.
echo =============================================
echo   Starting containers...
echo =============================================
echo.

%DOCKER_COMPOSE% up -d

echo.
echo =============================================
echo   Setup Complete!
echo =============================================
echo.
echo   Project:   %PROJECT_NAME%
echo   Domain:    %PROJECT_DOMAIN%
echo   PHP:       %PHP_VERSION%
echo   Node:      %NODE_VERSION%
echo   URL:       http://localhost:%APP_PORT%
echo.

if "%ENABLE_SSL%"=="true" (
    echo   To generate SSL certificates:
    echo     plod.bat ssl
    echo.
)

if "%FRAMEWORK%"=="laravel" (
    echo   Installing Laravel...
    echo.
    %DOCKER_COMPOSE% exec -T app composer create-project laravel/laravel . --prefer-dist --no-interaction
    echo.
    echo   Laravel installed! Configure your .env:
    echo     DB_HOST=mysql
    echo     DB_DATABASE=myapp
    echo     DB_USERNAME=myapp
    echo     DB_PASSWORD=secret
    echo     CACHE_DRIVER=redis
    echo     MAIL_MAILER=smtp
    echo     MAIL_HOST=mailpit
    echo     MAIL_PORT=1025
    echo.
)
if "%FRAMEWORK%"=="wordpress" (
    echo   Installing WordPress...
    echo.
    %DOCKER_COMPOSE% exec -T app wp core download --allow-root
    echo.
    echo   WordPress downloaded! Configure wp-config.php with:
    echo     DB_NAME: myapp
    echo     DB_USER: myapp
    echo     DB_PASSWORD: secret
    echo     DB_HOST: mysql
    echo.
)
if "%FRAMEWORK%"=="laminas" (
    echo   Installing Laminas...
    echo.
    %DOCKER_COMPOSE% exec -T app composer create-project laminas/laminas-mvc-skeleton . --prefer-dist --no-interaction
    echo.
    echo   Laminas installed!
    echo.
)
if "%FRAMEWORK%"=="none" (
    echo   No framework selected. Start building in the public/ directory.
    echo.
)

echo   Useful commands:
echo     plod.bat shell       - Open a shell in the container
echo     plod.bat composer    - Run Composer commands
echo     plod.bat npm install - Install Node dependencies
echo     plod.bat logs        - View container logs
echo     plod.bat help        - See all commands
echo.

endlocal
