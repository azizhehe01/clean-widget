#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import time
import urllib.parse
import urllib.request

cache_file = "/tmp/ml4w_desktop_widgets_cache.json"
lyrics_cache_file = "/tmp/ml4w_desktop_lyrics_cache_v2.json"
now = time.time()
data = {}

# 0. Current Wallpaper Path (from ML4W cache)
wallpaper_cache = os.path.expanduser("~/.cache/ml4w/hyprland-dotfiles/current_wallpaper")
default_wp = os.path.expanduser("~/.config/ml4w/wallpapers/default.jpg")
data["wallpaper"] = default_wp
if os.path.exists(wallpaper_cache):
    try:
        with open(wallpaper_cache, "r") as f:
            wp = f.read().strip()
            if wp and os.path.exists(wp):
                data["wallpaper"] = wp
    except Exception:
        pass

# 1. Disk usage
try:
    root = shutil.disk_usage('/')
    data["root_used"] = f"{root.used / (1024**3):.1f} GB"
    data["root_total"] = f"{root.total / (1024**3):.1f} GB"
    data["root_pct"] = round((root.used / root.total) * 100)
except Exception:
    data["root_used"] = "114.7 GB"
    data["root_total"] = "712.8 GB"
    data["root_pct"] = 16

try:
    home = shutil.disk_usage(os.path.expanduser('~'))
    data["home_used"] = f"{home.used / (1024**3):.1f} GB"
    data["home_total"] = f"{home.total / (1024**3):.1f} GB"
    data["home_pct"] = round((home.used / home.total) * 100)
except Exception:
    data["home_used"] = "114.7 GB"
    data["home_total"] = "712.8 GB"
    data["home_pct"] = 16

# 2. Battery
data["battery_pct"] = 100
data["battery_status"] = "Full"
try:
    if os.path.exists('/sys/class/power_supply'):
        bats = [b for b in os.listdir('/sys/class/power_supply') if b.startswith('BAT')]
        if bats:
            bat_name = bats[0]
            with open(f'/sys/class/power_supply/{bat_name}/capacity', 'r') as f:
                data["battery_pct"] = int(f.read().strip())
            with open(f'/sys/class/power_supply/{bat_name}/status', 'r') as f:
                data["battery_status"] = f.read().strip()
except Exception:
    pass

# 3. Trash size
trash_dir = os.path.expanduser('~/.local/share/Trash')
trash_bytes = 0
if os.path.exists(trash_dir):
    try:
        for dirpath, dirnames, filenames in os.walk(trash_dir):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    trash_bytes += os.path.getsize(fp)
    except Exception:
        pass

if trash_bytes > 1024**3:
    data["trash_size"] = f"{trash_bytes / (1024**3):.1f} GB"
else:
    data["trash_size"] = f"{int(trash_bytes / (1024**2))} MB"

# 4. Weather (cached for 15 minutes)
cached_weather = {}
if os.path.exists(cache_file):
    try:
        with open(cache_file, 'r') as f:
            cached_weather = json.load(f)
    except Exception:
        pass

if "weather_time" in cached_weather and (now - cached_weather["weather_time"] < 900):
    data["weather_temp"] = cached_weather.get("weather_temp", "28°C")
    data["weather_condition"] = cached_weather.get("weather_condition", "🌦️")
else:
    try:
        req = urllib.request.Request("https://wttr.in/?format=%c+%t", headers={"User-Agent": "curl/7.68.0"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            raw = resp.read().decode('utf-8').strip()
            parts = raw.split()
            if len(parts) >= 2:
                cond = parts[0]
                temp = parts[-1].replace("+", "")
                data["weather_temp"] = temp
                data["weather_condition"] = cond
            else:
                data["weather_temp"] = "28°C"
                data["weather_condition"] = "🌦️"
        with open(cache_file, 'w') as f:
            json.dump({
                "weather_time": now,
                "weather_temp": data["weather_temp"],
                "weather_condition": data["weather_condition"]
            }, f)
    except Exception:
        data["weather_temp"] = cached_weather.get("weather_temp", "28°C")
        data["weather_condition"] = cached_weather.get("weather_condition", "🌦️")

# 5. Live Lyrics (via playerctl + LRCLIB, matching active Playing player)
data["lyrics"] = []


def clean_query(s):
    s = re.sub(r"\s*-\s*Topic$", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\(.*?(Official|Visualizer|Lyric|Audio|Video|MV).*?\)", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\[.*?(Official|Visualizer|Lyric|Audio|Video|MV).*?\]", "", s, flags=re.IGNORECASE)
    return s.strip()


def fetch_lrclib(q_str):
    url = f"https://lrclib.net/api/search?q={urllib.parse.quote(q_str)}"
    req = urllib.request.Request(url, headers={"User-Agent": "QuickshellDesktopWidgets/1.0"})
    synced_lines = []
    plain_lines = []
    with urllib.request.urlopen(req, timeout=3.0) as resp:
        results = json.loads(resp.read().decode("utf-8"))
        if isinstance(results, list) and len(results) > 0:
            best = results[0]
            for item in results:
                if item.get("syncedLyrics"):
                    best = item
                    break
            raw_synced = best.get("syncedLyrics") or ""
            raw_plain = best.get("plainLyrics") or ""
            if raw_synced:
                for line in raw_synced.splitlines():
                    m = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\](.*)$", line.strip())
                    if m:
                        ts = int(m.group(1)) * 60 + float(m.group(2))
                        txt = m.group(3).strip()
                        if txt:
                            synced_lines.append({"t": ts, "text": txt})
            elif raw_plain:
                plain_lines = [ln.strip() for ln in raw_plain.splitlines() if ln.strip()]
    return synced_lines, plain_lines


try:
    players_raw = subprocess.check_output(
        ["playerctl", "-l"], stderr=subprocess.DEVNULL, timeout=1
    ).decode("utf-8").splitlines()
    players = [p.strip() for p in players_raw if p.strip()]

    chosen_player = None
    for p in players:
        try:
            st = subprocess.check_output(
                ["playerctl", "-p", p, "status"], stderr=subprocess.DEVNULL, timeout=1
            ).decode("utf-8").strip()
            if st == "Playing":
                chosen_player = p
                break
        except Exception:
            pass
    if not chosen_player and players:
        chosen_player = players[0]

    if chosen_player:
        title = subprocess.check_output(
            ["playerctl", "-p", chosen_player, "metadata", "xesam:title"],
            stderr=subprocess.DEVNULL, timeout=1
        ).decode("utf-8").strip()
        artist = subprocess.check_output(
            ["playerctl", "-p", chosen_player, "metadata", "xesam:artist"],
            stderr=subprocess.DEVNULL, timeout=1
        ).decode("utf-8").strip()
        try:
            pos_raw = subprocess.check_output(
                ["playerctl", "-p", chosen_player, "position"],
                stderr=subprocess.DEVNULL, timeout=1
            ).decode("utf-8").strip()
            position = float(pos_raw) if pos_raw else 0.0
        except Exception:
            position = 0.0

        if title:
            clean_t = clean_query(title)
            clean_a = clean_query(artist)
            track_key = f"{clean_t} - {clean_a}".strip()

            lyrics_cache = {}
            if os.path.exists(lyrics_cache_file):
                try:
                    with open(lyrics_cache_file, "r") as f:
                        lyrics_cache = json.load(f)
                except Exception:
                    lyrics_cache = {}

            if lyrics_cache.get("track_key") != track_key:
                synced_lines = []
                plain_lines = []
                try:
                    synced_lines, plain_lines = fetch_lrclib(f"{clean_t} {clean_a}".strip())
                    if not synced_lines and not plain_lines and clean_t:
                        synced_lines, plain_lines = fetch_lrclib(clean_t)
                except Exception:
                    pass

                if synced_lines or plain_lines:
                    lyrics_cache = {
                        "track_key": track_key,
                        "synced": synced_lines,
                        "plain": plain_lines
                    }
                    try:
                        with open(lyrics_cache_file, "w") as f:
                            json.dump(lyrics_cache, f)
                    except Exception:
                        pass
                else:
                    lyrics_cache = {"track_key": track_key, "synced": [], "plain": []}

            synced = lyrics_cache.get("synced") or []
            plain = lyrics_cache.get("plain") or []

            if len(synced) > 0:
                active_idx = 0
                for i, item in enumerate(synced):
                    if item["t"] <= position + 0.35:
                        active_idx = i
                    else:
                        break
                window = synced[active_idx:active_idx + 3]
                if len(window) < 3 and len(synced) >= 3:
                    window = synced[-3:]
                for idx_w, item in enumerate(window):
                    data["lyrics"].append({
                        "text": item["text"],
                        "active": (idx_w == 0)
                    })
            elif len(plain) > 0:
                step = max(0, min(len(plain) - 3, int(position // 6)))
                window = plain[step:step + 3]
                for idx_w, txt in enumerate(window):
                    data["lyrics"].append({
                        "text": txt,
                        "active": (idx_w == 0)
                    })
except Exception:
    data["lyrics"] = []

print(json.dumps(data))
