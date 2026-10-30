# p1xi3 (._.)

> **p1xi3** : Turn your Google Pixel 7 (`panther`) into a dedicated, hardened, air-gapped LLM inference coprocessor running GrapheneOS and streaming responses back over a physical USB-C cable.

---

## Architecture Overview

```
┌──────────────────────────────────────┐          USB-C Cable          ┌──────────────────────────────────────┐
│             Host Machine             │ ────────────────────────────> │       Pixel 7 / p1xi3 (GrapheneOS)   │
│                                      │                               │                                      │
│  • client.py                         │    adb forward tcp:11434      │  • Radios (Wi-Fi/BT/Cellular): OFF   │
│  • Queries http://localhost:11434    │ ────────────────────────────> │  • Termux (Network permission: OFF)  │
│  • Real-time token streaming & stats │                               │  • Native llama-server (127.0.0.1)   │
└──────────────────────────────────────┘                               └──────────────────────────────────────┘
```

### Hardware Constraints & Curated Model Catalog (Tensor G2, 8GB RAM)
- **RAM**: 8 GB LPDDR5 (~4.5–5.5 GB usable after OS overhead).
- **Curated Model Profiles**:
  - **Coding & Dev**:
    - `Qwen2.5-Coder-1.5B-Instruct` (Q4_K_M ~986 MB) — Fast code completion (~14-18 t/s)
    - `Qwen2.5-Coder-3B-Instruct` (Q4_K_M ~2.2 GB) — SOTA 3B technical assistant (~8-11 t/s)
  - **Reasoning & Math**:
    - `DeepSeek-R1-Distill-Qwen-1.5B` (Q4_K_M ~1.1 GB) — Chain-of-thought step-by-step reasoning (~12-16 t/s)
    - `Qwen2.5-1.5B-Instruct` (Q4_K_M ~986 MB) — Strong logic, math, and instruction following (~14-18 t/s)
  - **General Conversation**:
    - `Llama-3.2-1B-Instruct` (Q4_K_M ~780 MB) — Ultra fast, minimal battery draw (~18-22 t/s)
    - `Llama-3.2-3B-Instruct` (Q4_K_M ~2.0 GB) — Balanced general knowledge and speed (~8-12 t/s)
    - `SmolLM2-1.7B-Instruct` (Q4_K_M ~1.0 GB) — High efficiency conversational assistant
  - **Ultra-Compact / Instant**:
    - `SmolLM2-360M-Instruct` (Q8_0 ~380 MB) — Instant responses (>30 t/s), microscopic memory footprint

---

## System Requirements & Prerequisites

### 1. Host Requirements
- **Operating System**: Linux (Ubuntu/Debian, Arch, Fedora, openSUSE) or macOS.
- **Python**: Python 3.8+ (The host client and TUI use **pure standard library** modules—`curses`, `urllib`, `subprocess`, `json`—with **zero mandatory pip packages**).
- **Host Binaries**:
  - `adb` & `fastboot` (Android SDK platform-tools)
  - `curl` & `tar`
  - Linux: Android USB `udev` rules for non-root device access.

### 2. Device Requirements
- **Target Device**: Google Pixel 7 (`panther`) or Tensor-series Pixel device (8 GB RAM recommended).
- **Connection**: High-speed USB-C to USB-C / USB-A data cable connected directly to the host machine.

---

## Installation & Setup

### Automated Installation (Recommended)

Run the included installer to automatically detect your operating system, install missing package dependencies (`adb`, `fastboot`, `curl`, `tar`, `python3`), configure USB udev permissions, and set file permissions:

```bash
git clone https://github.com/keahiakio/p1xi3.git
cd p1xi3
chmod +x install.sh
./install.sh
```

### Manual Installation by Platform

If you prefer to configure your environment manually:

<details>
<summary><b>Debian / Ubuntu / Pop!_OS / Linux Mint</b></summary>

```bash
sudo apt-get update
sudo apt-get install -y android-tools-adb android-tools-fastboot curl tar python3 python3-curses
```
</details>

<details>
<summary><b>Arch Linux / Manjaro / CachyOS / EndeavourOS</b></summary>

```bash
sudo pacman -Syu --needed android-tools android-udev curl tar python
```
</details>

<details>
<summary><b>Fedora / RHEL / CentOS / Rocky Linux</b></summary>

```bash
sudo dnf install -y android-tools curl tar python3
```
</details>

<details>
<summary><b>macOS (Homebrew)</b></summary>

```bash
brew install --cask android-platform-tools
brew install curl python3
```
</details>

### Python Dependencies

No third-party packages are required to run the TUI, setup wizard, or chat client:
```bash
# Optional: verify your python environment meets the zero-dependency spec
pip install -r requirements.txt
```

---

## Global CLI & Quick Start

Once installed via `./install.sh` (or by running `./p1xi3 link`), `p1xi3` is **globally executable from any directory in your terminal**:

```bash
# Launch interactive TUI dashboard (default)
p1xi3

# Or execute specific subcommands directly from anywhere:
p1xi3 chat       # Start host USB streaming chat client (interactive REPL)
p1xi3 status     # Check phone connection, battery, carrier SKU & OEM lock
p1xi3 bridge     # Start the adb port forward bridge (tcp:11435 -> tcp:11434)
p1xi3 switch     # Hot-swap between installed models on the device
p1xi3 models     # Browse, download, and push curated GGUF models
p1xi3 update     # Check for model updates upstream & push to airgapped phone
p1xi3 ide        # Auto-configure detected IDEs (Zed, VS Code, JetBrains, Neovim)
p1xi3 provision  # Sideload Termux & stream native llama-server
p1xi3 harden     # Run air-gap security hardening checklist (--stock for stock Android)
p1xi3 --help     # View all global CLI options
```

### TUI Features & Controls
- **Live Hardware Telemetry**: Continuously polls ADB, Fastboot, device model, battery %, carrier SKU, OEM unlock state, radio status (Airplane/Wi-Fi/BT), and USB bridge health in the background. No need to restart or re-enter!
- **Dynamic Multi-Breakpoint Resizing**: Automatically adapts between full dual-pane layout and compact stacked layout for split terminal windows down to `40x12`.
- **Dual Operating Profiles (`Tab` or `p` to toggle)**:
  - **GrapheneOS Profile**: Complete wipe, bootloader unlocking, WebUSB/fastboot flashing, hardware verified boot.
  - **Stock Android Profile**: For devices with permanently carrier-locked bootloaders (e.g., Verizon). Hardens stock Android, disables background telemetry/radios via ADB, and provisions local LLMs without unlocking the bootloader.
- **Controls**:
  - `↑` / `↓` or `j` / `k` : Navigate actions (instant response, typematic debounce)
  - `Enter` : Execute highlighted action
  - `Tab` or `p` : Toggle between **GrapheneOS** and **Stock Android** profiles
  - `q` or `ESC` : Exit

---

## Command Reference

| Command | Direct Script | Description |
|---|---|---|
| `p1xi3` / `p1xi3 tui` | `./tui.py` | Launches the interactive, dynamically resizing TUI dashboard. |
| `p1xi3 chat` | `python3 client.py` | Host CLI interface streaming responses with tokens/sec metrics over USB. |
| `p1xi3 status` | `./scripts/01_check_device.sh` | Verifies ADB/Fastboot connectivity, battery level, carrier SKU, and OEM unlock permission. |
| `p1xi3 bridge` | `./scripts/06_start_bridge.sh` | Establishes `adb forward tcp:11435 tcp:11434` with auto-collision prevention. |
| `p1xi3 switch` | `./scripts/07_switch_model.sh` | Interactive switcher to hot-swap active models in memory on the device. |
| `p1xi3 models` | `./scripts/05_push_model.sh` | Downloads individual models or the complete ~10.5 GB suite and streams to device. |
| `p1xi3 update` | `./scripts/08_update_models.sh` | Checks upstream repository commits on host and updates air-gapped device over USB. |
| `p1xi3 ide` | `./scripts/09_link_ide.sh` | Detects host IDEs (Zed, VS Code, JetBrains, Neovim) and configures air-gapped agent. |
| `p1xi3 provision` | `./scripts/04_provision_device.sh` | Installs Termux APK, pushes compilation script for native `llama-server`. |
| `p1xi3 harden` | `./scripts/03_airgap_harden.sh` | Checks Airplane mode, disables Wi-Fi/BT, and hardens USB & permissions. |
| `p1xi3 harden --stock` | `./scripts/03_stock_harden.sh` | Disables radios, location scanning, and Google telemetry on locked stock Android. |
| `p1xi3 flash` | `./scripts/02_flash_guide.sh` | Guided walkthrough for WebUSB installer or CLI fastboot flashing. |
| `p1xi3 link` | `p1xi3 link` | Re-links `p1xi3` into `~/.local/bin` and `/usr/local/bin`. |

---

## Step-by-Step Flow

### 1. Preparation & OEM Unlock
1. On the Pixel 7, unlock the screen and connect via USB.
2. Go to **Settings > About phone** and tap **Build number** 7 times.
3. Go to **Settings > System > Developer options**:
   - Turn **USB debugging** ON.
   - Turn **OEM unlocking** ON.
4. Run:
   ```bash
   ./scripts/01_check_device.sh
   ```

### 2. Flashing GrapheneOS
1. The simplest and safest method is the official **[GrapheneOS Web Installer](https://grapheneos.org/install/web)** using Chrome/Chromium/Brave.
2. Put the phone into bootloader mode (`adb reboot bootloader` or Hold `Power + Vol Down`).
3. Click **Unlock bootloader** -> Confirm on phone.
4. Click **Download release** (panther) -> **Flash release**.
5. Click **Lock bootloader** -> Confirm on phone (essential for Verified Boot security).
6. Boot into GrapheneOS.

### 3. Air-Gap Hardening
1. Remove physical SIM card.
2. Turn ON **Airplane Mode**.
3. Turn OFF **Wi-Fi** and **Bluetooth**.
4. In GrapheneOS:
   - Go to **Settings > Security > USB-C port** and configure access behavior.
   - Revoke the **Network permission** for Termux to ensure no packets leave the app.

### 4. Setting up the LLM Server (Termux)
1. Run `./scripts/04_provision_device.sh` to install Termux and stage `init_pixel_llm.sh`.
2. Inside Termux on the phone:
   ```bash
   bash /sdcard/Download/init_pixel_llm.sh
   ```
3. Push your model using `./scripts/05_push_model.sh`.
4. Start the server inside Termux:
   ```bash
   cd ~/llama.cpp
   ./build/bin/llama-server -m /sdcard/Download/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf --host 127.0.0.1 --port 11434 -c 2048 -t 4
   ```

### 5. Communicating via USB
1. On your host machine:
   ```bash
   ./scripts/06_start_bridge.sh
   python3 client.py
   ```
2. Any request to `http://localhost:11435` passes over ADB USB to the phone's native server without touching any wireless or external network.

### 6. Linking IDEs & AI Coding Agents

`p1xi3` can directly power your IDE's AI assistant, inline code completion, and autonomous coding agents while maintaining total air-gap security:

```bash
# In the TUI choose "Link IDEs & Coding Agents", or run:
p1xi3 ide
```

This automatically detects and configures:
- **Zed Editor**: Injects `p1xi3` into `settings.json` for Assistant Panel chat (`Ctrl+?`) and Inline Assist (`Ctrl+Enter`).
- **VS Code / Cursor / Windsurf / JetBrains**: Automatically configures the **Continue.dev** extension (`~/.continue/config.json`) with primary chat and tab-autocomplete models.
- **Neovim**: Generates `p1xi3.lua` adapter modules for `avante.nvim` and `codecompanion.nvim`.
- **Shell & CLI Agents**: Exports `OPENAI_API_BASE=http://127.0.0.1:11435/v1` for instant compatibility with `aider`, LangChain tools, and terminal assistants.

---

## Credits & Acknowledgments

`p1xi3` stands on the shoulders of giants. This project is made possible thanks to the groundbreaking work of the open-source software, security, and machine learning communities:

### Core Infrastructure & Runtimes
- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** (`Georgi Gerganov & ggml-org`): High-performance C/C++ LLM inference engine and official Android ARM64 builds (16KB page-aligned) powering fast, low-memory edge inference on the Pixel 7's Tensor G2.
- **[GrapheneOS](https://grapheneos.org)** (`The GrapheneOS Project`): The hardened, security-focused mobile operating system providing hardware verified boot, sandboxing, and granular runtime network permission controls that make genuine hardware air-gapping possible.
- **[Termux](https://github.com/termux/termux-app)** (`Fredrik Fornwall & Termux contributors`): Advanced terminal emulator and POSIX environment on Android that allows running native binary daemons without requiring device rooting.
- **[Android Open Source Project (AOSP)](https://source.android.com)**: Platform tools (`adb` & `fastboot`) that establish zero-network physical USB forwarding channels (`adb forward`).

### Model Research & Open Weights
- **[Qwen Team / Alibaba Cloud](https://github.com/QwenLM/Qwen2.5)**: For developing the exceptional `Qwen2.5-Coder` and `Qwen2.5` model families under the Apache 2.0 license.
- **[DeepSeek AI](https://github.com/deepseek-ai)**: For pioneering chain-of-thought reasoning models and open-weight distillation with `DeepSeek-R1` under the MIT license.
- **[Meta AI](https://llama.meta.com/)**: For the highly efficient, low-latency `Llama-3.2-1B` and `Llama-3.2-3B` lightweight edge architectures.
- **[Hugging Face TB](https://huggingface.co/HuggingFaceTB)**: For the compact, ultra-fast `SmolLM2` conversational models and datasets.
- **Quantization & Distribution Contributors**:
  - **[bartowski](https://huggingface.co/bartowski)** for high-precision GGUF quantizations.
  - **[Unsloth AI](https://github.com/unslothai/unsloth)** for quantized DeepSeek-R1 GGUF releases.
  - **[Hugging Face Hub](https://huggingface.co)** for open model hosting infrastructure.

---

## License & Compliance

- **Project License**: Licensed under the [MIT License](LICENSE).
- **Compliance & Attribution**: Full licensing terms for upstream components (`llama.cpp`, `Termux`, `GrapheneOS`) and model weights (`Llama 3.2`, `Qwen 2.5`, `DeepSeek`, `SmolLM2`) are detailed in [COMPLIANCE.md](COMPLIANCE.md).

