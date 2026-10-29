#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FIRMWARE_DIR="$SCRIPT_DIR/firmware"
[ ! -d "$FIRMWARE_DIR" ] && FIRMWARE_DIR="/firmware" # fallback kalo lu emang taro di /firmware

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
    echo "[!] Must be root (sudo)."
    exit 1
fi

echo "================================================="
echo "  Auto Script Setup Wi-Fi MT7601U (FreeBSD)"
echo "================================================="

if confirm "1. Do you want to install packages/firmware from $FIRMWARE_DIR?"; then
    if [ -d "$FIRMWARE_DIR" ]; then
        echo "[i] Loading drivers..."
        kldload if_run 2>/dev/null; kldload runfw 2>/dev/null
        kldload if_mtw 2>/dev/null; kldload if_mt76 2>/dev/null
        sysrc kld_list+=" if_run runfw if_mtw if_mt76" >/dev/null

        LOCAL_PKG=$(ls "$FIRMWARE_DIR"/*.pkg 2>/dev/null)
        if [ -n "$LOCAL_PKG" ]; then
            if confirm "    Install packages via 'pkg add'?"; then
                for pkg in "$FIRMWARE_DIR"/*.pkg; do
                    echo "[+] Installing $pkg ..."
                    pkg add "$pkg" || pkg install -y "$pkg"
                done
            fi
        else
            echo "[!] No .pkg files found in $FIRMWARE_DIR."
            if confirm "    Install online 'pkg install wpa_supplicant'?"; then
                pkg update && pkg install -y wpa_supplicant wifi-firmware-mt7601u-kmod
            fi
        fi
    else
        echo "[!] Directory $FIRMWARE_DIR does not exist."
    fi
else
    echo "[->] Skipping package installation."
fi

echo ""

if confirm "2. Do you want to create/update /etc/wpa_supplicant.conf?"; then
    printf "Enter Wi-Fi SSID: "; read -r WIFI_SSID
    printf "Enter Wi-Fi Password: "; read -r WIFI_PASS
    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASS" ]; then
        [ -f /etc/wpa_supplicant.conf ] && cp /etc/wpa_supplicant.conf /etc/wpa_supplicant.conf.bak
        cat <<EOF > /etc/wpa_supplicant.conf
ctrl_interface=/var/run/wpa_supplicant
eapol_version=2
ap_scan=1
network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
}
EOF
        chmod 600 /etc/wpa_supplicant.conf
        echo "[+] wpa_supplicant.conf created."
    else
        echo "[!] SSID/PASS empty, cancelled."
    fi
fi

echo ""

if confirm "3. Do you want to add interface to /etc/rc.conf?"; then
    DETECTED_IF=$(dmesg | grep -E "run0|mtw0|mt76" | tail -1 | grep -oE "run[0-9]|mtw[0-9]|mt76[0-9]" | head -1)
    [ -z "$DETECTED_IF" ] && DETECTED_IF="mtw0"
    
    printf "Enter driver interface name (detected: %s): " "$DETECTED_IF"
    read -r INPUT_IF
    DRIVER_IF=${INPUT_IF:-$DETECTED_IF}
    
    ifconfig wlan0 destroy 2>/dev/null; true
    ifconfig wlan0 create wlandev $DRIVER_IF 2>/dev/null && echo "[+] wlan0 created from $DRIVER_IF" || echo "[!] Failed create wlan0, cek dmesg"

    sysrc -f /boot/loader.conf if_mt7601u_load="YES"
    sysrc -f /boot/loader.conf mt7601ufw_load="YES"
    sysrc wlans_${DRIVER_IF}="wlan0"
    sysrc ifconfig_wlan0="WPA DHCP"
    sysrc wpa_supplicant_enable="YES"
    echo "[+] rc.conf updated."
fi

echo ""

if confirm "4. Restart network and connect now?"; then
    service netif restart
    service routing restart
    sleep 2
    ifconfig wlan0
    echo "[+] Done! ping 8.8.8.8"
else
    echo "[->] Skipping. Reboot needed."
fi
