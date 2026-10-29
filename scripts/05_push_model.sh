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
MODELS_DIR="$PROJECT_DIR/models"

mkdir -p "$MODELS_DIR"

echo -e "${BLUE}=== [Step 5] Model Catalog & Push for Pixel 7 (Tensor G2, 8GB RAM) ===${NC}\n"

echo -e "${BOLD}${CYAN}--- Coding & Development Models ---${NC}"
echo "  1) Qwen 2.5 Coder 1.5B Instruct (Q4_K_M, ~986 MB) - Fast code completion (~14-18 t/s)"
echo "  2) Qwen 2.5 Coder 3B Instruct   (Q4_K_M, ~2.2 GB) - SOTA 3B coding & technical assistant"
echo ""
echo -e "${BOLD}${CYAN}--- Reasoning & Chain-of-Thought ---${NC}"
echo "  3) DeepSeek R1 Distill Qwen 1.5B (Q4_K_M, ~1.1 GB) - Deep step-by-step reasoning"
echo "  4) Qwen 2.5 1.5B Instruct        (Q4_K_M, ~986 MB) - Strong math, logic & general tasks"
echo ""
echo -e "${BOLD}${CYAN}--- General Conversation & Chat ---${NC}"
echo "  5) Llama 3.2 1B Instruct         (Q4_K_M, ~780 MB) - Ultra fast, low battery (~18-22 t/s)"
echo "  6) Llama 3.2 3B Instruct         (Q4_K_M, ~2.0 GB) - Great balance of knowledge and speed"
echo "  7) SmolLM2 1.7B Instruct         (Q4_K_M, ~1.0 GB) - Lightweight conversational model"
echo ""
echo -e "${BOLD}${CYAN}--- Ultra-Compact / Instant ---${NC}"
echo "  8) SmolLM2 360M Instruct         (Q8_0,   ~380 MB) - Instant response (>30 t/s), minimal RAM"
echo ""
echo -e "${BOLD}${CYAN}--- Custom ---${NC}"
echo "  9) Push an existing local .gguf file from host"
echo ""

read -p "Select a model [1-9]: " -r OPTION

MODEL_URL=""
MODEL_FILE=""

case $OPTION in
    1)
        MODEL_FILE="qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
        ;;
    2)
        MODEL_FILE="qwen2.5-coder-3b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
        ;;
    3)
        MODEL_FILE="DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
        ;;
    4)
        MODEL_FILE="qwen2.5-1.5b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
        ;;
    5)
        MODEL_FILE="Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        ;;
    6)
        MODEL_FILE="Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        ;;
    7)
        MODEL_FILE="smollm2-1.7b-instruct-q4_k_m.gguf"
        MODEL_URL="https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf"
        ;;
    8)
        MODEL_FILE="smollm2-360m-instruct-q8_0.gguf"
        MODEL_URL="https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf"
        ;;
    9)
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

# Download model if not present on host
if [ ! -f "$LOCAL_MODEL_PATH" ] && [ -n "$MODEL_URL" ]; then
    echo -e "\n${YELLOW}Downloading $MODEL_FILE...${NC}"
    curl -L --progress-bar -o "$LOCAL_MODEL_PATH" "$MODEL_URL"
    echo -e "${GREEN}(^_^) [ok] Downloaded $MODEL_FILE successfully.${NC}"
fi

# Push to phone via USB
if ! adb get-state &>/dev/null; then
    echo -e "\n${RED}(- -) [!] No ADB device connected.${NC}"
    echo "Model saved to $LOCAL_MODEL_PATH. Connect device and run again to push."
    exit 1
fi

echo -e "\n${YELLOW}Streaming $MODEL_FILE over USB directly into Termux (~/models/)...${NC}"
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'mkdir -p /data/data/com.termux/files/home/models'"

tar -cz -C "$MODELS_DIR" "$MODEL_FILE" | adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/tar -xz -C /data/data/com.termux/files/home/models"

echo -e "\n${GREEN}(^_^) [ok] Model deployed successfully to:${NC}"
echo "  ~/models/$MODEL_FILE"
echo ""
echo -e "${CYAN}Next step:${NC} Run 'Switch Active Model' in the TUI to load this model into llama-server."
