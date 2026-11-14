#!/usr/bin/env python3
"""
glyph-shell Native Keybindings Extractor
Reads active binds dynamically from `hyprctl binds -j`, normalizes keycaps,
and categorizes them for KeybindsWindow.qml.
"""

import json
import os
import re
import subprocess
import sys

MOD_ORDER = [
    (64, "SUPER"),
    (4, "CTRL"),
    (8, "ALT"),
    (1, "SHIFT"),
]

KEY_ALIASES = {
    "RETURN": "ENTER",
    "TAB": "TAB",
    "ESCAPE": "ESC",
    "SPACE": "SPACE",
    "PRINT": "PRT SC",
    "MOUSE:272": "LMB",
    "MOUSE:273": "RMB",
    "MOUSE_DOWN": "SCROLL ↓",
    "MOUSE_UP": "SCROLL ↑",
    "XF86AUDIORAISEVOLUME": "VOL +",
    "XF86AUDIOLOWERVOLUME": "VOL -",
    "XF86AUDIOMUTE": "MUTE",
    "XF86AUDIOMICMUTE": "MIC MUTE",
    "XF86MONBRIGHTNESSUP": "BRIGHT +",
    "XF86MONBRIGHTNESSDOWN": "BRIGHT -",
    "XF86AUDIOPLAY": "PLAY",
    "XF86AUDIOPAUSE": "PAUSE",
    "XF86AUDIONEXT": "NEXT",
    "XF86AUDIOPREV": "PREV",
}


def detect_category(desc: str) -> str:
    d = desc.lower()
    if any(w in d for w in ("workspace", "scratchpad")):
        return "workspaces"
    if any(
        w in d
        for w in (
            "launcher",
            "clipboard",
            "emoji",
            "wallpaper",
            "sidebar",
            "display",
            "hdmi",
            "wifi",
            "bluetooth",
            "lock",
            "overview",
            "select window",
            "keybindings",
            "power",
            "animations",
            "terminal",
            "browser",
            "filemanager",
        )
    ):
        return "shell"
    if any(
        w in d
        for w in (
            "screenshot",
            "volume",
            "mute",
            "microphone",
            "brightness",
            "extract text",
            "reload",
        )
    ):
        return "media"
    return "windows"


def format_key(raw_key: str) -> str:
    upper = (raw_key or "").strip().upper()
    return KEY_ALIASES.get(upper, upper)


def load_keybinds():
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        hypr_dir = f"/run/user/{os.getuid()}/hypr"
        if os.path.isdir(hypr_dir):
            entries = sorted(os.listdir(hypr_dir))
            if entries:
                env["HYPRLAND_INSTANCE_SIGNATURE"] = entries[0]

    try:
        res = subprocess.run(
            ["hyprctl", "binds", "-j"],
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )
        if res.returncode != 0 or not res.stdout.strip():
            return []
        binds = json.loads(res.stdout)
    except Exception as e:
        sys.stderr.write(f"Error reading hyprctl binds: {e}\n")
        return []

    items = []
    seen = set()
    focus_ws_added = False
    move_ws_added = False

    for b in binds:
        desc = (b.get("description") or "").strip()
        if not desc:
            continue

        # Collapse "Focus workspace 1..10" into a single entry
        if re.match(r"^Focus workspace \d+$", desc, re.IGNORECASE):
            if not focus_ws_added:
                focus_ws_added = True
                items.append(
                    {
                        "keys": ["SUPER", "1 – 0"],
                        "search_keys": ["SUPER", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "10", "1-0", "1-10"],
                        "combo": "SUPER + 1 – 0",
                        "desc": "Focus workspace 1 – 10",
                        "search_desc": "Focus workspace 1 2 3 4 5 6 7 8 9 10",
                        "cat": "workspaces",
                    }
                )
            continue

        # Collapse "Move window to workspace 1..10" into a single entry
        if re.match(r"^Move window to workspace \d+$", desc, re.IGNORECASE):
            if not move_ws_added:
                move_ws_added = True
                items.append(
                    {
                        "keys": ["SUPER", "SHIFT", "1 – 0"],
                        "search_keys": ["SUPER", "SHIFT", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "10", "1-0", "1-10"],
                        "combo": "SUPER + SHIFT + 1 – 0",
                        "desc": "Move window to workspace 1 – 10",
                        "search_desc": "Move window to workspace 1 2 3 4 5 6 7 8 9 10",
                        "cat": "workspaces",
                    }
                )
            continue

        modmask = int(b.get("modmask") or 0)
        keys = [name for bit, name in MOD_ORDER if (modmask & bit)]

        k = format_key(b.get("key") or "")
        if k:
            keys.append(k)

        combo = " + ".join(keys)
        dedup_key = (combo, desc)
        if dedup_key in seen:
            continue
        seen.add(dedup_key)

        items.append(
            {
                "keys": keys,
                "combo": combo,
                "desc": desc,
                "cat": detect_category(desc),
            }
        )

    return items


if __name__ == "__main__":
    print(json.dumps(load_keybinds(), ensure_ascii=False))

