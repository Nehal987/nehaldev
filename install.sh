#!/bin/bash
echo -e "\033[1;36m[+] Starting Comprehensive Setup for Termux (Self-Healing)...\033[0m"

# 1. Update & Upgrade (Standard) & Self-Heal
echo -e "\033[1;33m[*] Updating Termux Packages...\033[0m"

# Force "New" config files (Auto Y response behavior)
export DEBIAN_FRONTEND=noninteractive

# Self-heal interrupted dpkg runs FIRST (Auto Repair)
if command -v dpkg &> /dev/null; then
    echo -e "\033[1;33m[*] Running dpkg self-repair...\033[0m"
    # Force configure any pending packages
    yes | dpkg --configure -a --force-confnew || echo "dpkg configure returned code $?"
fi

# 2. Install Core Packages (Force Accept New Configs)
echo -e "\033[1;33m[*] Installing System Dependencies...\033[0m"
# Update repositories
yes | pkg update -y
# Upgrade with force-confnew to accept maintainer scripts automatically
yes | pkg upgrade -y -o Dpkg::Options::="--force-confnew"

yes | pkg install python python-cryptography rust binutils build-essential git pkg-config libjpeg-turbo libcrypt ndk-sysroot clang libffi termux-api procps debianutils x11-repo -y -o Dpkg::Options::="--force-confnew"

# 3. Install Chromium (Simple Method)
echo -e "\033[1;33m[*] Installing Chromium...\033[0m"
yes | pkg install chromium -y -o Dpkg::Options::="--force-confnew"

# 4. Fix Chromium Path (Symlink if needed)
echo -e "\033[1;33m[*] Checking Chromium paths...\033[0m"
if [ ! -f "/data/data/com.termux/files/usr/bin/chromium" ]; then
    if [ -f "/data/data/com.termux/files/usr/bin/chromium-browser" ]; then
         echo "Symlinking chromium-browser to chromium..."
         ln -s /data/data/com.termux/files/usr/bin/chromium-browser /data/data/com.termux/files/usr/bin/chromium
    fi
fi

# VERIFICATION
echo -e "\033[1;33m[*] Verifying Installation...\033[0m"
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || { which "$1" >/dev/null 2>&1; }
}

if check_cmd chromium; then 
    echo -e "\033[1;32m[+] Chromium Verified: $(command -v chromium)\033[0m"
else 
    echo -e "\033[1;31m[!] Chromium NOT found.\033[0m"
fi

if check_cmd chromedriver; then
    echo -e "\033[1;32m[+] Chromedriver Verified: $(command -v chromedriver)\033[0m"
else
    echo -e "\033[1;33m[!] Chromedriver binary not found in path (might be included in chromium or via webdriver-manager).\033[0m"
fi

# 5. Install Python Libraries
echo -e "\033[1;33m[*] Installing Python Libraries...\033[0m"
python -m pip install --upgrade pip
PIPARGS="requests colorama rich selenium openpyxl psutil urllib3 ua-parser pydub webdriver-manager"

if python -m pip install --no-input $PIPARGS --break-system-packages; then
    echo -e "\033[1;32m[+] Libraries installed successfully.\033[0m"
else
    echo -e "\033[1;33m[!] Retrying with standard pip...\033[0m"
    python -m pip install --no-input $PIPARGS
fi

# 6. Move Files
echo -e "\033[1;33m[*] Moving Bot to Home Screen...\033[0m"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/auth.py" "$HOME/auth.py" 2>/dev/null || echo "auth.py not found in script dir"
cp "$SCRIPT_DIR/README.md" "$HOME/README.md" 2>/dev/null || echo "README.md not found"

echo -e "\033[1;32m INSTALLATION COMPLETE \033[0m"
