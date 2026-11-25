@echo off
rem claude-config setup launcher for Command Prompt, Windows Terminal or
rem PowerShell. Uses Windows PowerShell 5.1, which every Windows machine has.
rem The execution policy override applies to this one process only and cannot
rem override Group Policy. Arguments are passed on, e.g. setup.cmd -DryRun
setlocal
rem Started from PowerShell 7, PSModulePath points at its modules, which
rem Windows PowerShell cannot load; clearing it restores the defaults.
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\setup.ps1" %*
exit /b %ERRORLEVEL%
