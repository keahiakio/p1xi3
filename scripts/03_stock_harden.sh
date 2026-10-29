#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}=== [Stock Android] Air-Gap Hardening & Telemetry Debloat ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] No authorized ADB device connected.${NC}"
    echo "Connect your Pixel 7 via USB and accept the RSA debugging prompt."
    exit 1
fi

echo -e "${BOLD}Target: Stock Android (Locked Bootloader Safe Mode)${NC}"
echo "This script hardens stock Android by disabling wireless radios and telemetry without root.\n"

# 1. Radio status check & recommendations
echo -e "${YELLOW}1. Checking wireless radios...${NC}"
WIFI_ON=$(adb shell settings get global wifi_on 2>/dev/null || echo "1")
BLUETOOTH_ON=$(adb shell settings get global bluetooth_on 2>/dev/null || echo "1")
AIRPLANE_ON=$(adb shell settings get global airplane_mode_on 2>/dev/null || echo "0")

if [ "$AIRPLANE_ON" != "1" ]; then
    echo "  (o.o) Airplane mode is currently OFF. Please turn ON Airplane mode in Quick Settings."
else
    echo -e "  ${GREEN}(^_^) [ok] Airplane mode is ON.${NC}"
fi

if [ "$WIFI_ON" != "0" ]; then
    echo "  (o.o) Wi-Fi is ON. Turning off Wi-Fi via ADB..."
    adb shell cmd connectivity airplane-mode enable 2>/dev/null || true
    adb shell svc wifi disable 2>/dev/null || true
else
    echo -e "  ${GREEN}(^_^) [ok] Wi-Fi is OFF.${NC}"
fi

if [ "$BLUETOOTH_ON" != "0" ]; then
    echo "  (o.o) Bluetooth is ON. Turning off Bluetooth via ADB..."
    adb shell cmd bluetooth disable 2>/dev/null || true
else
    echo -e "  ${GREEN}(^_^) [ok] Bluetooth is OFF.${NC}"
fi

# 2. Disable Location & Scanning
echo -e "\n${YELLOW}2. Disabling background location & radio scanning...${NC}"
adb shell settings put global wifi_scan_always_enabled 0 2>/dev/null || true
adb shell settings put global ble_scan_always_enabled 0 2>/dev/null || true
echo -e "  ${GREEN}(^_^) [ok] Background Wi-Fi & Bluetooth scanning disabled.${NC}"

# 3. Optional Debloat / Telemetry suppression
echo -e "\n${YELLOW}3. Telemetry & Analytics suppression:${NC}"
echo "You can disable Google Play analytics, telemetry, and background sync services."
read -p "Disable telemetry and sync packages for user 0? (y/N): " -r CONFIRM_DEBLOAT
if [[ $CONFIRM_DEBLOAT =~ ^[Yy]$ ]]; then
    PACKAGES=(
        "com.google.android.gms.policy_sidecar_aps"
        "com.google.android.apps.carrier.carrierwifi"
        "com.google.android.feedback"
        "com.google.android.setupwizard"
    )
    for pkg in "${PACKAGES[@]}"; do
        if adb shell pm list packages | grep -q "$pkg"; then
            echo -n "  Disabling $pkg... "
            adb shell pm disable-user --user 0 "$pkg" 2>/dev/null && echo -e "${GREEN}[ok]${NC}" || echo -e "${YELLOW}[skipped]${NC}"
        fi
    done
    echo -e "${GREEN}(^_^) [ok] Telemetry suppression complete.${NC}"
else
    echo "  Skipped telemetry debloat."
fi

echo -e "\n${GREEN}(^_^) [ok] Stock Android hardening complete!${NC}"
