@echo off
setlocal
set GODOT=D:\software\Godot4\Godot_v4.7.2-stable_win64_console.exe
cd /d "%~dp0"
set PROJ=%~dp0.
if not exist build mkdir build
echo === Exporting Windows release ===
"%GODOT%" --headless --path "%PROJ%" --export-release "Windows Desktop" "build/FarmStory.exe"
if errorlevel 1 goto failed
echo.
echo Done: build\FarmStory.exe
goto end
:failed
echo.
echo Export failed. Check that 4.7.2 export templates are installed.
:end
endlocal
