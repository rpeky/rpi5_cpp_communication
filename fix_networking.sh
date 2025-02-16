#!/bin/bash
set -e  # Exit on error

echo "[+] Fixing networking issues on Raspberry Pi..."

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Step 1: Unblock Wi-Fi and bring up wlan0
echo "[+] Checking and unblocking Wi-Fi..."
rfkill unblock wifi
rfkill unblock all
rfkill list

# Step 2: Check if wlan0 exists
echo "[+] Checking if wlan0 exists..."
if ! ip link show wlan0 > /dev/null 2>&1; then
    echo "[ERROR] wlan0 not found. Reloading Wi-Fi driver..."
    modprobe -r brcmfmac
    modprobe brcmfmac
fi

# Step 3: Bring up wlan0
echo "[+] Bringing up wlan0..."
ip link set wlan0 up || echo "[WARNING] Failed to bring up wlan0"

# Step 4: Restart Networking Services
echo "[+] Restarting networking services..."
systemctl restart networking || echo "[ERROR] Failed to restart networking"
systemctl restart wpa_supplicant || echo "[WARNING] wpa_supplicant restart failed"
systemctl restart dhcpcd || echo "[WARNING] dhcpcd restart failed"

# Step 5: Fix /etc/network/interfaces file
echo "[+] Fixing /etc/network/interfaces..."
cat <<EOF > /etc/network/interfaces
# Loopback interface
auto lo
iface lo inet loopback

# Ethernet (eth0)
allow-hotplug eth0
iface eth0 inet dhcp

# Wi-Fi (wlan0)
allow-hotplug wlan0
iface wlan0 inet dhcp
    wpa-ssid "YourWiFiSSID"
    wpa-psk "YourWiFiPassword"
EOF

# Step 6: Remove corrupt config files
echo "[+] Removing possible corrupt files..."
rm -rf /etc/network/interfaces.d/* || echo "[INFO] No corrupt files found"

# Step 7: Assign a Static IP (Temporary Test)
echo "[+] Assigning a temporary static IP to wlan0..."
ip addr add 192.168.1.100/24 dev wlan0 || echo "[INFO] wlan0 might already have an IP"
ip link set wlan0 up

# Step 8: Test Connectivity
echo "[+] Checking internet connectivity..."
ping -c 4 8.8.8.8 || echo "[WARNING] No internet connection detected"

# Step 9: Reinstall Network Packages if Needed
echo "[+] Reinstalling network packages..."
apt update
apt install --reinstall ifupdown net-tools isc-dhcp-client wpasupplicant -y

# Step 10: Final Restart
echo "[+] Restarting networking and Wi-Fi services..."
systemctl restart networking
systemctl restart wpa_supplicant
systemctl restart dhcpcd
systemctl restart NetworkManager || echo "[INFO] NetworkManager not found, skipping"

echo "[✅] Networking should be fixed! Rebooting..."
sleep 2
reboot
