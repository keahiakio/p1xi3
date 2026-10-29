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
PORT_FILE="$PROJECT_DIR/.port"

echo -e "${BLUE}=== [Step 6] Start USB Port Forwarding Bridge ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] Device not connected via ADB.${NC}"
    exit 1
fi

TARGET_PHONE_PORT=11434
HOST_PORT=11434

# Check if host port 11434 is occupied by another host process (e.g., host Ollama)
if command -v ss &>/dev/null && ss -tulpn | grep -q "127.0.0.1:11434"; then
    echo -e "${YELLOW}(o.o) Notice: Host port 11434 is already in use by local host service (e.g. host Ollama).${NC}"
    echo -e "Using fallback port ${BOLD}11435${NC} for USB communication with Pixel 7."
    HOST_PORT=11435
fi

# Configure forwarding
adb forward "tcp:$HOST_PORT" "tcp:$TARGET_PHONE_PORT"
echo "$HOST_PORT" > "$PORT_FILE"

echo -e "\n${GREEN}(^_^) [ok] Port forwarding active: localhost:$HOST_PORT -> Pixel 7:$TARGET_PHONE_PORT${NC}"
echo "Forwarded connections:"
adb forward --list

echo -e "\n${YELLOW}Testing endpoint at http://127.0.0.1:$HOST_PORT ...${NC}"
RESPONSE=$(curl -s -m 3 "http://127.0.0.1:$HOST_PORT/v1/models" 2>/dev/null || echo "")

if [[ "$RESPONSE" == *"llamacpp"* ]] || [[ "$RESPONSE" == *"models"* ]]; then
    echo -e "${GREEN}(^_^) [ok] Success! Pixel 7 LLM server responded over physical USB.${NC}"
    echo -e "  Found active model on device."
else
    echo -e "${YELLOW}(o.o) [!] Bridge is open, but server did not respond.${NC}"
    echo "Make sure the server is running on the phone. Inside Termux, run:"
    echo "  bash ~/start_server.sh"
fi

echo -e "\nTo chat with the model from your host computer:"
echo -e "  ${BOLD}python3 client.py${NC}"
