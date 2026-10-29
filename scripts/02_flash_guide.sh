#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}=== [Step 2] GrapheneOS Flashing Guide (Pixel 7 / panther) ===${NC}\n"

echo -e "${BOLD}Recommended Flashing Paths:${NC}"
echo -e "  Option 1: Official WebUSB Installer (Easiest, fully verified, handles fastbootd automatically)"
echo -e "  Option 2: CLI Fastboot method (Manual download & flash-all script)\n"

echo -e "${YELLOW}Important Warning:${NC} Flashing GrapheneOS will completely wipe all data on the phone.\n"

echo -e "${BLUE}--- Option 1: WebUSB Installer Steps (Recommended) ---${NC}"
echo "1. Open a Chromium-based browser (Brave, Chrome, Chromium) and navigate to:"
echo "   https://grapheneos.org/install/web"
echo "2. Boot phone into bootloader: Run 'adb reboot bootloader' or hold Volume Down + Power."
echo "3. Click 'Unlock bootloader' on the web page, and confirm on the phone screen."
echo "4. Click 'Download release' for Pixel 7 (panther)."
echo "5. Click 'Flash release' and wait for all partitions to flash."
echo "6. Click 'Lock bootloader' and confirm on the phone screen."
echo "7. Select 'Start' on the phone to boot into GrapheneOS.\n"

echo -e "${BLUE}--- Option 2: CLI Helper Commands ---${NC}"
echo "If you prefer the command line, this script can reboot your phone to bootloader right now."
read -p "Would you like to reboot connected device to bootloader now? (y/N): " -r CONFIRM
if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    if adb get-state &>/dev/null; then
        echo "Rebooting device to bootloader..."
        adb reboot bootloader
        echo -e "${GREEN}Phone rebooting into bootloader mode.${NC}"
        echo "Next step: Run 'fastboot flashing unlock' if not already unlocked."
    else
        echo -e "${YELLOW}Device not reachable via ADB. You can manually power off and hold Volume Down + Power.${NC}"
    fi
else
    echo "Skipping bootloader reboot."
fi
