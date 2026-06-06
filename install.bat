@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PLOD_HOME=%LOCALAPPDATA%\plod
set PLOD_BIN_DIR=%LOCALAPPDATA%\plod\bin
set PLOD_REPO=https://github.com/Guerrerohgp/phplocaldocker.git

echo.
echo =============================================
echo   Plod - Global Installer (Windows)
echo =============================================
echo.
echo This will install plod as a global command.
echo.
echo   Template location: %PLOD_HOME%
echo   Command location:  %PLOD_BIN_DIR%\plod.bat
echo.

set /p "confirm=Continue? [Y/n]: "
if /i "%confirm%"=="n" (
    echo Installation cancelled.
    exit /b 0
)

echo.
echo Installing plod template to %PLOD_HOME%...

if exist "%PLOD_HOME%" rmdir /s /q "%PLOD_HOME%"
mkdir "%PLOD_HOME%"
mkdir "%PLOD_HOME%\docker"
mkdir "%PLOD_BIN_DIR%"

xcopy /E /I /Q /Y "%SCRIPT_DIR%docker" "%PLOD_HOME%\docker" >nul
copy /Y "%SCRIPT_DIR%docker-compose.yml" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%.env.example" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%.gitignore" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%.gitattributes" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%.dockerignore" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%plod" "%PLOD_HOME%\" >nul
copy /Y "%SCRIPT_DIR%plod.bat" "%PLOD_HOME%\" >nul

if not exist "%PLOD_HOME%\public" mkdir "%PLOD_HOME%\public"
copy /Y "%SCRIPT_DIR%public\index.php" "%PLOD_HOME%\public\" >nul

if exist "%SCRIPT_DIR%README.md" copy /Y "%SCRIPT_DIR%README.md" "%PLOD_HOME%\" >nul
if exist "%SCRIPT_DIR%LICENSE" copy /Y "%SCRIPT_DIR%LICENSE" "%PLOD_HOME%\" >nul
if exist "%SCRIPT_DIR%SECURITY.md" copy /Y "%SCRIPT_DIR%SECURITY.md" "%PLOD_HOME%\" >nul

echo %PLOD_REPO%> "%PLOD_HOME%\.plod-repo"

if exist "%SCRIPT_DIR%.git" (
    for /f "tokens=*" %%i in ('git -C "%SCRIPT_DIR%" rev-parse HEAD 2^>nul') do set "GIT_VERSION=%%i"
    if defined GIT_VERSION (
        echo !GIT_VERSION!> "%PLOD_HOME%\.plod-version"
    ) else (
        echo unknown> "%PLOD_HOME%\.plod-version"
    )
) else (
    echo unknown> "%PLOD_HOME%\.plod-version"
)

echo Template installed.
echo.
echo Creating global command...

(
echo @echo off
echo setlocal enabledelayedexpansion
echo.
echo set "PLOD_HOME=%%LOCALAPPDATA%%\plod"
echo set "CURRENT_DIR=%%CD%%"
echo.
echo if "%%1"=="update" ^(
echo     call :do_update
echo     exit /b %%errorlevel%%
echo ^)
echo.
echo if "%%1"=="upgrade" ^(
echo     call :do_upgrade
echo     exit /b %%errorlevel%%
echo ^)
echo.
echo if "%%1"=="init" ^(
echo     if not exist "%%CURRENT_DIR%%\.env.example" ^(
echo         echo.
echo         echo Bootstrapping new plod project in %%CURRENT_DIR%%...
echo         echo.
echo.
echo         if not exist "%%PLOD_HOME%%" ^(
echo             echo Error: Plod is not installed. Run install.bat first.
echo             exit /b 1
echo         ^)
echo.
echo         xcopy /E /I /Q /Y "%%PLOD_HOME%%\docker" "%%CURRENT_DIR%%\docker" ^>nul
echo         copy /Y "%%PLOD_HOME%%\docker-compose.yml" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\.env.example" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\.gitignore" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\.gitattributes" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\.dockerignore" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\plod" "%%CURRENT_DIR%%\" ^>nul
echo         copy /Y "%%PLOD_HOME%%\plod.bat" "%%CURRENT_DIR%%\" ^>nul
echo.
echo         if not exist "%%CURRENT_DIR%%\public" mkdir "%%CURRENT_DIR%%\public"
echo         copy /Y "%%PLOD_HOME%%\public\index.php" "%%CURRENT_DIR%%\public\" ^>nul
echo.
echo         if exist "%%PLOD_HOME%%\README.md" if not exist "%%CURRENT_DIR%%\README.md" copy /Y "%%PLOD_HOME%%\README.md" "%%CURRENT_DIR%%\" ^>nul
echo         if exist "%%PLOD_HOME%%\LICENSE" if not exist "%%CURRENT_DIR%%\LICENSE" copy /Y "%%PLOD_HOME%%\LICENSE" "%%CURRENT_DIR%%\" ^>nul
echo         if exist "%%PLOD_HOME%%\SECURITY.md" if not exist "%%CURRENT_DIR%%\SECURITY.md" copy /Y "%%PLOD_HOME%%\SECURITY.md" "%%CURRENT_DIR%%\" ^>nul
echo.
echo         echo Project files copied. Running setup wizard...
echo         echo.
echo.
echo         call "%%CURRENT_DIR%%\docker\scripts\init.bat"
echo         exit /b %%errorlevel%%
echo     ^)
echo ^)
echo.
echo if exist "%%CURRENT_DIR%%\plod.bat" ^(
echo     if not "%%CURRENT_DIR%%\plod.bat"=="%%~f0" ^(
echo         call "%%CURRENT_DIR%%\plod.bat" %%*
echo         exit /b %%errorlevel%%
echo     ^)
echo ^)
echo.
echo if exist "%%CURRENT_DIR%%\.env.example" ^(
echo     if not exist "%%CURRENT_DIR%%\plod.bat" ^(
echo         copy /Y "%%PLOD_HOME%%\plod.bat" "%%CURRENT_DIR%%\" ^>nul
echo     ^)
echo     call "%%CURRENT_DIR%%\plod.bat" %%*
echo     exit /b %%errorlevel%%
echo ^)
echo.
echo echo Error: Not in a plod project directory.
echo echo.
echo echo Run 'plod init' in an empty directory to create a new project,
echo echo or navigate to an existing plod project directory.
echo exit /b 1
echo.
echo :do_update
echo if not exist "%%PLOD_HOME%%" ^(
echo     echo Error: Plod is not installed. Run install.bat first.
echo     exit /b 1
echo ^)
echo.
echo set "REPO_URL=https://github.com/Guerrerohgp/phplocaldocker.git"
echo if exist "%%PLOD_HOME%%\.plod-repo" set /p REPO_URL=^<"%%PLOD_HOME%%\.plod-repo"
echo.
echo set "OLD_VERSION=unknown"
echo if exist "%%PLOD_HOME%%\.plod-version" set /p OLD_VERSION=^<"%%PLOD_HOME%%\.plod-version"
echo.
echo echo.
echo echo =============================================
echo echo   Updating Plod
echo echo =============================================
echo echo.
echo echo   Repository: %%REPO_URL%%
echo echo   Current version: %%OLD_VERSION:~0,8%%
echo echo.
echo.
echo set "TMP_DIR=%%TEMP%%\plod_update_%%RANDOM%%"
echo echo Cloning latest version...
echo.
echo git clone --depth 1 "%%REPO_URL%%" "%%TMP_DIR%%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Failed to clone repository.
echo     exit /b 1
echo ^)
echo.
echo set "NEW_VERSION=unknown"
echo for /f "tokens=*" %%%%i in ('git -C "%%TMP_DIR%%" rev-parse HEAD 2^^^>nul'^) do set "NEW_VERSION=%%%%i"
echo.
echo if "%%OLD_VERSION%%"=="%%NEW_VERSION%%" ^(
echo     echo.
echo     echo Already up to date.
echo     rmdir /s /q "%%TMP_DIR%%" ^>nul 2^>^&1
echo     exit /b 0
echo ^)
echo.
echo echo Updating template files...
echo.
echo rmdir /s /q "%%PLOD_HOME%%\docker" ^>nul 2^>^&1
echo xcopy /E /I /Q /Y "%%TMP_DIR%%\docker" "%%PLOD_HOME%%\docker" ^>nul
echo copy /Y "%%TMP_DIR%%\docker-compose.yml" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\.env.example" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\.gitignore" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\.gitattributes" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\.dockerignore" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\plod" "%%PLOD_HOME%%\" ^>nul
echo copy /Y "%%TMP_DIR%%\plod.bat" "%%PLOD_HOME%%\" ^>nul
echo rmdir /s /q "%%PLOD_HOME%%\public" ^>nul 2^>^&1
echo xcopy /E /I /Q /Y "%%TMP_DIR%%\public" "%%PLOD_HOME%%\public" ^>nul
echo.
echo if exist "%%TMP_DIR%%\README.md" copy /Y "%%TMP_DIR%%\README.md" "%%PLOD_HOME%%\" ^>nul
echo if exist "%%TMP_DIR%%\LICENSE" copy /Y "%%TMP_DIR%%\LICENSE" "%%PLOD_HOME%%\" ^>nul
echo if exist "%%TMP_DIR%%\SECURITY.md" copy /Y "%%TMP_DIR%%\SECURITY.md" "%%PLOD_HOME%%\" ^>nul
echo.
echo echo %%REPO_URL%%^> "%%PLOD_HOME%%\.plod-repo"
echo echo %%NEW_VERSION%%^> "%%PLOD_HOME%%\.plod-version"
echo.
echo rmdir /s /q "%%TMP_DIR%%" ^>nul 2^>^&1
echo.
echo echo.
echo echo =============================================
echo echo   Update Complete!
echo echo =============================================
echo echo.
echo echo   Previous version: %%OLD_VERSION:~0,8%%
echo echo   New version:      %%NEW_VERSION:~0,8%%
echo echo.
echo echo   To update an existing project, run:
echo echo     cd your-project ^&^& plod upgrade
echo echo.
echo exit /b 0
echo.
echo :do_upgrade
echo if not exist "%%PLOD_HOME%%" ^(
echo     echo Error: Plod global template is not installed. Run install.bat first.
echo     exit /b 1
echo ^)
echo.
echo if not exist "%%CURRENT_DIR%%\.env.example" ^(
echo     echo Error: Not in a plod project directory.
echo     exit /b 1
echo ^)
echo.
echo set "TEMPLATE_VERSION=unknown"
echo if exist "%%PLOD_HOME%%\.plod-version" set /p TEMPLATE_VERSION=^<"%%PLOD_HOME%%\.plod-version"
echo.
echo echo.
echo echo =============================================
echo echo   Upgrading Project
echo echo =============================================
echo echo.
echo echo   Directory: %%CURRENT_DIR%%
echo echo   Template version: %%TEMPLATE_VERSION:~0,8%%
echo echo.
echo echo   This will update plod template files in your project.
echo echo   Your .env, public/, backups/, and source code will NOT be modified.
echo echo.
echo.
echo set /p "confirm=Continue? [Y/n]: "
echo if /i "%%confirm%%"=="n" ^(
echo     echo Upgrade cancelled.
echo     exit /b 0
echo ^)
echo.
echo echo.
echo echo Updating template files...
echo.
echo rmdir /s /q "%%CURRENT_DIR%%\docker" ^>nul 2^>^&1
echo xcopy /E /I /Q /Y "%%PLOD_HOME%%\docker" "%%CURRENT_DIR%%\docker" ^>nul
echo copy /Y "%%PLOD_HOME%%\docker-compose.yml" "%%CURRENT_DIR%%\" ^>nul
echo copy /Y "%%PLOD_HOME%%\.dockerignore" "%%CURRENT_DIR%%\" ^>nul
echo copy /Y "%%PLOD_HOME%%\plod" "%%CURRENT_DIR%%\" ^>nul
echo copy /Y "%%PLOD_HOME%%\plod.bat" "%%CURRENT_DIR%%\" ^>nul
echo.
echo if exist "%%CURRENT_DIR%%\.env.example" ^(
echo     copy /Y "%%CURRENT_DIR%%\.env.example" "%%CURRENT_DIR%%\.env.example.bak" ^>nul
echo     echo   Backed up .env.example -^> .env.example.bak
echo ^)
echo copy /Y "%%PLOD_HOME%%\.env.example" "%%CURRENT_DIR%%\" ^>nul
echo.
echo copy /Y "%%PLOD_HOME%%\.gitignore" "%%CURRENT_DIR%%\" ^>nul
echo copy /Y "%%PLOD_HOME%%\.gitattributes" "%%CURRENT_DIR%%\" ^>nul
echo.
echo if exist "%%PLOD_HOME%%\README.md" copy /Y "%%PLOD_HOME%%\README.md" "%%CURRENT_DIR%%\" ^>nul
echo if exist "%%PLOD_HOME%%\LICENSE" copy /Y "%%PLOD_HOME%%\LICENSE" "%%CURRENT_DIR%%\" ^>nul
echo if exist "%%PLOD_HOME%%\SECURITY.md" copy /Y "%%PLOD_HOME%%\SECURITY.md" "%%CURRENT_DIR%%\" ^>nul
echo.
echo echo.
echo echo =============================================
echo echo   Upgrade Complete!
echo echo =============================================
echo echo.
echo echo   Template files updated to version %%TEMPLATE_VERSION:~0,8%%.
echo echo   Your .env, public/, backups/, and source code were preserved.
echo echo.
echo echo   If your docker-compose.yml or .env.example changed significantly,
echo echo   review the .env.example.bak backup and merge any custom settings.
echo echo.
echo echo   Run 'plod build' to rebuild containers with the new configuration.
echo echo.
echo exit /b 0
) > "%PLOD_BIN_DIR%\plod.bat"

echo Global command created.
echo.

echo Checking PATH...
echo %PATH% | findstr /i "%PLOD_BIN_DIR%" >nul
if %errorlevel% neq 0 (
    echo Adding %PLOD_BIN_DIR% to user PATH...
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%b"
    if defined CURRENT_PATH (
        setx PATH "!CURRENT_PATH!;%PLOD_BIN_DIR%" >nul
    ) else (
        setx PATH "%PLOD_BIN_DIR%" >nul
    )
    echo PATH updated. You may need to restart your terminal for changes to take effect.
) else (
    echo PATH already includes plod directory.
)

echo.
echo =============================================
echo   Installation Complete!
echo =============================================
echo.
echo You can now use plod from anywhere:
echo.
echo   REM Create a new project
echo   mkdir my-project ^&^& cd my-project
echo   plod init
echo.
echo   REM Use in an existing project
echo   cd my-project
echo   plod up
echo   plod composer install
echo   plod npm install
echo.
echo   REM Update global template
echo   plod update
echo.
echo   REM Upgrade an existing project
echo   cd my-project ^&^& plod upgrade
echo.
echo NOTE: If 'plod' is not recognized, restart your terminal
echo       to reload the PATH environment variable.
echo.
echo To uninstall:
echo   rmdir /s /q "%PLOD_HOME%"
echo   REM Remove %PLOD_BIN_DIR% from PATH
echo.

endlocal
