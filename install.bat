@echo off
setlocal EnableDelayedExpansion
title [NM Zone] Auto Setup - Windows
color 0B

echo.
echo  ============================================
echo   NM Zone - One-Click Windows Setup
echo  ============================================
echo.

:: ============================================
:: CHECK ADMIN PRIVILEGES
:: ============================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo [+] Running as Administrator...
echo.

:: ============================================
:: STEP 1: CHECK / INSTALL PYTHON
:: ============================================
echo [*] Checking for Python...
where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYVER=%%i
    echo [+] Found: !PYVER!
    goto :python_done
)

echo [!] Python not found. Installing Python 3.12...
echo [*] Downloading Python installer...

set "PY_URL=https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
set "PY_INSTALLER=%TEMP%\python_installer.exe"

powershell -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%'" 2>nul
if not exist "%PY_INSTALLER%" (
    echo [!] Download failed. Trying with curl...
    curl -L -o "%PY_INSTALLER%" "%PY_URL%"
)

if not exist "%PY_INSTALLER%" (
    echo [ERROR] Could not download Python. Please install manually from python.org
    pause
    exit /b 1
)

echo [*] Installing Python silently (this may take a minute)...
"%PY_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_test=0

:: Refresh PATH
set "PATH=%LocalAppData%\Programs\Python\Python312;%LocalAppData%\Programs\Python\Python312\Scripts;C:\Python312;C:\Python312\Scripts;%ProgramFiles%\Python312;%ProgramFiles%\Python312\Scripts;%PATH%"

:: Verify
timeout /t 3 /nobreak >nul
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Python installed but PATH not updated yet.
    echo [*] Trying common install locations...
    if exist "C:\Python312\python.exe" set "PATH=C:\Python312;C:\Python312\Scripts;%PATH%"
    if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PATH=%LocalAppData%\Programs\Python\Python312;%LocalAppData%\Programs\Python\Python312\Scripts;%PATH%"
    if exist "%ProgramFiles%\Python312\python.exe" set "PATH=%ProgramFiles%\Python312;%ProgramFiles%\Python312\Scripts;%PATH%"
)

del "%PY_INSTALLER%" 2>nul
echo [+] Python installation complete!

:python_done
echo.

:: ============================================
:: STEP 2: CHECK / INSTALL GIT
:: ============================================
echo [*] Checking for Git...
where git >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('git --version 2^>^&1') do set GITVER=%%i
    echo [+] Found: !GITVER!
    goto :git_done
)

echo [!] Git not found. Installing Git for Windows...
echo [*] Downloading Git installer...

set "GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
set "GIT_INSTALLER=%TEMP%\git_installer.exe"

powershell -Command "Invoke-WebRequest -Uri '%GIT_URL%' -OutFile '%GIT_INSTALLER%'" 2>nul
if not exist "%GIT_INSTALLER%" (
    echo [!] Download failed. Trying with curl...
    curl -L -o "%GIT_INSTALLER%" "%GIT_URL%"
)

if not exist "%GIT_INSTALLER%" (
    echo [ERROR] Could not download Git. Please install manually from git-scm.com
    pause
    exit /b 1
)

echo [*] Installing Git silently...
"%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"

:: Refresh PATH for Git
set "PATH=C:\Program Files\Git\bin;C:\Program Files\Git\cmd;%PATH%"

timeout /t 3 /nobreak >nul
del "%GIT_INSTALLER%" 2>nul
echo [+] Git installation complete!

:git_done
echo.

:: ============================================
:: STEP 3: UPGRADE PIP
:: ============================================
echo [*] Upgrading pip...
python -m pip install --upgrade pip --quiet 2>nul
echo [+] pip upgraded.
echo.

:: ============================================
:: STEP 4: INSTALL PYTHON DEPENDENCIES
:: ============================================
echo [*] Installing Python libraries...

set "PIPARGS=requests colorama rich cryptography openpyxl urllib3"

python -m pip install %PIPARGS% --quiet
if %errorlevel% equ 0 (
    echo [+] All libraries installed successfully!
) else (
    echo [!] Retrying with --break-system-packages flag...
    python -m pip install %PIPARGS% --break-system-packages --quiet
)
echo.

:: ============================================
:: STEP 5: CLONE REPO / DOWNLOAD FILES
:: ============================================
echo [*] Setting up bot files...

set "INSTALL_DIR=%USERPROFILE%\NMZone"

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Try Git clone first
where git >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%INSTALL_DIR%\nehaldev" (
        echo [*] Updating existing repo...
        cd /d "%INSTALL_DIR%\nehaldev"
        git pull --quiet
    ) else (
        echo [*] Cloning repository...
        git clone https://github.com/Nehal987/nehaldev.git "%INSTALL_DIR%\nehaldev"
    )
) else (
    echo [*] Git not available, downloading files directly...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Nehal987/nehaldev/main/auth.py' -OutFile '%INSTALL_DIR%\auth.py'"
    goto :files_ready
)

:: Copy auth.py to main install dir for easy access
if exist "%INSTALL_DIR%\nehaldev\auth.py" (
    copy /Y "%INSTALL_DIR%\nehaldev\auth.py" "%INSTALL_DIR%\auth.py" >nul
)

:files_ready
echo [+] Bot files ready at: %INSTALL_DIR%
echo.

:: ============================================
:: STEP 6: VERIFY INSTALLATION
:: ============================================
echo  ============================================
echo   VERIFICATION
echo  ============================================
echo.

where python >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo  [OK] %%i
) else (
    echo  [FAIL] Python not found in PATH
)

where git >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('git --version 2^>^&1') do echo  [OK] %%i
) else (
    echo  [WARN] Git not found in PATH
)

python -c "import requests, colorama, rich, cryptography" 2>nul
if %errorlevel% equ 0 (
    echo  [OK] All Python libraries verified
) else (
    echo  [WARN] Some libraries may be missing
)

if exist "%INSTALL_DIR%\auth.py" (
    echo  [OK] auth.py found
) else (
    echo  [FAIL] auth.py not found
)

echo.
echo  ============================================
echo   INSTALLATION COMPLETE!
echo  ============================================
echo.
echo  Bot Location: %INSTALL_DIR%
echo.

:: ============================================
:: STEP 7: AUTO-START BOT
:: ============================================
echo [+] Launching Bot in 3 seconds...
timeout /t 3 /nobreak >nul

cd /d "%INSTALL_DIR%"
python auth.py

pause
