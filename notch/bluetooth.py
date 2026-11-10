#!/usr/bin/env python3
import json
import re
import subprocess
import sys


def _run_bt(args, timeout=3):
    try:
        return subprocess.check_output(
            ["bluetoothctl"] + args,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        ).decode("utf-8", errors="ignore")
    except Exception:
        return ""


def get_bt_status(do_scan=False):
    data = {
        "bt_enabled": False,
        "active_device": "",
        "connected_count": 0,
        "devices": [],
    }

    show_out = _run_bt(["show"], timeout=2)
    for line in show_out.splitlines():
        s = line.strip()
        if s.startswith("Powered:"):
            data["bt_enabled"] = ("yes" in s.lower())
            break

    if not data["bt_enabled"]:
        return data

    if do_scan:
        try:
            subprocess.run(
                ["bluetoothctl", "--timeout", "3", "scan", "on"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=4,
            )
        except Exception:
            pass

    devs_out = _run_bt(["devices"], timeout=2)
    seen_macs = set()

    for line in devs_out.splitlines():
        line = line.strip()
        if not line.startswith("Device "):
            continue
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        mac = parts[1].strip()
        name = parts[2].strip()
        if not mac or mac in seen_macs:
            continue
        # Skip unnamed raw MAC addresses
        if re.match(r"^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$", name):
            continue
        seen_macs.add(mac)

        info_out = _run_bt(["info", mac], timeout=1.5)
        is_connected = False
        is_paired = False
        icon_cat = "device"
        battery_pct = -1

        for iline in info_out.splitlines():
            s = iline.strip()
            if s.startswith("Connected:"):
                is_connected = ("yes" in s.lower())
            elif s.startswith("Paired:"):
                is_paired = ("yes" in s.lower())
            elif s.startswith("Icon:"):
                ic = s.split(":", 1)[1].strip().lower()
                if "audio" in ic or "headset" in ic or "headphone" in ic:
                    icon_cat = "audio"
                elif "input" in ic or "mouse" in ic or "keyboard" in ic or "gaming" in ic:
                    icon_cat = "input"
                elif "phone" in ic:
                    icon_cat = "phone"
            elif "Battery Percentage:" in s:
                m = re.search(r"\((\d+)\)", s)
                if m:
                    battery_pct = int(m.group(1))

        if is_connected:
            data["connected_count"] += 1
            if not data["active_device"]:
                data["active_device"] = name

        data["devices"].append({
            "mac": mac,
            "name": name,
            "is_connected": is_connected,
            "is_paired": is_paired,
            "icon_type": icon_cat,
            "battery": battery_pct,
        })

    data["devices"].sort(key=lambda d: (
        not d["is_connected"],
        not d["is_paired"],
        d["name"].lower(),
    ))
    return data


def toggle_bt():
    status = get_bt_status(do_scan=False)
    if status["bt_enabled"]:
        subprocess.run(["bluetoothctl", "power", "off"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    else:
        subprocess.run(["rfkill", "unblock", "bluetooth"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
        subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    return get_bt_status(do_scan=False)


def connect_bt(mac):
    if not mac:
        return get_bt_status(do_scan=False)
    subprocess.run(["bluetoothctl", "trust", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    return get_bt_status(do_scan=False)


def disconnect_bt(mac):
    if not mac:
        return get_bt_status(do_scan=False)
    subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    return get_bt_status(do_scan=False)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(get_bt_status(do_scan=False)))
    elif cmd == "scan":
        print(json.dumps(get_bt_status(do_scan=True)))
    elif cmd == "toggle":
        print(json.dumps(toggle_bt()))
    elif cmd == "connect" and len(sys.argv) > 2:
        print(json.dumps(connect_bt(sys.argv[2])))
    elif cmd == "disconnect" and len(sys.argv) > 2:
        print(json.dumps(disconnect_bt(sys.argv[2])))
    else:
        print(json.dumps(get_bt_status(do_scan=False)))
