@echo off
setlocal
cd /d "%~dp0"
echo.
echo ========================================
echo  Codex + Gemini Orchestrator Setup
echo ========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Setup failed with exit code %EXITCODE%.
) else (
  echo Setup finished successfully.
)
echo.
pause
exit /b %EXITCODE%
