@echo off
echo WARNING: This will stop all running Codex containers and
echo interrupt any active sessions in this sandbox.
echo.
echo Stopping containers...
echo.
docker-compose stop
echo.
echo Containers stopped. They can be restarted with start.bat.
echo.
pause
