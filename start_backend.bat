@echo off
echo ============================================
echo   Fleet Dispatch AI Assistant - Backend Server
echo ============================================
echo.

:: Clear __pycache__ to avoid stale bytecode
echo Clearing __pycache__...
for /d /r "backend" %%d in (__pycache__) do (
    if exist "%%d" rd /s /q "%%d"
)
echo Done.
echo.

:: Start uvicorn
echo Starting FastAPI server on 0.0.0.0:8000 ...
echo Web UI:  http://localhost:8000/
echo API:     http://localhost:8000/api/query
echo.
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

pause
