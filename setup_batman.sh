#!/bin/bash
set -e  # Exit on error

# Check if an argument is provided
if [[ -z "$1" ]]; then
	    echo "Usage: $0 <last_octet_of_ip>"
	        echo "Example: $0 50 (sets IP as 192.168.100.50)"
		    exit 1
fi

# Configuration Variables
BAT_IFACE="bat0"
WLAN_IFACE="wlan0"   # Change to your Wi-Fi interface name
SSID="BATMAN-MESH"
FREQ=2412            # 2.4 GHz (use 5200 for 5 GHz)
CHANNEL=1            # Wi-Fi Ad-Hoc Channel
BAT_IP="192.168.100.$1/24"  # Using provided integer as last octet

echo "[+] Unblocking Wi-Fi via rfkill"
rfkill unblock wlan

echo "[+] Loading BATMAN-adv kernel module"
modprobe batman_adv

echo "[+] Setting up Wi-Fi in Ad-Hoc mode"
ip link set "$WLAN_IFACE" down
iw dev "$WLAN_IFACE" set type ibss
ip link set "$WLAN_IFACE" up

echo "[+] Connecting to BATMAN Wi-Fi Ad-Hoc Network"
iw dev "$WLAN_IFACE" ibss join "$SSID" "$FREQ" fixed-freq "$CHANNEL" 02:12:34:56:78:9A

echo "[+] Adding $WLAN_IFACE to BATMAN-adv"
batctl if add "$WLAN_IFACE"
ip link set "$BAT_IFACE" up

echo "[+] Assigning IP address to $BAT_IFACE: $BAT_IP"
ip addr add "$BAT_IP" dev "$BAT_IFACE"

echo "[+] BATMAN-adv setup complete! Checking network status..."
batctl n   # Show connected neighbors
batctl o   # Show BATMAN-adv originators
