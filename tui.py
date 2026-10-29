#!/usr/bin/env python3
"""
p1xi3 (._.) - Rust-style TUI for Pixel 7 Air-Gapped USB LLM Toolkit
Features live background hardware polling, dual GrapheneOS / Stock Android modes,
and smooth box-styled terminal interface.
"""

import curses
import os
import sys
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
    "llm_online": False,
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
            fb_out = subprocess.check_output(["fastboot", "devices"], stderr=subprocess.DEVNULL, timeout=1).decode("utf-8").strip()
            if fb_out:
                fastboot_on = True
                adb_st = "Fastboot Mode"
        except Exception:
            pass

        # 2. Check adb
        if not fastboot_on:
            try:
                adb_out = subprocess.check_output(["adb", "devices"], stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8").strip()
                lines = [l for l in adb_out.splitlines() if l and not l.startswith("List of")]
                if lines:
                    line = lines[0]
                    parts = line.split()
                    if len(parts) >= 2:
                        raw_st = parts[1]
                        if raw_st == "device":
                            adb_st = "Online"
                        elif raw_st == "unauthorized":
                            adb_st = "Unauthorized (Prompt on Phone)"
                        elif raw_st == "offline":
                            adb_st = "Offline"
                        else:
                            adb_st = raw_st
            except Exception:
                adb_st = "ADB Offline"

        # 3. If online, query hardware & radio props
        if adb_st == "Online":
            try:
                # Batch query to minimize subshell calls
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
                output = subprocess.check_output(["adb", "shell", cmd], stderr=subprocess.DEVNULL, timeout=2).decode("utf-8")
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
                        oem_unl = "Allowed" if raw_oem == "1" else ("Greyed Out / Locked" if raw_oem == "0" else "Unknown")
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

        # 4. Check bridge
        br_active = False
        try:
            fwd_list = subprocess.check_output(["adb", "forward", "--list"], stderr=subprocess.DEVNULL, timeout=1).decode("utf-8")
            if "11434" in fwd_list:
                br_active = True
        except Exception:
            pass

        # 5. Check LLM Server
        llm_on = False
        if br_active:
            for endpoint in ["http://127.0.0.1:11434/health", "http://127.0.0.1:11434/v1/models"]:
                try:
                    req = urllib.request.Request(endpoint, method="GET")
                    with urllib.request.urlopen(req, timeout=0.8) as resp:
                        if resp.status == 200:
                            llm_on = True
                            break
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
            state["llm_online"] = llm_on
            state["last_check"] = time.strftime("%H:%M:%S")

        # Sleep with early exit check
        for _ in range(15):
            if stop_monitor.is_set():
                break
            time.sleep(0.1)

def draw_box(win, y, x, h, w, title=""):
    """Renders a modern rounded-corner box with optional title."""
    try:
        # Corners and edges: ╭ ╮ ╯ ╰ ─ │
        win.addstr(y, x, "╭" + "─" * (w - 2) + "╮")
        for i in range(1, h - 1):
            win.addstr(y + i, x, "│" + " " * (w - 2) + "│")
        win.addstr(y + h - 1, x, "╰" + "─" * (w - 2) + "╯")
        if title:
            titlestr = f" {title} "
            win.addstr(y, x + 2, titlestr, curses.A_BOLD)
    except curses.error:
        pass

def run_curses_ui(stdscr):
    curses.curs_set(0)
    curses.use_default_colors()

    # Define color pairs if terminal supports them
    if curses.has_colors():
        curses.init_pair(1, curses.COLOR_CYAN, -1)     # Header / Borders
        curses.init_pair(2, curses.COLOR_GREEN, -1)    # OK / Online
        curses.init_pair(3, curses.COLOR_YELLOW, -1)   # Warning / Caution
        curses.init_pair(4, curses.COLOR_RED, -1)      # Error / Disconnected
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLUE) # Selection highlight
        curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_CYAN) # Tag / Mode pill
    else:
        # Fallback
        for i in range(1, 7):
            curses.init_pair(i, -1, -1)

    stdscr.nodelay(True) # Non-blocking input for live polling loop
    selected_idx = 0

    while True:
        with state["lock"]:
            snap = dict(state)

        max_y, max_x = stdscr.getmaxyx()
        stdscr.erase()

        if max_y < 24 or max_x < 80:
            msg = f"Terminal too small ({max_x}x{max_y}). Need at least 80x24."
            try:
                stdscr.addstr(0, 0, msg, curses.color_pair(3))
            except curses.error:
                pass
            stdscr.refresh()
            time.sleep(0.2)
            # Check exit
            ch = stdscr.getch()
            if ch in [ord('q'), ord('Q'), 27]:
                break
            continue

        # Header Bar
        mode_pill = f" [Profile: {snap['target_os']}] "
        stdscr.addstr(1, 2, "p1xi3", curses.color_pair(1) | curses.A_BOLD)
        stdscr.addstr(1, 8, "(._.)", curses.A_BOLD)
        stdscr.addstr(1, 15, ":: Pixel 7 Air-Gapped USB LLM Toolkit", curses.A_DIM)
        stdscr.addstr(1, max_x - len(mode_pill) - 18, mode_pill, curses.color_pair(6) | curses.A_BOLD)
        stdscr.addstr(1, max_x - 14, f"[{snap['last_check']}]", curses.A_DIM)

        # ---------------------------------------------------------------------
        # TOP PANEL: Live Hardware & Security Telemetry Box
        # ---------------------------------------------------------------------
        top_h = 7
        draw_box(stdscr, 3, 2, top_h, max_x - 4, "Live Hardware Telemetry (Auto-updates)")

        # Column 1: Connection & Device
        st_color = curses.color_pair(2) if snap['adb_status'] == "Online" else (curses.color_pair(3) if "Unauthorized" in snap['adb_status'] else curses.color_pair(4))
        stdscr.addstr(4, 4, "Status   : ")
        stdscr.addstr(4, 15, f"{snap['adb_status']}", st_color | curses.A_BOLD)

        stdscr.addstr(5, 4, "Device   : ")
        stdscr.addstr(5, 15, f"{snap['device_model']} ({snap['device_name']})")

        stdscr.addstr(6, 4, "Carrier  : ")
        carrier_str = f"{snap['carrier']} / {snap['sku']}"
        if "vzw" in snap['carrier'].lower() or "verizon" in snap['carrier'].lower():
            carrier_str += " (Verizon Locked)"
            stdscr.addstr(6, 15, carrier_str, curses.color_pair(3))
        else:
            stdscr.addstr(6, 15, carrier_str)

        # Column 2: Security & Radios
        col2_x = max(40, max_x // 2 - 4)
        oem_color = curses.color_pair(2) if snap['oem_unlock'] == "Allowed" else (curses.color_pair(3) if "Greyed Out" in snap['oem_unlock'] else curses.A_NORMAL)
        stdscr.addstr(4, col2_x, "OEM Unlock : ")
        stdscr.addstr(4, col2_x + 13, snap['oem_unlock'], oem_color | curses.A_BOLD)

        air_color = curses.color_pair(2) if snap['airplane'] == "ON" else curses.color_pair(3)
        stdscr.addstr(5, col2_x, "Air-Gap    : ")
        stdscr.addstr(5, col2_x + 13, f"Airplane: {snap['airplane']} | Wi-Fi: {snap['wifi']} | BT: {snap['bluetooth']}", air_color)

        stdscr.addstr(6, col2_x, "Battery    : ")
        stdscr.addstr(6, col2_x + 13, f"{snap['battery']}%" if snap['battery'] != "--" else "--")

        # Column 3: USB Bridge & LLM Server
        col3_x = max(col2_x + 35, (max_x * 3) // 4)
        br_color = curses.color_pair(2) if snap['bridge_active'] else curses.A_DIM
        llm_color = curses.color_pair(2) if snap['llm_online'] else curses.A_DIM
        stdscr.addstr(4, col3_x, "USB Bridge : ")
        stdscr.addstr(4, col3_x + 13, "tcp:11434 [OK]" if snap['bridge_active'] else "Inactive", br_color | curses.A_BOLD)
        stdscr.addstr(5, col3_x, "LLM Server : ")
        stdscr.addstr(5, col3_x + 13, "Online (11434)" if snap['llm_online'] else "Offline", llm_color | curses.A_BOLD)

        # ---------------------------------------------------------------------
        # BOTTOM LEFT: Action Menu List
        # ---------------------------------------------------------------------
        bottom_y = 10
        bottom_h = max_y - bottom_y - 2
        menu_w = min(42, max_x // 2)

        draw_box(stdscr, bottom_y, 2, bottom_h, menu_w, "Actions")

        # Dynamic action items based on profile
        if snap['target_os'] == "GrapheneOS":
            items = [
                ("1. Check Device & OEM Unlock", "01_check_device.sh", "Verify fastboot, ADB, and OEM unlocking permission."),
                ("2. Flash GrapheneOS (panther)", "02_flash_guide.sh", "Reboot to bootloader & follow GrapheneOS WebUSB/fastboot."),
                ("3. Air-Gap Hardening Check", "03_airgap_harden.sh", "Verify physical SIM, Airplane mode, and GrapheneOS toggles."),
                ("4. Provision Termux & Compiler", "04_provision_device.sh", "Sideload Termux, revoke network permission & stage build."),
                ("5. Download & Push GGUF Model", "05_push_model.sh", "Download 1B/3B GGUF model and push over USB."),
                ("6. Start USB Port Bridge", "06_start_bridge.sh", "Configure adb forward tcp:11434 tcp:11434."),
                ("7. Launch Host Chat Client", "client.py", "Open interactive USB streaming terminal chat session."),
                ("8. Switch Profile -> Stock Android", "TOGGLE_PROFILE", "Switch workflow for carrier-locked bootloaders."),
                ("9. Exit", "EXIT", "Quit p1xi3.")
            ]
        else: # Stock Android
            items = [
                ("1. Check Device & Carrier Info", "01_check_device.sh", "Inspect carrier SKU and ADB connectivity."),
                ("2. Stock Air-Gap & Debloat", "03_stock_harden.sh", "Disable wireless radios, scanning, and stock telemetry."),
                ("3. Provision Termux & Compiler", "04_provision_device.sh", "Sideload Termux & compile native llama-server."),
                ("4. Download & Push GGUF Model", "05_push_model.sh", "Download 1B/3B GGUF model and push over USB."),
                ("5. Start USB Port Bridge", "06_start_bridge.sh", "Configure adb forward tcp:11434 tcp:11434."),
                ("6. Launch Host Chat Client", "client.py", "Open interactive USB streaming terminal chat session."),
                ("7. Switch Profile -> GrapheneOS", "TOGGLE_PROFILE", "Switch workflow back to GrapheneOS installer."),
                ("8. Exit", "EXIT", "Quit p1xi3.")
            ]

        if selected_idx >= len(items):
            selected_idx = 0

        for i, (label, _, _) in enumerate(items):
            item_y = bottom_y + 2 + i
            if item_y < bottom_y + bottom_h - 1:
                if i == selected_idx:
                    stdscr.addstr(item_y, 4, f"> {label:<{menu_w - 8}}", curses.color_pair(5) | curses.A_BOLD)
                else:
                    stdscr.addstr(item_y, 4, f"  {label:<{menu_w - 8}}")

        # ---------------------------------------------------------------------
        # BOTTOM RIGHT: Details & Guidance Box
        # ---------------------------------------------------------------------
        detail_x = menu_w + 3
        detail_w = max_x - detail_x - 2
        draw_box(stdscr, bottom_y, detail_x, bottom_h, detail_w, "Step Details & Context")

        curr_label, curr_cmd, curr_desc = items[selected_idx]
        stdscr.addstr(bottom_y + 2, detail_x + 3, curr_label, curses.color_pair(1) | curses.A_BOLD)
        stdscr.addstr(bottom_y + 4, detail_x + 3, f"Description: {curr_desc}")

        if snap['target_os'] == "Stock Android":
            stdscr.addstr(bottom_y + 6, detail_x + 3, "Profile Note (Stock Android):", curses.A_BOLD)
            stdscr.addstr(bottom_y + 7, detail_x + 3, "Ideal when OEM unlocking is permanently disabled by your carrier.")
            stdscr.addstr(bottom_y + 8, detail_x + 3, "Keeps stock firmware, enforces air-gap, and runs models over USB.")
        else:
            stdscr.addstr(bottom_y + 6, detail_x + 3, "Profile Note (GrapheneOS):", curses.A_BOLD)
            stdscr.addstr(bottom_y + 7, detail_x + 3, "Maximum security. Requires OEM unlocking enabled in Developer options.")
            stdscr.addstr(bottom_y + 8, detail_x + 3, "Replaces OS completely with hardened Android & verified boot.")

        # Live guidance hints
        stdscr.addstr(bottom_y + 11, detail_x + 3, "Live Suggestions:", curses.A_BOLD)
        if snap['adb_status'] == "Disconnected":
            stdscr.addstr(bottom_y + 12, detail_x + 3, "• Plug your Pixel 7 into this machine with a USB-C data cable.", curses.color_pair(3))
        elif "Unauthorized" in snap['adb_status']:
            stdscr.addstr(bottom_y + 12, detail_x + 3, "• Check your phone screen and tap 'Always allow from this computer'.", curses.color_pair(3))
        elif snap['target_os'] == "GrapheneOS" and snap['oem_unlock'] == "Greyed Out / Locked":
            stdscr.addstr(bottom_y + 12, detail_x + 3, "• OEM unlocking is greyed out. If carrier-locked, press Tab for Stock Mode.", curses.color_pair(3))
        elif snap['bridge_active'] and snap['llm_online']:
            stdscr.addstr(bottom_y + 12, detail_x + 3, "• LLM server is online! Select 'Launch Host Chat Client' to converse.", curses.color_pair(2))
        else:
            stdscr.addstr(bottom_y + 12, detail_x + 3, "• Ready. Press Enter to run the selected step.")

        # Footer Navigation Hints
        hints = " [↑/↓ or j/k] Navigate  |  [Enter] Execute  |  [Tab] Switch Profile  |  [q] Quit "
        stdscr.addstr(max_y - 1, 3, hints, curses.A_DIM)

        stdscr.refresh()

        # Handle Keyboard Input
        ch = stdscr.getch()
        if ch in [ord('q'), ord('Q')]:
            break
        elif ch in [curses.KEY_UP, ord('k')]:
            selected_idx = (selected_idx - 1) % len(items)
        elif ch in [curses.KEY_DOWN, ord('j')]:
            selected_idx = (selected_idx + 1) % len(items)
        elif ch in [ord('\t'), ord('m'), ord('M')]:
            # Toggle profile
            with state["lock"]:
                state["target_os"] = "Stock Android" if state["target_os"] == "GrapheneOS" else "GrapheneOS"
            selected_idx = 0
        elif ch in [10, 13, curses.KEY_ENTER]:
            # Execute selected action
            _, target_cmd, _ = items[selected_idx]
            if target_cmd == "EXIT":
                break
            elif target_cmd == "TOGGLE_PROFILE":
                with state["lock"]:
                    state["target_os"] = "Stock Android" if state["target_os"] == "GrapheneOS" else "GrapheneOS"
                selected_idx = 0
            else:
                # Suspend curses, run subprocess, then resume
                curses.endwin()
                print("\n" * 2)
                if target_cmd == "client.py":
                    cmd_path = os.path.join(SCRIPT_DIR, "client.py")
                    subprocess.call([sys.executable, cmd_path])
                else:
                    cmd_path = os.path.join(SCRIPTS_DIR, target_cmd)
                    subprocess.call(["bash", cmd_path])

                print("\n\033[90m(^_^) [ok] Task complete. Press Enter to return to p1xi3 TUI...\033[0m")
                input()
                # Re-initialize curses screen after return
                stdscr.clear()
                curses.curs_set(0)

        time.sleep(0.05)

def main():
    # Start monitor thread
    t = threading.Thread(target=monitor_thread_func, daemon=True)
    t.start()
    try:
        curses.wrapper(run_curses_ui)
    finally:
        stop_monitor.set()
        t.join(timeout=1.0)
    print("\np1xi3 (._.) session closed. Farewell!\n")

if __name__ == "__main__":
    main()
