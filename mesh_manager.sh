#!/bin/bash
# mesh_manager.sh
#
# This script can:
#   1. Configure Batman mesh mode (ad‑hoc) on wlan0 with a static IP.
#   2. Revert wlan0 back to regular (managed) Wi‑Fi mode.
#   3. Install or remove a systemd service that “persists” the configuration.
#   4. Test Batman connectivity using batctl (neighbors, originators, etc).
#
# Usage:
#   sudo mesh_manager.sh batman [--last-octet <number>] [--install-systemd] [--remove-systemd]
#       e.g., sudo mesh_manager.sh batman --last-octet 10 --install-systemd
#
#   sudo mesh_manager.sh regular [--install-systemd] [--remove-systemd]
#
#   sudo mesh_manager.sh test <n|o>
#       (n for neighbor list; o for originator table)
#
# Make sure this script is placed at a fixed location (e.g. /usr/local/bin/mesh_manager.sh)
# so that the generated systemd unit files point to the correct path.
#

set -e

print_usage() {
    echo "Usage:"
    echo "  sudo $0 batman [--last-octet <number>] [--install-systemd] [--remove-systemd]"
    echo "     (Configures Batman mesh mode with IP 192.168.199.X; default last octet is 10)"
    echo "  sudo $0 regular [--install-systemd] [--remove-systemd]"
    echo "     (Reverts wlan0 back to managed mode)"
    echo "  sudo $0 test <n|o>"
    echo "     (Tests Batman connectivity: n = neighbors, o = originators)"
    exit 1
}

# Check if run as root.
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Defaults
LAST_OCTET=10
INSTALL_SYSTEMD=false
REMOVE_SYSTEMD=false
TEST_ARG=""

# Require at least one argument
if [ "$#" -lt 1 ]; then
    print_usage
fi

COMMAND="$1"
shift

# Parse additional options
while [[ "$1" != "" ]]; do
    case "$1" in
        --last-octet)
            shift
            LAST_OCTET="$1"
            ;;
        --install-systemd)
            INSTALL_SYSTEMD=true
            ;;
        --remove-systemd)
            REMOVE_SYSTEMD=true
            ;;
        *)
            # For the test command, capture the test parameter (like n or o)
            TEST_ARG="$1"
            ;;
    esac
    shift
done

# --- Functions ---

config_batman_mode() {
    local octet="$1"
    local BATMAN_IP="192.168.199.${octet}"
    echo "=== Configuring Batman mesh mode with IP ${BATMAN_IP} ==="

    echo "[1/5] Installing required packages..."
    apt-get update
    apt-get install -y batctl batman-adv wireless-tools iw

    echo "[2/5] Stopping interfering services (e.g., wpa_supplicant)..."
    systemctl stop wpa_supplicant.service || true

    echo "[3/5] Configuring wlan0 for ad-hoc mode..."
    ip link set wlan0 down
    iwconfig wlan0 mode ad-hoc
    iwconfig wlan0 essid batmesh
    iwconfig wlan0 channel 1
    ip addr flush dev wlan0
    ip addr add "${BATMAN_IP}/24" dev wlan0
    ip link set wlan0 up

    echo "[4/5] Loading batman-adv module and attaching wlan0..."
    modprobe batman-adv
    batctl if add wlan0

    echo "[5/5] Setting up bat0 interface..."
    # bat0 may already exist; flush its IP and assign our static IP
    ip link set bat0 up || true
    ip addr flush dev bat0 || true
    ip addr add "${BATMAN_IP}/24" dev bat0

    echo "Batman mesh mode enabled. (bat0 IP: ${BATMAN_IP})"
}

config_regular_mode() {
    echo "=== Reverting to regular (managed) Wi-Fi mode ==="

    echo "[1] Bringing down bat0 (if it exists)..."
    if ip link show bat0 > /dev/null 2>&1; then
        ip link set bat0 down
    fi

    echo "[2] Removing wlan0 from batman-adv (if attached)..."
    batctl if del wlan0 2>/dev/null || true

    echo "[3] Reconfiguring wlan0 to managed mode..."
    ip link set wlan0 down
    iwconfig wlan0 mode managed
    ip addr flush dev wlan0
    ip link set wlan0 up

    echo "[4] Restarting networking (dhcpcd)..."
    systemctl restart dhcpcd

    echo "Regular Wi-Fi mode restored."
}

install_systemd_service() {
    local mode="$1"
    local SERVICE_FILE=""
    local SCRIPT_PATH
    SCRIPT_PATH=$(readlink -f "$0")
    
    if [ "$mode" = "batman" ]; then
         SERVICE_FILE="/etc/systemd/system/mesh-mode-batman.service"
         cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Batman Mesh Mode Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} batman --last-octet ${LAST_OCTET}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
         systemctl daemon-reload
         systemctl enable mesh-mode-batman.service
         echo "Installed and enabled systemd service for Batman mode."
    elif [ "$mode" = "regular" ]; then
         SERVICE_FILE="/etc/systemd/system/mesh-mode-regular.service"
         cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Regular Wi-Fi Mode Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} regular
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
         systemctl daemon-reload
         systemctl enable mesh-mode-regular.service
         echo "Installed and enabled systemd service for Regular mode."
    else
         echo "Unknown mode for systemd installation: $mode"
         exit 1
    fi
}

remove_systemd_service() {
    local mode="$1"
    local SERVICE_FILE=""
    
    if [ "$mode" = "batman" ]; then
         SERVICE_FILE="/etc/systemd/system/mesh-mode-batman.service"
         systemctl disable mesh-mode-batman.service || true
         rm -f "$SERVICE_FILE"
         systemctl daemon-reload
         echo "Disabled and removed systemd service for Batman mode."
    elif [ "$mode" = "regular" ]; then
         SERVICE_FILE="/etc/systemd/system/mesh-mode-regular.service"
         systemctl disable mesh-mode-regular.service || true
         rm -f "$SERVICE_FILE"
         systemctl daemon-reload
         echo "Disabled and removed systemd service for Regular mode."
    else
         echo "Unknown mode for systemd removal: $mode"
         exit 1
    fi
}

test_mesh() {
    local arg="$1"
    case "$arg" in
       n)
           echo "=== Batman neighbor list ==="
           batctl n
           ;;
       o)
           echo "=== Batman originator table ==="
           batctl o
           ;;
       *)
           echo "Unknown test parameter: $arg"
           echo "Use 'n' for neighbors or 'o' for originators."
           exit 1
           ;;
    esac
}

# --- Main Dispatch ---

case "$COMMAND" in
    batman)
         config_batman_mode "$LAST_OCTET"
         if [ "$INSTALL_SYSTEMD" = true ]; then
             install_systemd_service "batman"
         fi
         if [ "$REMOVE_SYSTEMD" = true ]; then
             remove_systemd_service "batman"
         fi
         ;;
    regular)
         config_regular_mode
         if [ "$INSTALL_SYSTEMD" = true ]; then
             install_systemd_service "regular"
         fi
         if [ "$REMOVE_SYSTEMD" = true ]; then
             remove_systemd_service "regular"
         fi
         ;;
    test)
         if [ -z "$TEST_ARG" ]; then
             echo "Please provide a test parameter (e.g., n or o)"
             exit 1
         fi
         test_mesh "$TEST_ARG"
         ;;
    *)
         print_usage
         ;;
esac
