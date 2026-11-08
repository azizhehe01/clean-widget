#!/usr/bin/env python3
import glob
import json
import os
import subprocess

data = {
    "battery_pct": 100,
    "battery_status": "Full",
    "wifi_ssid": "OFFLINE",
    "wifi_connected": False,
}

# 1. Battery from sysfs
try:
    bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if bats:
        bat = bats[0]
        with open(os.path.join(bat, "capacity"), "r") as f:
            data["battery_pct"] = int(f.read().strip())
        with open(os.path.join(bat, "status"), "r") as f:
            data["battery_status"] = f.read().strip()
except Exception:
    pass

# 2. Active WiFi SSID (fast, zero scan delay)
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
                data["wifi_ssid"] = ssid.upper()
                data["wifi_connected"] = True
                break
except Exception:
    pass

print(json.dumps(data))
