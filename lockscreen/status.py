#!/usr/bin/env python3
import glob
import html
import json
import os
import subprocess
import sys
import time


def get_wifi():
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"],
            stderr=subprocess.DEVNULL,
            timeout=1.0,
        ).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            if ":802-11-wireless" in line:
                ssid = line.split(":802-11-wireless", 1)[0].strip()
                if ssid:
                    return f"[:::] WIFI · {html.escape(ssid.upper())}"
    except Exception:
        pass
    return "[:::] WIFI · OFFLINE"


def get_battery():
    try:
        bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
        if bats:
            bat = bats[0]
            with open(os.path.join(bat, "capacity"), "r") as f:
                pct = int(f.read().strip())
            with open(os.path.join(bat, "status"), "r") as f:
                st = f.read().strip().upper()
            filled = max(0, min(5, round(pct / 20)))
            dots = "●" * filled + "○" * (5 - filled)
            if st == "CHARGING":
                return f"⚡ CHG {pct}%  [{dots}]"
            return f"BAT {pct}%  [{dots}]"
    except Exception:
        pass
    return "AC POWER  [●●●●●]"


def get_date_weather():
    date_str = time.strftime("%a, %d %b %Y").upper()
    temp_str = "28°C"
    cache_file = "/tmp/ml4w_desktop_widgets_cache.json"
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                d = json.load(f)
                t = d.get("weather_temp", "").strip()
                if t:
                    temp_str = t.upper()
        except Exception:
            pass
    return f"{date_str}   ·   {html.escape(temp_str)}   ·   JAKARTA"


def _playerctl(args):
    try:
        return (
            subprocess.check_output(
                ["playerctl"] + args, stderr=subprocess.DEVNULL, timeout=1.0
            )
            .decode("utf-8", errors="ignore")
            .strip()
        )
    except Exception:
        return ""


def get_music_header():
    status = _playerctl(["status"])
    player = _playerctl(["metadata", "--format", "{{playerName}}"]).upper()
    if status == "Playing":
        p = f" · {player}" if player else ""
        return f'<span foreground="#ff3b30">●</span> NOW PLAYING{html.escape(p)}'
    elif status == "Paused":
        p = f" · {player}" if player else ""
        return f'<span foreground="#ffffff88">○</span> PAUSED{html.escape(p)}'
    return '<span foreground="#ffffff55">[:::]</span> NOTHING MEDIA'


def get_music_title():
    status = _playerctl(["status"])
    if status in ("Playing", "Paused"):
        title = _playerctl(["metadata", "--format", "{{title}}"])
        if title:
            if len(title) > 32:
                title = title[:29] + "..."
            return html.escape(title)
    return "NO ACTIVE TRACK"


def get_music_artist():
    status = _playerctl(["status"])
    if status in ("Playing", "Paused"):
        artist = _playerctl(["metadata", "--format", "{{artist}}"]).upper()
        if artist:
            if len(artist) > 38:
                artist = artist[:35] + "..."
            return html.escape(artist)
        return "UNKNOWN ARTIST"
    return "PLAY AUDIO TO ACTIVATE GLYPH PLAYER"


def get_music_play_label():
    status = _playerctl(["status"])
    if status == "Playing":
        return "[ ⏸ PAUSE ]"
    return "[ ▷ PLAY ]"


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "wifi":
        print(get_wifi())
    elif cmd == "battery":
        print(get_battery())
    elif cmd == "date-weather":
        print(get_date_weather())
    elif cmd == "music-header":
        print(get_music_header())
    elif cmd == "music-title":
        print(get_music_title())
    elif cmd == "music-artist":
        print(get_music_artist())
    elif cmd == "music-play-label":
        print(get_music_play_label())
