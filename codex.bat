@echo off
echo Updating, building, and cleaning...
echo.
docker-compose build --pull > NUL
echo.
echo Starting codex...
echo.

:: Reuse existing container if it exists, otherwise create one
docker container inspect codex-session >nul 2>&1
if %errorlevel% equ 0 (
    docker start -ai codex-session
) else (
    docker-compose run --service-ports --name codex-session codex
)
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to stop containers, and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

echo.
echo Shutting down containers...
docker rm -f codex-session >nul 2>&1
docker-compose down --remove-orphans
echo.
echo Retrying...
echo.
docker-compose build --pull > NUL
docker-compose run --service-ports --name codex-session codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
