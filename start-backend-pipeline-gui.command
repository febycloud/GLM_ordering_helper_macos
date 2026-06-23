#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

source "$ROOT/scripts/portable_env.sh"

cat <<'EOF'
------------------------------------------------------------
 GLM Coding Helper Pipeline Backend (GUI / macOS)
------------------------------------------------------------
 Starts the Tk monitor and backend.server worker pipeline.
 Closing the GUI window stops the backend child process.
 MacBook Air M2 defaults: CPU-only, 1 YOLO worker, 2 OCR workers.
 Port stays 8888.
------------------------------------------------------------

EOF

test_gui_python() {
  local python_path="$1"
  [[ -n "$python_path" && -x "$python_path" ]] || return 1
  "$python_path" -c "import fastapi, uvicorn, psutil, tkinter, ultralytics, paddleocr, paddlex, paddle, cv2, PIL, numpy" >/dev/null 2>&1
}

python_candidates=(
  "$ROOT/.venv_paddle/bin/python"
  "$ROOT/.venv_paddle_gpu/bin/python"
  "$ROOT/venv/bin/python"
)

main_python=""
for candidate in "${python_candidates[@]}"; do
  if test_gui_python "$candidate"; then
    main_python="$candidate"
    break
  fi
done

if [[ -z "$main_python" ]]; then
  for candidate in "${python_candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      main_python="$candidate"
      break
    fi
  done
fi

if [[ -z "$main_python" ]]; then
  echo "No Python virtual environment found."
  echo "Run one-click-start.command or setup-backend-macos.command first."
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

if ! "$main_python" -c "import tkinter" >/dev/null 2>&1; then
  echo "This Python is missing tkinter."
  echo "Homebrew users can install it with: brew install python-tk@3.12"
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

if ! test_gui_python "$main_python"; then
  echo "Backend dependencies are incomplete in: $main_python"
  echo "Run one-click-start.command or setup-backend-macos.command to repair the CPU backend environment."
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

occupying_pid="$(lsof -ti tcp:8888 -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
if [[ -n "$occupying_pid" ]]; then
  echo "Port 8888 is already in use."
  ps -p "$occupying_pid" -o pid=,comm=,command= 2>/dev/null || true
  read -r -p "Enter 1 to stop it and restart, or press Enter to exit: " choice
  if [[ "$choice" == "1" ]]; then
    kill "$occupying_pid" 2>/dev/null || true
    sleep 2
  else
    exit 1
  fi
fi

echo "Using Python: $main_python"
exec "$main_python" "$ROOT/backend/gui.py"
