#!/usr/bin/env python3
"""
glyph-shell Native Emoji Picker Engine
Universal auto-paste for all Wayland apps (Chromium, Brave, Electron, Terminals, GTK, Qt).
"""

import json
import os
import shutil
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
DATA_FILE = os.path.join(SCRIPT_DIR, "emojis.json")


def load_emojis():
    if not os.path.exists(DATA_FILE):
        return []
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write(f"Error loading emojis: {e}\n")
        return []


def get_active_window_class():
    try:
        res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, check=False)
        if res.returncode == 0 and res.stdout:
            data = json.loads(res.stdout)
            return (data.get("class") or "").lower()
    except Exception:
        pass
    return ""


def paste_emoji(emoji_char):
    if not emoji_char:
        return

    # 1. Selalu copy emoji ke Wayland clipboard
    if shutil.which("wl-copy"):
        try:
            subprocess.run(["wl-copy", emoji_char], check=False)
        except Exception:
            pass

    # 2. Beri jeda agar window overlay Quickshell benar-benar unfocus & window target dapat fokus
    time.sleep(0.18)

    if not shutil.which("wtype"):
        return

    win_class = get_active_window_class()
    # Aplikasi terminal yang memakai Ctrl+Shift+V
    terminal_classes = ("kitty", "alacritty", "foot", "wezterm", "gnome-terminal", "konsole", "xterm")

    is_terminal = any(term in win_class for term in terminal_classes)

    try:
        if is_terminal:
            # Di terminal: gunakan Ctrl + Shift + V
            subprocess.run(["wtype", "-M", "ctrl", "-M", "shift", "-k", "v", "-m", "shift", "-m", "ctrl"], check=False)
        else:
            # Di GUI app (Brave, Chrome, Antigravity IDE, Discord, dll):
            # Kirim simulasi paste Ctrl + V dari clipboard
            # Ini 100% universal dan tidak menghasilkan tanda tanya atau replacement char
            subprocess.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"], check=False)
    except Exception as e:
        sys.stderr.write(f"wtype paste error: {e}\n")


def main():
    if len(sys.argv) < 2:
        emojis = load_emojis()
        print(json.dumps(emojis, ensure_ascii=False))
        return

    cmd = sys.argv[1]
    if cmd == "paste":
        if len(sys.argv) >= 3:
            paste_emoji(sys.argv[2])
    elif cmd == "list":
        emojis = load_emojis()
        print(json.dumps(emojis, ensure_ascii=False))
    else:
        sys.stderr.write(f"Unknown command: {cmd}\n")


if __name__ == "__main__":
    main()
