#!/usr/bin/env bash
# ==============================================================================
# p1xi3 (._.) - IDE & Agent Integrator Wrapper
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 "$SCRIPT_DIR/ide_integrator.py" "$@"
