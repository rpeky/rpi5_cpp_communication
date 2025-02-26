#!/bin/bash
set -e  # Exit on error

# Ensure script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0 <last_octet_of_ip>"
    exit 1
fi

# Configuration Variables
BAT_IFACE="bat0"
WLAN_IFACE="wlan0"
SSID="BATMAN-MESH"
DEFAULT_FREQ=2412  # Default to 2.4 GHz
FREQ_5GHZ=5200  # Alternative 5 GHz frequency
CHANNEL=1  # Wi-Fi Ad-Hoc Channel
DEFAULT_OCTET=100  # Default last octet if none provided

# Check if an argument is provided
if [ -z "$1" ]; then
    LAST_OCTET=$DEFAULT_OCTET
    echo "[!] No IP octet provided, defaulting to 172.16.0.$LAST_OCTET"
else
    # Validate argument is a number between 2-254
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 2 ] || [ "$1" -gt 254 ]; then
        echo "[ERROR] Invalid argument: Please provide a number between 2 and 254."
        exit 1
    fi
    LAST_OCTET=$1
fi

BAT_IP="172.16.0.$LAST_OCTET/24"
SERVICE_FILE="/etc/systemd/system/batman.service"

echo "[+] Unblocking Wi-Fi via rfkill"
rfkill unblock all

echo "[+] Removing old BATMAN-adv installation"
modprobe -r batman_adv || true
apt remove --purge -y batctl || true
apt autoremove -y

echo "[+] Reinstalling BATMAN-adv"
apt update && apt install -y batctl iw wireless-tools

echo "[+] Loading BATMAN-adv kernel module"
modprobe batman_adv

# Ensure BATMAN module loads at boot
echo "batman_adv" | tee -a /etc/modules

echo "[+] Stopping interfering services (NetworkManager & wpa_supplicant)"
systemctl stop wpa_supplicant || true
systemctl stop NetworkManager || true
systemctl disable wpa_supplicant || true
systemctl disable NetworkManager || true
pkill wpa_supplicant || true
pkill dhclient || true
pkill NetworkManager || true

echo "[+] Checking if the Wi-Fi adapter supports IBSS mode..."
if ! iw list | grep -q "IBSS"; then
    echo "[ERROR] Your Wi-Fi adapter does not support IBSS (Ad-Hoc) mode."
    exit 1
fi

echo "[+] Setting up Wi-Fi in IBSS (Ad-Hoc) mode"
ip link set "$WLAN_IFACE" down
iw dev "$WLAN_IFACE" set type ibss || { echo "Error: Failed to set IBSS mode"; exit 1; }
ip link set "$WLAN_IFACE" up

echo "[+] Determining best frequency..."
if iw list | grep -q "5200 MHz"; then
    FREQ=$FREQ_5GHZ
    echo "[+] Using 5 GHz (5200 MHz) for IBSS mode."
else
    FREQ=$DEFAULT_FREQ
    echo "[+] Using 2.4 GHz (2412 MHz) for IBSS mode."
fi

echo "[+] Joining BATMAN-MESH IBSS Cell"
iw dev "$WLAN_IFACE" ibss join "$SSID" "$FREQ" 02:12:34:56:78:9A || { echo "Error: Failed to join IBSS"; exit 1; }

echo "[DEBUG] Checking Wi-Fi mode..."
iw dev "$WLAN_IFACE" info

echo "[DEBUG] Checking IBSS status..."
iw dev "$WLAN_IFACE" link

echo "[+] Adding $WLAN_IFACE to BATMAN-adv"
batctl if add "$WLAN_IFACE"
ip link set "$BAT_IFACE" up

echo "[+] Assigning IP address to $BAT_IFACE: $BAT_IP"
ip addr flush dev "$BAT_IFACE" || true
ip addr add "$BAT_IP" dev "$BAT_IFACE"

echo "[+] Persisting BATMAN-adv configuration"
cat <<EOF | tee /etc/network/interfaces.d/batman
auto $BAT_IFACE
iface $BAT_IFACE inet static
    address $BAT_IP
    netmask 255.255.255.0
    pre-up modprobe batman_adv
    post-up batctl if add $WLAN_IFACE
EOF

echo "[+] Creating systemd service for automatic startup"
cat <<EOF | tee $SERVICE_FILE
[Unit]
Description=BATMAN-adv Mesh Network Setup
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup_batman.sh $LAST_OCTET
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Moving script to /usr/local/bin and setting permissions"
mv "$0" /usr/local/bin/setup_batman.sh
chmod +x /usr/local/bin/setup_batman.sh

echo "[+] Enabling and starting systemd service"
systemctl daemon-reload
systemctl enable batman.service
systemctl start batman.service

echo "[+] BATMAN-adv setup complete! Checking network status..."
batctl n  # Show connected neighbors
batctl o  # Show BATMAN-adv originators
