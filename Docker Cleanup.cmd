@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0container\scripts\docker-cleanup.ps1"
