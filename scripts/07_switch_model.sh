#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}=== [Step 7] Switch Active Model on Pixel 7 ===${NC}\n"

if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] No ADB device connected.${NC}"
    exit 1
fi

get_model_tags() {
    local fname="$1"
    case "$fname" in
        *qwen2.5-coder-1.5b*)
            echo -e "${YELLOW}[Coding · Python/JS/Bash · Fast Scripting]${NC}"
            ;;
        *qwen2.5-coder-3b*)
            echo -e "${YELLOW}[Coding · Refactoring · Architecture · Debugging]${NC}"
            ;;
        *DeepSeek-R1-Distill*|*deepseek-r1*)
            echo -e "${MAGENTA}[Deep Reasoning · Step-by-Step CoT · Math]${NC}"
            ;;
        *qwen2.5-1.5b*)
            echo -e "${CYAN}[General Reasoning · Math · Instructions]${NC}"
            ;;
        *Llama-3.2-1B*|*llama-3.2-1b*)
            echo -e "${GREEN}[Fast Chat · Low Battery · Quick Answers]${NC}"
            ;;
        *Llama-3.2-3B*|*llama-3.2-3b*)
            echo -e "${BLUE}[General Assistant · Writing · Broad Knowledge]${NC}"
            ;;
        *smollm2-1.7b*)
            echo -e "${CYAN}[Lightweight Chat · Dialogue · Efficient]${NC}"
            ;;
        *smollm2-360m*)
            echo -e "${GREEN}[Ultra-Fast · Micro RAM · Instant Responses]${NC}"
            ;;
        *)
            echo -e "${DIM}[Custom Local GGUF Model]${NC}"
            ;;
    esac
}

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
    TAGS=$(get_model_tags "$FNAME")
    STATUS=""
    if [[ "$ACTIVE_PROCESS" == *"$FNAME"* ]]; then
        STATUS=" ${GREEN}[ACTIVE]${NC}"
    fi
    echo -e "  $((i+1))) ${BOLD}$FNAME${NC}$STATUS"
    echo -e "     ${DIM}↳ Best Suited For:${NC} $TAGS"
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
SELECTED_TAGS=$(get_model_tags "$SELECTED_NAME")

echo -e "\n${YELLOW}Switching model to: $SELECTED_NAME ...${NC}"
echo -e "Profile tags: $SELECTED_TAGS"

# Stop old server cleanly using exact process match
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'pkill -x llama-server 2>/dev/null || killall llama-server 2>/dev/null || true'"
sleep 1

# Launch new server in background inside Termux
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'export LD_LIBRARY_PATH=/data/data/com.termux/files/home/llama:\$LD_LIBRARY_PATH; nohup /data/data/com.termux/files/home/llama/llama-server -m \"$SELECTED_MODEL_PATH\" --host 127.0.0.1 --port 11434 -c 32768 -np 2 -t 4 -tb 4 -b 2048 -ub 512 -ctk q8_0 -ctv q8_0 > /data/data/com.termux/files/home/llama.log 2>&1 &'"

echo "Waiting for model to initialize into Tensor G2 memory..."
sleep 2

# Verify running process
NEW_PROC=$(adb shell "run-as com.termux ps -ef | grep llama-server | grep -v grep || true")
if [ -n "$NEW_PROC" ]; then
    echo -e "${GREEN}(^_^) [ok] Model successfully switched and running!${NC}"
    echo "  Loaded : $SELECTED_NAME"
    echo "  Role   : $SELECTED_TAGS"
    echo -e "\nRun 'Launch Host Chat Client' in p1xi3 to begin conversing."
else
    echo -e "${RED}(- -) [!] Server failed to start. Checking log output:${NC}"
    adb shell "run-as com.termux cat /data/data/com.termux/files/home/llama.log"
fi
