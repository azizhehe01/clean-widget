#!/usr/bin/env python3
import configparser
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import urllib.parse
import urllib.request

cache_file = "/tmp/ml4w_desktop_widgets_cache_v3.json"
lyrics_cache_file = "/tmp/ml4w_desktop_lyrics_cache_v2.json"
now = time.time()
data = {"wallpaper": ""}

# 1. Disk usage (Linux partitions: Root / and Home /home)
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

# 4. Weather & Location (Nothing OS style: temp, H/L, condition, city, humidity & wind, cached 15m)
WMO_DESC = {
    0: "CLEAR SKY",
    1: "MAINLY CLEAR",
    2: "PARTLY CLOUDY",
    3: "OVERCAST",
    45: "FOGGY",
    48: "FOGGY",
    51: "LIGHT DRIZZLE",
    53: "DRIZZLE",
    55: "HEAVY DRIZZLE",
    61: "LIGHT RAIN",
    63: "MODERATE RAIN",
    65: "HEAVY RAIN",
    71: "LIGHT SNOW",
    73: "SNOW",
    75: "HEAVY SNOW",
    80: "RAIN SHOWERS",
    81: "RAIN SHOWERS",
    82: "HEAVY SHOWERS",
    95: "THUNDERSTORM",
    96: "THUNDERSTORM",
    99: "THUNDERSTORM",
}

cached_weather = {}
if os.path.exists(cache_file):
    try:
        with open(cache_file, 'r') as f:
            cached_weather = json.load(f)
    except Exception:
        pass

if "weather_time" in cached_weather and (now - cached_weather["weather_time"] < 900) and cached_weather.get("weather_location"):
    data["weather_temp"] = cached_weather.get("weather_temp", "29°")
    data["weather_high"] = cached_weather.get("weather_high", "H 31°")
    data["weather_low"] = cached_weather.get("weather_low", "L 25°")
    data["weather_desc"] = cached_weather.get("weather_desc", "PARTLY CLOUDY")
    data["weather_location"] = cached_weather.get("weather_location", "JAKARTA")
    data["weather_meta"] = cached_weather.get("weather_meta", "78% · 14 KM/H")
else:
    fetched_ok = False
    # Primary: Fast IP geolocation + Open-Meteo real-time forecast
    try:
        geo_req = urllib.request.Request("http://ip-api.com/json/?fields=city,lat,lon", headers={"User-Agent": "curl/8.0"})
        with urllib.request.urlopen(geo_req, timeout=2.5) as g_resp:
            geo = json.loads(g_resp.read().decode("utf-8"))
            city = (geo.get("city") or "JAKARTA").strip().upper()
            lat = geo.get("lat")
            lon = geo.get("lon")
            if lat is not None and lon is not None:
                meteo_url = (
                    f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
                    "&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"
                    "&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
                )
                m_req = urllib.request.Request(meteo_url, headers={"User-Agent": "curl/8.0"})
                with urllib.request.urlopen(m_req, timeout=2.5) as m_resp:
                    m_data = json.loads(m_resp.read().decode("utf-8"))
                    cur = m_data.get("current", {})
                    daily = m_data.get("daily", {})
                    t_now = round(cur.get("temperature_2m", 29))
                    hum = round(cur.get("relative_humidity_2m", 78))
                    wind = round(cur.get("wind_speed_10m", 14))
                    wcode = int(cur.get("weather_code", 2))
                    t_max = round((daily.get("temperature_2m_max") or [t_now + 2])[0])
                    t_min = round((daily.get("temperature_2m_min") or [t_now - 3])[0])

                    data["weather_temp"] = f"{t_now}°"
                    data["weather_high"] = f"H {t_max}°"
                    data["weather_low"] = f"L {t_min}°"
                    data["weather_desc"] = WMO_DESC.get(wcode, "PARTLY CLOUDY")
                    data["weather_location"] = city
                    data["weather_meta"] = f"{hum}% · {wind} KM/H"
                    fetched_ok = True
    except Exception:
        pass

    # Fallback: wttr.in JSON API
    if not fetched_ok:
        try:
            req = urllib.request.Request("https://wttr.in/?format=j1", headers={"User-Agent": "curl/8.0"})
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                wj = json.loads(resp.read().decode("utf-8"))
                cur = wj["current_condition"][0]
                w0 = wj.get("weather", [{}])[0]
                area = wj.get("nearest_area", [{}])[0].get("areaName", [{}])[0].get("value", "JAKARTA").upper()
                t_now = cur.get("temp_C", "29")
                t_max = w0.get("maxtempC", str(int(t_now) + 2))
                t_min = w0.get("mintempC", str(int(t_now) - 3))
                desc = cur.get("weatherDesc", [{}])[0].get("value", "PARTLY CLOUDY").upper()
                hum = cur.get("humidity", "78")
                wind = cur.get("windspeedKmph", "14")

                data["weather_temp"] = f"{t_now}°"
                data["weather_high"] = f"H {t_max}°"
                data["weather_low"] = f"L {t_min}°"
                data["weather_desc"] = desc
                data["weather_location"] = area
                data["weather_meta"] = f"{hum}% · {wind} KM/H"
                fetched_ok = True
        except Exception:
            pass

    if fetched_ok:
        try:
            with open(cache_file, 'w') as f:
                json.dump({
                    "weather_time": now,
                    "weather_temp": data["weather_temp"],
                    "weather_high": data["weather_high"],
                    "weather_low": data["weather_low"],
                    "weather_desc": data["weather_desc"],
                    "weather_location": data["weather_location"],
                    "weather_meta": data["weather_meta"],
                }, f)
        except Exception:
            pass
    else:
        data["weather_temp"] = cached_weather.get("weather_temp", "29°")
        data["weather_high"] = cached_weather.get("weather_high", "H 31°")
        data["weather_low"] = cached_weather.get("weather_low", "L 25°")
        data["weather_desc"] = cached_weather.get("weather_desc", "PARTLY CLOUDY")
        data["weather_location"] = cached_weather.get("weather_location", "JAKARTA")
        data["weather_meta"] = cached_weather.get("weather_meta", "78% · 14 KM/H")

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
