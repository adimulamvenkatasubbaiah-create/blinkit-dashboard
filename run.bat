@echo off
REM ============================================================
REM  Blinkit Dashboard — Launcher
REM  1. Installs dependencies (skips if already present)
REM  2. Optionally runs database setup
REM  3. Launches Streamlit dashboard
REM ============================================================

echo.
echo  ========================================
echo   Blinkit Operations Dashboard Launcher
echo  ========================================
echo.

REM -- Install dependencies --
echo [1/3] Installing Python dependencies...
python -m pip install -r "%~dp0requirements.txt" --quiet
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: pip install failed. Make sure Python is on your PATH.
    pause
    exit /b 1
)
echo       Done.

REM -- Optional: run database setup --
echo.
set /p SETUP="[2/3] Run database setup (create tables + load data)? [y/N]: "
if /i "%SETUP%"=="y" (
    echo       Running setup_data.py...
    set SNOWFLAKE_DEFAULT_CONNECTION_NAME=PC95747
    python "%~dp0setup_data.py" --connection PC95747
    echo       Database setup complete.
) else (
    echo       Skipped database setup.
)

REM -- Launch Streamlit --
echo.
echo [3/3] Launching Streamlit dashboard...
echo       URL: http://localhost:8501
echo       Press Ctrl+C to stop.
echo.
set SNOWFLAKE_DEFAULT_CONNECTION_NAME=PC95747
streamlit run "%~dp0streamlit_app.py" --server.headless true
