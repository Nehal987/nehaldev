@echo off
setlocal EnableDelayedExpansion
title [NM Zone] Auto Setup - Windows
color 0B

echo.
echo  ============================================
echo   NM Zone - One-Click Windows Setup
echo   Fully Automatic - No Input Needed
echo  ============================================
echo.

:: ============================================
:: AUTO ADMIN ELEVATE (No prompt, just UAC)
:: ============================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo [+] Running as Administrator...
echo.

:: Set TLS 1.2 globally
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" >nul 2>&1

:: Install folder on DESKTOP
set "INSTALL_DIR=%USERPROFILE%\Desktop\Nehaldev"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: ============================================
:: STEP 1: INSTALL PYTHON (Auto)
:: ============================================
echo [*] Step 1/6: Python...

set "PYTHON_CMD="
where python >nul 2>&1 && set "PYTHON_CMD=python"
if not defined PYTHON_CMD (
    if exist "C:\Python312\python.exe" set "PYTHON_CMD=C:\Python312\python.exe"
    if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PYTHON_CMD=%LocalAppData%\Programs\Python\Python312\python.exe"
    if exist "%ProgramFiles%\Python312\python.exe" set "PYTHON_CMD=%ProgramFiles%\Python312\python.exe"
)

if defined PYTHON_CMD (
    echo     [OK] Already installed
    goto :python_done
)

echo     [*] Downloading Python 3.12...
set "PY_URL=https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
set "PY_INSTALLER=%TEMP%\python_installer.exe"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%' -UseBasicParsing" >nul 2>&1
if not exist "%PY_INSTALLER%" curl -L -s -o "%PY_INSTALLER%" "%PY_URL%" >nul 2>&1
if not exist "%PY_INSTALLER%" bitsadmin /transfer "PythonDL" /download /priority high "%PY_URL%" "%PY_INSTALLER%" >nul 2>&1

if not exist "%PY_INSTALLER%" (
    echo     [FAIL] Download failed. Get it from python.org
    pause & exit /b 1
)

echo     [*] Installing Python (auto, ~2 min)...
"%PY_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_test=0 Include_launcher=1
timeout /t 10 /nobreak >nul
del "%PY_INSTALLER%" 2>nul

:: Refresh PATH
set "PATH=C:\Python312;C:\Python312\Scripts;%ProgramFiles%\Python312;%ProgramFiles%\Python312\Scripts;%LocalAppData%\Programs\Python\Python312;%LocalAppData%\Programs\Python\Python312\Scripts;%PATH%"
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "PATH=%%b;%PATH%"

set "PYTHON_CMD="
where python >nul 2>&1 && set "PYTHON_CMD=python"
if not defined PYTHON_CMD (
    if exist "C:\Python312\python.exe" set "PYTHON_CMD=C:\Python312\python.exe"
    if exist "%ProgramFiles%\Python312\python.exe" set "PYTHON_CMD=%ProgramFiles%\Python312\python.exe"
    if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PYTHON_CMD=%LocalAppData%\Programs\Python\Python312\python.exe"
)

if defined PYTHON_CMD (
    echo     [OK] Python installed
) else (
    echo     [FAIL] Restart PC and run again
    pause & exit /b 1
)

:python_done
echo.

:: ============================================
:: STEP 2: INSTALL GIT (Auto)
:: ============================================
echo [*] Step 2/6: Git...

set "GIT_CMD="
where git >nul 2>&1 && set "GIT_CMD=git"
if not defined GIT_CMD (
    if exist "C:\Program Files\Git\bin\git.exe" set "GIT_CMD=C:\Program Files\Git\bin\git.exe"
)

if defined GIT_CMD (
    echo     [OK] Already installed
    goto :git_done
)

echo     [*] Downloading Git...
set "GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
set "GIT_INSTALLER=%TEMP%\git_installer.exe"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%GIT_URL%' -OutFile '%GIT_INSTALLER%' -UseBasicParsing" >nul 2>&1
if not exist "%GIT_INSTALLER%" curl -L -s -o "%GIT_INSTALLER%" "%GIT_URL%" >nul 2>&1
if not exist "%GIT_INSTALLER%" bitsadmin /transfer "GitDL" /download /priority high "%GIT_URL%" "%GIT_INSTALLER%" >nul 2>&1

if not exist "%GIT_INSTALLER%" (
    echo     [WARN] Git download failed. Skipping (will download files directly).
    goto :git_done
)

echo     [*] Installing Git (auto)...
"%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"
timeout /t 8 /nobreak >nul
del "%GIT_INSTALLER%" 2>nul

set "PATH=C:\Program Files\Git\bin;C:\Program Files\Git\cmd;%PATH%"
set "GIT_CMD="
where git >nul 2>&1 && set "GIT_CMD=git"
if not defined GIT_CMD (
    if exist "C:\Program Files\Git\bin\git.exe" set "GIT_CMD=C:\Program Files\Git\bin\git.exe"
)

if defined GIT_CMD (
    echo     [OK] Git installed
) else (
    echo     [WARN] Git needs restart. Using direct download.
)

:git_done
echo.

:: ============================================
:: STEP 3: INSTALL ADB (Android Platform Tools)
:: ============================================
echo [*] Step 3/6: ADB (Android Debug Bridge)...

:: Check if adb already exists
set "ADB_CMD="
where adb >nul 2>&1 && set "ADB_CMD=adb"
if not defined ADB_CMD (
    if exist "C:\platform-tools\adb.exe" set "ADB_CMD=C:\platform-tools\adb.exe"
    if exist "%USERPROFILE%\platform-tools\adb.exe" set "ADB_CMD=%USERPROFILE%\platform-tools\adb.exe"
    if exist "%INSTALL_DIR%\platform-tools\adb.exe" set "ADB_CMD=%INSTALL_DIR%\platform-tools\adb.exe"
)

if defined ADB_CMD (
    echo     [OK] Already installed: !ADB_CMD!
    goto :adb_done
)

echo     [*] Downloading Android Platform Tools...
set "ADB_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "ADB_ZIP=%TEMP%\platform-tools.zip"
set "ADB_EXTRACT=C:\platform-tools"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%ADB_URL%' -OutFile '%ADB_ZIP%' -UseBasicParsing" >nul 2>&1
if not exist "%ADB_ZIP%" curl -L -s -o "%ADB_ZIP%" "%ADB_URL%" >nul 2>&1
if not exist "%ADB_ZIP%" bitsadmin /transfer "ADBDL" /download /priority high "%ADB_URL%" "%ADB_ZIP%" >nul 2>&1

if not exist "%ADB_ZIP%" (
    echo     [WARN] ADB download failed. Install manually from developer.android.com
    goto :adb_done
)

echo     [*] Extracting ADB to C:\platform-tools...
powershell -Command "Expand-Archive -Path '%ADB_ZIP%' -DestinationPath 'C:\' -Force" >nul 2>&1
del "%ADB_ZIP%" 2>nul

:: Add ADB to system PATH permanently
set "PATH=C:\platform-tools;%PATH%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2>nul | findstr /i /c:"platform-tools" >nul 2>&1
if %errorlevel% neq 0 (
    echo     [*] Adding ADB to system PATH...
    for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "OLDPATH=%%b"
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!OLDPATH!;C:\platform-tools" /f >nul 2>&1
)

set "ADB_CMD="
where adb >nul 2>&1 && set "ADB_CMD=adb"
if not defined ADB_CMD (
    if exist "C:\platform-tools\adb.exe" set "ADB_CMD=C:\platform-tools\adb.exe"
)

if defined ADB_CMD (
    echo     [OK] ADB installed
) else (
    echo     [WARN] ADB extract may have failed
)

:adb_done
echo.

:: ============================================
:: STEP 4: INSTALL PYTHON LIBRARIES (Auto)
:: ============================================
echo [*] Step 4/6: Python Libraries...

!PYTHON_CMD! -m ensurepip >nul 2>&1
!PYTHON_CMD! -m pip install --upgrade pip -q >nul 2>&1

echo     Installing: requests colorama rich cryptography openpyxl urllib3...
!PYTHON_CMD! -m pip install requests colorama rich cryptography openpyxl urllib3 -q
if %errorlevel% neq 0 (
    !PYTHON_CMD! -m pip install requests colorama rich cryptography openpyxl urllib3 --break-system-packages -q
)

echo     [OK] Libraries installed
echo.

:: ============================================
:: STEP 5: DOWNLOAD auth.py TO DESKTOP
:: ============================================
echo [*] Step 5/6: Downloading auth.py to Desktop\Nehaldev...

:: Download auth.py only (no git clone, no extra files)
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Nehal987/nehaldev/main/auth.py' -OutFile '%INSTALL_DIR%\auth.py' -UseBasicParsing" >nul 2>&1
if not exist "%INSTALL_DIR%\auth.py" curl -L -s -o "%INSTALL_DIR%\auth.py" "https://raw.githubusercontent.com/Nehal987/nehaldev/main/auth.py" >nul 2>&1
if not exist "%INSTALL_DIR%\auth.py" bitsadmin /transfer "AuthDL" /download /priority high "https://raw.githubusercontent.com/Nehal987/nehaldev/main/auth.py" "%INSTALL_DIR%\auth.py" >nul 2>&1

if exist "%INSTALL_DIR%\auth.py" (
    echo     [OK] auth.py downloaded
) else (
    echo     [FAIL] Could not download auth.py!
    pause & exit /b 1
)

:files_ok
echo.

:: ============================================
:: STEP 6: VERIFICATION
:: ============================================
echo  ============================================
echo   VERIFICATION
echo  ============================================
echo.

!PYTHON_CMD! --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('!PYTHON_CMD! --version 2^>^&1') do echo  [OK] %%i
) else (
    echo  [FAIL] Python
)

if defined GIT_CMD (
    for /f "tokens=*" %%i in ('"!GIT_CMD!" --version 2^>^&1') do echo  [OK] %%i
) else (
    echo  [--] Git (not critical)
)

if defined ADB_CMD (
    for /f "tokens=*" %%i in ('"!ADB_CMD!" version 2^>^&1') do (
        echo  [OK] %%i
        goto :adb_ver_done
    )
)
:adb_ver_done

!PYTHON_CMD! -c "import requests, colorama, rich, cryptography" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] All Python libraries
) else (
    echo  [WARN] Some libraries missing
)

if exist "%INSTALL_DIR%\auth.py" (
    echo  [OK] auth.py on Desktop
) else (
    echo  [FAIL] auth.py missing
)

echo.
echo  ============================================
echo   INSTALLATION COMPLETE!
echo  ============================================
echo.
echo  Location : %INSTALL_DIR%
echo  Run again: double-click auth.py
echo.

:: ============================================
:: AUTO LAUNCH BOT
:: ============================================
echo [+] Launching Bot...
timeout /t 3 /nobreak >nul

cd /d "%INSTALL_DIR%"
!PYTHON_CMD! auth.py

pause
