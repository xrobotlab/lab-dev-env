@echo off
setlocal
set "LAB_DEV_ENV_ROOT=%~dp0"
powershell.exe -NoProfile -Command "$p=Join-Path $env:LAB_DEV_ENV_ROOT 'scripts\bootstrap.ps1'; $c=[IO.File]::ReadAllText($p,[Text.UTF8Encoding]::new($false)); & ([ScriptBlock]::Create($c))"
exit /b %errorlevel%
