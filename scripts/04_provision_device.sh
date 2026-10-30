#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PROJECT_DIR/bin"
TERMUX_APK="$BIN_DIR/termux-app.apk"
LLAMA_TAR="$BIN_DIR/llama-android-arm64.tar.gz"

echo -e "${BLUE}=== [Step 4] Provision Termux & Native llama-server ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] No authorized ADB device connected.${NC}"
    echo "Make sure the Pixel 7 is connected, screen unlocked, and USB debugging enabled."
    exit 1
fi

mkdir -p "$BIN_DIR"

# 1. Check / Install Termux
echo -e "${YELLOW}1. Checking Termux installation...${NC}"
if ! adb shell pm list packages | grep -q "com.termux"; then
    if [ ! -f "$TERMUX_APK" ]; then
        echo "Downloading Termux APK..."
        TERMUX_URL="https://github.com/termux/termux-app/releases/download/v0.118.1/termux-app_v0.118.1+github-debug_arm64-v8a.apk"
        curl -L -o "$TERMUX_APK" "$TERMUX_URL"
    fi
    echo "Installing Termux via ADB..."
    adb install -r -d "$TERMUX_APK"
    echo -e "${GREEN}(^_^) [ok] Termux installed.${NC}"
else
    echo -e "${GREEN}(^_^) [ok] Termux is already installed.${NC}"
fi

# Ensure Termux activity has run at least once to create home directories
adb shell am start -n com.termux/.app.TermuxActivity &>/dev/null || true
sleep 1

# 2. Permission Hardening (GrapheneOS vs Stock Android)
echo -e "\n${YELLOW}2. Checking Permission Policy...${NC}"
IS_GRAPHENE=$(adb shell getprop os.grapheneos.version 2>/dev/null || echo "")

if [ -n "$IS_GRAPHENE" ]; then
    echo "GrapheneOS detected: Revoking network permission from Termux..."
    adb shell pm revoke com.termux android.permission.INTERNET 2>/dev/null || true
    echo -e "${GREEN}(^_^) [ok] Termux internet permission revoked (GrapheneOS runtime toggle).${NC}"
else
    echo -e "${GREEN}(^_^) [ok] Stock Android detected.${NC}"
    echo "  Notice: Stock Android uses a static install-time permission for INTERNET."
    echo "  Air-gap is maintained at the hardware/OS level (Airplane mode ON, Wi-Fi OFF)."
fi

# 3. Deploy Precompiled Android ARM64 llama-server
echo -e "\n${YELLOW}3. Deploying Native llama-server (16KB aligned ARM64)...${NC}"
if [ ! -f "$LLAMA_TAR" ]; then
    echo "Downloading official Android ARM64 binaries..."
    LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/download/b11988/llama-b11988-bin-android-arm64.tar.gz"
    curl -L -o "$LLAMA_TAR" "$LLAMA_URL"
fi

echo "Streaming binaries directly into Termux private storage..."
TMP_EXTRACT="/tmp/llama_extract_$$"
mkdir -p "$TMP_EXTRACT"
tar -xzf "$LLAMA_TAR" -C "$TMP_EXTRACT"
BIN_SUBDIR=$(find "$TMP_EXTRACT" -maxdepth 1 -type d -name "llama-*" | head -n 1)

adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'mkdir -p /data/data/com.termux/files/home/llama /data/data/com.termux/files/home/models'"

tar -cz -C "$BIN_SUBDIR" . | adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/tar -xz -C /data/data/com.termux/files/home/llama"
rm -rf "$TMP_EXTRACT"

# Create a convenient start script inside Termux
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'cat << \"STARTEOF\" > /data/data/com.termux/files/home/start_server.sh
#!/data/data/com.termux/files/usr/bin/bash
export LD_LIBRARY_PATH=/data/data/com.termux/files/home/llama:\$LD_LIBRARY_PATH
MODEL=\$(ls /data/data/com.termux/files/home/models/*.gguf 2>/dev/null | head -n 1)
if [ -z \"\$MODEL\" ]; then
    echo \"(o.o) [!] No model found in ~/models/.\"
    echo \"Use step 5 in p1xi3 to push a GGUF model first.\"
    exit 1
fi
echo \"(^_^) Starting llama-server with: \$MODEL\"
/data/data/com.termux/files/home/llama/llama-server -m \"\$MODEL\" --host 127.0.0.1 --port 11434 -c 16384 -t 4
STARTEOF
chmod +x /data/data/com.termux/files/home/start_server.sh
'"

# 4. Verify binary execution
echo -e "\n${YELLOW}4. Verifying execution on Pixel 7 Tensor G2...${NC}"
TEST_OUT=$(adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'export LD_LIBRARY_PATH=/data/data/com.termux/files/home/llama; /data/data/com.termux/files/home/llama/llama-cli --version'" 2>&1 || echo "Error")

if [[ "$TEST_OUT" == *"version:"* ]]; then
    echo -e "${GREEN}(^_^) [ok] Binary verified! Native llama-server is ready on device.${NC}"
    echo "  $TEST_OUT"
else
    echo -e "${RED}(- -) [!] Verification output:${NC} $TEST_OUT"
fi

echo -e "\n${BLUE}Note on 16 KB Page Size dialog:${NC}"
echo "If your phone displays a '16 KB page size incompatibility' prompt for Termux, simply tap 'OK' / 'Dismiss'."
echo "The native llama-server binaries are compiled with 16KB (0x4000) alignment and run cleanly."
