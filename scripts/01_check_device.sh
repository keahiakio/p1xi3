#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== [Step 1] Device Connection & Readiness Check ===${NC}\n"

# 1. Check tools
echo -n "Checking required host tools (adb, fastboot)... "
for tool in adb fastboot curl python3; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "\n${RED}Error:${NC} Missing required command: $tool"
        exit 1
    fi
done
echo -e "${GREEN}OK${NC}"

# 2. Check ADB devices
echo -e "\n${YELLOW}Checking ADB devices...${NC}"
adb devices -l

ADB_COUNT=$(adb devices | grep -v "List of devices" | grep -v '^$' | wc -l || true)
FASTBOOT_COUNT=$(fastboot devices | wc -l || true)

if [ "$ADB_COUNT" -eq 0 ] && [ "$FASTBOOT_COUNT" -eq 0 ]; then
    echo -e "\n${RED}[!] No device detected in ADB or Fastboot mode.${NC}"
    echo -e "Troubleshooting steps:"
    echo -e "  1. Connect your Pixel 7 via a high-speed USB-C data cable directly to the machine."
    echo -e "  2. On the phone, unlock the screen."
    echo -e "  3. Go to Settings > System > Developer options."
    echo -e "     - Enable 'USB debugging'."
    echo -e "     - Enable 'OEM unlocking'."
    echo -e "  4. Watch for an 'Allow USB debugging?' RSA prompt on the phone screen and tap 'Always allow'."
    exit 1
fi

if [ "$ADB_COUNT" -gt 0 ]; then
    DEVICE_STATE=$(adb get-state 2>/dev/null || echo "unknown")
    if [ "$DEVICE_STATE" == "unauthorized" ]; then
        echo -e "\n${YELLOW}[!] Device is connected but unauthorized.${NC}"
        echo "Check your Pixel screen and tap 'Always allow from this computer'."
        exit 1
    fi

    DEVICE_MODEL=$(adb shell getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_NAME=$(adb shell getprop ro.product.name 2>/dev/null || echo "Unknown")
    BATTERY_LEVEL=$(adb shell dumpsys battery 2>/dev/null | grep level | awk '{print $2}' || echo "Unknown")

    echo -e "\n${GREEN}Device Detected via ADB:${NC}"
    echo "  Model:       $DEVICE_MODEL ($DEVICE_NAME)"
    echo "  Battery:     $BATTERY_LEVEL%"

    # Pixel 7 codename is panther
    if [[ "$DEVICE_NAME" != *"panther"* ]]; then
        echo -e "${YELLOW}[Notice] Expected Pixel 7 ('panther'). Detected: '$DEVICE_NAME'.${NC}"
    else
        echo -e "${GREEN}Verified target device: Pixel 7 (panther)${NC}"
    fi

    # Check OEM unlock status
    echo -n "Checking OEM unlockable status... "
    OEM_UNLOCKABLE=$(adb shell getprop sys.oem_unlock_allowed 2>/dev/null || echo "0")
    if [ "$OEM_UNLOCKABLE" == "1" ]; then
        echo -e "${GREEN}Allowed (OEM unlocking enabled in Developer Options)${NC}"
    else
        echo -e "${YELLOW}Unknown or Disabled ($OEM_UNLOCKABLE)${NC}"
        echo "Please verify in Settings > System > Developer options > OEM unlocking is toggled ON."
    fi
fi

if [ "$FASTBOOT_COUNT" -gt 0 ]; then
    echo -e "\n${GREEN}Device detected in Fastboot mode:${NC}"
    fastboot devices
    PRODUCT=$(fastboot getvar product 2>&1 | grep "product:" | awk '{print $2}' || echo "unknown")
    UNLOCKED=$(fastboot getvar unlocked 2>&1 | grep "unlocked:" | awk '{print $2}' || echo "unknown")
    echo "  Fastboot product: $PRODUCT"
    echo "  Bootloader status: unlocked=$UNLOCKED"
fi

echo -e "\n${GREEN}Step 1 Complete!${NC}"
