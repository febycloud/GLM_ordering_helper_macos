#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

source "$ROOT/scripts/portable_env.sh"

PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Setting up the GLM Coding Helper CPU backend for macOS."
echo "Using Python: $($PYTHON_BIN --version 2>&1)"
echo

"$PYTHON_BIN" "scripts/setup_backend.py" --target cpu

echo
echo "Setup complete. You can now double-click start-backend-pipeline-gui.command."
read -r -p "Press Enter to close this window..." _
