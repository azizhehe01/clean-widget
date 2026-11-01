#!/usr/bin/env python3
import json
import os
import shutil
import time
import subprocess
import urllib.request

cache_file = "/tmp/ml4w_desktop_widgets_cache.json"
now = time.time()
data = {}

# 1. Disk usage
try:
    root = shutil.disk_usage('/')
    data["root_used"] = f"{root.used / (1024**3):.1f} GB"
    data["root_total"] = f"{root.total / (1024**3):.1f} GB"
    data["root_pct"] = round((root.used / root.total) * 100)
except Exception:
    data["root_used"] = "112.0 GB"
    data["root_total"] = "713.0 GB"
    data["root_pct"] = 16

try:
    home = shutil.disk_usage(os.path.expanduser('~'))
    data["home_used"] = f"{home.used / (1024**3):.1f} GB"
    data["home_total"] = f"{home.total / (1024**3):.1f} GB"
    data["home_pct"] = round((home.used / home.total) * 100)
except Exception:
    data["home_used"] = "112.0 GB"
    data["home_total"] = "713.0 GB"
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
    data["weather_temp"] = cached_weather.get("weather_temp", "27°C")
    data["weather_condition"] = cached_weather.get("weather_condition", "Rain")
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
                data["weather_temp"] = "27°C"
                data["weather_condition"] = "Rain"
        # save cache
        with open(cache_file, 'w') as f:
            json.dump({"weather_time": now, "weather_temp": data["weather_temp"], "weather_condition": data["weather_condition"]}, f)
    except Exception:
        data["weather_temp"] = cached_weather.get("weather_temp", "27°C")
        data["weather_condition"] = cached_weather.get("weather_condition", "Rain")

print(json.dumps(data))
