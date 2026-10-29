#!/usr/bin/env python3
"""
Host-side USB Chat Client for Air-Gapped Pixel 7 LLM
Communicates with llama-server on Pixel 7 over ADB forwarded port.
Auto-detects active bridge port (11435/11434) to avoid conflict with host Ollama.
"""

import os
import sys
import json
import time
import subprocess
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PORT_FILE = os.path.join(SCRIPT_DIR, ".port")

def discover_port():
    """Detects active forward port from adb forward --list or .port file."""
    # 1. Try checking adb forward --list
    try:
        fwd_out = subprocess.check_output(["adb", "forward", "--list"], stderr=subprocess.DEVNULL).decode("utf-8")
        for line in fwd_out.splitlines():
            # e.g.: "32241FDH2005DM tcp:11435 tcp:11434"
            parts = line.split()
            if len(parts) >= 3 and parts[2] == "tcp:11434":
                host_tcp = parts[1]
                if host_tcp.startswith("tcp:"):
                    return int(host_tcp[4:])
    except Exception:
        pass

    # 2. Try .port file
    if os.path.exists(PORT_FILE):
        try:
            with open(PORT_FILE, "r") as f:
                return int(f.read().strip())
        except Exception:
            pass

    # 3. Defaults: check 11435 then 11434
    for p in [11435, 11434]:
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{p}/v1/models", method="GET")
            with urllib.request.urlopen(req, timeout=1) as resp:
                data = resp.read().decode("utf-8")
                if "llamacpp" in data or "panther" in data or "models" in data:
                    return p
        except Exception:
            continue

    return 11435

PORT = discover_port()
ENDPOINT = f"http://127.0.0.1:{PORT}"

def get_loaded_model():
    """Fetches the active model name from the server."""
    try:
        req = urllib.request.Request(f"{ENDPOINT}/v1/models", method="GET")
        with urllib.request.urlopen(req, timeout=2) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if "data" in data and len(data["data"]) > 0:
                return data["data"][0].get("id", "default")
    except Exception:
        pass
    return "default"

def stream_chat(prompt: str, history: list, model_id: str):
    history.append({"role": "user", "content": prompt})

    payload = {
        "model": model_id,
        "messages": history,
        "temperature": 0.7,
        "stream": True,
        "max_tokens": 1024
    }

    url = f"{ENDPOINT}/v1/chat/completions"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})

    t0 = time.time()
    token_count = 0
    full_response = ""

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            for line in resp:
                line_str = line.decode("utf-8").strip()
                if not line_str or line_str == "data: [DONE]":
                    continue
                if line_str.startswith("data: "):
                    line_str = line_str[6:]
                try:
                    chunk = json.loads(line_str)
                    delta = chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
                    if delta:
                        sys.stdout.write(delta)
                        sys.stdout.flush()
                        full_response += delta
                        token_count += 1
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        print(f"\n\033[31m(- -) [!] Error during streaming: {e}\033[0m")
        return

    dt = time.time() - t0
    tps = token_count / dt if dt > 0 else 0
    print(f"\n\n\033[90m[{token_count} tokens in {dt:.2f}s | {tps:.2f} t/s]\033[0m\n")
    history.append({"role": "assistant", "content": full_response})

def main():
    global PORT, ENDPOINT
    PORT = discover_port()
    ENDPOINT = f"http://127.0.0.1:{PORT}"

    print("\033[1;36m=== p1xi3 (._.) : Pixel 7 Air-Gapped USB LLM Client ===\033[0m")
    print(f"Connecting to Pixel 7 over USB at \033[1;32m{ENDPOINT}\033[0m ...")

    model_id = get_loaded_model()
    if model_id == "default":
        # Check if bridge needs starting
        print(f"\033[1;31m(- -) [!] Could not communicate with llama-server on localhost:{PORT}.\033[0m")
        print("Please verify:")
        print(f"  1. USB bridge is active: run ./scripts/06_start_bridge.sh")
        print("  2. 'bash ~/start_server.sh' is currently running inside Termux on your Pixel 7.")
        sys.exit(1)

    clean_model_name = os.path.basename(model_id)
    print(f"\033[1;32m(^_^) [ok] Connected to Pixel 7!\033[0m")
    print(f"Loaded Model : \033[1;33m{clean_model_name}\033[0m")
    print("Type your message or 'exit' / 'quit' to finish.\n")

    history = []
    while True:
        try:
            prompt = input("\033[1;32mUser > \033[0m").strip()
            if not prompt:
                continue
            if prompt.lower() in ["exit", "quit", "q"]:
                break

            sys.stdout.write("\033[1;36mPixel 7 > \033[0m")
            sys.stdout.flush()
            stream_chat(prompt, history, model_id)
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

if __name__ == "__main__":
    main()
