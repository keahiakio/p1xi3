#!/usr/bin/env python3
"""
Host-side USB Chat Client for Air-Gapped Pixel 7 LLM
Communicates with llama-server or Ollama over ADB forwarded port 11434.
"""

import sys
import json
import time
import urllib.request
import urllib.error

ENDPOINT = "http://127.0.0.1:11434"

def check_connection():
    for test_path in ["/health", "/v1/models", "/api/tags"]:
        try:
            req = urllib.request.Request(f"{ENDPOINT}{test_path}", method="GET")
            with urllib.request.urlopen(req, timeout=2) as response:
                return True
        except Exception:
            continue
    return False

def stream_chat(prompt: str, history: list):
    """
    Attempts to stream via llama.cpp /v1/chat/completions or fallback to Ollama /api/generate
    """
    history.append({"role": "user", "content": prompt})

    # Try OpenAI-compatible endpoint (standard on llama-server)
    payload = {
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
    except urllib.error.HTTPError as e:
        # Fallback to Ollama native /api/generate
        url_ollama = f"{ENDPOINT}/api/generate"
        ollama_payload = {
            "prompt": prompt,
            "stream": True
        }
        data_ollama = json.dumps(ollama_payload).encode("utf-8")
        req_ollama = urllib.request.Request(url_ollama, data=data_ollama, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req_ollama, timeout=120) as resp:
            for line in resp:
                line_str = line.decode("utf-8").strip()
                if not line_str:
                    continue
                try:
                    chunk = json.loads(line_str)
                    resp_piece = chunk.get("response", "")
                    sys.stdout.write(resp_piece)
                    sys.stdout.flush()
                    full_response += resp_piece
                    token_count += 1
                except json.JSONDecodeError:
                    continue

    dt = time.time() - t0
    tps = token_count / dt if dt > 0 else 0
    print(f"\n\n\033[90m[{token_count} tokens in {dt:.2f}s | {tps:.2f} t/s]\033[0m\n")
    history.append({"role": "assistant", "content": full_response})

def main():
    print("\033[1;34m=== p1xi3 (o.o) : Pixel 7 Air-Gapped USB LLM Client ===\033[0m")
    print(f"Connecting to p1xi3 over USB at \033[1;32m{ENDPOINT}\033[0m ...\n")

    if not check_connection():
        print("\033[1;31m(-_-) [!] Could not connect to LLM server on localhost:11434.\033[0m")
        print("Please verify:")
        print("  1. 'adb forward tcp:11434 tcp:11434' is active (run ./scripts/06_start_bridge.sh)")
        print("  2. 'llama-server' or 'ollama' is actively listening inside Termux on the phone.")
        sys.exit(1)

    print("\033[1;32m(^_^) [ok] Connected to Pixel 7! Type your prompt or 'exit' / 'quit' to end.\033[0m\n")

    history = []
    while True:
        try:
            prompt = input("\033[1;33mUser > \033[0m").strip()
            if not prompt:
                continue
            if prompt.lower() in ["exit", "quit"]:
                break

            sys.stdout.write("\033[1;36mPixel 7 > \033[0m")
            sys.stdout.flush()
            stream_chat(prompt, history)
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

if __name__ == "__main__":
    main()
