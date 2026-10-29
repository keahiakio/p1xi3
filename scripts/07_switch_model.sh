#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}=== [Step 7] Switch Active Model on Pixel 7 ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] No ADB device connected.${NC}"
    exit 1
fi

# 1. Fetch list of models from device
echo "Querying installed models on Pixel 7..."
MODELS_RAW=$(adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'ls -1 /data/data/com.termux/files/home/models/*.gguf 2>/dev/null || true'")

if [ -z "$MODELS_RAW" ]; then
    echo -e "${YELLOW}(o.o) [!] No GGUF models found on device in ~/models/.${NC}"
    echo "Please use 'Download & Push Model' (Step 5) to push a model first."
    exit 1
fi

# Detect currently loaded model
ACTIVE_PROCESS=$(adb shell "run-as com.termux ps -ef | grep llama-server | grep -v grep || true")

# Read models into array
MODEL_LIST=()
while IFS= read -r line; do
    [ -n "$line" ] && MODEL_LIST+=("$line")
done <<< "$MODELS_RAW"

echo -e "\n${BOLD}Installed Models on Device:${NC}"
for i in "${!MODEL_LIST[@]}"; do
    FULL_PATH="${MODEL_LIST[$i]}"
    FNAME=$(basename "$FULL_PATH")
    STATUS=""
    if [[ "$ACTIVE_PROCESS" == *"$FNAME"* ]]; then
        STATUS=" ${GREEN}[ACTIVE]${NC}"
    fi
    echo -e "  $((i+1))) ${BOLD}$FNAME${NC}$STATUS"
done

echo ""
if [ -t 0 ]; then
    read -p "Select a model to load [1-${#MODEL_LIST[@]}]: " -r CHOICE
else
    read -r CHOICE || CHOICE=1
fi

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#MODEL_LIST[@]}" ]; then
    echo -e "${RED}Invalid selection.${NC}"
    exit 1
fi

SELECTED_MODEL_PATH="${MODEL_LIST[$((CHOICE-1))]}"
SELECTED_NAME=$(basename "$SELECTED_MODEL_PATH")

echo -e "\n${YELLOW}Switching model to: $SELECTED_NAME ...${NC}"

# Stop old server cleanly using exact process match
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'pkill -x llama-server 2>/dev/null || killall llama-server 2>/dev/null || true'"
sleep 1

# Launch new server in background inside Termux
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'export LD_LIBRARY_PATH=/data/data/com.termux/files/home/llama:\$LD_LIBRARY_PATH; nohup /data/data/com.termux/files/home/llama/llama-server -m \"$SELECTED_MODEL_PATH\" --host 127.0.0.1 --port 11434 -c 2048 -t 4 > /data/data/com.termux/files/home/llama.log 2>&1 &'"

echo "Waiting for model to initialize into Tensor G2 memory..."
sleep 2

# Verify running process
NEW_PROC=$(adb shell "run-as com.termux ps -ef | grep llama-server | grep -v grep || true")
if [ -n "$NEW_PROC" ]; then
    echo -e "${GREEN}(^_^) [ok] Model successfully switched and running!${NC}"
    echo "  Loaded: $SELECTED_NAME"
    echo -e "\nRun 'Launch Host Chat Client' in p1xi3 to begin conversing."
else
    echo -e "${RED}(- -) [!] Server failed to start. Checking log output:${NC}"
    adb shell "run-as com.termux cat /data/data/com.termux/files/home/llama.log"
fi
