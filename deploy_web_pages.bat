@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM --- Config ---
set "BASE_HREF=/NumberGym/"
set "PAGES_URL=https://dimonsmart.github.io/NumberGym/"
set "COMMIT_MSG=Deploy web"

REM --- Sanity checks ---
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: git not found in PATH.
  exit /b 1
)
where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found in PATH.
  exit /b 1
)

REM Resolve repo root and move there (works even if script is run elsewhere)
for /f "delims=" %%i in ('git rev-parse --show-toplevel 2^>nul') do set "REPO_ROOT=%%i"
if not defined REPO_ROOT (
  echo ERROR: Not inside a git repository.
  exit /b 1
)
cd /d "%REPO_ROOT%"

REM Temp folders (outside repo)
set "DEPLOY_SRC=%TEMP%\numbergym_web_%RANDOM%%RANDOM%"
set "WORKTREE=%TEMP%\numbergym_gh_pages_%RANDOM%%RANDOM%"

mkdir "%DEPLOY_SRC%" >nul 2>&1
if errorlevel 1 (
  echo ERROR: Cannot create temp folder: %DEPLOY_SRC%
  exit /b 1
)

echo [1/6] Build Flutter Web...
call flutter build web --release --base-href "%BASE_HREF%"
if errorlevel 1 goto :fail

if not exist "build\web\index.html" (
  echo ERROR: build\web\index.html not found. Build failed?
  goto :fail
)

echo [2/6] Prepare helper files for GitHub Pages...
type nul > "build\web\.nojekyll"
copy /Y "build\web\index.html" "build\web\404.html" >nul

echo [3/6] Copy build to temp folder...
robocopy "build\web" "%DEPLOY_SRC%" /E >nul
set "RC=%errorlevel%"
if %RC% GEQ 8 (
  echo ERROR: robocopy build^>temp failed with code %RC%
  goto :fail
)

echo [4/6] Prepare gh-pages worktree...
git fetch origin >nul 2>&1

git show-ref --verify --quiet refs/heads/gh-pages
if %errorlevel%==0 (
  git worktree add -f "%WORKTREE%" gh-pages
  if errorlevel 1 goto :fail
) else (
  git ls-remote --exit-code --heads origin gh-pages >nul 2>&1
  if %errorlevel%==0 (
    git fetch origin gh-pages >nul 2>&1
    git worktree add -f -b gh-pages "%WORKTREE%" origin/gh-pages
    if errorlevel 1 goto :fail
  ) else (
    git worktree add -f -b gh-pages "%WORKTREE%"
    if errorlevel 1 goto :fail
  )
)

echo [5/6] Sync build to gh-pages worktree...
robocopy "%DEPLOY_SRC%" "%WORKTREE%" /MIR /XD .git /XF .git >nul
set "RC=%errorlevel%"
if %RC% GEQ 8 (
  echo ERROR: robocopy temp^>worktree failed with code %RC%
  goto :fail
)

echo [6/6] Commit and push...
git -C "%WORKTREE%" add -A
git -C "%WORKTREE%" diff --cached --quiet
if %errorlevel%==0 (
  echo No changes to deploy.
  goto :cleanup
)

git -C "%WORKTREE%" commit -m "%COMMIT_MSG%"
if errorlevel 1 goto :fail

git -C "%WORKTREE%" push -u origin gh-pages
if errorlevel 1 goto :fail

echo.
echo DONE.
echo Site URL: %PAGES_URL%
goto :cleanup

:cleanup
if exist "%WORKTREE%" git worktree remove --force "%WORKTREE%" >nul 2>&1
if exist "%DEPLOY_SRC%" rd /s /q "%DEPLOY_SRC%" >nul 2>&1
endlocal
exit /b 0

:fail
echo.
echo DEPLOY FAILED.
if exist "%WORKTREE%" git worktree remove --force "%WORKTREE%" >nul 2>&1
if exist "%DEPLOY_SRC%" rd /s /q "%DEPLOY_SRC%" >nul 2>&1
endlocal
exit /b 1
