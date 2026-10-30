#!/usr/bin/env bash
# ==============================================================================
# p1xi3 Host Dependency & Setup Installer
# Sets up host prerequisites (adb, fastboot, curl, tar, python3, udev rules)
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}=================================================================="
echo -e "       p1xi3 (._.) : Host Environment & Dependency Installer"
echo -e "==================================================================${NC}\n"

# Helper functions
has_cmd() {
    command -v "$1" &>/dev/null
}

can_sudo() {
    [ "$(id -u)" -eq 0 ] && return 0
    if has_cmd sudo; then
        if sudo -n true 2>/dev/null; then
            return 0
        fi
        # If terminal is interactive, user can enter password
        if [ -t 0 ]; then
            return 0
        fi
    fi
    return 1
}

# Determine privilege elevator
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if has_cmd sudo; then
        SUDO="sudo"
    elif has_cmd doas; then
        SUDO="doas"
    fi
fi

# Detect OS
OS_TYPE="$(uname -s)"
echo -e "${BLUE}[*] Detecting operating system ($OS_TYPE)...${NC}"

MISSING_TOOLS=()

for tool in python3 curl tar; do
    if ! has_cmd "$tool"; then
        MISSING_TOOLS+=("$tool")
    fi
done

if ! has_cmd adb || ! has_cmd fastboot; then
    MISSING_TOOLS+=("android-tools (adb/fastboot)")
fi

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${GREEN}(^_^) [ok] Core binary tools already installed: python3, curl, tar, adb, fastboot.${NC}"
else
    echo -e "${YELLOW}[!] Missing required host components: ${MISSING_TOOLS[*]}${NC}"
    echo -e "Attempting package installation...\n"

    case "$OS_TYPE" in
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID:-linux}"
                DISTRO_LIKE="${ID_LIKE:-}"
            else
                DISTRO="unknown"
                DISTRO_LIKE=""
            fi

            if [[ "$DISTRO" =~ ^(debian|ubuntu|linuxmint|pop)$ ]] || [[ "$DISTRO_LIKE" =~ (debian|ubuntu) ]]; then
                echo -e "${BLUE}[*] Debian/Ubuntu based system detected.${NC}"
                $SUDO apt-get update -y
                $SUDO apt-get install -y android-tools-adb android-tools-fastboot curl tar python3 python3-curses || \
                $SUDO apt-get install -y adb fastboot curl tar python3
            elif [[ "$DISTRO" =~ ^(arch|cachyos|manjaro|endeavouros)$ ]] || [[ "$DISTRO_LIKE" =~ arch ]]; then
                echo -e "${BLUE}[*] Arch-based system detected.${NC}"
                $SUDO pacman -Sy --noconfirm --needed android-tools android-udev curl tar python
            elif [[ "$DISTRO" =~ ^(fedora|rhel|centos|rocky|alma)$ ]] || [[ "$DISTRO_LIKE" =~ (fedora|rhel) ]]; then
                echo -e "${BLUE}[*] Fedora/RHEL based system detected.${NC}"
                $SUDO dnf install -y android-tools curl tar python3
            elif [[ "$DISTRO" =~ ^(opensuse|suse)$ ]] || [[ "$DISTRO_LIKE" =~ (opensuse|suse) ]]; then
                echo -e "${BLUE}[*] openSUSE detected.${NC}"
                $SUDO zypper install -y android-tools curl tar python3
            elif [[ "$DISTRO" =~ ^alpine$ ]]; then
                echo -e "${BLUE}[*] Alpine Linux detected.${NC}"
                $SUDO apk add android-tools curl tar python3
            else
                echo -e "${RED}[!] Unrecognized Linux distribution ($DISTRO).${NC}"
                echo "Please manually install: adb, fastboot, curl, tar, python3."
            fi
            ;;

        Darwin)
            echo -e "${BLUE}[*] macOS detected.${NC}"
            if has_cmd brew; then
                brew install --cask android-platform-tools
                brew install curl python3
            else
                echo -e "${RED}[!] Homebrew not found.${NC}"
                echo "Install Homebrew from https://brew.sh or manually install Android platform-tools."
            fi
            ;;

        *)
            echo -e "${RED}[!] Unsupported operating system: $OS_TYPE.${NC}"
            echo "Please manually install adb, fastboot, curl, tar, and python3."
            ;;
    esac
fi

# Ensure Linux udev rules for Google Pixel / Android USB access
if [ "$OS_TYPE" = "Linux" ]; then
    echo -e "\n${BLUE}[*] Checking Android USB permissions...${NC}"
    UDEV_RULE_FILE="/etc/udev/rules.d/51-android.rules"
    SYSTEM_RULES="/usr/lib/udev/rules.d/51-android.rules"
    ARCH_UDEV="/usr/lib/udev/rules.d/70-android.rules"

    # Test if adb has permission issues
    HAS_PERMISSION_ISSUE=0
    if adb devices 2>&1 | grep -q "no permissions"; then
        HAS_PERMISSION_ISSUE=1
    fi

    if [ -f "$UDEV_RULE_FILE" ] || [ -f "$SYSTEM_RULES" ] || [ -f "$ARCH_UDEV" ] || [ -f "/lib/udev/rules.d/51-android-udev.rules" ]; then
        echo -e "${GREEN}(^_^) [ok] Android udev rules already present.${NC}"
    elif [ "$HAS_PERMISSION_ISSUE" -eq 1 ]; then
        echo -e "${YELLOW}[!] Permission issue detected with ADB.${NC}"
        if can_sudo && [ -n "$SUDO" ]; then
            echo "Creating Google Pixel udev rule at $UDEV_RULE_FILE..."
            $SUDO bash -c "cat > '$UDEV_RULE_FILE'" << 'EOF'
# Google Pixel / Android USB rules for p1xi3
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", TAG+="uaccess"
EOF
            $SUDO udevadm control --reload-rules 2>/dev/null || true
            $SUDO udevadm trigger 2>/dev/null || true
            echo -e "${GREEN}(^_^) [ok] USB udev rules installed and reloaded.${NC}"
        else
            echo -e "${YELLOW}Note: If ADB shows 'no permissions', add a udev rule for Google Pixel (vendor 18d1):${NC}"
            echo "  echo 'SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0666\", TAG+=\"uaccess\"' | sudo tee /etc/udev/rules.d/51-android.rules"
            echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
        fi
    else
        echo -e "${GREEN}(^_^) [ok] Device access permissions verified.${NC}"
    fi
fi

# Ensure project directories exist
echo -e "\n${BLUE}[*] Verifying workspace directories...${NC}"
mkdir -p "$SCRIPT_DIR/bin" "$SCRIPT_DIR/models"
echo -e "${GREEN}(^_^) [ok] Directories ready: bin/, models/${NC}"

# Ensure permissions on scripts and binaries
echo -e "${BLUE}[*] Ensuring script execution permissions...${NC}"
chmod +x "$SCRIPT_DIR/p1xi3" "$SCRIPT_DIR/wizard.py" "$SCRIPT_DIR/tui.py" "$SCRIPT_DIR/client.py" "$SCRIPT_DIR/install.sh"
chmod +x "$SCRIPT_DIR/scripts"/*.sh 2>/dev/null || true
echo -e "${GREEN}(^_^) [ok] Executable permissions set.${NC}"

# Configure Global Command Link
echo -e "\n${BLUE}[*] Setting up global 'p1xi3' executable command...${NC}"
USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
ln -sf "$SCRIPT_DIR/p1xi3" "$USER_BIN/p1xi3"
echo -e "${GREEN}(^_^) [ok] Created symlink:${NC} $USER_BIN/p1xi3"

if [ -w "/usr/local/bin" ]; then
    ln -sf "$SCRIPT_DIR/p1xi3" "/usr/local/bin/p1xi3" 2>/dev/null || true
fi

case ":$PATH:" in
    *":$USER_BIN:"*)
        echo -e "${GREEN}[ok] Global execution verified: Type 'p1xi3' anywhere!${NC}"
        ;;
    *)
        echo -e "${YELLOW}Note: Add $USER_BIN to your PATH to run 'p1xi3' anywhere:${NC}"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

# Python Environment & Curses Validation
echo -e "\n${BLUE}[*] Verifying Python runtime & curses support...${NC}"
if python3 -c "import sys, curses, urllib.request, json; sys.exit(0)" 2>/dev/null; then
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
    echo -e "${GREEN}(^_^) [ok] Python $PY_VER detected with full curses and standard library support.${NC}"
else
    echo -e "${RED}[!] Python curses or stdlib verification failed.${NC}"
    echo "On Debian/Ubuntu: sudo apt-get install python3-curses"
    exit 1
fi

# Host Tools Summary
echo -e "\n${CYAN}=================================================================="
echo -e "                   Verification Summary"
echo -e "==================================================================${NC}"
echo -e "  • Python:   $(python3 --version 2>&1)"
echo -e "  • ADB:      $(adb version 2>/dev/null | head -n 1 || echo 'Not found')"
echo -e "  • Fastboot: $(fastboot --version 2>&1 | head -n 1 || echo 'Present')"
echo -e "  • Curl:     $(curl --version 2>&1 | head -n 1 | awk '{print $1, $2}')"
echo -e "  • Tar:      $(tar --version 2>&1 | head -n 1 | awk '{print $1, $4}')"

# Device Connectivity Check
echo -e "\n${BLUE}[*] Checking connected devices via ADB...${NC}"
if adb devices | grep -v "List of devices" | grep -q "device$"; then
    DEV_SERIAL=$(adb devices | grep -v "List of devices" | grep "device$" | head -n 1 | awk '{print $1}')
    DEV_MODEL=$(adb -s "$DEV_SERIAL" shell getprop ro.product.model 2>/dev/null || echo "Android Device")
    echo -e "${GREEN}(^_^) [ok] Found connected & authorized device: $DEV_MODEL ($DEV_SERIAL)${NC}"
else
    echo -e "${YELLOW}(._.) No authorized device currently detected over USB.${NC}"
    echo "      Connect your Pixel via USB-C, enable USB debugging, and tap 'Always allow'."
fi

echo -e "\n${GREEN}${BOLD}Setup complete!${NC}"
echo -e "You can now run p1xi3 globally from any directory:"
echo -e "  ${CYAN}p1xi3${NC}          (Interactive TUI dashboard)"
echo -e "  ${CYAN}p1xi3 chat${NC}     (Host USB chat client)"
echo -e "  ${CYAN}p1xi3 status${NC}   (Device & telemetry check)"
echo -e "  ${CYAN}p1xi3 --help${NC}   (View all global CLI options)\n"
