import os
import sys
import platform
import hashlib
import uuid
import json
import base64
import requests
import time
import atexit
import shutil
import subprocess

from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from colorama import Fore, Style, init

init(autoreset=True)

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# CONFIGURATION
# CONFIGURATION
SERVER_URL = "https://fb-reset-tool-2.fly.dev/auth" # Update this after deployment!

# Embedded Public Key (No external file needed)
PUBLIC_KEY_STR = r"""-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAro5LRNth3caYSzJMNiA7
PtyUU8qyUUujW2P5iQfHnR/aFo6XlA3tzmmp6HqdbBi7Sf+JbOSDDLWplnVCII5b
zyxammMJgTWmooPRJNOGHpLndqA6R+bjj5ZXKt1cwdlYs71yUA9cAIapF9TlNOfk
zcoC+gZUkaxNrvlnEMeuuibTPcGETnTTWd8uZKa88TWmb45m5NdWVbgg0cOqyCxO
77Ta8SWq4AT6FAT//crjoT2pUheb9afaNY60siITjKUJvHlU+Lw0769dhJuRPbvm
d25qJg70LKZg5+QbbYOcUPNKCiKZscj1i8DApyk6Q3Fbc/rs5kdUGI8DLtHqA0pn
OwIDAQAB
-----END PUBLIC KEY-----"""

def get_hwid():
    """Generate a stable Hardware ID (No MAC Address)."""
    try:
        if os.name == 'nt':
            # Windows: Motherboard UUID (via PowerShell as wmic is deprecated)
            cmd = "powershell -Command \"Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID\""
            try:
                uuid_str = subprocess.check_output(cmd, shell=True).decode().strip()
                return hashlib.sha256(uuid_str.encode()).hexdigest()
            except:
                # Fallback to wmic if powershell fails
                cmd = "wmic csproduct get uuid"
                uuid_str = subprocess.check_output(cmd, shell=True).decode().split('\n')[1].strip()
                return hashlib.sha256(uuid_str.encode()).hexdigest()
        elif hasattr(sys, 'getandroidapilevel'):
            # Android: Device Serial
            try:
                # Try standard generic serial
                cmd = "getprop ro.serialno"
                serial = subprocess.check_output(cmd, shell=True).decode().strip()
                if not serial: raise Exception
                return hashlib.sha256(serial.encode()).hexdigest()
            except:
                # Fallback combines model + manufacturer for some stability
                cmd = "getprop ro.product.model && getprop ro.product.manufacturer"
                fallback = subprocess.check_output(cmd, shell=True).decode().strip()
                return hashlib.sha256(fallback.encode()).hexdigest()
        else:
            # Linux/Others: Machine ID
            with open("/etc/machine-id", "r") as f:
                return hashlib.sha256(f.read().strip().encode()).hexdigest()
    except Exception:
        # Extreme Fallback
        return hashlib.sha256(str(uuid.getnode()).encode()).hexdigest()

def anti_debug():
    """Basic Anti-Debug checks."""
    if sys.gettrace() is not None:
        print(Fore.RED + "Debugger detected! Exiting...")
        sys.exit(1)
        
    # Check for common debugging tools in processes (Linux/Termux focus)
    # Skipped for simplicity/reliability, can add psutil check if needed.
    pass

def load_public_key():
    """Load Server's Public Key from embedded string."""
    try:
        return serialization.load_pem_public_key(PUBLIC_KEY_STR.encode())
    except Exception as e:
        print(Fore.RED + f"Error loading embedded key: {e}")
        sys.exit(1)

def cleanup():
    """Cleanup artifacts."""
    try:
        # Delete __pycache__ if exists
        # Use sys.argv[0] as fallback if __file__ is missing explicitly
        base_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
        cache = os.path.join(base_dir, "__pycache__")
        if os.path.exists(cache):
            shutil.rmtree(cache, ignore_errors=True)
    except Exception:
        pass

def main():
    try:
        anti_debug()
        
        print(Fore.CYAN + r"""
  _   _  __  __   _____                 
 | \ | ||  \/  | |__  /   ___   _ __    ___ 
 |  \| || |\/| |   / /   / _ \ | '_ \  / _ \
 | |\  || |  | |  / /_  | (_) || | | ||  __/
 |_| \_||_|  |_| /____|  \___/ |_| |_| \___|
        SECURE CLIENT AUTHORIZATION
        """)
        
        hwid = get_hwid()
        print(Fore.YELLOW + f"[!] Verifying Device...")
        # print(Fore.BLACK + f"HWID: {hwid}") # Debug only
        
        try:
            # 1. Generate Session Key (AES-256)
            session_key = AESGCM.generate_key(bit_length=256)
            
            # 2. Encrypt HWID with Session Key
            aesgcm = AESGCM(session_key)
            nonce = os.urandom(12)
            encrypted_hwid_bytes = nonce + aesgcm.encrypt(nonce, hwid.encode(), None)
            encrypted_hwid_b64 = base64.b64encode(encrypted_hwid_bytes).decode('utf-8')
            
            # 3. Encrypt Session Key with Server Public Key
            server_public_key = load_public_key()
            encrypted_session_key = server_public_key.encrypt(
                session_key,
                padding.OAEP(
                    mgf=padding.MGF1(algorithm=hashes.SHA256()),
                    algorithm=hashes.SHA256(),
                    label=None
                )
            )
            encrypted_session_key_b64 = base64.b64encode(encrypted_session_key).decode('utf-8')
            
            # 4. Send Request
            payload = {
                "hwid": encrypted_hwid_b64,
                "session_key": encrypted_session_key_b64
            }
            
            response = requests.post(SERVER_URL, json=payload, timeout=10, verify=False)
            
            if response.status_code != 200:
                print(Fore.RED + f"[!] Authorization Failed (Server: {response.status_code})")
                sys.exit(1)
                
            data = response.json()
            status = data.get("status")
            
            if status == "approved":
                print(Fore.GREEN + f"\n[SUCCESS] Authorized!")
                print(Fore.GREEN + f"Time Remaining: {data.get('time_left')}")
                
                # 5. Decrypt Payload
                encrypted_payload_b64 = data.get("payload")
                encrypted_payload = base64.b64decode(encrypted_payload_b64)
                
                # Decrypt using the SAME session key
                nonce = encrypted_payload[:12]
                ciphertext = encrypted_payload[12:]
                
                decrypted_code = aesgcm.decrypt(nonce, ciphertext, None).decode('utf-8')
                
                print(Fore.MAGENTA + "\nJust loading...\n")
                time.sleep(1)
                
                # 6. Execute in Memory
                global_context = globals()
                # Ensure __name__ is main so the script runs
                global_context['__name__'] = '__main__'
                
                try:
                    exec(decrypted_code, global_context)
                except KeyboardInterrupt:
                    sys.exit(0)
                except Exception as e:
                    print(Fore.RED + f"[CRASH] Execution Error: {e}")
                    
            elif status == "pending":
                auth_code = data.get("auth_code", "N/A")
                print(Fore.YELLOW + "\n[!] Device NOT Authorized.")
                
                print(Fore.WHITE + "------------------------------------------------")
                print(Fore.CYAN + f" Your Auth Code : {auth_code}")
                
                print(Fore.WHITE + "\n (Send this 5-digit code to the Telegram Bot)")
                print(Fore.GREEN + " Bot : @buy_Fb_auto_bot")
                print(Fore.YELLOW + " Admin ID : @NehalZone")
                print(Fore.WHITE + "------------------------------------------------")
                
                # Manual Copy Fallback for full key
                print(Fore.BLACK + Style.BRIGHT + f"\nFull Key (Double Tap): {hwid}\n") 
                input("Press Enter to exit...")
                
            elif status == "expired":
                auth_code = data.get("auth_code", "N/A")
                bot_username = data.get("bot_username", "buy_Fb_auto_bot")
                
                print(Fore.RED + f"\n[!] {data.get('message', 'License Expired.')}")
                print(Fore.WHITE + "------------------------------------------------")
                print(Fore.CYAN + f" Your Auth Code : {auth_code}")
                print(Fore.WHITE + "------------------------------------------------")
                print(Fore.RED + "Please renew your subscription.")
                print(Fore.GREEN + f" Bot : @{bot_username}")
                print(Fore.YELLOW + " Admin ID : @NehalZone")
                input("\nPress Enter to exit...")
                
            else:
                 print(Fore.RED + f"[!] Unknown Status: {status}")
                 sys.exit(1)
    
        except requests.exceptions.ConnectionError:
            print(Fore.RED + "\n[!] Connection Failed.")
            print(Fore.YELLOW + "Server unavailable or unreachable.")
            sys.exit(1)
        except Exception as e:
            print(Fore.RED + f"\n[!] Error: {e}")
            # print(e) # Debug
            sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == "__main__":
    main()
