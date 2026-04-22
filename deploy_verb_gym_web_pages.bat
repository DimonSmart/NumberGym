@echo off
setlocal

where pwsh >nul 2>&1
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\publish_verb_gym_web.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\publish_verb_gym_web.ps1" %*
)

exit /b %errorlevel%
