@echo off
echo Updating, building, and cleaning...
echo.
docker-compose build --pull > NUL
echo.
echo Starting codex...
echo.
docker-compose run --service-ports --remove-orphans codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to run docker-cleanup.bat and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

call "%~dp0docker-cleanup.bat" -y
echo.
echo Retrying...
echo.
docker-compose build --pull > NUL
docker-compose run --service-ports --rm --remove-orphans codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
