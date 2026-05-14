@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0container\scripts\migrate-old-codex-settings.ps1"
