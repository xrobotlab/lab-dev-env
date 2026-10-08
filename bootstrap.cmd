@echo off
setlocal DisableDelayedExpansion
set "LAB_DEV_ENV_ROOT=%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "try { $p=Join-Path $env:LAB_DEV_ENV_ROOT 'scripts\bootstrap-entry.ps1'; $c=[IO.File]::ReadAllText($p,[Text.UTF8Encoding]::new($false)); & ([ScriptBlock]::Create($c)) } catch { Write-Host $_; Read-Host 'Press Enter to close'; exit 1 }"
exit /b %errorlevel%
