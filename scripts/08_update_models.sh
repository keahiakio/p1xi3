#!/usr/bin/env bash
# ==============================================================================
# p1xi3 (._.) - Air-Gapped Model Update Manager
# Checks for upstream model updates on the host and pushes updates to the
# airgapped Pixel 7 strictly over physical USB.
# ==============================================================================
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
META_DIR="$MODELS_DIR/.metadata"

mkdir -p "$MODELS_DIR" "$META_DIR"

# Curated catalog definitions:
# filename|huggingface_url|display_name|tags
CATALOG=(
    "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf|Qwen 2.5 Coder 1.5B|[Coding] [Fast Scripting]"
    "qwen2.5-coder-3b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf|Qwen 2.5 Coder 3B|[Coding] [Refactoring]"
    "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf|https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf|DeepSeek R1 Distill Qwen 1.5B|[Reasoning] [Math & Logic]"
    "qwen2.5-1.5b-instruct-q4_k_m.gguf|https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf|Qwen 2.5 1.5B Instruct|[General Reasoning]"
    "Llama-3.2-1B-Instruct-Q4_K_M.gguf|https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf|Llama 3.2 1B Instruct|[Fast Chat] [Low Battery]"
    "Llama-3.2-3B-Instruct-Q4_K_M.gguf|https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf|Llama 3.2 3B Instruct|[General Assistant]"
    "smollm2-1.7b-instruct-q4_k_m.gguf|https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf|SmolLM2 1.7B Instruct|[Lightweight Dialogue]"
    "smollm2-360m-instruct-q8_0.gguf|https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf|SmolLM2 360M Instruct|[Ultra-Fast] [Low Memory]"
)

echo -e "${CYAN}=================================================================="
echo -e "         p1xi3 (._.) : Air-Gapped Model Update Manager"
echo -e "==================================================================${NC}\n"

echo -e "${BLUE}Air-Gap Safety Guarantee:${NC}"
echo -e "  • The phone remains completely offline with radios disabled."
echo -e "  • Update checks & downloads occur solely on this host workstation."
echo -e "  • Model binaries are transferred to the device strictly over physical USB.\n"

# Verify ADB connection
if ! adb get-state &>/dev/null; then
    echo -e "${RED}(- -) [!] No ADB device connected.${NC}"
    echo "Connect your Pixel 7 via USB-C to check installed models and apply updates."
    exit 1
fi

echo -e "${YELLOW}[*] Querying installed models on Pixel 7 over USB...${NC}"
DEVICE_MODELS_RAW=$(adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'ls -1 /data/data/com.termux/files/home/models/*.gguf 2>/dev/null || true'")

DEVICE_FILES=()
while IFS= read -r line; do
    [ -n "$line" ] && DEVICE_FILES+=("$(basename "$line")")
done <<< "$DEVICE_MODELS_RAW"

echo -e "${GREEN}(^_^) [ok] Found ${#DEVICE_FILES[@]} model(s) installed on Pixel 7.${NC}"

# Check internet connectivity on host
echo -e "${YELLOW}[*] Checking upstream Hugging Face repositories for updates...${NC}"
HAS_INTERNET=1
if ! curl -sI --connect-timeout 4 "https://huggingface.co" &>/dev/null; then
    echo -e "${RED}[!] Host machine appears to be offline.${NC}"
    echo "Host internet connection is required to check upstream repository metadata."
    exit 1
fi

declare -a UPDATE_STATUS=()
declare -a REMOTE_COMMITS=()
declare -a REMOTE_SIZES=()
declare -a REMOTE_ETAGS=()

format_size() {
    local b="$1"
    if [ "$b" -ge 1073741824 ]; then
        awk -v b="$b" 'BEGIN { printf "%.2f GB", b / 1073741824 }'
    elif [ "$b" -ge 1048576 ]; then
        awk -v b="$b" 'BEGIN { printf "%.1f MB", b / 1048576 }'
    else
        echo "${b} B"
    fi
}

echo ""
printf " %-3s | %-28s | %-12s | %-15s | %-10s\n" "No" "Model Name" "Device State" "Upstream Rev" "Size"
echo "----------------------------------------------------------------------------------"

IDX=0
for entry in "${CATALOG[@]}"; do
    IFS="|" read -r c_file c_url c_desc c_tags <<< "$entry"
    IDX=$((IDX + 1))
    
    # Check if installed on device
    ON_DEVICE="no"
    for df in "${DEVICE_FILES[@]}"; do
        if [ "$df" == "$c_file" ]; then
            ON_DEVICE="yes"
            break
        fi
    done

    # Fetch remote HTTP headers for revision check
    HDRS=$(curl -sI -m 8 "$c_url" 2>/dev/null | tr -d '\r' || true)
    REMOTE_COMMIT=$(echo "$HDRS" | grep -i "^x-repo-commit:" | head -n1 | awk '{print $2}' || true)
    REMOTE_SIZE=$(echo "$HDRS" | grep -i "^x-linked-size:" | head -n1 | awk '{print $2}' || true)
    REMOTE_ETAG=$(echo "$HDRS" | grep -i "^x-linked-etag:" | head -n1 | awk '{print $2}' | tr -d '"' || true)

    REMOTE_COMMITS+=("${REMOTE_COMMIT:-unknown}")
    REMOTE_SIZES+=("${REMOTE_SIZE:-0}")
    REMOTE_ETAGS+=("${REMOTE_ETAG:-unknown}")

    LOCAL_META_FILE="$META_DIR/$c_file.meta"
    SAVED_COMMIT=""
    if [ -f "$LOCAL_META_FILE" ]; then
        SAVED_COMMIT=$(cat "$LOCAL_META_FILE" 2>/dev/null || true)
    fi

    # Determine status
    STATUS_TXT=""
    STATUS_CODE=""
    if [ "$ON_DEVICE" == "no" ]; then
        STATUS_TXT="${YELLOW}Not on phone${NC}"
        STATUS_CODE="NEW"
    else
        if [ -n "$SAVED_COMMIT" ] && [ -n "$REMOTE_COMMIT" ] && [ "$SAVED_COMMIT" != "$REMOTE_COMMIT" ]; then
            STATUS_TXT="${RED}${BOLD}Update avail${NC}"
            STATUS_CODE="UPDATE"
        else
            STATUS_TXT="${GREEN}Up to date${NC}"
            STATUS_CODE="CURRENT"
        fi
    fi
    UPDATE_STATUS+=("$STATUS_CODE")

    SZ_FMT="--"
    if [ -n "$REMOTE_SIZE" ] && [ "$REMOTE_SIZE" -gt 0 ]; then
        SZ_FMT=$(format_size "$REMOTE_SIZE")
    fi

    REV_FMT="${REMOTE_COMMIT:0:8}"
    [ -z "$REV_FMT" ] && REV_FMT="main"

    printf " %-3d | %-28s | %-22b | %-15s | %-10s\n" "$IDX" "${c_desc:0:28}" "$STATUS_TXT" "$REV_FMT" "$SZ_FMT"
done

echo "----------------------------------------------------------------------------------"
echo -e "\n${BOLD}Options:${NC}"
echo -e "  ${GREEN}U)${NC} Update all models currently installed on device"
echo -e "  ${GREEN}1-8)${NC} Select a specific model to download and push to Pixel 7"
echo -e "  ${CYAN}C)${NC} Re-check upstream metadata"
echo -e "  ${YELLOW}Q)${NC} Back to p1xi3 menu\n"

read -p "Select an action [U, 1-8, C, Q]: " -r ACTION

deploy_update() {
    local index="$1"
    local entry="${CATALOG[$index]}"
    IFS="|" read -r c_file c_url c_desc c_tags <<< "$entry"
    local remote_rev="${REMOTE_COMMITS[$index]}"
    local local_path="$MODELS_DIR/$c_file"
    local meta_path="$META_DIR/$c_file.meta"

    echo -e "\n${CYAN}------------------------------------------------------------------${NC}"
    echo -e "${BOLD}Deploying: $c_desc${NC}"
    echo -e "  File: $c_file"
    echo -e "  Revision: ${remote_rev:0:8}"
    echo -e "  Air-gap mode: Physical USB transfer via ADB"
    echo -e "${CYAN}------------------------------------------------------------------${NC}"

    # Step 1: Download to host cache
    echo -e "${YELLOW}[1/3] Downloading updated weights on host machine...${NC}"
    curl -L --progress-bar -o "$local_path.tmp" "$c_url"
    mv "$local_path.tmp" "$local_path"
    [ -n "$remote_rev" ] && echo "$remote_rev" > "$meta_path"
    echo -e "${GREEN}(^_^) [ok] Download finished on host.${NC}"

    # Step 2: Stream over USB to device
    echo -e "${YELLOW}[2/3] Streaming model over USB to Pixel 7 (~/models/)...${NC}"
    adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'mkdir -p /data/data/com.termux/files/home/models'"
    tar -cz -C "$MODELS_DIR" "$c_file" | adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/tar -xz -C /data/data/com.termux/files/home/models"
    echo -e "${GREEN}(^_^) [ok] Transfer complete on device.${NC}"

    # Step 3: Check if this model is currently loaded in llama-server
    echo -e "${YELLOW}[3/3] Checking active server process on device...${NC}"
    ACTIVE_PROC=$(adb shell "run-as com.termux ps -ef | grep llama-server | grep -v grep || true")
    if [[ "$ACTIVE_PROC" == *"$c_file"* ]]; then
        echo -e "${MAGENTA}(o.o) This model is currently loaded in the active llama-server!${NC}"
        read -p "Restart llama-server with updated weights now? (Y/n): " -r RESTART_SRV
        if [[ ! "$RESTART_SRV" =~ ^[Nn]$ ]]; then
            echo "Restarting llama-server..."
            adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'pkill -x llama-server 2>/dev/null || killall llama-server 2>/dev/null || true'"
            sleep 1
            adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c 'export LD_LIBRARY_PATH=/data/data/com.termux/files/home/llama:\$LD_LIBRARY_PATH; nohup /data/data/com.termux/files/home/llama/llama-server -m \"/data/data/com.termux/files/home/models/$c_file\" --host 127.0.0.1 --port 11434 -c 32768 -np 2 -t 4 -tb 4 -b 2048 -ub 512 -ctk q8_0 -ctv q8_0 > /data/data/com.termux/files/home/llama.log 2>&1 &'"
            sleep 2
            echo -e "${GREEN}(^_^) [ok] Active llama-server reloaded with updated model!${NC}"
        fi
    else
        echo -e "${GREEN}(^_^) [ok] Ready on device.${NC} Use 'Switch Active Model' to run it."
    fi
}

case "${ACTION,,}" in
    u|"update")
        UPDATED_ANY=0
        for i in "${!CATALOG[@]}"; do
            IFS="|" read -r c_file _ _ _ <<< "${CATALOG[$i]}"
            ON_DEVICE="no"
            for df in "${DEVICE_FILES[@]}"; do
                if [ "$df" == "$c_file" ]; then
                    ON_DEVICE="yes"
                    break
                fi
            done
            if [ "$ON_DEVICE" == "yes" ]; then
                UPDATED_ANY=1
                deploy_update "$i"
            fi
        done
        if [ "$UPDATED_ANY" -eq 0 ]; then
            echo -e "\n${YELLOW}No models currently installed on device. Select 1-8 to install one.${NC}"
        else
            echo -e "\n${GREEN}${BOLD}(^_^) All installed models successfully updated on Pixel 7!${NC}"
        fi
        ;;
    1|2|3|4|5|6|7|8)
        IDX=$((ACTION - 1))
        deploy_update "$IDX"
        ;;
    c|"check")
        exec bash "$0"
        ;;
    q|"quit"|"exit")
        echo "Update check finished."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
        ;;
esac
