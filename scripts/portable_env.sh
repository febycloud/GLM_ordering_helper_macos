#!/usr/bin/env bash

# Keep package/model caches inside this folder so the macOS install behaves
# like a portable app bundle.
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-$ROOT/.cache/pip}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$ROOT/.config}"
export PADDLE_HOME="${PADDLE_HOME:-$ROOT/.paddle_home/.cache/paddle}"
export PADDLE_PDX_CACHE_HOME="${PADDLE_PDX_CACHE_HOME:-$ROOT/.paddlex_cache}"
export PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK="${PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK:-True}"
export YOLO_CONFIG_DIR="${YOLO_CONFIG_DIR:-$ROOT/.config/Ultralytics}"

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
  # MacBook Air M2-friendly defaults: CPU-only, fewer workers, local-only bind.
  export CNCAPTCHA_HOST="${CNCAPTCHA_HOST:-127.0.0.1}"
  export CNCAPTCHA_MODE="${CNCAPTCHA_MODE:-cpu_parallel}"
  export CNCAPTCHA_OCR_MODE="${CNCAPTCHA_OCR_MODE:-cpu_parallel}"
  export CNCAPTCHA_SKIP_GPU_DETECT="${CNCAPTCHA_SKIP_GPU_DETECT:-1}"
  export CNCAPTCHA_YOLO_DEVICE="${CNCAPTCHA_YOLO_DEVICE:-cpu}"
  export CNCAPTCHA_CPU_OCR_WORKERS="${CNCAPTCHA_CPU_OCR_WORKERS:-2}"
  export CNCAPTCHA_PIPELINE_YOLO_WORKERS="${CNCAPTCHA_PIPELINE_YOLO_WORKERS:-1}"
  export CNCAPTCHA_PIPELINE_OCR_WORKERS="${CNCAPTCHA_PIPELINE_OCR_WORKERS:-2}"
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
  export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
  export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
  export NUMEXPR_NUM_THREADS="${NUMEXPR_NUM_THREADS:-1}"
fi
