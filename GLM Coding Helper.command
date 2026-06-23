#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

source "$ROOT/scripts/portable_env.sh"

cat <<'EOF'
------------------------------------------------------------
 GLM Coding Helper for MacBook Air M2 (GUI)
------------------------------------------------------------
 First run installs/repairs the local CPU backend environment.
 Then it opens the Tk backend monitor window.
 Port stays 8888.
------------------------------------------------------------

EOF

VENV_PY="$ROOT/.venv_paddle/bin/python"

needs_install=0
if [[ ! -x "$VENV_PY" ]]; then
  needs_install=1
elif ! "$VENV_PY" -c "import fastapi, uvicorn, psutil, tkinter, ultralytics, paddleocr, paddlex, paddle, cv2, PIL, numpy" >/dev/null 2>&1; then
  needs_install=1
fi

if [[ "$needs_install" -eq 1 ]]; then
  echo "[INFO] Installing or repairing the local macOS CPU backend environment..."
  if ! "$ROOT/scripts/setup_backend_macos.sh"; then
    echo
    echo "[ERROR] Setup failed. Check the messages above."
    read -r -p "Press Enter to close this window..." _
    exit 1
  fi
fi

if [[ ! -f "$ROOT/models/weights/yolo-captcha-detector.pt" ]]; then
  echo "[ERROR] Missing detector weight:"
  echo "  $ROOT/models/weights/yolo-captcha-detector.pt"
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

if ! "$VENV_PY" -c "import tkinter" >/dev/null 2>&1; then
  echo "[ERROR] This Python is missing tkinter."
  echo "Homebrew users can install it with: brew install python-tk@3.12"
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

occupying_pid="$(lsof -ti tcp:8888 -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
if [[ -n "$occupying_pid" ]]; then
  echo "[WARN] Port 8888 is already in use."
  ps -p "$occupying_pid" -o pid=,comm=,command= 2>/dev/null || true
  read -r -p "Enter 1 to stop it and restart, or press Enter to exit: " choice
  if [[ "$choice" == "1" ]]; then
    kill "$occupying_pid" 2>/dev/null || true
    sleep 2
  else
    exit 1
  fi
fi

echo "[INFO] Starting GUI backend on http://127.0.0.1:8888"
exec "$VENV_PY" "$ROOT/backend/gui.py"
