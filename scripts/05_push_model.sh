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
MODELS_DIR="$PROJECT_DIR/models"

mkdir -p "$MODELS_DIR"

CATALOG=(
    "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf|Qwen 2.5 Coder 1.5B|~986 MB|[Coding] [Python/JS/Bash] [Scripting]|Fast code completion & inline suggestions (~14-18 t/s)"
    "qwen2.5-coder-3b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf|Qwen 2.5 Coder 3B|~2.2 GB|[Coding] [Architecture] [Refactoring] [Debugging]|SOTA 3B programming & deep technical assistant (~8-11 t/s)"
    "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf|https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf|DeepSeek R1 Distill Qwen 1.5B|~1.1 GB|[Reasoning] [Math] [Step-by-Step CoT] [Logic]|Complex problem solving with chain-of-thought (~12-16 t/s)"
    "qwen2.5-1.5b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf|Qwen 2.5 1.5B Instruct|~986 MB|[General Reasoning] [Math] [Instruction Following]|Strong general intelligence & factual comprehension (~14-18 t/s)"
    "Llama-3.2-1B-Instruct-Q4_K_M.gguf|https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf|Llama 3.2 1B Instruct|~780 MB|[Fast Chat] [Low Battery] [Conversational]|Rapid conversational responses with minimum battery draw (~18-22 t/s)"
    "Llama-3.2-3B-Instruct-Q4_K_M.gguf|https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf|Llama 3.2 3B Instruct|~2.0 GB|[General Assistant] [Writing] [Broad Knowledge]|High quality chat & broad knowledge base (~8-12 t/s)"
    "smollm2-1.7b-instruct-q4_k_m.gguf|https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf|SmolLM2 1.7B Instruct|~1.0 GB|[Lightweight] [Dialogue] [Instruction]|Compact general assistant with natural conversation"
    "smollm2-360m-instruct-q8_0.gguf|https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf|SmolLM2 360M Instruct|~380 MB|[Ultra-Fast] [Low Memory] [Basic Tasks]|Instant generation (>30 t/s) with near-zero memory footprint"
)

echo -e "${BLUE}=== [Step 5] Model Catalog & Push for Pixel 7 (Tensor G2, 8GB RAM) ===${NC}\n"

echo -e "${BOLD}${CYAN}--- Coding & Development ---${NC}"
echo -e "  1) ${BOLD}Qwen 2.5 Coder 1.5B Instruct${NC} (~986 MB)"
echo -e "     ${YELLOW}[Coding] [Python/JS/Bash] [Scripting]${NC}"
echo -e "     ${DIM}↳ Fast code completion & inline suggestions (~14-18 t/s)${NC}\n"

echo -e "  2) ${BOLD}Qwen 2.5 Coder 3B Instruct${NC} (~2.2 GB)"
echo -e "     ${YELLOW}[Coding] [Architecture] [Refactoring] [Debugging]${NC}"
echo -e "     ${DIM}↳ SOTA 3B programming & deep technical assistant (~8-11 t/s)${NC}\n"

echo -e "${BOLD}${CYAN}--- Reasoning & Chain-of-Thought ---${NC}"
echo -e "  3) ${BOLD}DeepSeek R1 Distill Qwen 1.5B${NC} (~1.1 GB)"
echo -e "     ${MAGENTA}[Deep Reasoning] [Math] [Step-by-Step CoT] [Logic]${NC}"
echo -e "     ${DIM}↳ Complex problem solving with chain-of-thought (~12-16 t/s)${NC}\n"

echo -e "  4) ${BOLD}Qwen 2.5 1.5B Instruct${NC} (~986 MB)"
echo -e "     ${CYAN}[General Reasoning] [Math] [Instruction Following]${NC}"
echo -e "     ${DIM}↳ Strong general intelligence & factual comprehension (~14-18 t/s)${NC}\n"

echo -e "${BOLD}${CYAN}--- General Conversation & Chat ---${NC}"
echo -e "  5) ${BOLD}Llama 3.2 1B Instruct${NC} (~780 MB)"
echo -e "     ${GREEN}[Fast Chat] [Low Battery] [Conversational]${NC}"
echo -e "     ${DIM}↳ Rapid conversational responses with minimum battery draw (~18-22 t/s)${NC}\n"

echo -e "  6) ${BOLD}Llama 3.2 3B Instruct${NC} (~2.0 GB)"
echo -e "     ${BLUE}[General Assistant] [Writing] [Broad Knowledge]${NC}"
echo -e "     ${DIM}↳ High quality chat & broad knowledge base (~8-12 t/s)${NC}\n"

echo -e "  7) ${BOLD}SmolLM2 1.7B Instruct${NC} (~1.0 GB)"
echo -e "     ${CYAN}[Lightweight] [Dialogue] [Instruction]${NC}"
echo -e "     ${DIM}↳ Compact general assistant with natural conversation${NC}\n"

echo -e "${BOLD}${CYAN}--- Ultra-Compact / Instant ---${NC}"
echo -e "  8) ${BOLD}SmolLM2 360M Instruct${NC} (~380 MB)"
echo -e "     ${GREEN}[Ultra-Fast] [Low Memory] [Basic Tasks]${NC}"
echo -e "     ${DIM}↳ Instant generation (>30 t/s) with near-zero memory footprint${NC}\n"

echo -e "${BOLD}${CYAN}--- Bulk & Custom ---${NC}"
echo -e "  ${BOLD}${GREEN}A) Download & Deploy ALL Models${NC} (Complete ~10.5 GB suite: Coding, Reasoning, Chat)"
echo -e "  9) Push an existing local .gguf file from host\n"

read -p "Select an option [1-9 or A]: " -r OPTION

deploy_single_model() {
    local m_file="$1"
    local m_url="$2"
    local m_name="$3"
    local m_tags="${4:-}"
    local local_path="$MODELS_DIR/$m_file"

    echo -e "\n${BOLD}Processing $m_name...${NC}"
    if [ -n "$m_tags" ]; then
        echo -e "  Optimal suited for: ${YELLOW}$m_tags${NC}"
    fi

    # Check if already on device
    DEVICE_HAS_MODEL=$(adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c '[ -f /data/data/com.termux/files/home/models/$m_file ] && echo yes || echo no'")
    if [ "$DEVICE_HAS_MODEL" == "yes" ]; then
        echo -e "  ${GREEN}(^_^) [ok] Already deployed on device (~/models/$m_file). Skipping push.${NC}"
        return 0
    fi

    # Download to host if not already cached
    if [ ! -f "$local_path" ]; then
        echo -e "  ${YELLOW}Downloading from HuggingFace to host cache...${NC}"
        curl -L --progress-bar -o "$local_path" "$m_url"
        echo -e "  ${GREEN}(^_^) [ok] Download complete.${NC}"
    else
        echo -e "  Found cached copy in host models directory."
    fi

    # Stream to device
    echo -e "  ${YELLOW}Streaming over USB into Pixel 7 (~/models/)...${NC}"
    adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'mkdir -p /data/data/com.termux/files/home/models'"
    tar -cz -C "$MODELS_DIR" "$m_file" | adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/tar -xz -C /data/data/com.termux/files/home/models"
    echo -e "  ${GREEN}(^_^) [ok] Deployed: ~/models/$m_file${NC}"
}

if ! adb get-state &>/dev/null; then
    echo -e "\n${RED}(- -) [!] No ADB device connected.${NC}"
    echo "Connect your Pixel 7 via USB to deploy models."
    exit 1
fi

case ${OPTION,,} in
    a|"all")
        echo -e "\n${BOLD}Preparing to deploy full model suite to Pixel 7...${NC}"
        AVAILABLE_STORAGE=$(adb shell "df -h /data | tail -n 1 | awk '{print \$4}'")
        echo -e "Available device storage on /data: ${GREEN}$AVAILABLE_STORAGE${NC}\n"

        TOTAL="${#CATALOG[@]}"
        COUNT=1
        for entry in "${CATALOG[@]}"; do
            IFS="|" read -r c_file c_url c_desc c_sz c_tags c_notes <<< "$entry"
            echo -e "${CYAN}[$COUNT/$TOTAL]${NC} ----------------------------------------"
            deploy_single_model "$c_file" "$c_url" "$c_desc" "$c_tags"
            COUNT=$((COUNT + 1))
        done

        echo -e "\n${GREEN}(^_^) [ok] All models in catalog have been deployed to Pixel 7!${NC}"
        echo -e "${CYAN}Next step:${NC} Run 'Switch Active Model' in the TUI to choose which model to run."
        ;;
    1|2|3|4|5|6|7|8)
        IDX=$((OPTION - 1))
        IFS="|" read -r s_file s_url s_desc s_sz s_tags s_notes <<< "${CATALOG[$IDX]}"
        deploy_single_model "$s_file" "$s_url" "$s_desc" "$s_tags"
        echo -e "\n${GREEN}(^_^) [ok] Model deployment complete.${NC}"
        echo -e "${CYAN}Next step:${NC} Run 'Switch Active Model' in the TUI to load this model into llama-server."
        ;;
    9)
        read -p "Enter full path to local .gguf file: " -r LOCAL_PATH
        if [ ! -f "$LOCAL_PATH" ]; then
            echo -e "${RED}File not found: $LOCAL_PATH${NC}"
            exit 1
        fi
        CUST_FILE=$(basename "$LOCAL_PATH")
        cp "$LOCAL_PATH" "$MODELS_DIR/$CUST_FILE"
        deploy_single_model "$CUST_FILE" "" "$CUST_FILE (Custom Local)" "[Custom Model]"
        echo -e "\n${GREEN}(^_^) [ok] Custom model deployed.${NC}"
        echo -e "${CYAN}Next step:${NC} Run 'Switch Active Model' in the TUI to load this model."
        ;;
    *)
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
        ;;
esac
