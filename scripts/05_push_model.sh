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
MODELS_DIR="$PROJECT_DIR/models"

mkdir -p "$MODELS_DIR"

echo -e "${BLUE}=== [Step 5] Download & Push GGUF Model to Pixel 7 ===${NC}\n"

echo -e "${BOLD}Recommended Quantized GGUF Models for Pixel 7 (Tensor G2, 8GB RAM):${NC}"
echo "1) Llama-3.2-1B-Instruct (Q4_K_M, ~780 MB)  - Ultra fast, minimal memory"
echo "2) Llama-3.2-3B-Instruct (Q4_K_M, ~2.0 GB)  - Strong quality/speed balance"
echo "3) Qwen2.5-1.5B-Instruct (Q4_K_M, ~986 MB)  - Excellent reasoning & math"
echo "4) Qwen2.5-3B-Instruct   (Q4_K_M, ~2.17 GB) - Top 3B performer"
echo "5) Push an existing local .gguf file"
echo ""

read -p "Select an option [1-5]: " -r OPTION

MODEL_URL=""
MODEL_FILE=""

case $OPTION in
    1)
        MODEL_FILE="Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        ;;
    2)
        MODEL_FILE="Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        ;;
    3)
        MODEL_FILE="Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
        ;;
    4)
        MODEL_FILE="Qwen2.5-3B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
        ;;
    5)
        read -p "Enter full path to local .gguf file: " -r LOCAL_PATH
        if [ ! -f "$LOCAL_PATH" ]; then
            echo -e "${RED}File not found: $LOCAL_PATH${NC}"
            exit 1
        fi
        MODEL_FILE=$(basename "$LOCAL_PATH")
        cp "$LOCAL_PATH" "$MODELS_DIR/$MODEL_FILE"
        ;;
    *)
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
        ;;
esac

LOCAL_MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

# Download model if not present
if [ ! -f "$LOCAL_MODEL_PATH" ] && [ -n "$MODEL_URL" ]; then
    echo -e "\n${YELLOW}Downloading $MODEL_FILE...${NC}"
    curl -L --progress-bar -o "$LOCAL_MODEL_PATH" "$MODEL_URL"
    echo -e "${GREEN}Downloaded $MODEL_FILE successfully.${NC}"
fi

# Push to phone via USB
if ! adb get-state &>/dev/null; then
    echo -e "\n${RED}[!] No ADB device connected.${NC}"
    echo "Model saved to $LOCAL_MODEL_PATH. Connect device and run again to push."
    exit 1
fi

echo -e "\n${YELLOW}Creating target directory on device (/sdcard/Download/models)...${NC}"
adb shell mkdir -p /sdcard/Download/models

echo -e "${YELLOW}Pushing $MODEL_FILE over USB to Pixel 7...${NC}"
adb push "$LOCAL_MODEL_PATH" "/sdcard/Download/models/$MODEL_FILE"

echo -e "\n${GREEN}Model deployed successfully to:${NC}"
echo "  /sdcard/Download/models/$MODEL_FILE"
