#!/bin/bash
echo -e "\033[1;36m[+] Starting Comprehensive Setup for Termux...\033[0m"

# 1. Update & Upgrade (Force Non-Interactive)
echo -e "\033[1;33m[*] Updating Termux repositories...\033[0m"
yes | pkg update -y
yes | pkg upgrade -y -o Dpkg::Options::="--force-confnew"

# 2. Setup Storage (Skipped - User Handling Separately)
# echo -e "\033[1;33m[*] Setting up storage permissions...\033[0m"
# termux-setup-storage

# 3. Install Core System Packages
echo -e "\033[1;33m[*] Installing System Dependencies (Compiler, Libraries)...\033[0m"
# python-cryptography is pre-compiled, avoids the long build time
yes | pkg install python python-cryptography rust binutils build-essential git pkg-config libjpeg-turbo libcrypt ndk-sysroot clang libffi termux-api procps -y

# 4. Install Repos needed for X11 & Chromium
echo -e "\033[1;33m[*] Enabling X11 and TUR Repos...\033[0m"
yes | pkg install x11-repo -y
yes | pkg install tur-repo -y

# 5. Install Chromium & X11 (Force Reinstall to ensure version match)
echo -e "\033[1;33m[*] Installing Chromium & Termux-X11...\033[0m"
yes | pkg install tur-repo x11-repo -y
yes | pkg update -y

# Force remove potential wrong versions first
echo -e "\033[1;33m[*] Cleaning up old Chromium versions...\033[0m"
yes | pkg uninstall chromium termux-x11-nightly -y 2>/dev/null

# Install fresh
echo -e "\033[1;33m[*] Installing Correct Chromium & X11...\033[0m"
yes | pkg install chromium termux-x11-nightly xfce4 -y
# proper dependencies often missing + FFMPEG for Audio
yes | pkg install libnss libnspr glib ffmpeg -y

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
cp auth.py $HOME/auth.py
cp README.md $HOME/README.md

echo -e "\033[1;32m"
echo "       INSTALLATION COMPLETE!             "
echo "=========================================="
echo " Launching Bot..."
echo "=========================================="
echo -e "\033[0m"

# Auto-Run from Home
cd $HOME
python auth.py
