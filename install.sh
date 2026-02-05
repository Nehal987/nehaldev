#!/bin/bash
echo -e "\033[1;36m[+] Starting Comprehensive Setup for Termux...\033[0m"

# 1. Update & Upgrade (Force Non-Interactive)
echo -e "\033[1;33m[*] Switching to Generic Mirror (Asia/Global Optimized)...\033[0m"
# Check if sources.list exists
if [ -f "$PREFIX/etc/apt/sources.list" ]; then
    # Backup
    cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak"
    # Switch to BFSU (Beijing Foreign Studies University) - Very stable Asia mirror
    echo "deb https://mirrors.bfsu.edu.cn/termux/termux-packages-24 stable main" > "$PREFIX/etc/apt/sources.list"
    echo -e "\033[1;32m[+] Mirror switched to BFSU (Asia).\033[0m"
fi

echo -e "\033[1;33m[*] Refreshing package lists...\033[0m"
apt-get update -y

# 2. Setup Storage (Skipped - User Handling Separately)
# 2. Setup Storage (Skipped - User Handling Separately)
# echo -e "\033[1;33m[*] Setting up storage permissions...\033[0m"
# termux-setup-storage

# 3. Install Core System Packages
echo -e "\033[1;33m[*] Installing System Dependencies (Compiler, Libraries)...\033[0m"
# python-cryptography is pre-compiled, avoids the long build time
# Added debianutils for 'which' command
yes | pkg install python python-cryptography rust binutils build-essential git pkg-config libjpeg-turbo libcrypt ndk-sysroot clang libffi termux-api procps debianutils -y

# 4. Install Repos needed for X11 & Chromium
echo -e "\033[1;33m[*] Enabling X11 and TUR Repos...\033[0m"
yes | pkg install x11-repo -y
yes | pkg install tur-repo -y

# 5. Install Chromium & X11 (Force Reinstall to ensure version match)
echo -e "\033[1;33m[*] Installing Chromium & Termux-X11...\033[0m"
yes | pkg update -y

# Clean up old versions to prevent conflicts
echo -e "\033[1;33m[*] Cleaning up old Chromium versions...\033[0m"
yes | pkg uninstall chromium termux-x11-nightly chromedriver -y 2>/dev/null

# Install fresh
echo -e "\033[1;33m[*] Installing Correct Chromium & X11...\033[0m"
# Install specifically from tur-repo if needed, but standard pkg usually works if repo is active
yes | pkg install chromium termux-x11-nightly xfce4 -y
# proper dependencies often missing + FFMPEG for Audio
yes | pkg install libnss libnspr glib ffmpeg -y

# VERIFICATION & REPAIR
echo -e "\033[1;33m[*] Verifying Chromium Installation...\033[0m"

install_chromium() {
    echo -e "\033[1;33m[*] Attempting to install Chromium & Chromedriver...\033[0m"
    yes | pkg install tur-repo -y
    yes | pkg update -y
    # Install chromium first
    yes | pkg install chromium -y
    # Then chromedriver
    yes | pkg install chromedriver -y
}

# Check if binary exists using command -v (more portable) or which
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || { which "$1" >/dev/null 2>&1; }
}

echo -e "\033[1;34m[*] Debug: Checking binary paths...\033[0m"
if check_cmd chromium; then echo "Chromium found: $(command -v chromium)"; else echo "Chromium NOT found"; fi
if check_cmd chromedriver; then echo "Chromedriver found: $(command -v chromedriver)"; else echo "Chromedriver NOT found"; fi

if ! check_cmd chromium || ! check_cmd chromedriver; then
    echo -e "\033[1;31m[!] Chromium or Chromedriver MISSING. Starting Repair...\033[0m"
    
    # Try install
    install_chromium
    
    # Re-verify
    if ! check_cmd chromium || ! check_cmd chromedriver; then
        echo -e "\033[1;31m[!] Repair Attempt 1 Failed. Retrying with 'pkg upgrade'...\033[0m"
        apt-get update -y
        yes | pkg upgrade -y
        install_chromium
    fi
fi

# Final Check
if ! check_cmd chromium || ! check_cmd chromedriver; then
     echo -e "\033[1;31m[!] ERROR: Install FAILED.\033[0m" 
     echo -e "\033[1;33m    Missing:\033[0m"
     ! check_cmd chromium && echo "    - chromium"
     ! check_cmd chromedriver && echo "    - chromedriver"
     
     echo -e "\033[1;33m    Please try running manual install:\033[0m"
     echo -e "\033[1;37m    pkg install tur-repo\033[0m"
     echo -e "\033[1;37m    pkg install chromium chromedriver\033[0m"
else
     echo -e "\033[1;32m[+] Chromium Verified: $(command -v chromium)\033[0m"
     echo -e "\033[1;32m[+] Chromedriver Verified: $(command -v chromedriver)\033[0m"
fi

# 6. Install Python Libraries (Directly, no requirements.txt needed)
echo -e "\033[1;33m[*] Installing Python Libraries...\033[0m"
# Using --break-system-packages for newer Termux python environments if needed, 
# otherwise standard pip. We try both to be safe.
# NOTE: Cryptography is handled by pkg install python-cryptography above.

PIPARGS="requests colorama rich selenium openpyxl psutil urllib3 ua-parser pydub"

if python -m pip install --no-input $PIPARGS --break-system-packages; then
    echo -e "\033[1;32m[+] Libraries installed successfully (with break-system-packages).\033[0m"
else
    echo -e "\033[1;33m[!] Retrying with standard pip...\033[0m"
    python -m pip install --no-input $PIPARGS
fi

# 7. Move Files to Home Directory
echo -e "\033[1;33m[*] Moving Bot to Home Screen...\033[0m"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/auth.py" "$HOME/auth.py"
cp "$SCRIPT_DIR/README.md" "$HOME/README.md"

echo -e "\033[1;32m"
echo "       INSTALLATION COMPLETE!             "
echo "=========================================="
echo " Launching Bot..."
echo "=========================================="
echo -e "\033[0m"

# Auto-Run from Home
cd $HOME
python auth.py
