#!/bin/bash
sudo modprobe batman-adv
sudo ip link set wlan0 down
sudo iw dev wlan0 set types ibss
