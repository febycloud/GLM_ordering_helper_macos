#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

source "$ROOT/scripts/portable_env.sh"

test_gui_python() {
  local python_path="$1"
  [[ -n "$python_path" && -x "$python_path" ]] || return 1
  "$python_path" -c "import fastapi, uvicorn, psutil, tkinter" >/dev/null 2>&1
}

python_candidates=(
  "$ROOT/.venv_paddle_gpu/bin/python"
  "$ROOT/.venv_paddle/bin/python"
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
  echo "Run setup-backend-macos.command first."
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

if ! test_gui_python "$main_python"; then
  echo "Missing GUI/backend dependencies in: $main_python"
  echo "Run setup-backend-macos.command to install or repair the CPU backend environment."
  read -r -p "Press Enter to close this window..." _
  exit 1
fi

echo "Using Python: $main_python"
exec "$main_python" "$ROOT/backend/gui.py"
