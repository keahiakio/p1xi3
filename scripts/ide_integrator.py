#!/usr/bin/env python3
"""
p1xi3 (._.) - IDE & Agent Integrator
Automatically detects host IDEs (Zed, VS Code, Cursor, Windsurf, JetBrains, Neovim)
and configures them to use the air-gapped Pixel 7 LLM over physical USB.
"""

import os
import sys
import json
import shutil
import urllib.request
import urllib.error

CYAN = "\033[1;36m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[1;34m"
MAGENTA = "\033[1;35m"
RED = "\033[1;31m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"

PORT_DEFAULT = 11435
API_BASE = f"http://127.0.0.1:{PORT_DEFAULT}/v1"

def print_header():
    print(f"{CYAN}==================================================================")
    print("      p1xi3 (._.) : IDE & AI Agent Integration Manager")
    print(f"=================================================================={NC}\n")
    print(f"{BLUE}Physical USB Bridge Endpoint:{NC} {BOLD}{API_BASE}{NC}")
    print("Air-gap preserved: Zero packets touch external Wi-Fi/cellular networks.\n")

def check_bridge_status():
    """Checks if the local USB bridge is running and responsive."""
    try:
        req = urllib.request.Request(f"{API_BASE}/models", method="GET")
        with urllib.request.urlopen(req, timeout=1.2) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            active_models = [m.get("id", "") for m in data.get("data", [])]
            return True, active_models
    except Exception:
        return False, []

def detect_ides():
    home = os.path.expanduser("~")
    is_mac = sys.platform == "darwin"

    detect_map = {
        "zed": {
            "name": "Zed Editor",
            "detected": False,
            "config_dir": os.path.join(home, "Library/Application Support/Zed") if is_mac else os.path.join(home, ".config/zed"),
            "config_file": "settings.json",
            "type": "zed"
        },
        "continue": {
            "name": "Continue.dev (VS Code / JetBrains / Cursor)",
            "detected": False,
            "config_dir": os.path.join(home, ".continue"),
            "config_file": "config.json",
            "type": "continue"
        },
        "vscode": {
            "name": "Visual Studio Code (User Settings)",
            "detected": False,
            "config_dir": os.path.join(home, "Library/Application Support/Code/User") if is_mac else os.path.join(home, ".config/Code/User"),
            "config_file": "settings.json",
            "type": "vscode"
        },
        "cursor": {
            "name": "Cursor Editor",
            "detected": False,
            "config_dir": os.path.join(home, "Library/Application Support/Cursor/User") if is_mac else os.path.join(home, ".config/Cursor/User"),
            "config_file": "settings.json",
            "type": "cursor"
        },
        "windsurf": {
            "name": "Windsurf Editor",
            "detected": False,
            "config_dir": os.path.join(home, "Library/Application Support/Windsurf/User") if is_mac else os.path.join(home, ".config/windsurf/User"),
            "config_file": "settings.json",
            "type": "windsurf"
        },
        "jetbrains": {
            "name": "JetBrains IDEs (IntelliJ / PyCharm / CLion)",
            "detected": False,
            "config_dir": os.path.join(home, "Library/Application Support/JetBrains") if is_mac else os.path.join(home, ".config/JetBrains"),
            "config_file": "continue_link",
            "type": "jetbrains"
        },
        "neovim": {
            "name": "Neovim (avante.nvim / codecompanion.nvim)",
            "detected": False,
            "config_dir": os.path.join(home, ".config/nvim"),
            "config_file": "init.lua",
            "type": "neovim"
        },
        "shell_env": {
            "name": "Shell Environment (OPENAI_API_BASE for CLI agents/Aider)",
            "detected": True,
            "config_dir": home,
            "config_file": ".bashrc",
            "type": "shell_env"
        }
    }

    # Binary and directory existence checks
    binaries = {
        "zed": ["zed", "zed-editor"],
        "vscode": ["code", "codium"],
        "cursor": ["cursor"],
        "windsurf": ["windsurf"],
        "neovim": ["nvim"],
        "jetbrains": ["idea", "pycharm", "webstorm", "clion", "goland"]
    }

    for key, info in detect_map.items():
        # Check config dir
        if os.path.exists(info["config_dir"]):
            info["detected"] = True
            continue

        # Check binaries in PATH
        if key in binaries:
            for b in binaries[key]:
                if shutil.which(b):
                    info["detected"] = True
                    break

        # Check continue specifically
        if key == "continue" and (detect_map["vscode"]["detected"] or detect_map["cursor"]["detected"] or detect_map["jetbrains"]["detected"]):
            info["detected"] = True

    return detect_map

def load_json_relaxed(filepath):
    """Loads JSON file, ignoring comments or formatting issues if possible."""
    if not os.path.exists(filepath):
        return {}
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            lines = []
            for line in f:
                stripped = line.strip()
                # Basic strip of whole line single-line comments //
                if stripped.startswith("//"):
                    continue
                lines.append(line)
            return json.loads("".join(lines))
    except Exception:
        return {}

def backup_file(path):
    if os.path.exists(path):
        bak = f"{path}.p1xi3.bak"
        try:
            shutil.copy2(path, bak)
            print(f"  {DIM}↳ Created backup:{NC} {bak}")
        except Exception:
            pass

def configure_zed(info):
    cfg_dir = info["config_dir"]
    os.makedirs(cfg_dir, exist_ok=True)
    cfg_file = os.path.join(cfg_dir, "settings.json")
    backup_file(cfg_file)

    current_cfg = load_json_relaxed(cfg_file)

    # Prepare p1xi3 models entry
    p1xi3_models = [
        {
            "name": "qwen2.5-coder-1.5b-instruct-q4_k_m",
            "display_name": "p1xi3 Qwen 2.5 Coder 1.5B (Fast USB Agent)",
            "max_tokens": 4096,
            "supports_tools": True
        },
        {
            "name": "qwen2.5-coder-3b-instruct-q4_k_m",
            "display_name": "p1xi3 Qwen 2.5 Coder 3B (Architecture/Refactor)",
            "max_tokens": 4096,
            "supports_tools": True
        },
        {
            "name": "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M",
            "display_name": "p1xi3 DeepSeek R1 Distill 1.5B (CoT Reasoning)",
            "max_tokens": 4096,
            "supports_tools": False
        },
        {
            "name": "Llama-3.2-1B-Instruct-Q4_K_M",
            "display_name": "p1xi3 Llama 3.2 1B (Low Battery / Rapid Chat)",
            "max_tokens": 4096,
            "supports_tools": False
        }
    ]

    if "language_models" not in current_cfg:
        current_cfg["language_models"] = {}

    current_cfg["language_models"]["openai_compatible"] = {
        "api_url": API_BASE,
        "available_models": p1xi3_models
    }

    # Set assistant defaults
    current_cfg["assistant"] = {
        "version": "2",
        "default_model": {
            "provider": "openai_compatible",
            "model": "qwen2.5-coder-1.5b-instruct-q4_k_m"
        }
    }

    current_cfg["inline_assist"] = {
        "version": "2",
        "default_model": {
            "provider": "openai_compatible",
            "model": "qwen2.5-coder-1.5b-instruct-q4_k_m"
        }
    }

    with open(cfg_file, "w", encoding="utf-8") as f:
        json.dump(current_cfg, f, indent=2)

    print(f"  {GREEN}(^_^) [ok] Configured Zed settings:{NC} {cfg_file}")
    print(f"       • Assistant Panel model set to p1xi3 Qwen 2.5 Coder")
    print(f"       • Inline Assist (Ctrl+Enter) linked to Pixel 7 USB")

def configure_continue(info):
    cfg_dir = info["config_dir"]
    os.makedirs(cfg_dir, exist_ok=True)
    cfg_file = os.path.join(cfg_dir, "config.json")
    backup_file(cfg_file)

    current_cfg = load_json_relaxed(cfg_file)

    p1xi3_model = {
        "title": "p1xi3 (Pixel 7 Air-Gapped LLM)",
        "provider": "openai",
        "model": "qwen2.5-coder-1.5b-instruct-q4_k_m",
        "apiBase": API_BASE,
        "apiKey": "p1xi3",
        "contextLength": 4096,
        "completionOptions": {
            "temperature": 0.2
        }
    }

    p1xi3_tab = {
        "title": "p1xi3 Autocomplete",
        "provider": "openai",
        "model": "qwen2.5-coder-1.5b-instruct-q4_k_m",
        "apiBase": API_BASE,
        "apiKey": "p1xi3"
    }

    models = current_cfg.get("models", [])
    # Replace existing p1xi3 or append
    models = [m for m in models if "p1xi3" not in m.get("title", "").lower()]
    models.insert(0, p1xi3_model)
    current_cfg["models"] = models
    current_cfg["tabAutocompleteModel"] = p1xi3_tab

    with open(cfg_file, "w", encoding="utf-8") as f:
        json.dump(current_cfg, f, indent=2)

    print(f"  {GREEN}(^_^) [ok] Configured Continue.dev settings:{NC} {cfg_file}")
    print(f"       • Added p1xi3 as primary Chat & Agent model")
    print(f"       • Set p1xi3 as Tab-Autocomplete coprocessor")
    print(f"       • Works seamlessly across VS Code, Cursor, Windsurf, & JetBrains!")

def configure_neovim(info):
    cfg_dir = info["config_dir"]
    os.makedirs(cfg_dir, exist_ok=True)
    snippet_file = os.path.join(cfg_dir, "p1xi3.lua")

    lua_code = f"""-- p1xi3 Pixel 7 Air-Gapped USB LLM Neovim Integration
-- Endpoint: {API_BASE}

-- 1. Avante.nvim (Cursor-like agent for Neovim)
-- Add this table inside your avante setup:
local avante_p1xi3 = {{
  provider = "openai",
  openai = {{
    endpoint = "{API_BASE}",
    model = "qwen2.5-coder-1.5b-instruct-q4_k_m",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  }},
}}

-- 2. CodeCompanion.nvim (AI Assistant for Neovim)
-- Add this adapter into your codecompanion setup:
local codecompanion_p1xi3 = {{
  adapters = {{
    p1xi3 = function()
      return require("codecompanion.adapters").extend("openai_compatible", {{
        env = {{
          url = "{API_BASE}",
          api_key = "p1xi3",
          chat_url = "/chat/completions",
        }},
        schema = {{
          model = {{
            default = "qwen2.5-coder-1.5b-instruct-q4_k_m",
          }},
        }},
      }})
    end,
  }},
  strategies = {{
    chat = {{ adapter = "p1xi3" }},
    inline = {{ adapter = "p1xi3" }},
  }},
}}

return {{
  endpoint = "{API_BASE}",
  avante = avante_p1xi3,
  codecompanion = codecompanion_p1xi3,
}}
"""
    with open(snippet_file, "w", encoding="utf-8") as f:
        f.write(lua_code)

    print(f"  {GREEN}(^_^) [ok] Created Neovim integration module:{NC} {snippet_file}")
    print(f"       • Ready for avante.nvim & codecompanion.nvim")
    print(f"       • Load with: require('p1xi3') in your init.lua")

def configure_shell_env(info):
    home = os.path.expanduser("~")
    targets = [os.path.join(home, ".bashrc"), os.path.join(home, ".zshrc")]
    configured = 0

    snippet = f"""
# p1xi3 (._.) Local Air-Gapped USB LLM Agent Endpoint
export OPENAI_API_BASE="{API_BASE}"
export OPENAI_API_KEY="p1xi3"
export OPENAI_BASE_URL="{API_BASE}"
"""
    for t in targets:
        if os.path.exists(t):
            with open(t, "r", encoding="utf-8") as f:
                content = f.read()
            if "p1xi3" not in content:
                with open(t, "a", encoding="utf-8") as f:
                    f.write(snippet)
                print(f"  {GREEN}(^_^) [ok] Exported OPENAI_API_BASE into:{NC} {t}")
                configured += 1

    if configured > 0:
        print(f"       • Instant support for CLI agents: Aider, Ollama CLI, LangChain, curl")

def main():
    print_header()

    bridge_ok, models = check_bridge_status()
    if bridge_ok:
        active_str = ", ".join(models) if models else "llama-server ready"
        print(f"  {GREEN}(^_^) [ok] USB Port Forward Active:{NC} {API_BASE}")
        print(f"  Active model on Pixel 7: {BOLD}{active_str}{NC}\n")
    else:
        print(f"  {YELLOW}(o.o) [!] USB bridge is not currently connected or llama-server is loading.{NC}")
        print(f"  Run '{BOLD}p1xi3 bridge{NC}' to activate the USB link when ready.\n")

    ide_map = detect_ides()

    print(f"{BOLD}Detected Development Environments on this Machine:{NC}")
    items_list = list(ide_map.items())
    for idx, (k, info) in enumerate(items_list, 1):
        status_tag = f"{GREEN}[DETECTED]{NC}" if info["detected"] else f"{DIM}[Not found]{NC}"
        print(f"  {BOLD}{idx}){NC} {info['name']:<50} {status_tag}")

    print(f"\n{BOLD}Actions:{NC}")
    print(f"  {GREEN}A){NC} Configure ALL detected IDEs & Shell automatically")
    print(f"  {GREEN}1-{len(items_list)}){NC} Configure specific IDE / tool")
    print(f"  {YELLOW}Q){NC} Back to main menu\n")

    try:
        choice = input(f"{YELLOW}Select an option [A, 1-{len(items_list)}, Q]: {NC}").strip()
    except (KeyboardInterrupt, EOFError):
        print("\nExiting.")
        return

    print()
    if choice.lower() in ["q", "exit"]:
        return
    elif choice.lower() in ["a", "all"]:
        for k, info in items_list:
            if info["detected"]:
                print(f"{BOLD}Configuring {info['name']}...{NC}")
                if k == "zed":
                    configure_zed(info)
                elif k == "continue":
                    configure_continue(info)
                elif k == "neovim":
                    configure_neovim(info)
                elif k == "shell_env":
                    configure_shell_env(info)
                print()
        print(f"{GREEN}{BOLD}(^_^) All detected IDEs successfully configured to use p1xi3!{NC}")
    else:
        try:
            sel_idx = int(choice) - 1
            if 0 <= sel_idx < len(items_list):
                k, info = items_list[sel_idx]
                print(f"{BOLD}Configuring {info['name']}...{NC}")
                if k == "zed":
                    configure_zed(info)
                elif k in ["continue", "vscode", "cursor", "windsurf", "jetbrains"]:
                    configure_continue(ide_map["continue"])
                elif k == "neovim":
                    configure_neovim(info)
                elif k == "shell_env":
                    configure_shell_env(info)
                print(f"\n{GREEN}{BOLD}(^_^) Configuration complete for {info['name']}.{NC}")
            else:
                print(f"{RED}Invalid selection.{NC}")
        except ValueError:
            print(f"{RED}Invalid selection.{NC}")

if __name__ == "__main__":
    main()
