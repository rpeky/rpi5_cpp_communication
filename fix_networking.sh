#!/bin/bash
set -e  # Exit on error

echo "[+] Fixing networking issues on Raspberry Pi..."

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Step 1: Unblock RFKill (Wi-Fi & Bluetooth)
echo "[+] Checking and unblocking Wi-Fi & Bluetooth..."
rfkill unblock all
rfkill list

# Step 2: Check if wlan0 exists, reload driver if missing
echo "[+] Checking if wlan0 exists..."
if ! ip link show wlan0 > /dev/null 2>&1; then
    echo "[ERROR] wlan0 not found. Reloading Wi-Fi driver..."
    modprobe -r brcmfmac
    modprobe brcmfmac
fi

# Step 3: Bring up wlan0
echo "[+] Bringing up wlan0..."
ip link set wlan0 up || echo "[WARNING] Failed to bring up wlan0"

# Step 4: Restart the Correct Network Services
echo "[+] Restarting necessary network services..."
systemctl restart networking || echo "[ERROR] Failed to restart networking"
systemctl restart wpa_supplicant || echo "[WARNING] wpa_supplicant restart failed"

# Check if NetworkManager exists and restart it
if systemctl list-unit-files | grep -q "NetworkManager.service"; then
    echo "[+] Restarting NetworkManager..."
    systemctl restart NetworkManager
fi

# Check if systemd-networkd exists and restart it
if systemctl list-unit-files | grep -q "systemd-networkd.service"; then
    echo "[+] Restarting systemd-networkd..."
    systemctl restart systemd-networkd
fi

# Step 5: Fix /etc/network/interfaces file
echo "[+] Repairing /etc/network/interfaces file..."
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

# Step 6: Remove corrupt config files if they exist
echo "[+] Checking and removing corrupt network configuration files..."
rm -rf /etc/network/interfaces.d/* || echo "[INFO] No corrupt files found"

# Step 7: Ensure wlan0 has an IP
echo "[+] Checking if wlan0 has an IP..."
if ! ip a show wlan0 | grep -q "inet "; then
    echo "[+] Assigning a temporary static IP to wlan0..."
    ip addr add 192.168.1.100/24 dev wlan0
    ip link set wlan0 up
fi

# Step 8: Check connectivity
echo "[+] Testing internet connection..."
if ping -c 4 8.8.8.8 &> /dev/null; then
    echo "[✅] Internet is working!"
else
    echo "[WARNING] No internet connection detected."
fi

# Step 9: Reinstall Network Packages if Needed
echo "[+] Reinstalling essential network packages..."
apt update
apt install --reinstall ifupdown net-tools isc-dhcp-client wpasupplicant network-manager -y

# Step 10: Final Restart of All Network Services
echo "[+] Restarting all network services..."
systemctl restart networking
systemctl restart wpa_supplicant
systemctl restart NetworkManager || echo "[INFO] NetworkManager not installed, skipping..."
systemctl restart systemd-networkd || echo "[INFO] systemd-networkd not installed, skipping..."

echo "[✅] Networking should be fixed! Rebooting..."
sleep 2
reboot
