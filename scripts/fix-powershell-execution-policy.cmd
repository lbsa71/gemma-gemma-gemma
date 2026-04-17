@echo off
REM One double-click / cmd path: runs the fixer with Bypass so it works even when policy blocks scripts.
cd /d "%~dp0\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-powershell-execution-policy.ps1"
exit /b %ERRORLEVEL%
