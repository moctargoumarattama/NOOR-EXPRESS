@echo off
setlocal

cd /d "%~dp0"
if exist "%~dp0venv\Scripts\python.exe" (
  "%~dp0venv\Scripts\python.exe" "%~dp0run.py"
) else (
  python "%~dp0run.py"
)

endlocal
