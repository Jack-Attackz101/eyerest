#!/usr/bin/env python3
"""
EyeRest — 20-20-20 Eye Rest Rule
Cross-platform system tray app (Windows + macOS + Linux)

Install deps:  pip install pystray pillow
Run:           python eyerest.py
Build .exe:    build.bat  (Windows)
"""

import sys, os, json, time, math, threading
import tkinter as tk
from tkinter import ttk

try:
    import pystray
    from PIL import Image, ImageDraw
except ImportError:
    print("Missing dependencies. Run:  pip install pystray pillow")
    sys.exit(1)

# ── Paths ─────────────────────────────────────────────────────────────────────

if sys.platform == "win32":
    SETTINGS_PATH = os.path.join(os.environ.get("APPDATA", "~"), "EyeRest", "settings.json")
else:
    SETTINGS_PATH = os.path.expanduser("~/.config/eyerest/settings.json")

# ── Design tokens ─────────────────────────────────────────────────────────────

ACCENT    = "#FF6B35"
BG_DARK   = "#111111"
BG_BANNER = "#1A1A1A"
BG_FIELD  = "#2A2A2A"
WHITE     = "#FFFFFF"
GRAY      = "#888888"
GRAY_DIM  = "#333333"

FONT      = "Segoe UI" if sys.platform == "win32" else "SF Pro Display"
FONT_MONO = "Consolas"  if sys.platform == "win32" else "SF Mono"

DEFAULTS = {
    "interval_minutes":      20,
    "warning_minutes":        2,
    "rest_duration_seconds": 20,
    "launch_at_login":     False,
}

# ── Settings ──────────────────────────────────────────────────────────────────

class Settings:
    def __init__(self):
        self._d = dict(DEFAULTS)
        self._load()

    def _load(self):
        try:
            with open(SETTINGS_PATH) as f:
                self._d.update(json.load(f))
        except (FileNotFoundError, json.JSONDecodeError, PermissionError):
            pass

    def save(self):
        try:
            os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)
            with open(SETTINGS_PATH, "w") as f:
                json.dump(self._d, f, indent=2)
        except Exception as e:
            print(f"Settings save error: {e}")

    def __getattr__(self, key):
        if key.startswith("_"): raise AttributeError(key)
        return self._d.get(key, DEFAULTS.get(key))

    def __setattr__(self, key, value):
        if key.startswith("_"):
            super().__setattr__(key, value)
        else:
            self._d[key] = value
            self.save()

# ── Monitor detection ─────────────────────────────────────────────────────────

def get_monitors():
    """Returns list of (x, y, w, h) for every connected display."""
    if sys.platform == "win32":
        try:
            import ctypes
            from ctypes import wintypes
            monitors = []
            def _cb(hMon, hdcMon, lpRect, dwData):
                r = lpRect.contents
                monitors.append((r.left, r.top, r.right - r.left, r.bottom - r.top))
                return True
            cb = ctypes.WINFUNCTYPE(
                ctypes.c_bool, ctypes.c_ulong, ctypes.c_ulong,
                ctypes.POINTER(wintypes.RECT), ctypes.c_double
            )(_cb)
            ctypes.windll.user32.EnumDisplayMonitors(None, None, cb, 0)
            if monitors:
                return monitors
        except Exception as e:
            print(f"Monitor detection error: {e}")

    # Fallback — primary screen via tkinter
    try:
        tmp = tk.Tk(); tmp.withdraw()
        w, h = tmp.winfo_screenwidth(), tmp.winfo_screenheight()
        tmp.destroy()
        return [(0, 0, w, h)]
    except Exception:
        return [(0, 0, 1920, 1080)]

# ── Tray icon image ───────────────────────────────────────────────────────────

def make_icon(paused=False, size=64):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    col = (136, 136, 136) if paused else (255, 107, 53)
    cx, cy = size // 2, size // 2

    # Almond / eye outline
    ew, eh = int(size * 0.82), int(size * 0.46)
    d.ellipse([cx - ew//2, cy - eh//2, cx + ew//2, cy + eh//2],
              outline=col, width=max(2, size // 18))

    # Pupil
    pr = int(size * 0.14)
    d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], fill=col)

    # Strikethrough when paused
    if paused:
        lw = max(2, size // 16)
        d.line([cx - ew//2, cy + eh//2, cx + ew//2, cy - eh//2], fill=col, width=lw)

    return img

# ── Timer manager ─────────────────────────────────────────────────────────────

class TimerManager:
    def __init__(self, settings: Settings):
        self.s               = settings
        self.time_until_rest = settings.interval_minutes * 60
        self.rest_remaining  = settings.rest_duration_seconds
        self.rest_duration   = settings.rest_duration_seconds
        self.is_resting      = False
        self.is_paused       = False
        self._stop           = threading.Event()
        self._lock           = threading.Lock()

        # Callbacks — assigned by App
        self.on_tick         = None
        self.on_warning_show = None
        self.on_warning_hide = None
        self.on_rest_start   = None
        self.on_rest_end     = None

    def start(self):
        self._stop.clear()
        threading.Thread(target=self._loop, daemon=True).start()

    def stop(self):
        self._stop.set()

    def pause(self):   self.is_paused = True
    def resume(self):  self.is_paused = False
    def toggle_pause(self): self.is_paused = not self.is_paused

    def reset_cycle(self):
        with self._lock:
            self.time_until_rest = self.s.interval_minutes * 60
            self.is_resting      = False
            self.rest_remaining  = self.s.rest_duration_seconds
            self.rest_duration   = self.s.rest_duration_seconds

    def skip_rest(self):
        with self._lock:
            self.is_resting = False

    def trigger_now(self):
        with self._lock:
            self.time_until_rest = 0

    def _loop(self):
        warning_shown = False
        while not self._stop.is_set():
            time.sleep(1)
            if self.is_paused:
                continue

            with self._lock:
                if self.is_resting:
                    self.rest_remaining -= 1
                    if self.rest_remaining <= 0:
                        self.is_resting    = False
                        self.time_until_rest = self.s.interval_minutes * 60
                        self.rest_remaining = self.s.rest_duration_seconds
                        self.rest_duration  = self.s.rest_duration_seconds
                        warning_shown       = False
                        if self.on_rest_end: self.on_rest_end()
                    continue

                self.time_until_rest = max(0, self.time_until_rest - 1)
                warn = self.s.warning_minutes * 60

                if self.time_until_rest <= warn and not warning_shown:
                    warning_shown = True
                    if self.on_warning_show: self.on_warning_show()

                if self.time_until_rest <= 0:
                    warning_shown        = False
                    self.is_resting      = True
                    self.rest_remaining  = self.s.rest_duration_seconds
                    self.rest_duration   = self.s.rest_duration_seconds
                    if self.on_warning_hide: self.on_warning_hide()
                    if self.on_rest_start:   self.on_rest_start()

            if self.on_tick: self.on_tick()

# ── Warning banner ────────────────────────────────────────────────────────────

class WarningBanner:
    W, H = 340, 72

    def __init__(self, root: tk.Tk, timer: TimerManager):
        self.root  = root
        self.timer = timer
        self._win  = None

    def show(self):
        if self._win and self._win.winfo_exists():
            return

        win = tk.Toplevel(self.root)
        win.overrideredirect(True)
        win.attributes("-topmost", True)
        win.configure(bg=BG_BANNER)

        if sys.platform == "darwin":
            win.attributes("-alpha", 0.95)

        # Position: top-center, 40px from top (below Windows taskbar or Mac menu bar)
        sw = win.winfo_screenwidth()
        offset = 40 if sys.platform == "win32" else 30
        win.geometry(f"{self.W}x{self.H}+{(sw - self.W)//2}+{offset}")

        cv = tk.Canvas(win, width=self.W, height=self.H,
                       bg=BG_BANNER, highlightthickness=0)
        cv.pack(fill="both", expand=True)

        # Orange circle icon
        cv.create_oval(12, 18, 44, 50, fill=ACCENT, outline="")
        cv.create_text(28, 34, text="👁", font=(FONT, 14), fill=WHITE)

        # Text
        cv.create_text(56, 23, anchor="w", text="Eye Break Soon",
                       fill=WHITE, font=(FONT, 12, "bold"))
        self._cd_text = cv.create_text(56, 43, anchor="w",
                       text=self._fmt(),
                       fill=GRAY, font=(FONT, 10))

        # Dismiss
        btn = tk.Label(win, text="Dismiss", fg=GRAY, bg=BG_BANNER,
                       font=(FONT, 10), cursor="hand2")
        btn.place(x=self.W - 62, y=26)
        btn.bind("<Button-1>", lambda _: self.hide())

        self._cv  = cv
        self._win = win
        self._tick()

    def _fmt(self):
        s = int(self.timer.time_until_rest)
        return f"Screen blackout in {s // 60}:{s % 60:02d}"

    def _tick(self):
        if self._win and self._win.winfo_exists():
            try:
                self._cv.itemconfigure(self._cd_text, text=self._fmt())
                self._win.after(1000, self._tick)
            except tk.TclError:
                pass

    def hide(self):
        if self._win:
            try:
                self._win.destroy()
            except tk.TclError:
                pass
            self._win = None

# ── Full-screen overlay ───────────────────────────────────────────────────────

class Overlay:
    SKIP_DELAY = 5   # seconds before skip becomes active

    def __init__(self, root: tk.Tk, timer: TimerManager):
        self.root  = root
        self.timer = timer
        self._wins = []
        self._skip_elapsed = 0
        self._skip_ready   = False

    def show(self):
        self._wins.clear()
        self._skip_elapsed = 0
        self._skip_ready   = False

        for i, (mx, my, mw, mh) in enumerate(get_monitors()):
            win = tk.Toplevel(self.root)
            win.overrideredirect(True)
            win.attributes("-topmost", True)
            win.configure(bg="black")
            win.geometry(f"{mw}x{mh}+{mx}+{my}")
            win.lift()
            win.focus_force()

            if i == 0:
                self._build_ui(win, mw, mh)

            self._wins.append(win)

        self._rest_tick()

    def _build_ui(self, win, sw, sh):
        frame = tk.Frame(win, bg="black")
        frame.place(relx=0.5, rely=0.5, anchor="center")

        # ── Eye icon (canvas, animated) ──
        self._eye_cv = tk.Canvas(frame, width=96, height=96,
                                 bg="black", highlightthickness=0)
        self._eye_cv.pack(pady=(0, 16))
        self._breathe(scale=1.0, direction=1)

        # ── Labels ──
        tk.Label(frame, text="Rest your eyes", bg="black", fg=WHITE,
                 font=(FONT, 30, "bold")).pack()
        tk.Label(frame, text="Look at something 20 feet away",
                 bg="black", fg=GRAY, font=(FONT, 17)).pack(pady=(8, 28))

        # ── Countdown ring ──
        RS = 150
        self._ring = tk.Canvas(frame, width=RS, height=RS,
                               bg="black", highlightthickness=0)
        self._ring.pack(pady=(0, 28))
        self._rs = RS
        self._draw_ring()

        # ── Skip button ──
        self._skip_var = tk.StringVar(value=f"Skip available in {self.SKIP_DELAY}s")
        self._skip_lbl = tk.Label(frame, textvariable=self._skip_var,
                                  bg="black", fg=GRAY, font=(FONT, 12),
                                  cursor="arrow")
        self._skip_lbl.pack()
        self._skip_lbl.bind("<Button-1>", self._on_skip)

    # ── Breathing animation ──────────────────────────────────────────────────

    def _breathe(self, scale=1.0, direction=1):
        if not self._wins:
            return
        try:
            c  = self._eye_cv
            s  = scale
            cx = cy = 48
            c.delete("all")

            ew = int(40 * s); eh = int(22 * s)
            c.create_oval(cx - ew, cy - eh, cx + ew, cy + eh,
                          outline=WHITE, width=3)
            pr = int(12 * s)
            c.create_oval(cx - pr, cy - pr, cx + pr, cy + pr, fill=WHITE)

            new_s = s + direction * 0.004
            new_d = direction
            if new_s >= 1.05: new_s, new_d = 1.05, -1
            elif new_s <= 1.0: new_s, new_d = 1.0,  1

            c.after(50, self._breathe, new_s, new_d)
        except tk.TclError:
            pass

    # ── Ring countdown ───────────────────────────────────────────────────────

    def _draw_ring(self):
        c   = self._ring
        s   = self._rs
        pad = 12
        c.delete("all")

        total     = max(1, self.timer.rest_duration)
        remaining = self.timer.rest_remaining
        progress  = remaining / total

        # Track
        c.create_oval(pad, pad, s - pad, s - pad,
                      outline=GRAY_DIM, width=5)
        # Arc
        extent = -360 * progress
        c.create_arc(pad, pad, s - pad, s - pad,
                     start=90, extent=extent,
                     outline=WHITE, width=5, style="arc")
        # Number
        c.create_text(s // 2, s // 2, text=str(max(0, remaining)),
                      fill=WHITE, font=(FONT_MONO, 44, "bold"))

    # ── Per-second tick ──────────────────────────────────────────────────────

    def _rest_tick(self):
        if not self._wins:
            return
        try:
            self._draw_ring()
            self._skip_elapsed += 1

            if not self._skip_ready and self._skip_elapsed >= self.SKIP_DELAY:
                self._skip_ready = True
                self._skip_var.set("Skip  ↩")
                self._skip_lbl.configure(fg=WHITE, cursor="hand2",
                                         font=(FONT, 12, "underline"))
            elif not self._skip_ready:
                left = self.SKIP_DELAY - self._skip_elapsed
                self._skip_var.set(f"Skip available in {left}s")

            if self.timer.rest_remaining > 0:
                self._wins[0].after(1000, self._rest_tick)
        except (tk.TclError, AttributeError):
            pass

    def _on_skip(self, _=None):
        if self._skip_ready:
            self.timer.skip_rest()

    def hide(self):
        for w in self._wins:
            try: w.destroy()
            except tk.TclError: pass
        self._wins.clear()

# ── Settings window ───────────────────────────────────────────────────────────

class SettingsWindow:
    def __init__(self, root: tk.Tk, settings: Settings,
                 timer: TimerManager, on_apply=None):
        self.root     = root
        self.s        = settings
        self.timer    = timer
        self.on_apply = on_apply
        self._win     = None

    def show(self):
        if self._win and self._win.winfo_exists():
            self._win.lift(); return

        win = tk.Toplevel(self.root)
        win.title("EyeRest — Settings")
        win.configure(bg=BG_DARK)
        win.resizable(False, False)
        win.attributes("-topmost", True)

        WW, WH = 340, 310
        sw, sh = win.winfo_screenwidth(), win.winfo_screenheight()
        win.geometry(f"{WW}x{WH}+{(sw - WW)//2}+{(sh - WH)//2}")

        # Title
        tk.Label(win, text="  EyeRest Settings", bg=BG_DARK, fg=WHITE,
                 font=(FONT, 14, "bold"), anchor="w").pack(
                     fill="x", padx=0, pady=(14, 6))

        tk.Frame(win, bg=GRAY_DIM, height=1).pack(fill="x", padx=20)

        # Spinbox rows
        self._vars = {}
        rows = [
            ("Rest every (minutes)",   "interval_minutes",      5, 120),
            ("Warn before (minutes)",  "warning_minutes",       1,  10),
            ("Rest duration (seconds)","rest_duration_seconds", 20,  60),
        ]
        for label, key, lo, hi in rows:
            f = tk.Frame(win, bg=BG_DARK); f.pack(fill="x", padx=20, pady=6)
            tk.Label(f, text=label, bg=BG_DARK, fg=GRAY,
                     font=(FONT, 11), anchor="w").pack(side="left")
            var = tk.IntVar(value=getattr(self.s, key))
            self._vars[key] = var
            tk.Spinbox(f, from_=lo, to=hi, textvariable=var, width=5,
                       bg=BG_FIELD, fg=WHITE, insertbackground=WHITE,
                       buttonbackground=BG_FIELD, relief="flat",
                       font=(FONT, 12)).pack(side="right")

        tk.Frame(win, bg=GRAY_DIM, height=1).pack(fill="x", padx=20, pady=8)

        # Launch at login
        self._login_var = tk.BooleanVar(value=self.s.launch_at_login)
        tk.Checkbutton(win, text="Launch at login",
                       variable=self._login_var,
                       bg=BG_DARK, fg=WHITE, selectcolor=BG_FIELD,
                       activebackground=BG_DARK, activeforeground=WHITE,
                       font=(FONT, 11)).pack(anchor="w", padx=20)

        # Buttons
        bf = tk.Frame(win, bg=BG_DARK); bf.pack(fill="x", padx=20, pady=(14, 18))
        tk.Button(bf, text="Apply & Reset Timer", bg=ACCENT, fg=WHITE,
                  font=(FONT, 11, "bold"), relief="flat", padx=12, pady=6,
                  command=self._apply).pack(side="left")
        tk.Button(bf, text="Cancel", bg=GRAY_DIM, fg=WHITE,
                  font=(FONT, 11), relief="flat", padx=12, pady=6,
                  command=win.destroy).pack(side="right")

        self._win = win

    def _apply(self):
        for key, var in self._vars.items():
            setattr(self.s, key, var.get())
        self.s.launch_at_login = self._login_var.get()
        _apply_launch_at_login(self.s.launch_at_login)
        if self.on_apply:
            self.on_apply()
        if self._win:
            self._win.destroy()

# ── Launch at login (Windows registry / macOS launchd) ───────────────────────

def _apply_launch_at_login(enable: bool):
    if sys.platform == "win32":
        try:
            import winreg
            key = r"Software\Microsoft\Windows\CurrentVersion\Run"
            exe = f'"{sys.executable}" "{os.path.abspath(__file__)}"'
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key,
                                0, winreg.KEY_SET_VALUE) as k:
                if enable:
                    winreg.SetValueEx(k, "EyeRest", 0, winreg.REG_SZ, exe)
                else:
                    try: winreg.DeleteValue(k, "EyeRest")
                    except FileNotFoundError: pass
        except Exception as e:
            print(f"Launch at login error: {e}")

    elif sys.platform == "darwin":
        plist = os.path.expanduser(
            "~/Library/LaunchAgents/com.jackkg.eyerest.plist")
        if enable:
            content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.jackkg.eyerest</string>
  <key>ProgramArguments</key>
  <array>
    <string>{sys.executable}</string>
    <string>{os.path.abspath(__file__)}</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict></plist>"""
            os.makedirs(os.path.dirname(plist), exist_ok=True)
            with open(plist, "w") as f: f.write(content)
            os.system(f"launchctl load {plist}")
        else:
            if os.path.exists(plist):
                os.system(f"launchctl unload {plist}")
                os.remove(plist)

# ── Main application ──────────────────────────────────────────────────────────

class EyeRestApp:
    def __init__(self):
        self.settings = Settings()

        # Hidden tkinter root — used only as scheduler + parent for Toplevels
        self.root = tk.Tk()
        self.root.withdraw()
        self.root.protocol("WM_DELETE_WINDOW", lambda: None)

        self.timer    = TimerManager(self.settings)
        self.banner   = WarningBanner(self.root, self.timer)
        self.overlay  = Overlay(self.root, self.timer)
        self.settings_win = SettingsWindow(
            self.root, self.settings, self.timer,
            on_apply=self._on_settings_applied
        )

        # Thread-safe shim: schedule callbacks onto tkinter's main thread
        def ui(fn):
            def wrapper(*a, **kw):
                try: self.root.after(0, lambda: fn(*a, **kw))
                except RuntimeError: pass
            return wrapper

        self.timer.on_tick         = ui(self._on_tick)
        self.timer.on_warning_show = ui(self.banner.show)
        self.timer.on_warning_hide = ui(self.banner.hide)
        self.timer.on_rest_start   = ui(self._on_rest_start)
        self.timer.on_rest_end     = ui(self._on_rest_end)

        self.tray = pystray.Icon(
            "EyeRest",
            make_icon(paused=False),
            "EyeRest",
            menu=self._menu()
        )

    # ── Tray menu (rebuilt dynamically each open) ────────────────────────────

    def _menu(self):
        def title(_): return self._status_line()
        return pystray.Menu(
            pystray.MenuItem(title, None, enabled=False),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Pause / Resume",  lambda *_: self._toggle_pause()),
            pystray.MenuItem("Rest Now",         lambda *_: self._rest_now()),
            pystray.MenuItem("Reset Timer",      lambda *_: self._reset()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Settings…",        lambda *_: self.root.after(0, self.settings_win.show)),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit EyeRest",     lambda *_: self._quit()),
        )

    def _status_line(self):
        s   = int(self.timer.time_until_rest)
        tag = " ⏸" if self.timer.is_paused else ""
        return f"Next rest in  {s // 60:02d}:{s % 60:02d}{tag}"

    # ── Callbacks ────────────────────────────────────────────────────────────

    def _on_tick(self):
        s = int(self.timer.time_until_rest)
        try: self.tray.title = f"EyeRest — {s // 60:02d}:{s % 60:02d}"
        except Exception: pass

    def _on_rest_start(self):
        self.overlay.show()
        try: self.tray.icon = make_icon(paused=True)
        except Exception: pass

    def _on_rest_end(self):
        self.overlay.hide()
        try: self.tray.icon = make_icon(paused=False)
        except Exception: pass

    def _toggle_pause(self):
        self.timer.toggle_pause()
        try: self.tray.icon = make_icon(paused=self.timer.is_paused)
        except Exception: pass

    def _rest_now(self):
        self.timer.trigger_now()

    def _reset(self):
        self.timer.reset_cycle()

    def _on_settings_applied(self):
        self.timer.reset_cycle()

    def _quit(self):
        self.timer.stop()
        try: self.tray.stop()
        except Exception: pass
        self.root.after(0, self.root.destroy)

    # ── Run ──────────────────────────────────────────────────────────────────

    def run(self):
        self.timer.start()
        # pystray must own one thread; tkinter owns the main thread
        threading.Thread(target=self.tray.run, daemon=True).start()
        self.root.mainloop()

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    EyeRestApp().run()
