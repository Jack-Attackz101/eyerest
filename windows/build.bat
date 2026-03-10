@echo off
echo ============================================================
echo  EyeRest — Build Windows .exe
echo ============================================================

:: Install deps
pip install -r requirements.txt
pip install pyinstaller

:: Build single-file exe with no console window
pyinstaller ^
  --onefile ^
  --windowed ^
  --name "EyeRest" ^
  --icon "icon.ico" ^
  eyerest.py

echo.
echo Done! Find EyeRest.exe in the dist\ folder.
pause
