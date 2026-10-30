#!/usr/bin/env python3
"""
p1xi3 (._.) - Responsive Rust-style TUI for Pixel 7 Air-Gapped USB LLM Toolkit
Features dynamic multi-breakpoint responsive resizing, instant key input response,
key debouncing, live background hardware polling, and dual GrapheneOS / Stock Android modes.
"""

import os
import sys

# Crucial: Reduce ESC resolution delay from 1000ms down to 25ms
# This prevents arrow keys and escape sequences from lagging or being misparsed.
os.environ.setdefault("ESCDELAY", "25")

import curses
import json
import time
import threading
import subprocess
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.join(SCRIPT_DIR, "scripts")

# State shared between background monitor and curses UI
state = {
    "lock": threading.Lock(),
    "adb_status": "Checking...",     # Disconnected, Unauthorized, Online, Fastboot
    "device_model": "None",
    "device_name": "None",
    "carrier": "Unknown",
    "sku": "Unknown",
    "battery": "--",
    "oem_unlock": "Unknown",
    "airplane": "--",
    "wifi": "--",
    "bluetooth": "--",
    "bridge_active": False,
    "host_port": 11435,
    "llm_online": False,
    "active_model": "None",
    "last_check": "",
    "fastboot_active": False,
    "target_os": "GrapheneOS"       # "GrapheneOS" or "Stock Android"
}

stop_monitor = threading.Event()

def monitor_thread_func():
    """Background polling thread that updates device hardware state continuously."""
    while not stop_monitor.is_set():
        adb_st = "Disconnected"
        dev_model = "None"
        dev_name = "None"
        carrier = "None"
        sku = "None"
        battery = "--"
        oem_unl = "Unknown"
        airp = "--"
        wf = "--"
        bt = "--"
        fastboot_on = False

        # 1. Check fastboot
        try:
            fb_out = subprocess.check_output(
                ["fastboot", "devices"], stderr=subprocess.DEVNULL, timeout=1
            ).decode("utf-8").strip()
            if fb_out:
                fastboot_on = True
                adb_st = "Fastboot Mode"
        except Exception:
            pass

        # 2. Check adb
        if not fastboot_on:
            try:
                adb_out = subprocess.check_output(
                    ["adb", "devices"], stderr=subprocess.DEVNULL, timeout=1.5
                ).decode("utf-8").strip()
                lines = [l for l in adb_out.splitlines() if l and not l.startswith("List of")]
                if lines:
                    line = lines[0]
                    parts = line.split()
                    if len(parts) >= 2:
                        raw_st = parts[1]
                        if raw_st == "device":
                            adb_st = "Online"
                        elif raw_st == "unauthorized":
                            adb_st = "Unauthorized"
                        elif raw_st == "offline":
                            adb_st = "Offline"
                        else:
                            adb_st = raw_st
            except Exception:
                adb_st = "ADB Offline"

        # 3. If online, query hardware & radio props
        if adb_st == "Online":
            try:
                cmd = (
                    "echo MODEL:$(getprop ro.product.model);"
                    "echo NAME:$(getprop ro.product.name);"
                    "echo CARRIER:$(getprop ro.carrier);"
                    "echo SKU:$(getprop ro.boot.hardware.sku);"
                    "echo OEM:$(getprop sys.oem_unlock_allowed);"
                    "echo AIR:$(settings get global airplane_mode_on);"
                    "echo WIFI:$(settings get global wifi_on);"
                    "echo BT:$(settings get global bluetooth_on);"
                    "echo BATT:$(dumpsys battery | grep level | awk '{print $2}');"
                )
                output = subprocess.check_output(
                    ["adb", "shell", cmd], stderr=subprocess.DEVNULL, timeout=2
                ).decode("utf-8")
                for line in output.splitlines():
                    if line.startswith("MODEL:"):
                        dev_model = line.split(":", 1)[1].strip() or "Pixel 7"
                    elif line.startswith("NAME:"):
                        dev_name = line.split(":", 1)[1].strip() or "panther"
                    elif line.startswith("CARRIER:"):
                        carrier = line.split(":", 1)[1].strip() or "unlocked"
                    elif line.startswith("SKU:"):
                        sku = line.split(":", 1)[1].strip() or "unknown"
                    elif line.startswith("OEM:"):
                        raw_oem = line.split(":", 1)[1].strip()
                        oem_unl = "Allowed" if raw_oem == "1" else ("Locked" if raw_oem == "0" else "Unknown")
                    elif line.startswith("AIR:"):
                        raw_air = line.split(":", 1)[1].strip()
                        airp = "ON" if raw_air == "1" else "OFF"
                    elif line.startswith("WIFI:"):
                        raw_wf = line.split(":", 1)[1].strip()
                        wf = "ON" if raw_wf == "1" else "OFF"
                    elif line.startswith("BT:"):
                        raw_bt = line.split(":", 1)[1].strip()
                        bt = "ON" if raw_bt == "1" else "OFF"
                    elif line.startswith("BATT:"):
                        battery = line.split(":", 1)[1].strip() or "--"
            except Exception:
                pass

        # 4. Check bridge & determine host port
        br_active = False
        active_host_port = 11435
        try:
            fwd_list = subprocess.check_output(
                ["adb", "forward", "--list"], stderr=subprocess.DEVNULL, timeout=1
            ).decode("utf-8")
            for line in fwd_list.splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[2] == "tcp:11434":
                    br_active = True
                    host_part = parts[1]
                    if host_part.startswith("tcp:"):
                        active_host_port = int(host_part[4:])
        except Exception:
            pass

        # 5. Check LLM Server & Active Model on discovered port
        llm_on = False
        active_mdl = "None"
        if br_active:
            try:
                req = urllib.request.Request(
                    f"http://127.0.0.1:{active_host_port}/v1/models", method="GET"
                )
                with urllib.request.urlopen(req, timeout=0.6) as resp:
                    raw_data = resp.read().decode("utf-8")
                    if "llamacpp" in raw_data or "models" in raw_data:
                        llm_on = True
                        parsed = json.loads(raw_data)
                        if "data" in parsed and len(parsed["data"]) > 0:
                            raw_id = parsed["data"][0].get("id", "")
                            active_mdl = os.path.basename(raw_id).replace(".gguf", "")
            except Exception:
                pass

        # Commit to shared state
        with state["lock"]:
            state["adb_status"] = adb_st
            state["fastboot_active"] = fastboot_on
            state["device_model"] = dev_model
            state["device_name"] = dev_name
            state["carrier"] = carrier
            state["sku"] = sku
            state["battery"] = battery
            state["oem_unlock"] = oem_unl
            state["airplane"] = airp
            state["wifi"] = wf
            state["bluetooth"] = bt
            state["bridge_active"] = br_active
            state["host_port"] = active_host_port
            state["llm_online"] = llm_on
            state["active_model"] = active_mdl
            state["last_check"] = time.strftime("%H:%M:%S")

        # Sleep with early exit check
        for _ in range(15):
            if stop_monitor.is_set():
                break
            time.sleep(0.1)

def safe_addstr(win, y, x, text, attr=0):
    """Safely writes a string clipped to window boundaries, preventing curses.error crashes."""
    try:
        max_y, max_x = win.getmaxyx()
        if y < 0 or y >= max_y or x < 0 or x >= max_x:
            return
        available = max_x - x
        if available <= 0:
            return
        if len(text) >= available:
            # Leave the rightmost column blank to prevent cursor wrapping exceptions
            text = text[:available - 1]
        win.addstr(y, x, text, attr)
    except curses.error:
        pass

def draw_box(win, y, x, h, w, title="", color=0):
    """Renders a rounded-corner box with boundary checking and optional title."""
    max_y, max_x = win.getmaxyx()
    if y < 0 or x < 0 or y >= max_y - 1 or x >= max_x - 1:
        return
    h = min(h, max_y - y)
    w = min(w, max_x - x)
    if h < 2 or w < 2:
        return
    try:
        # Top border
        win.addstr(y, x, "╭" + "─" * (w - 2) + "╮", color)
        # Side borders
        for i in range(1, h - 1):
            win.addstr(y + i, x, "│", color)
            win.addstr(y + i, x + w - 1, "│", color)
        # Bottom border
        if y + h - 1 == max_y - 1 and x + w >= max_x:
            # Prevent writing to extreme lower-right character
            win.addstr(y + h - 1, x, "╰" + "─" * (w - 3) + "╯", color)
        else:
            win.addstr(y + h - 1, x, "╰" + "─" * (w - 2) + "╯", color)

        if title and w > len(title) + 6:
            titlestr = f" {title[:w - 8]} "
            win.addstr(y, x + 2, titlestr, curses.A_BOLD | color)
    except curses.error:
        pass

def drain_queued_key(win, key_code):
    """Consumes identical duplicate keys queued in the input buffer to prevent repeat runaway."""
    win.nodelay(True)
    count = 0
    try:
        while count < 10:
            next_ch = win.getch()
            if next_ch == key_code:
                count += 1
                continue
            elif next_ch != -1:
                curses.ungetch(next_ch)
            break
    finally:
        win.timeout(50)

def run_curses_ui(stdscr):
    # Curses initialization
    curses.curs_set(0)
    curses.noecho()
    curses.cbreak()
    stdscr.keypad(True)
    curses.use_default_colors()

    if hasattr(curses, "set_escdelay"):
        try:
            curses.set_escdelay(25)
        except Exception:
            pass

    # High-responsiveness input loop: 50ms timeout (20 FPS update rate)
    stdscr.timeout(50)
    curses.flushinp()

    # Define color pairs if terminal supports them
    if curses.has_colors():
        curses.init_pair(1, curses.COLOR_CYAN, -1)     # Header / Borders
        curses.init_pair(2, curses.COLOR_GREEN, -1)    # OK / Online
        curses.init_pair(3, curses.COLOR_YELLOW, -1)   # Warning / Caution
        curses.init_pair(4, curses.COLOR_RED, -1)      # Error / Disconnected
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLUE) # Selection highlight
        curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_CYAN) # Tag / Mode pill
    else:
        for i in range(1, 7):
            curses.init_pair(i, -1, -1)

    selected_idx = 0
    scroll_offset = 0
    prev_max_y, prev_max_x = 0, 0
    last_profile_toggle = 0.0
    last_action_time = 0.0
    last_nav_time = 0.0

    while True:
        with state["lock"]:
            snap = dict(state)

        max_y, max_x = stdscr.getmaxyx()

        # Terminal resize detection
        if (max_y, max_x) != (prev_max_y, prev_max_x):
            prev_max_y, prev_max_x = max_y, max_x
            stdscr.clear()

        # Handle very small terminals gracefully without crashing or laggy sleep
        if max_y < 12 or max_x < 40:
            stdscr.erase()
            msg1 = "p1xi3 (._.)"
            msg2 = f"Resize: ({max_x}x{max_y})"
            msg3 = "Min: 40x12"
            safe_addstr(stdscr, max(0, max_y // 2 - 1), max(0, (max_x - len(msg1)) // 2), msg1, curses.color_pair(1) | curses.A_BOLD)
            safe_addstr(stdscr, max_y // 2, max(0, (max_x - len(msg2)) // 2), msg2, curses.color_pair(3))
            safe_addstr(stdscr, min(max_y - 1, max_y // 2 + 1), max(0, (max_x - len(msg3)) // 2), msg3, curses.A_DIM)
            stdscr.refresh()
            ch = stdscr.getch()
            if ch in [ord('q'), ord('Q'), 27]:
                break
            continue

        stdscr.erase()

        # Dynamic action items based on profile
        if snap['target_os'] == "GrapheneOS":
            items = [
                ("1. Check Device & OEM Unlock", "01_check_device.sh", "Verify fastboot, ADB, and OEM unlocking permission."),
                ("2. Flash GrapheneOS (panther)", "02_flash_guide.sh", "Reboot to bootloader & follow GrapheneOS WebUSB/fastboot."),
                ("3. Air-Gap Hardening Check", "03_airgap_harden.sh", "Verify physical SIM, Airplane mode, and GrapheneOS toggles."),
                ("4. Provision Termux & Engine", "04_provision_device.sh", "Sideload Termux, revoke network permission & stream binaries."),
                ("5. Download & Push Model", "05_push_model.sh", "Download optimal coding, reasoning, or chat GGUF model."),
                ("6. Check / Update Models", "08_update_models.sh", "Check upstream model revisions & push updates via USB."),
                ("7. Switch / Load Active Model", "07_switch_model.sh", "Select and switch between installed models on device."),
                ("8. Start USB Port Bridge", "06_start_bridge.sh", "Configure adb forward tcp:11435 tcp:11434."),
                ("9. Launch Host Chat Client", "client.py", "Open interactive USB streaming terminal chat session."),
                ("10. Switch Profile -> Stock Android", "TOGGLE_PROFILE", "Switch workflow for carrier-locked bootloaders."),
                ("11. Exit", "EXIT", "Quit p1xi3.")
            ]
        else: # Stock Android
            items = [
                ("1. Check Device & Carrier Info", "01_check_device.sh", "Inspect carrier SKU and ADB connectivity."),
                ("2. Stock Air-Gap & Debloat", "03_stock_harden.sh", "Disable wireless radios, scanning, and stock telemetry."),
                ("3. Provision Termux & Engine", "04_provision_device.sh", "Sideload Termux & stream 16KB-aligned llama-server."),
                ("4. Download & Push Model", "05_push_model.sh", "Download optimal coding, reasoning, or chat GGUF model."),
                ("5. Check / Update Models", "08_update_models.sh", "Check upstream model revisions & push updates via USB."),
                ("6. Switch / Load Active Model", "07_switch_model.sh", "Select and switch between installed models on device."),
                ("7. Start USB Port Bridge", "06_start_bridge.sh", "Configure adb forward tcp:11435 tcp:11434."),
                ("8. Launch Host Chat Client", "client.py", "Open interactive USB streaming terminal chat session."),
                ("9. Switch Profile -> GrapheneOS", "TOGGLE_PROFILE", "Switch workflow back to GrapheneOS installer."),
                ("10. Exit", "EXIT", "Quit p1xi3.")
            ]

        if selected_idx >= len(items):
            selected_idx = len(items) - 1
        if selected_idx < 0:
            selected_idx = 0

        # Colors & Status Strings
        st_color = (curses.color_pair(2) if snap['adb_status'] == "Online" 
                    else (curses.color_pair(3) if "Unauthorized" in snap['adb_status'] 
                    else curses.color_pair(4)))
        oem_color = (curses.color_pair(2) if snap['oem_unlock'] == "Allowed" 
                     else (curses.color_pair(3) if "Locked" in snap['oem_unlock'] 
                     else curses.A_NORMAL))
        air_color = curses.color_pair(2) if snap['airplane'] == "ON" else curses.color_pair(3)
        br_color = curses.color_pair(2) if snap['bridge_active'] else curses.A_DIM
        llm_color = curses.color_pair(2) if snap['llm_online'] else curses.A_DIM

        # Determine Layout Mode
        is_wide = (max_x >= 80 and max_y >= 20)
        is_compact_h = (max_y < 20)

        # ---------------------------------------------------------------------
        # 1. HEADER BAR
        # ---------------------------------------------------------------------
        mode_pill = f" [{snap['target_os']}] "
        safe_addstr(stdscr, 0, 2, "p1xi3", curses.color_pair(1) | curses.A_BOLD)
        safe_addstr(stdscr, 0, 8, "(._.)", curses.A_BOLD)
        if max_x >= 65:
            safe_addstr(stdscr, 0, 15, ":: Pixel 7 Air-Gapped USB LLM", curses.A_DIM)

        pill_x = max(20, max_x - len(mode_pill) - 14)
        safe_addstr(stdscr, 0, pill_x, mode_pill, curses.color_pair(6) | curses.A_BOLD)
        if max_x >= 48:
            safe_addstr(stdscr, 0, max_x - 11, f"[{snap['last_check']}]", curses.A_DIM)

        # ---------------------------------------------------------------------
        # 2. HARDWARE TELEMETRY PANEL
        # ---------------------------------------------------------------------
        telemetry_y = 1
        if is_wide:
            telemetry_h = 7
            draw_box(stdscr, telemetry_y, 2, telemetry_h, max_x - 4, "Live Hardware Telemetry")

            # Layout: 3 Columns if width >= 105, 2 Columns if 80 <= width < 105
            if max_x >= 105:
                # Column 1
                safe_addstr(stdscr, telemetry_y + 1, 4, "Status   : ")
                safe_addstr(stdscr, telemetry_y + 1, 15, snap['adb_status'], st_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 2, 4, "Device   : ")
                safe_addstr(stdscr, telemetry_y + 2, 15, f"{snap['device_model']} ({snap['device_name']})")
                safe_addstr(stdscr, telemetry_y + 3, 4, "Carrier  : ")
                safe_addstr(stdscr, telemetry_y + 3, 15, f"{snap['carrier']} / {snap['sku']}")

                # Column 2
                col2_x = max(38, max_x // 3 + 2)
                safe_addstr(stdscr, telemetry_y + 1, col2_x, "OEM Unlock : ")
                safe_addstr(stdscr, telemetry_y + 1, col2_x + 13, snap['oem_unlock'], oem_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 2, col2_x, "Air-Gap    : ")
                safe_addstr(stdscr, telemetry_y + 2, col2_x + 13, f"Air:{snap['airplane']} | Wi-Fi:{snap['wifi']} | BT:{snap['bluetooth']}", air_color)
                safe_addstr(stdscr, telemetry_y + 3, col2_x, "Battery    : ")
                safe_addstr(stdscr, telemetry_y + 3, col2_x + 13, f"{snap['battery']}%" if snap['battery'] != "--" else "--")

                # Column 3
                col3_x = max(col2_x + 36, (max_x * 2) // 3)
                safe_addstr(stdscr, telemetry_y + 1, col3_x, "USB Bridge : ")
                safe_addstr(stdscr, telemetry_y + 1, col3_x + 13, f"tcp:{snap['host_port']} [OK]" if snap['bridge_active'] else "Inactive", br_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 2, col3_x, "LLM Server : ")
                safe_addstr(stdscr, telemetry_y + 2, col3_x + 13, f"Online ({snap['host_port']})" if snap['llm_online'] else "Offline", llm_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 3, col3_x, "Model      : ")
                safe_addstr(stdscr, telemetry_y + 3, col3_x + 13, f"{snap['active_model'][:18]}", curses.color_pair(2) if snap['active_model'] != "None" else curses.A_DIM)
            else:
                # 2 Columns
                half_x = max_x // 2
                safe_addstr(stdscr, telemetry_y + 1, 4, "Status : ")
                safe_addstr(stdscr, telemetry_y + 1, 13, snap['adb_status'], st_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 2, 4, "Device : ")
                safe_addstr(stdscr, telemetry_y + 2, 13, f"{snap['device_model']} ({snap['device_name']})")
                safe_addstr(stdscr, telemetry_y + 3, 4, "Carrier: ")
                safe_addstr(stdscr, telemetry_y + 3, 13, f"{snap['carrier']} / {snap['sku']}")
                safe_addstr(stdscr, telemetry_y + 4, 4, "Battery: ")
                safe_addstr(stdscr, telemetry_y + 4, 13, f"{snap['battery']}%" if snap['battery'] != "--" else "--")

                safe_addstr(stdscr, telemetry_y + 1, half_x, "OEM Unlock: ")
                safe_addstr(stdscr, telemetry_y + 1, half_x + 12, snap['oem_unlock'], oem_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 2, half_x, "Air-Gap   : ")
                safe_addstr(stdscr, telemetry_y + 2, half_x + 12, f"Air:{snap['airplane']} | WF:{snap['wifi']} | BT:{snap['bluetooth']}", air_color)
                safe_addstr(stdscr, telemetry_y + 3, half_x, "Bridge    : ")
                safe_addstr(stdscr, telemetry_y + 3, half_x + 12, f"tcp:{snap['host_port']} [OK]" if snap['bridge_active'] else "Off", br_color | curses.A_BOLD)
                safe_addstr(stdscr, telemetry_y + 4, half_x, "LLM Model : ")
                safe_addstr(stdscr, telemetry_y + 4, half_x + 12, f"{snap['active_model'][:18]}", curses.color_pair(2) if snap['active_model'] != "None" else curses.A_DIM)

            menu_start_y = telemetry_y + telemetry_h
        else:
            # Compact Telemetry Box (3 or 4 lines total)
            telemetry_h = 4
            draw_box(stdscr, telemetry_y, 2, telemetry_h, max_x - 4, "Telemetry")
            line1 = f"ADB:{snap['adb_status'][:12]} | Batt:{snap['battery']}% | Bridge:tcp:{snap['host_port']}"
            line2 = f"OEM:{snap['oem_unlock'][:7]} | Air:{snap['airplane']} | LLM:{'Online' if snap['llm_online'] else 'Offline'}"
            safe_addstr(stdscr, telemetry_y + 1, 4, line1)
            safe_addstr(stdscr, telemetry_y + 2, 4, line2)
            menu_start_y = telemetry_y + telemetry_h

        # ---------------------------------------------------------------------
        # 3. ACTIONS MENU & DETAILS (Adaptive Side-by-Side or Stacked)
        # ---------------------------------------------------------------------
        footer_h = 2
        content_h = max(4, max_y - menu_start_y - footer_h)

        if is_wide:
            # Side-by-Side: Menu (Left) | Details (Right)
            menu_w = min(42, max(36, max_x // 3 + 6))
            detail_x = menu_w + 3
            detail_w = max_x - detail_x - 2

            draw_box(stdscr, menu_start_y, 2, content_h, menu_w, "Actions")
            draw_box(stdscr, menu_start_y, detail_x, content_h, detail_w, "Step Details & Context")

            # Scroll calculation for menu
            visible_rows = max(1, content_h - 2)
            if selected_idx < scroll_offset:
                scroll_offset = selected_idx
            elif selected_idx >= scroll_offset + visible_rows:
                scroll_offset = selected_idx - visible_rows + 1

            # Render scroll indicators
            if scroll_offset > 0:
                safe_addstr(stdscr, menu_start_y, menu_w - 2, "▲", curses.color_pair(1))
            if scroll_offset + visible_rows < len(items):
                safe_addstr(stdscr, menu_start_y + content_h - 1, menu_w - 2, "▼", curses.color_pair(1))

            for disp_idx, item_i in enumerate(range(scroll_offset, min(len(items), scroll_offset + visible_rows))):
                label, _, _ = items[item_i]
                row_y = menu_start_y + 1 + disp_idx
                prefix = "> " if item_i == selected_idx else "  "
                attr = curses.color_pair(5) | curses.A_BOLD if item_i == selected_idx else curses.A_NORMAL
                item_text = f"{prefix}{label}"[:menu_w - 4]
                safe_addstr(stdscr, row_y, 4, f"{item_text:<{menu_w - 6}}", attr)

            # Details Panel Content
            curr_label, curr_cmd, curr_desc = items[selected_idx]
            safe_addstr(stdscr, menu_start_y + 1, detail_x + 3, curr_label, curses.color_pair(1) | curses.A_BOLD)
            safe_addstr(stdscr, menu_start_y + 3, detail_x + 3, f"Description: {curr_desc[:detail_w - 18]}")

            if "Update" in curr_label:
                safe_addstr(stdscr, menu_start_y + 5, detail_x + 3, "Air-Gapped Update Security:", curses.A_BOLD)
                safe_addstr(stdscr, menu_start_y + 6, detail_x + 3, "• Air-gap strictly maintained: Pixel remains completely offline.")
                safe_addstr(stdscr, menu_start_y + 7, detail_x + 3, "• Host checks HF repository commits on your explicit command.")
                safe_addstr(stdscr, menu_start_y + 8, detail_x + 3, "• Selected updates stream to phone over physical USB cable only.")
            elif "Download" in curr_label or "Switch" in curr_label:
                safe_addstr(stdscr, menu_start_y + 5, detail_x + 3, "Curated Models & Workloads:", curses.A_BOLD)
                safe_addstr(stdscr, menu_start_y + 6, detail_x + 3, "• Coding   : Qwen2.5-Coder 1.5B/3B (Python/JS, Refactoring)")
                safe_addstr(stdscr, menu_start_y + 7, detail_x + 3, "• Reasoning: DeepSeek-R1 Distill 1.5B (Step-by-step logic, Math)")
                safe_addstr(stdscr, menu_start_y + 8, detail_x + 3, "• Chat     : Llama-3.2 1B/3B & SmolLM2 (Speed, Low battery)")
            elif snap['target_os'] == "Stock Android":
                safe_addstr(stdscr, menu_start_y + 5, detail_x + 3, "Profile Note (Stock Android):", curses.A_BOLD)
                safe_addstr(stdscr, menu_start_y + 6, detail_x + 3, "• For locked bootloaders (e.g. Verizon). Hardens telemetry & radios.")
                safe_addstr(stdscr, menu_start_y + 7, detail_x + 3, "• Sideloads 16KB-page-size llama-server over ADB without unlocking.")
            else:
                safe_addstr(stdscr, menu_start_y + 5, detail_x + 3, "Profile Note (GrapheneOS):", curses.A_BOLD)
                safe_addstr(stdscr, menu_start_y + 6, detail_x + 3, "• Maximum hardware security, sandboxing, and verified boot.")
                safe_addstr(stdscr, menu_start_y + 7, detail_x + 3, "• Requires OEM unlocking enabled in Developer options.")

            # Live Suggestions
            sugg_y = min(menu_start_y + 10, menu_start_y + content_h - 3)
            safe_addstr(stdscr, sugg_y, detail_x + 3, "Live Guidance:", curses.A_BOLD)
            if snap['adb_status'] == "Disconnected":
                safe_addstr(stdscr, sugg_y + 1, detail_x + 3, "• Plug Pixel into this machine with a USB-C data cable.", curses.color_pair(3))
            elif "Unauthorized" in snap['adb_status']:
                safe_addstr(stdscr, sugg_y + 1, detail_x + 3, "• Tap 'Always allow from this computer' on phone screen.", curses.color_pair(3))
            elif snap['bridge_active'] and snap['llm_online']:
                safe_addstr(stdscr, sugg_y + 1, detail_x + 3, "• LLM server online! Press Enter on 'Launch Host Chat Client'.", curses.color_pair(2))
            else:
                safe_addstr(stdscr, sugg_y + 1, detail_x + 3, "• Press Enter to execute the highlighted step.")

        else:
            # Compact / Stacked: Menu takes full width; preview bar underneath
            menu_w = max_x - 4
            menu_h = max(3, content_h - 2)
            draw_box(stdscr, menu_start_y, 2, menu_h, menu_w, "Actions")

            visible_rows = max(1, menu_h - 2)
            if selected_idx < scroll_offset:
                scroll_offset = selected_idx
            elif selected_idx >= scroll_offset + visible_rows:
                scroll_offset = selected_idx - visible_rows + 1

            if scroll_offset > 0:
                safe_addstr(stdscr, menu_start_y, menu_w - 2, "▲", curses.color_pair(1))
            if scroll_offset + visible_rows < len(items):
                safe_addstr(stdscr, menu_start_y + menu_h - 1, menu_w - 2, "▼", curses.color_pair(1))

            for disp_idx, item_i in enumerate(range(scroll_offset, min(len(items), scroll_offset + visible_rows))):
                label, _, _ = items[item_i]
                row_y = menu_start_y + 1 + disp_idx
                prefix = "> " if item_i == selected_idx else "  "
                attr = curses.color_pair(5) | curses.A_BOLD if item_i == selected_idx else curses.A_NORMAL
                item_text = f"{prefix}{label}"[:menu_w - 4]
                safe_addstr(stdscr, row_y, 4, f"{item_text:<{menu_w - 6}}", attr)

            # Compact Preview Line
            curr_label, _, curr_desc = items[selected_idx]
            preview_y = menu_start_y + menu_h
            if preview_y < max_y - 1:
                safe_addstr(stdscr, preview_y, 3, f"▸ {curr_desc}"[:max_x - 6], curses.color_pair(1))

        # ---------------------------------------------------------------------
        # 4. FOOTER BAR
        # ---------------------------------------------------------------------
        footer_y = max_y - 1
        if max_x >= 70:
            hints = " [↑/↓ or j/k] Navigate  |  [Enter] Execute  |  [Tab/p] Switch Profile  |  [q] Quit "
        elif max_x >= 48:
            hints = " [↑/↓] Move  |  [Enter] Run  |  [Tab] Profile  |  [q] Quit "
        else:
            hints = " [↑/↓] Move [Enter] Run [q] Quit "
        safe_addstr(stdscr, footer_y, 2, hints, curses.A_DIM)

        stdscr.refresh()

        # ---------------------------------------------------------------------
        # 5. HIGH RESPONSIVENESS KEYBOARD INPUT & DEBOUNCE
        # ---------------------------------------------------------------------
        ch = stdscr.getch()
        if ch == -1:
            continue

        now = time.time()

        # Terminal Resize
        if ch == curses.KEY_RESIZE:
            try:
                curses.update_lines_cols()
            except Exception:
                pass
            stdscr.clear()
            stdscr.refresh()
            continue

        # Quit
        if ch in [ord('q'), ord('Q')]:
            break

        # Standalone ESC key handling (without eating arrow escape sequences)
        if ch == 27:
            stdscr.nodelay(True)
            next_ch = stdscr.getch()
            stdscr.timeout(50)
            if next_ch == -1:
                # Standalone ESC pressed
                break
            else:
                # Consume any remaining escape sequence bytes cleanly
                stdscr.nodelay(True)
                while stdscr.getch() != -1:
                    pass
                stdscr.timeout(50)
                continue

        # Navigation: Up
        elif ch in [curses.KEY_UP, ord('k'), ord('K')]:
            drain_queued_key(stdscr, ch)
            selected_idx = (selected_idx - 1) % len(items)

        # Navigation: Down
        elif ch in [curses.KEY_DOWN, ord('j'), ord('J')]:
            drain_queued_key(stdscr, ch)
            selected_idx = (selected_idx + 1) % len(items)

        # Navigation: Page Up / Home
        elif ch in [curses.KEY_PPAGE, curses.KEY_HOME, ord('g')]:
            selected_idx = 0

        # Navigation: Page Down / End
        elif ch in [curses.KEY_NPAGE, curses.KEY_END, ord('G')]:
            selected_idx = len(items) - 1

        # Profile Switch (Debounced 200ms)
        elif ch in [ord('\t'), ord('p'), ord('P')]:
            if now - last_profile_toggle > 0.2:
                last_profile_toggle = now
                with state["lock"]:
                    state["target_os"] = "Stock Android" if state["target_os"] == "GrapheneOS" else "GrapheneOS"
                selected_idx = 0
                scroll_offset = 0

        # Action Execution (Debounced 250ms)
        elif ch in [10, 13, curses.KEY_ENTER]:
            if now - last_action_time < 0.25:
                continue
            last_action_time = now

            # Flush input buffer before executing so no stray keystrokes carry over
            curses.flushinp()

            _, target_cmd, _ = items[selected_idx]
            if target_cmd == "EXIT":
                break
            elif target_cmd == "TOGGLE_PROFILE":
                with state["lock"]:
                    state["target_os"] = "Stock Android" if state["target_os"] == "GrapheneOS" else "GrapheneOS"
                selected_idx = 0
                scroll_offset = 0
            else:
                # Suspend curses cleanly
                curses.def_prog_mode()
                curses.endwin()
                print("\n" * 2)
                try:
                    if target_cmd == "client.py":
                        cmd_path = os.path.join(SCRIPT_DIR, "client.py")
                        subprocess.call([sys.executable, cmd_path])
                    else:
                        cmd_path = os.path.join(SCRIPTS_DIR, target_cmd)
                        subprocess.call(["bash", cmd_path])
                except (KeyboardInterrupt, Exception):
                    pass

                print("\n\033[90m(^_^) [ok] Task complete. Press Enter to return to p1xi3 TUI...\033[0m")
                try:
                    input()
                except (KeyboardInterrupt, EOFError):
                    pass

                # Restore curses state cleanly
                curses.reset_prog_mode()
                curses.curs_set(0)
                stdscr.keypad(True)
                stdscr.timeout(50)
                curses.flushinp()
                stdscr.clear()
                stdscr.refresh()

def main():
    # Start background telemetry thread
    t = threading.Thread(target=monitor_thread_func, daemon=True)
    t.start()
    try:
        curses.wrapper(run_curses_ui)
    except (curses.error, KeyboardInterrupt):
        pass
    finally:
        stop_monitor.set()
        t.join(timeout=0.8)
        try:
            curses.endwin()
        except Exception:
            pass
    print("\np1xi3 (._.) session closed. Farewell!\n")

if __name__ == "__main__":
    main()
