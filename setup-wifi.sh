#!/bin/sh

# ========================================================
# FreeBSD MediaTek MT6701U / MT7601U Wi-Fi Setup Script
# ========================================================

FIRMWARE_DIR="/firmware"

confirm() {
    while true; do
        printf "%s [y/N]: " "$1"
        read -r response
        case "$response" in
            [Yy]* ) return 0 ;;
            [Nn]* | "" ) return 1 ;;
            * ) echo "Please answer 'y' or 'n'." ;;
        esac
    done
}

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] This script must be run as root (sudo)."
    exit 1
fi

echo "================================================="
echo "  Auto Script Setup Wi-Fi MT6701U (FreeBSD)"
echo "================================================="
echo ""

if confirm "1. Do you want to install packages/firmware from $FIRMWARE_DIR?"; then
    if [ -d "$FIRMWARE_DIR" ]; then
        LOCAL_PKG=$(ls "$FIRMWARE_DIR"/*.pkg 2>/dev/null)
        
        if [ -n "$LOCAL_PKG" ]; then
            echo "[i] Local packages found in $FIRMWARE_DIR."
            if confirm "    Install packages via 'pkg add'?"; then
                for pkg in "$FIRMWARE_DIR"/*.pkg; do
                    echo "[+] Installing $pkg ..."
                    pkg add "$pkg"
                done
            fi
        else
            echo "[!] No .pkg files found in $FIRMWARE_DIR."
            if confirm "    Would you like to install via online repository ('pkg install wpa_supplicant')?"; then
                pkg update && pkg install -y wpa_supplicant
            fi
        fi
    else
        echo "[!] Directory $FIRMWARE_DIR does not exist."
        if confirm "    Would you like to install via online repository ('pkg install wpa_supplicant')?"; then
            pkg update && pkg install -y wpa_supplicant
        fi
    fi
else
    echo "[->] Skipping package installation step."
fi

echo ""

if confirm "2. Do you want to create/update /etc/wpa_supplicant.conf?"; then
    printf "Enter Wi-Fi SSID: "
    read -r WIFI_SSID
    printf "Enter Wi-Fi Password: "
    read -r WIFI_PASS

    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASS" ]; then
        echo "[+] Configuring /etc/wpa_supplicant.conf ..."
        
        # Backup existing file
        if [ -f /etc/wpa_supplicant.conf ]; then
            cp /etc/wpa_supplicant.conf /etc/wpa_supplicant.conf.bak
            echo "[i] Backup saved to /etc/wpa_supplicant.conf.bak"
        fi

        cat <<EOF > /etc/wpa_supplicant.conf
ctrl_interface=/var/run/wpa_supplicant
eapol_version=2
ap_scan=1
fast_reauth=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
}
EOF
        chmod 600 /etc/wpa_supplicant.conf
        echo "[+] /etc/wpa_supplicant.conf created successfully."
    else
        echo "[!] SSID or Password cannot be empty. Configuration cancelled."
    fi
else
    echo "[->] Skipping wpa_supplicant.conf configuration."
fi

echo ""

if confirm "3. Do you want to add interface configuration to /etc/rc.conf?"; then
    DRIVER_IF="mtw0" 
    printf "Enter driver interface name (default: mtw0): "
    read -r INPUT_IF
    if [ -n "$INPUT_IF" ]; then
        DRIVER_IF="$INPUT_IF"
    fi

    sysrc wlans_${DRIVER_IF}="wlan0"
    sysrc ifconfig_wlan0="WPA DHCP"
    echo "[+] /etc/rc.conf updated successfully."
else
    echo "[->] Skipping /etc/rc.conf configuration."
fi

echo ""

if confirm "4. Do you want to restart network services and connect to Wi-Fi now?"; then
    echo "[+] Reloading network..."
    service netif restart
    service routing restart
    echo "[+] Done! Check connection status with 'ifconfig wlan0'."
else
    echo "[->] Skipping network activation."
fi

echo ""
echo "=== Setup Process Completed ==="
