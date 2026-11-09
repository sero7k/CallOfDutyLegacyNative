@echo off
setlocal enabledelayedexpansion
rem CoD Legacy updater: pull latest, build Release, install into the game folder.
rem Put this file in the repo root (next to generate.bat) and double-click it.

set "GAME=C:\Users\Gaming PC\Documents\mwr_game_files"
set "BRANCH=bo2-hud"
set "REPO=%~dp0"
set "LOG=%REPO%update_log.txt"

cd /d "%REPO%"
echo CoD Legacy update %date% %time% > "%LOG%"

echo [1/5] Pulling %BRANCH%...
git fetch origin %BRANCH% >> "%LOG%" 2>&1
git checkout %BRANCH% >> "%LOG%" 2>&1
git pull --ff-only origin %BRANCH% >> "%LOG%" 2>&1
if errorlevel 1 (echo Pull failed - local changes in the way? See update_log.txt & goto :fail)

echo [2/5] Submodules and project files...
call generate.bat >> "%LOG%" 2>&1
if not exist "build\h1-mod.sln" (echo generate.bat did not produce build\h1-mod.sln & goto :fail)

echo [3/5] Finding MSBuild...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "MSBUILD="
if exist "%VSWHERE%" (
  for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSBUILD=%%I"
)
if not defined MSBUILD if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" set "MSBUILD=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if not defined MSBUILD (echo MSBuild not found. Install VS 2022 with the C++ workload. & goto :fail)

echo [4/5] Building Release x64 (this takes a while)...
"%MSBUILD%" build\h1-mod.sln /m /nologo /v:m /p:Configuration=Release /p:Platform=x64 >> "%LOG%" 2>&1
if errorlevel 1 (echo Build failed. See update_log.txt & goto :fail)

echo [5/5] Installing into %GAME%...
if not exist "%GAME%" (echo Game folder not found: %GAME% & goto :fail)
set "EXE=build\bin\x64\Release\h1-mod.exe"
if not exist "%EXE%" (echo Built exe not found: %EXE% & goto :fail)
copy /y "%EXE%" "%GAME%\CoD Legacy.exe" >> "%LOG%" 2>&1
if errorlevel 1 (echo Could not copy the exe - is the game still running? & goto :fail)

rem Loose UI scripts (claude_hud etc.); drop the abandoned bo2_hud.
if exist "%GAME%\h1-mod\ui_scripts\bo2_hud" rmdir /s /q "%GAME%\h1-mod\ui_scripts\bo2_hud"
xcopy /e /i /y "data\cdata\ui_scripts" "%GAME%\h1-mod\ui_scripts" >> "%LOG%" 2>&1

echo.
echo Done. Run "CoD Legacy.exe" and look for [claude_ui] / [claude_hud] in the console.
pause
exit /b 0

:fail
echo.
echo FAILED - details in "%LOG%"
pause
exit /b 1
