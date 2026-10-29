#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PORT="${1:-11434}"

echo -e "${BLUE}=== [Step 6] Start USB Port Forwarding Bridge ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}[!] Device not connected via ADB.${NC}"
    exit 1
fi

echo -e "Configuring ADB port forwarding: ${BOLD}localhost:$PORT -> Pixel 7:$PORT${NC}"
adb forward "tcp:$PORT" "tcp:$PORT"

echo -e "${GREEN}Port forwarding active!${NC}"
echo "Forwarded connections:"
adb forward --list

echo -e "\n${YELLOW}Testing endpoint at http://127.0.0.1:$PORT ...${NC}"
if curl -s -m 2 "http://127.0.0.1:$PORT/health" &>/dev/null || curl -s -m 2 "http://127.0.0.1:$PORT/v1/models" &>/dev/null || curl -s -m 2 "http://127.0.0.1:$PORT/api/tags" &>/dev/null; then
    echo -e "${GREEN}(^_^) [ok] Success! LLM server on Pixel 7 responded over USB.${NC}"
else
    echo -e "${YELLOW}(o.o) [!] LLM server is not responding yet.${NC}"
    echo "Make sure the server is running on the phone. Inside Termux, run:"
    echo "  bash ~/start_server.sh"
fi

echo -e "\nTo test chatting with the model from your host computer, run:"
echo "  python3 client.py"
