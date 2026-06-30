#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

cat <<'EOF'
------------------------------------------------------------
 GLM Coding Helper macOS Uninstaller
------------------------------------------------------------
 This removes local runtime files created inside this folder:
 - Python virtual environments
 - pip/Paddle/PaddleX/Ultralytics caches
 - downloaded OCR model cache
 - runtime logs and captured debug images

 It does NOT remove:
 - source code
 - Git history
 - system Python / Homebrew packages
 - Chrome / Tampermonkey
------------------------------------------------------------

EOF

if [[ ! -f "$ROOT/one-click-start.command" || ! -d "$ROOT/scripts" ]]; then
  echo "[ERROR] This does not look like the GLM Coding Helper project folder:"
  echo "  $ROOT"
  read -r -p "Press Enter to close..." _
  exit 1
fi

occupying_pids="$(lsof -ti tcp:8888 -sTCP:LISTEN 2>/dev/null | sort -u || true)"
if [[ -n "$occupying_pids" ]]; then
  echo "[WARN] Something is listening on port 8888:"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    ps -p "$pid" -o pid=,comm=,command= 2>/dev/null || true
  done <<< "$occupying_pids"
  echo
  read -r -p "Stop these process(es) before uninstall? [y/N] " stop_choice
  if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
    done <<< "$occupying_pids"
    sleep 2
  fi
fi

targets=(
  ".venv_paddle"
  ".venv_paddle_gpu"
  ".cache"
  ".config"
  ".home"
  ".paddle_home"
  ".paddle_home_gpu"
  ".paddlex_cache"
  ".paddlex_cache_cpu"
  ".paddlex_cache_gpu"
  "official_models"
  "logs"
  "dataset"
  "dist"
  "processed"
  "runs"
  "__pycache__"
)

existing=()
for target in "${targets[@]}"; do
  if [[ -e "$ROOT/$target" ]]; then
    existing+=("$target")
  fi
done

if [[ "${#existing[@]}" -eq 0 ]]; then
  echo "[OK] No local runtime environment or cache folders were found."
  read -r -p "Press Enter to close..." _
  exit 0
fi

echo "The following folders/files will be removed from:"
echo "  $ROOT"
echo
for target in "${existing[@]}"; do
  echo "  - $target"
done
echo

read -r -p "Type DELETE to remove them: " confirm
if [[ "$confirm" != "DELETE" ]]; then
  echo "Canceled. Nothing was removed."
  read -r -p "Press Enter to close..." _
  exit 0
fi

for target in "${existing[@]}"; do
  rm -rf "$ROOT/$target"
done

find "$ROOT" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
find "$ROOT" -type f \( -name "*.pyc" -o -name "*.pyo" -o -name "*.log" -o -name "*.tmp" \) -delete 2>/dev/null || true

cat <<'EOF'

[OK] Local GLM Coding Helper environment files were removed.

You can still keep this source folder. To reinstall later, double-click:
  one-click-start.command

To fully uninstall everything, delete this entire project folder after this
script finishes.
EOF

read -r -p "Press Enter to close..." _
