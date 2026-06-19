#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "$ROOT/scripts/portable_env.sh"

MODE="${CNCAPTCHA_MODE:-auto}"
HEADLESS="${CNCAPTCHA_HEADLESS:-0}"
PORT="${CNCAPTCHA_PORT:-8888}"
CPU_WORKERS="${CNCAPTCHA_CPU_OCR_WORKERS:-0}"
YOLO_DEVICE="${CNCAPTCHA_YOLO_DEVICE:-}"

find_venv_python() {
  local name="$1"
  local dir="$ROOT"
  for _ in 1 2 3 4 5; do
    local candidate="$dir/$name/bin/python"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    local parent
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done
  return 1
}

test_backend_python() {
  local python_path="$1"
  [[ -n "$python_path" && -x "$python_path" ]] || return 1
  "$python_path" -c "import ultralytics, PIL, cv2, numpy; from paddleocr import TextRecognition" >/dev/null 2>&1
}

cpu_python="${CNCAPTCHA_CPU_OCR_PYTHON:-$(find_venv_python ".venv_paddle" || true)}"
gpu_python="${CNCAPTCHA_GPU_OCR_PYTHON:-$(find_venv_python ".venv_paddle_gpu" || true)}"

case "$MODE" in
  gpu)
    if test_backend_python "$gpu_python"; then
      main_python="$gpu_python"
    else
      echo "GPU backend environment is missing or incomplete: ${gpu_python:-<not found>}" >&2
      echo "Run: python3 scripts/setup_backend.py --target gpu" >&2
      exit 1
    fi
    ;;
  cpu|cpu_parallel)
    if test_backend_python "$cpu_python"; then
      main_python="$cpu_python"
    else
      echo "CPU backend environment is missing or incomplete: ${cpu_python:-<not found>}" >&2
      echo "Run: python3 scripts/setup_backend.py --target cpu" >&2
      exit 1
    fi
    ;;
  auto)
    if test_backend_python "$gpu_python"; then
      main_python="$gpu_python"
    elif test_backend_python "$cpu_python"; then
      main_python="$cpu_python"
    else
      echo "No usable backend environment found." >&2
      echo "Run: python3 scripts/setup_backend.py --target cpu" >&2
      exit 1
    fi
    ;;
  *)
    echo "Invalid CNCAPTCHA_MODE=$MODE; use auto, gpu, cpu, or cpu_parallel." >&2
    exit 1
    ;;
esac

args=("scripts/tools/start_backend.py" "--mode" "$MODE" "--port" "$PORT")
if [[ "$HEADLESS" == "1" || "$HEADLESS" == "true" ]]; then
  args+=("--headless")
fi
if [[ "$CPU_WORKERS" =~ ^[0-9]+$ && "$CPU_WORKERS" -gt 0 ]]; then
  args+=("--cpu-workers" "$CPU_WORKERS")
fi
if [[ -n "$YOLO_DEVICE" ]]; then
  args+=("--yolo-device" "$YOLO_DEVICE")
fi

echo "Using backend Python: $main_python"
exec "$main_python" "${args[@]}"
