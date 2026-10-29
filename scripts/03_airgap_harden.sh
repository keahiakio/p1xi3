#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}=== [Step 3] Air-Gap Verification & Hardening Checklist ===${NC}\n"

echo -e "${BOLD}Follow these steps on your Pixel 7 (GrapheneOS):${NC}\n"

echo "1. Physical Layer:"
echo "   [ ] Remove physical SIM card."
echo "   [ ] Ensure no eSIM profile is installed."
echo ""
echo "2. Wireless Radios:"
echo "   [ ] Toggle Airplane Mode: ON."
echo "   [ ] Toggle Wi-Fi: OFF."
echo "   [ ] Toggle Bluetooth: OFF."
echo "   [ ] Disable Wi-Fi & Bluetooth scanning (Settings > Location > Location services)."
echo ""
echo "3. GrapheneOS Network Restrictions:"
echo "   [ ] Turn off captive portal detection."
echo "   [ ] Settings > Security > USB-C port: Set to 'On when unlocked' or customize as desired."
echo ""
echo "4. Developer Options for USB Communication:"
echo "   [ ] Settings > About phone > Tap 'Build number' 7 times."
echo "   [ ] Settings > System > Developer options > Enable 'USB debugging'."
echo "   [ ] Plug in USB cable and accept the computer's RSA debugging key ('Always allow')."
echo ""

if adb get-state &>/dev/null; then
    echo -e "${GREEN}Verifying device state via ADB...${NC}"
    WIFI_ON=$(adb shell settings get global wifi_on 2>/dev/null || echo "unknown")
    AIRPLANE_ON=$(adb shell settings get global airplane_mode_on 2>/dev/null || echo "unknown")
    BLUETOOTH_ON=$(adb shell settings get global bluetooth_on 2>/dev/null || echo "unknown")

    echo "  Airplane Mode: $([ "$AIRPLANE_ON" == "1" ] && echo -e "${GREEN}ENABLED${NC}" || echo -e "${YELLOW}DISABLED (Recommend Enabling)${NC}")"
    echo "  Wi-Fi:         $([ "$WIFI_ON" == "0" ] && echo -e "${GREEN}OFF${NC}" || echo -e "${YELLOW}ON (Recommend Turning Off)${NC}")"
    echo "  Bluetooth:     $([ "$BLUETOOTH_ON" == "0" ] && echo -e "${GREEN}OFF${NC}" || echo -e "${YELLOW}ON (Recommend Turning Off)${NC}")"
else
    echo -e "${YELLOW}Device not reachable via ADB yet. Enable USB debugging in Developer Options first.${NC}"
fi

echo -e "\n${GREEN}Checklist displayed.${NC}"
