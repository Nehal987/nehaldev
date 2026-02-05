#!/bin/bash
echo -e "\033[1;36m[+] Starting Comprehensive Setup for Termux...\033[0m"

# 1. Update & Upgrade (Standard)
echo -e "\033[1;33m[*] Updating Termux Packages...\033[0m"
# Removed mirror switching that was causing issues.


echo -e "\033[1;33m[*] Refreshing package lists...\033[0m"
apt-get update -y

# 2. Setup Storage (Skipped - User Handling Separately)
# 2. Setup Storage (Skipped - User Handling Separately)
# echo -e "\033[1;33m[*] Setting up storage permissions...\033[0m"
# termux-setup-storage

# 3. Install Core System Packages
echo -e "\033[1;33m[*] Installing System Dependencies...\033[0m"
# Added debianutils for 'which' command, kept other essentials
# Force "New" config files (Auto Y response behavior for configs)
export DEBIAN_FRONTEND=noninteractive
yes | pkg update
yes | pkg upgrade -y -o Dpkg::Options::="--force-confnew"

yes | pkg install python python-cryptography rust binutils build-essential git pkg-config libjpeg-turbo libcrypt ndk-sysroot clang libffi termux-api procps debianutils x11-repo -y -o Dpkg::Options::="--force-confnew"

# 4. Install Chromium (Simple Method from old.sh)
echo -e "\033[1;33m[*] Installing Chromium...\033[0m"
yes | pkg install chromium -y -o Dpkg::Options::="--force-confnew"

# 5. Fix Chromium Path (Symlink if needed - from old.sh)
echo -e "\033[1;33m[*] Checking Chromium paths...\033[0m"
if [ ! -f "/data/data/com.termux/files/usr/bin/chromium" ]; then
    if [ -f "/data/data/com.termux/files/usr/bin/chromium-browser" ]; then
         echo "Symlinking chromium-browser to chromium..."
         ln -s /data/data/com.termux/files/usr/bin/chromium-browser /data/data/com.termux/files/usr/bin/chromium
    fi
fi

# VERIFICATION
echo -e "\033[1;33m[*] Verifying Installation...\033[0m"
# Check if binary exists using command -v or which
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
    # Some termux chromium packages include driver, some don't. 
    # If old.sh worked without explicit chromedriver install, we proceed but warn.
    echo -e "\033[1;33m[!] Chromedriver binary not found in path (might be included in chromium or via webdriver-manager).\033[0m"
fi

# 6. Install Python Libraries (Directly, no requirements.txt needed)
echo -e "\033[1;33m[*] Installing Python Libraries...\033[0m"

# Ensure pip is up to date
python -m pip install --upgrade pip

# Install requirements - matching install.sh list + old.sh additions if any
PIPARGS="requests colorama rich selenium openpyxl psutil urllib3 ua-parser pydub webdriver-manager"

if python -m pip install --no-input $PIPARGS --break-system-packages; then
    echo -e "\033[1;32m[+] Libraries installed successfully.\033[0m"
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
