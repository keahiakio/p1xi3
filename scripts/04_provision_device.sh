#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PROJECT_DIR/bin"
TERMUX_APK="$BIN_DIR/termux-app.apk"

echo -e "${BLUE}=== [Step 4] Provision Termux & LLM Runner on Pixel 7 ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}[!] No authorized ADB device connected.${NC}"
    echo "Make sure the Pixel 7 is connected, screen unlocked, and USB debugging is enabled."
    exit 1
fi

mkdir -p "$BIN_DIR"

# 1. Download Termux if needed
if [ ! -f "$TERMUX_APK" ]; then
    echo -e "${YELLOW}Downloading Termux APK (F-Droid build from GitHub releases)...${NC}"
    TERMUX_URL="https://github.com/termux/termux-app/releases/download/v0.118.1/termux-app_v0.118.1+github-debug_arm64-v8a.apk"
    curl -L -o "$TERMUX_APK" "$TERMUX_URL"
    echo -e "${GREEN}Downloaded Termux APK to $TERMUX_APK${NC}"
fi

# 2. Install Termux via ADB
echo -e "\n${YELLOW}Installing Termux onto Pixel 7 via ADB...${NC}"
adb install -r -d "$TERMUX_APK"
echo -e "${GREEN}Termux successfully installed.${NC}"

# 3. Network permission policy in GrapheneOS
echo -e "\n${YELLOW}GrapheneOS Network Permission Hardening:${NC}"
echo "You can permanently revoke the Network permission from Termux."
echo "Even with network revoked, ADB port-forwarding over USB continues to function locally!"
read -p "Revoke internet permission from Termux now? (Y/n): " -r REVOKE_PERM
if [[ ! $REVOKE_PERM =~ ^[Nn]$ ]]; then
    adb shell pm revoke com.termux android.permission.INTERNET || true
    echo -e "${GREEN}Network permission revoked for Termux.${NC}"
fi

# 4. Prepare Setup Script for Phone
DEVICE_SETUP_SCRIPT="/sdcard/Download/init_pixel_llm.sh"

cat << 'EOF' > /tmp/init_pixel_llm.sh
#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Initializing LLM Server in Termux ==="
pkg update -y
pkg install -y git clang cmake make termux-tools python

if [ ! -d "$HOME/llama.cpp" ]; then
    echo "Cloning llama.cpp..."
    git clone https://github.com/ggerganov/llama.cpp "$HOME/llama.cpp"
fi

cd "$HOME/llama.cpp"
echo "Compiling native llama.cpp for ARM64..."
cmake -B build -DGGML_OPENMP=OFF
cmake --build build --config Release -j4 --target llama-server

echo "=== Build Complete! ==="
echo "The native llama-server is ready at: $HOME/llama.cpp/build/bin/llama-server"
echo "It provides both OpenAI-compatible and Ollama-compatible endpoints on port 11434."
EOF

echo -e "\n${YELLOW}Pushing setup script to Pixel 7...${NC}"
adb push /tmp/init_pixel_llm.sh "$DEVICE_SETUP_SCRIPT"
rm -f /tmp/init_pixel_llm.sh

echo -e "\n${GREEN}Termux setup script placed at $DEVICE_SETUP_SCRIPT${NC}"
echo -e "\n${BLUE}To run compilation directly inside Termux:${NC}"
echo "  Option A (Via phone UI): Open Termux and run:"
echo "    bash /sdcard/Download/init_pixel_llm.sh"
echo ""
echo "  Option B (Via ADB shell): Launch Termux on phone once, then run:"
echo "    adb shell am start -n com.termux/.app.TermuxActivity"
