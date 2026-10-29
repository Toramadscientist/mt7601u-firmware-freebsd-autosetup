# freebsd-mt7601u-wifi-fix
> Automated script to get MediaTek MT6701U / MT7601U Wi-Fi adapters working seamlessly on FreeBSD

## Problem
I needed to set up a wireless network connection on a FreeBSD box using an affordable USB Wi-Fi dongle powered by the MediaTek MT6701U (MT7601U) chipset. While FreeBSD actually supports this hardware out of the box through the `rtwn_usb` driver, getting it to work properly is far from straightforward for most users.

The main issues preventing a plug-and-play experience on FreeBSD are:

* The required kernel modules (`if_rtwn_usb`) and firmware binaries (`rtwn_mt7601u_fw`) are not loaded by default at boot.
* The system requires manual editing of multiple system configuration files (`/boot/loader.conf`, `/etc/rc.conf`, and `/etc/wpa_supplicant.conf`) just to create the `wlan0` interface and associate with an Access Point.
* Network configuration on FreeBSD can be error-prone if done manually, especially when setting up WPA/WPA2 authentication and DHCP sequentially.

## Fix
This repository provides a shell script that automates the entire driver loading and network setup process. It modifies the necessary configuration files and sets up the network interface interactively.

Here is a breakdown of what the fix does:

* Automatically loads the `if_rtwn_usb` driver and `rtwn_mt7601u_fw` firmware into the running kernel.
* Appends required module loading directives to `/boot/loader.conf` to ensure persistence across reboots.
* Configures `/etc/rc.conf` to automatically create the `wlan0` interface tied to `rtwn0` and enable DHCP.
* Interactively prompts for the Wi-Fi SSID and passphrase, then generates a proper `/etc/wpa_supplicant.conf` file.
* Restarts the FreeBSD `netif` and `routing` services so you get connected immediately without needing a reboot.

## Installation
**WARNING** - *This script modifies core system configuration files (`loader.conf`, `rc.conf`, `wpa_supplicant.conf`). Make sure your Wi-Fi dongle is plugged in before proceeding, and ensure you have root access.*

These instructions were tested on FreeBSD 13.x and 14.x.

1. Install `git` if you haven't already (or use `fetch` to download the raw script):

   ```
   pkg install git
   ```
2. Clone this repository:

   ```
   git clone https://github.com/username/freebsd-mt6701u-wifi-fix.git
   ```
3. Change to the repository directory:

   ```
   cd freebsd-mt6701u-wifi-fix
   ```
4. Make the script executable:

   ```
   chmod +x setup-wifi.sh
   ```
5. Run the setup script as root:

   ```
   sudo ./setup-wifi.sh
   ```
6. Follow the on-screen prompts to scan for nearby networks, enter your Wi-Fi SSID, and input your WPA password.

7. Verify that your interface is active and has received an IP address:

   ```
   ifconfig wlan0
   ping -c 4 1.1.1.1
   ```
