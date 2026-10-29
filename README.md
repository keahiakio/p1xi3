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

## Quick Start

Launch the interactive Rust-style TUI:
```bash
cd /home/keahiakio/p1xi3
python3 wizard.py
```
*(Or run `python3 tui.py` directly. For headless/dumb terminal environments, pass `python3 wizard.py --cli`).*

### TUI Features & Controls
- **Live Hardware Telemetry**: Continuously polls ADB, Fastboot, device model, battery %, carrier SKU, OEM unlock state, radio status (Airplane/Wi-Fi/BT), and USB bridge health in the background. No need to restart or re-enter!
- **Dual Operating Profiles (`Tab` to toggle)**:
  - **GrapheneOS Profile**: Complete wipe, bootloader unlocking, WebUSB/fastboot flashing, hardware verified boot.
  - **Stock Android Profile**: For devices with permanently carrier-locked bootloaders (e.g., Verizon). Hardens stock Android, disables background telemetry/radios via ADB, and provisions local LLMs without unlocking the bootloader.
- **Controls**:
  - `↑` / `↓` or `j` / `k` : Navigate actions
  - `Enter` : Execute highlighted action
  - `Tab` or `m` : Toggle between **GrapheneOS** and **Stock Android** profiles
  - `q` : Exit

---

## Script Index

| Step | Script | Description |
|---|---|---|
| **1. Check Device** | `./scripts/01_check_device.sh` | Verifies ADB/Fastboot connectivity, battery level, carrier SKU, and OEM unlock permission. |
| **2. Flash GrapheneOS** | `./scripts/02_flash_guide.sh` | Guided walkthrough for WebUSB installer or CLI fastboot flashing. |
| **3. Graphene Air-Gap** | `./scripts/03_airgap_harden.sh` | Checks Airplane mode, disables Wi-Fi/BT, and hardens USB & permissions. |
| **3. Stock Hardening** | `./scripts/03_stock_harden.sh` | Disables radios, location scanning, and Google telemetry on locked stock Android. |
| **4. Provision Device** | `./scripts/04_provision_device.sh` | Installs Termux APK, pushes compilation script for native `llama-server`. |
| **5. Push Model** | `./scripts/05_push_model.sh` | Downloads individual models or the complete ~10.5 GB suite (Option 'A') and streams to device. |
| **6. Switch Model** | `./scripts/07_switch_model.sh` | Interactive switcher to hot-swap active models in memory on the device. |
| **7. USB Bridge** | `./scripts/06_start_bridge.sh` | Establishes `adb forward tcp:11435 tcp:11434` with auto-collision prevention. |
| **8. Chat Client** | `python3 client.py` | Host CLI interface streaming responses with tokens/sec metrics. |

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
2. Any request to `http://localhost:11434` passes over ADB USB to the phone's native server without touching any wireless or external network.
