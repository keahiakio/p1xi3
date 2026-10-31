# Contributing to p1xi3

Thank you for your interest in contributing to `p1xi3`! We welcome contributions to help make edge LLM inference on Pixel devices more robust, efficient, and accessible.

---

## Code of Conduct

This project is governed by the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold its standards.

---

## Core Security & Architectural Principles

When contributing to `p1xi3`, the following core design constraints must be maintained:

1. **Strict Air-Gap Guarantees**: `p1xi3` exists to provide a completely isolated, zero-network LLM inference coprocessor. Under no circumstances should any feature introduce network calls, cloud dependencies, remote telemetry, or phone wireless interfaces (Wi-Fi, Bluetooth, mobile data).
2. **Deterministic USB Bridge**: All host-device communication flows strictly over USB-C via local loopback ADB port forwarding (`127.0.0.1:11435` -> phone `127.0.0.1:11434`).
3. **Android & ARM64 Compatibility**: Termux scripts and `llama.cpp` binaries must honor Android ARM64 constraints (including 16KB page alignment on Android 15+).
4. **Permissive Licensing**: Do not introduce dependencies that violate the project's MIT License or upstream software licenses.

---

## Development Setup

### Prerequisites
- Python 3.10+
- Android Platform Tools (`adb`, `fastboot`)
- Git

### Setup Instructions
1. Fork and clone the repository:
   ```bash
   git clone https://github.com/<your-username>/p1xi3.git
   cd p1xi3
   ```
2. Set up a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. Test Python script compilation:
   ```bash
   python3 -m py_compile client.py tui.py wizard.py
   ```

---

## Areas for Contribution

- **IDE & Agent Adapters**: Expanding automated linking support for new editors, coding agents, or terminal tools.
- **Model Presets**: Benchmarking and tuning context size, thread count, and quantization presets for various Pixel generations (Pixel 6, 7, 8, 9).
- **TUI & CLI Enhancements**: Refining the terminal dashboard, monitor metrics, or setup wizard.
- **Documentation**: Improving provisioning guides, troubleshooting tips, and hardware notes.

---

## Coding Standards

- Follow [PEP 8](https://peps.python.org/pep-0008/) style standards for Python code.
- Bash scripts should use `set -euo pipefail` where appropriate, provide clear status messages, and clean up temporary resources.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat:`, `fix:`, `docs:`, `perf:`).

---

## Pull Request Process

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```
2. Commit your changes with clear, descriptive commit messages.
3. Test locally and ensure Python scripts compile cleanly:
   ```bash
   python3 -m py_compile *.py
   ```
4. Push your branch to your fork and submit a Pull Request to `keahiakio/p1xi3:main`.
5. Fill out the PR template to describe the changes and verification steps.
