"""
Pipeline Backend GUI - Tk 监控面板

启动 backend.server 子进程，捕获 stdout 写入日志框；
定期拉取 /health 和 /recent，实时显示在状态栏和识别列表里。
"""
import os
import platform
import sys
import json
import queue
import threading
import subprocess
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path
from collections import deque
import tkinter as tk
from tkinter import ttk
import tkinter.font as tkfont

if getattr(sys, "frozen", False):
    ROOT = Path(sys._MEIPASS)
else:
    ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# ── 配置 ───────────────────────────────────────────────
BACKEND_HOST = "127.0.0.1"
BACKEND_PORT = 8888
BACKEND_URL = f"http://{BACKEND_HOST}:{BACKEND_PORT}"
POLL_HEALTH_MS = 1000
POLL_RECENT_MS = 500
MAX_LOG_LINES = 500
MAX_RECENT_SHOWN = 20
BACKEND_SHUTDOWN_TIMEOUT = 30
CONFIG_PATH = ROOT / "config.json"
OCR_MODEL_CHOICES = {
    "极速模式（v6 tiny，推荐）": "PP-OCRv6_tiny_rec",
    "精准模式（v6 medium）": "PP-OCRv6_medium_rec",
    "稳定模式（v5 server）": "PP-OCRv5_server_rec",
}

# 颜色
BG = "#f0f2f5"
FG_NORMAL = "#262626"
FG_SUCCESS = "#52c41a"
FG_WARN = "#faad14"
FG_ERROR = "#ff4d4f"
FG_INFO = "#1890ff"
FG_GREY = "#8c8c8c"
IS_MACOS = sys.platform == "darwin"


def _font_family(preferred: list[str], fallback: str = "TkDefaultFont") -> str:
    available = set(tkfont.families())
    for family in preferred:
        if family in available:
            return family
    return tkfont.nametofont(fallback).actual("family")


def _platform_fonts() -> tuple[str, str]:
    if IS_MACOS:
        return (
            _font_family(["SF Pro Text", ".AppleSystemUIFont", "Helvetica Neue"]),
            _font_family(["SF Mono", "Menlo", "Monaco"], "TkFixedFont"),
        )
    return (
        _font_family(["Microsoft YaHei UI", "Segoe UI", "Arial"]),
        _font_family(["Cascadia Mono", "Consolas", "Courier New"], "TkFixedFont"),
    )


def _platform_window_size() -> tuple[str, tuple[int, int]]:
    if IS_MACOS:
        return "820x640", (720, 520)
    return "720x600", (640, 480)


state = {
    "backend_proc": None,
    "log_queue": queue.Queue(),
    "log_lines": deque(maxlen=MAX_LOG_LINES),
    "recent_results": deque(maxlen=MAX_RECENT_SHOWN),
    "last_seen_req_id": 0,
    "health": {"status": "starting", "ready_workers": 0, "alive_workers": 0,
               "workers": 0, "n_yolo": 0, "n_ocr": 0, "port": BACKEND_PORT},
    "port": BACKEND_PORT,
}


def _load_config() -> dict:
    if not CONFIG_PATH.exists():
        return {}
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_config(updates: dict) -> None:
    data = _load_config()
    data.update(updates)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _ocr_model_label(model_name: str) -> str:
    for label, value in OCR_MODEL_CHOICES.items():
        if value == model_name:
            return label
    return f"自定义：{model_name}" if model_name else "未设置"


def _read_proc_stdout(proc: subprocess.Popen):
    """后台线程：读子进程 stdout/stderr，写入 log_queue"""
    for stream in (proc.stdout, proc.stderr):
        if stream is None:
            continue
        try:
            for line in iter(stream.readline, b""):
                try:
                    text = line.decode("utf-8", errors="replace").rstrip("\r\n")
                except Exception:
                    text = str(line)
                if text:
                    state["log_queue"].put(text)
        except Exception:
            pass


def _http_get_json(path: str, timeout: float = 3.0):
    try:
        with urllib.request.urlopen(BACKEND_URL + path, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except (urllib.error.URLError, ConnectionError, OSError, json.JSONDecodeError):
        return None


def _format_ts(ts: float) -> str:
    return datetime.fromtimestamp(ts).strftime("%H:%M:%S")


def _apply_portable_env(env: dict[str, str]) -> None:
    if os.name == "nt":
        return
    env.setdefault("PIP_CACHE_DIR", str(ROOT / ".cache" / "pip"))
    env.setdefault("XDG_CACHE_HOME", str(ROOT / ".cache"))
    env.setdefault("XDG_CONFIG_HOME", str(ROOT / ".config"))
    env.setdefault("PADDLE_HOME", str(ROOT / ".paddle_home" / ".cache" / "paddle"))
    env.setdefault("PADDLE_PDX_CACHE_HOME", str(ROOT / ".paddlex_cache"))
    env.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
    env.setdefault("YOLO_CONFIG_DIR", str(ROOT / ".config" / "Ultralytics"))
    if sys.platform == "darwin" and platform.machine() == "arm64":
        env.setdefault("CNCAPTCHA_HOST", "127.0.0.1")
        env.setdefault("CNCAPTCHA_MODE", "cpu_parallel")
        env.setdefault("CNCAPTCHA_OCR_MODE", "cpu_parallel")
        env.setdefault("CNCAPTCHA_SKIP_GPU_DETECT", "1")
        env.setdefault("CNCAPTCHA_YOLO_DEVICE", "cpu")
        env.setdefault("CNCAPTCHA_CPU_OCR_WORKERS", "2")
        env.setdefault("CNCAPTCHA_PIPELINE_YOLO_WORKERS", "1")
        env.setdefault("CNCAPTCHA_PIPELINE_OCR_WORKERS", "2")


class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("GLM Coding Captcha - Pipeline Backend")
        geometry, minsize = _platform_window_size()
        self.root.geometry(geometry)
        self.root.configure(bg=BG)
        self.root.minsize(*minsize)
        self.ui_font, self.mono_font = _platform_fonts()

        if IS_MACOS:
            try:
                self.root.tk.call("tk::unsupported::MacWindowStyle", "style", self.root._w, "document", "closeBox resizable")
            except tk.TclError:
                pass

        style = ttk.Style()
        try:
            style.theme_use("aqua" if IS_MACOS else "clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background=BG)
        style.configure("TLabel", background=BG, font=(self.ui_font, 10))
        style.configure("TLabelFrame", background=BG, font=(self.ui_font, 10))
        style.configure("TLabelFrame.Label", background=BG, font=(self.ui_font, 10, "bold"))
        style.configure("Treeview", rowheight=26 if IS_MACOS else 22, font=(self.ui_font, 10))
        style.configure("Treeview.Heading", font=(self.ui_font, 10, "bold"))
        style.configure("Status.TLabel", font=(self.ui_font, 12, "bold"))
        style.configure("Big.TLabel", font=(self.ui_font, 15 if IS_MACOS else 14, "bold"))
        style.configure("Ok.TLabel", foreground=FG_SUCCESS, font=(self.ui_font, 11, "bold"))
        style.configure("Warn.TLabel", foreground=FG_WARN, font=(self.ui_font, 11, "bold"))
        style.configure("Err.TLabel", foreground=FG_ERROR, font=(self.ui_font, 11, "bold"))
        style.configure("Info.TLabel", foreground=FG_INFO, font=(self.ui_font, 11, "bold"))

        self._build_ui()
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        self._start_backend()
        self.root.after(100, self._poll_logs)
        self.root.after(POLL_HEALTH_MS, self._poll_health)
        self.root.after(POLL_RECENT_MS, self._poll_recent)

    def _build_ui(self):
        # 顶部状态栏
        pad_x = 16 if IS_MACOS else 12
        top = ttk.Frame(self.root, padding=f"{pad_x} 12")
        top.pack(fill=tk.X)
        top.columnconfigure(1, weight=1)

        ttk.Label(top, text="智谱 GLM 验证码后端 (Pipeline)", style="Big.TLabel").grid(
            row=0, column=0, columnspan=4, sticky=tk.W, pady=(0, 8))

        # 第一行：系统状态
        ttk.Label(top, text="系统状态:").grid(row=1, column=0, sticky=tk.W, pady=2)
        self.lbl_status = ttk.Label(top, text="启动中…", style="Warn.TLabel")
        self.lbl_status.grid(row=1, column=1, sticky=tk.W, pady=2)

        # 第二行：worker 就绪
        ttk.Label(top, text="Workers:").grid(row=2, column=0, sticky=tk.W, pady=2)
        self.lbl_workers = ttk.Label(top, text="0/0")
        self.lbl_workers.grid(row=2, column=1, sticky=tk.W, pady=2)
        ttk.Label(top, text="YOLO / OCR:").grid(row=2, column=2, sticky=tk.W, padx=(20, 4), pady=2)
        self.lbl_pipeline = ttk.Label(top, text="-/-")
        self.lbl_pipeline.grid(row=2, column=3, sticky=tk.W, pady=2)

        # 第三行：端口 / 地址
        ttk.Label(top, text="监听:").grid(row=3, column=0, sticky=tk.W, pady=2)
        self.lbl_url = ttk.Label(top, text=f"{BACKEND_URL}", style="Info.TLabel")
        self.lbl_url.grid(row=3, column=1, columnspan=3, sticky=tk.W, pady=2)

        # 中间：最近识别结果
        mid = ttk.LabelFrame(self.root, text="最近识别结果（最新在上）", padding="8")
        mid.pack(fill=tk.BOTH, expand=True, padx=pad_x, pady=(4, 6))

        cols = ("time", "prompt", "pred", "conf", "ms", "yolo", "ocr", "req")
        self.tree = ttk.Treeview(mid, columns=cols, show="headings", height=8)
        for col, w, anchor in [
            ("time", 76, tk.W), ("prompt", 100, tk.W), ("pred", 130, tk.W),
            ("conf", 70, tk.E), ("ms", 70, tk.E), ("yolo", 70, tk.E),
            ("ocr", 70, tk.E), ("req", 70, tk.E),
        ]:
            self.tree.heading(col, text=col.upper())
            self.tree.column(col, width=w, anchor=anchor)
        self.tree.tag_configure("ok", foreground=FG_SUCCESS)
        self.tree.tag_configure("err", foreground=FG_ERROR)
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        sb = ttk.Scrollbar(mid, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        sb.pack(side=tk.RIGHT, fill=tk.Y)

        # 底部：实时日志
        bot = ttk.LabelFrame(self.root, text="后端日志（stdout）", padding="6")
        bot.pack(fill=tk.BOTH, expand=False, padx=pad_x, pady=(0, 10))
        self.log_box = tk.Text(bot, height=10, font=(self.mono_font, 11 if IS_MACOS else 9),
                               bg="#1e1e1e", fg="#d4d4d4", insertbackground="#d4d4d4",
                               relief=tk.FLAT, wrap=tk.NONE, padx=8, pady=6)
        self.log_box.tag_configure("info", foreground="#d4d4d4")
        self.log_box.tag_configure("ready", foreground=FG_SUCCESS)
        self.log_box.tag_configure("warn", foreground=FG_WARN)
        self.log_box.tag_configure("err", foreground=FG_ERROR)
        self.log_box.tag_configure("ts", foreground=FG_GREY)
        self.log_box.configure(state=tk.DISABLED)
        self.log_box.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        log_sb = ttk.Scrollbar(bot, orient=tk.VERTICAL, command=self.log_box.yview)
        self.log_box.configure(yscrollcommand=log_sb.set)
        log_sb.pack(side=tk.RIGHT, fill=tk.Y)

    def _append_log(self, line: str):
        state["log_lines"].append(line)
        ts = datetime.now().strftime("%H:%M:%S")
        # 着色：[architect] 蓝；worker ready 绿；含 ERROR/Exception/失败 红；含 WARN/⚠ 黄
        tag = "info"
        low = line.lower()
        if "worker ready" in low or "✓" in line or "就绪" in line or "warmed" in low:
            tag = "ready"
        elif "error" in low or "exception" in low or "traceback" in low or "fail" in low or "err:" in low:
            tag = "err"
        elif "warn" in low or "⚠" in line or "warning" in low:
            tag = "warn"
        elif line.startswith("[architect]"):
            tag = "info"

        self.log_box.configure(state=tk.NORMAL)
        self.log_box.insert(tk.END, f"[{ts}] ", "ts")
        self.log_box.insert(tk.END, line + "\n", tag)
        # 裁剪到 MAX_LOG_LINES
        line_count = int(self.log_box.index("end-1c").split(".")[0])
        if line_count > MAX_LOG_LINES:
            self.log_box.delete("1.0", f"{line_count - MAX_LOG_LINES}.0")
        self.log_box.see(tk.END)
        self.log_box.configure(state=tk.DISABLED)

    def _start_backend(self):
        """拉起 backend.server 子进程"""
        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"
        env["PYTHONUTF8"] = "1"
        _apply_portable_env(env)
        cmd = [sys.executable, "-m", "backend.server"]
        self._append_log(f"$ {sys.executable} -m backend.server")
        try:
            proc = subprocess.Popen(
                cmd, cwd=str(ROOT), env=env,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                bufsize=1,
            )
            state["backend_proc"] = proc
            threading.Thread(target=_read_proc_stdout, args=(proc,),
                             daemon=True).start()
        except Exception as e:
            self._append_log(f"FATAL: 启动后端失败: {e}")

    def _poll_logs(self):
        try:
            while True:
                line = state["log_queue"].get_nowait()
                self._append_log(line)
        except queue.Empty:
            pass
        self.root.after(100, self._poll_logs)

    def _poll_health(self):
        data = _http_get_json("/health")
        if data:
            state["health"] = data
            self._update_health_display(data)
        else:
            # 后端还没起来
            self.lbl_status.config(text="等待后端…", style="Warn.TLabel")
        self.root.after(POLL_HEALTH_MS, self._poll_health)

    def _update_health_display(self, h: dict):
        status = h.get("status", "starting")
        ready = h.get("ready_workers", 0)
        total = h.get("workers", 0)
        alive = h.get("alive_workers", 0)
        n_yolo = h.get("n_yolo", 0)
        n_ocr = h.get("n_ocr", 0)

        if status == "ok" and alive == total:
            self.lbl_status.config(text="● 运行中", style="Ok.TLabel")
        elif status == "starting":
            self.lbl_status.config(text="● 启动中", style="Warn.TLabel")
        else:
            self.lbl_status.config(text=f"● {status}", style="Warn.TLabel")

        self.lbl_workers.config(text=f"{ready}/{total} (alive={alive})")
        self.lbl_pipeline.config(text=f"{n_yolo} YOLO / {n_ocr} OCR")

    def _poll_recent(self):
        data = _http_get_json(f"/recent?limit={MAX_RECENT_SHOWN}")
        if data and "results" in data:
            self._update_recent_display(data["results"])
        self.root.after(POLL_RECENT_MS, self._poll_recent)

    def _update_recent_display(self, results: list):
        # 清空并重绘（识别结果最多 20 条，开销可接受）
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        for item in results:
            ts = _format_ts(item.get("ts", 0))
            if item.get("success") is False:
                self.tree.insert("", tk.END, values=(
                    ts, "-", f"ERR: {item.get('error','?')}", "-", "-", "-", "-",
                    item.get("req_id", "-")
                ), tags=("err",))
                continue
            prompt = "".join(item.get("prompt", []))
            pred = item.get("pred_text", "")
            conf = f"{item.get('confidence', 0):.2f}"
            ms = f"{item.get('elapsed_ms', 0):.0f}"
            yolo = f"{item.get('yolo_ms', 0):.0f}"
            ocr = f"{item.get('ocr_ms', 0):.0f}"
            req = item.get("req_id", "-")
            tag = "ok" if prompt and pred and prompt == pred else ("err" if pred.startswith("ERR") else "ok")
            self.tree.insert("", tk.END, values=(
                ts, prompt, pred, conf, ms, yolo, ocr, req
            ), tags=(tag,))

    def on_close(self):
        proc = state.get("backend_proc")
        if proc and proc.poll() is None:
            try:
                proc.terminate()
                try:
                    # 后端会依次正常停止 YOLO 和 OCR worker；给它足够时间
                    # 避免父进程过早退出，再次强制终止 Paddle 子进程。
                    proc.wait(timeout=BACKEND_SHUTDOWN_TIMEOUT)
                except subprocess.TimeoutExpired:
                    proc.kill()
            except Exception:
                pass
        self.root.destroy()


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
