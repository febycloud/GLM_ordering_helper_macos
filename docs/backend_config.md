# Backend Configuration

This macOS fork is tuned for MacBook Air M2 / macOS 26 and uses the local CPU
pipeline backend. The normal entry point is:

```bash
./"GLM Coding Helper.command"
```

For manual setup:

```bash
./scripts/setup_backend_macos.sh
```

For manual startup:

```bash
./.venv_paddle/bin/python backend/gui.py
```

Headless startup:

```bash
./.venv_paddle/bin/python -m backend.server
```

## macOS Defaults

The portable environment script sets MacBook Air M2-friendly defaults:

| Setting | Default |
| --- | --- |
| Host | `127.0.0.1` |
| Port | `8888` |
| OCR mode | `cpu_parallel` |
| YOLO device | `cpu` |
| Pipeline YOLO workers | `1` |
| Pipeline OCR workers | `2` |

The port intentionally stays `8888`, matching the userscript default backend
URL.

## Portable Files

Runtime files are kept inside the project folder:

| Path | Purpose |
| --- | --- |
| `.venv_paddle/` | Python virtual environment |
| `.cache/` | pip and package caches |
| `.config/` | local tool config |
| `.paddle_home/` | Paddle cache |
| `.paddlex_cache/` | PaddleX cache |

To uninstall, delete the project folder.

## Useful Environment Variables

Set these before starting the backend if you need to override defaults:

```bash
export CNCAPTCHA_PIPELINE_OCR_WORKERS=3
export CNCAPTCHA_CPU_OCR_MODEL=PP-OCRv6_tiny_rec
export CNCAPTCHA_DETECTOR_PATH="/path/to/yolo-captcha-detector.pt"
```

The recommended MacBook Air M2 default is still `1` YOLO worker and `2` OCR
workers to avoid sustained thermal load.

## Health Check

After starting the backend:

```bash
curl http://127.0.0.1:8888/health
```

## Notes

- macOS uses CPU inference only.
- The main flow does not rely on screen capture; the userscript sends the
  captcha image directly to `/captcha_direct`.
- Keep Chrome zoom at `100%` for best coordinate behavior.
