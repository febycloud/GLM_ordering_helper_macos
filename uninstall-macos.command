#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "GLM Coding Helper macOS uninstaller"
echo
echo "This removes local Python environments and package/model caches created inside:"
echo "  $ROOT"
echo
echo "It does not remove your source files, scripts, models, or README."
echo
read -r -p "Type DELETE to remove local environments and caches: " confirm
if [[ "$confirm" != "DELETE" ]]; then
  echo "Cancelled."
  read -r -p "Press Enter to close this window..." _
  exit 0
fi

targets=(
  ".venv_paddle"
  ".venv_paddle_gpu"
  "venv"
  ".cache"
  ".config"
  ".home"
  ".paddle_home"
  ".paddle_home_gpu"
  ".paddlex_cache"
  ".paddlex_cache_gpu"
  ".pytest_cache"
)

find_targets=(
  "__pycache__"
)

for target in "${targets[@]}"; do
  if [[ -e "$target" ]]; then
    echo "Removing $target"
    rm -rf "$target"
  fi
done

for name in "${find_targets[@]}"; do
  while IFS= read -r path; do
    echo "Removing $path"
    rm -rf "$path"
  done < <(find "$ROOT" -type d -name "$name" -prune)
done

echo
echo "Local environments and caches removed."
echo "You can now delete the GLM Coding Helper folder if you want a full uninstall."
read -r -p "Press Enter to close this window..." _
