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

### Hardware Constraints (Tensor G2)
- **RAM**: 8 GB LPDDR5 (~4.5–5.5 GB usable after OS overhead).
- **Recommended Model Profiles**:
  - `Llama-3.2-1B-Instruct` (Q4_K_M ~780 MB) — ~15-22 tokens/sec
  - `Llama-3.2-3B-Instruct` (Q4_K_M ~2.0 GB) — ~8-12 tokens/sec
  - `Qwen2.5-1.5B-Instruct` (Q4_K_M ~986 MB) — ~14-18 tokens/sec
  - `Qwen2.5-3B-Instruct` (Q4_K_M ~2.17 GB) — ~7-11 tokens/sec

---

## Quick Start

Launch the interactive wizard:
```bash
cd /home/keahiakio/p1xi3
python3 wizard.py
```

Or execute individual steps directly:

| Step | Script | Description |
|---|---|---|
| **1. Check Device** | `./scripts/01_check_device.sh` | Verifies ADB/Fastboot connectivity, battery level, and OEM unlock permission. |
| **2. Flash GrapheneOS** | `./scripts/02_flash_guide.sh` | Guided walkthrough for WebUSB installer or CLI fastboot flashing. |
| **3. Air-Gap Hardening** | `./scripts/03_airgap_harden.sh` | Checks Airplane mode, disables Wi-Fi/BT, and hardens USB & permissions. |
| **4. Provision Device** | `./scripts/04_provision_device.sh` | Installs Termux APK, pushes compilation script for native `llama-server`. |
| **5. Push Model** | `./scripts/05_push_model.sh` | Downloads 1B/3B GGUF models and transfers them to the device via USB. |
| **6. USB Bridge** | `./scripts/06_start_bridge.sh` | Establishes `adb forward tcp:11434 tcp:11434` and tests connection. |
| **7. Chat Client** | `python3 client.py` | Host CLI interface streaming responses with tokens/sec metrics. |

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
