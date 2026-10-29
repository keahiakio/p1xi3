#!/usr/bin/env python3
"""
Pixel 7 Air-Gapped LLM Setup Wizard
Interactive guide to flash GrapheneOS, enforce air-gap security, and run local LLMs over USB.
"""

import os
import sys
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.join(SCRIPT_DIR, "scripts")

def run_script(script_name):
    path = os.path.join(SCRIPTS_DIR, script_name)
    if not os.path.exists(path):
        print(f"Script not found: {path}")
        return
    subprocess.call(["bash", path])

def print_header():
    print("\033[1;36m" + "=" * 65)
    print("      p1xi3 (._.) : Pixel 7 Air-Gapped USB LLM Toolkit")
    print("=" * 65 + "\033[0m\n")

def menu():
    while True:
        print_header()
        print("Choose a step to execute:\n")
        print("  \033[1;32m1)\033[0m Check Device Status (ADB, Fastboot, OEM Unlock)")
        print("  \033[1;32m2)\033[0m GrapheneOS Flashing Guide (Pixel 7 / panther)")
        print("  \033[1;32m3)\033[0m Air-Gap Security Checklist & Hardening")
        print("  \033[1;32m4)\033[0m Provision Termux & Native llama-server")
        print("  \033[1;32m5)\033[0m Download & Push GGUF Model (Coding, Reasoning, Chat)")
        print("  \033[1;32m6)\033[0m Switch / Load Active Model on Device")
        print("  \033[1;32m7)\033[0m Start USB Bridge (Forward port)")
        print("  \033[1;32m8)\033[0m Launch Host Chat Client (Interactive REPL)")
        print("  \033[1;31m9)\033[0m Exit\n")

        choice = input("\033[1;33mSelect an option [1-9]: \033[0m").strip()
        print()

        if choice == "1":
            run_script("01_check_device.sh")
        elif choice == "2":
            run_script("02_flash_guide.sh")
        elif choice == "3":
            run_script("03_airgap_harden.sh")
        elif choice == "4":
            run_script("04_provision_device.sh")
        elif choice == "5":
            run_script("05_push_model.sh")
        elif choice == "6":
            run_script("07_switch_model.sh")
        elif choice == "7":
            run_script("06_start_bridge.sh")
        elif choice == "8":
            client_path = os.path.join(SCRIPT_DIR, "client.py")
            subprocess.call([sys.executable, client_path])
        elif choice == "9" or choice.lower() in ["exit", "q"]:
            print("Exiting wizard.")
            break
        else:
            print("\033[31mInvalid option. Please choose 1-8.\033[0m")

        input("\n\033[90mPress Enter to return to main menu...\033[0m")
        print("\n" * 2)

if __name__ == "__main__":
    if "--cli" in sys.argv:
        menu()
    else:
        try:
            import tui
            tui.main()
        except Exception as e:
            print(f"(o.o) [!] Could not initialize curses TUI ({e}). Falling back to CLI mode...")
            menu()
