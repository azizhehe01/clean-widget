#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys


def get_wifi_status():
    data = {
        "wifi_enabled": True,
        "active_ssid": "",
        "active_ip": "",
        "networks": []
    }

    try:
        radio = subprocess.check_output(
            ["nmcli", "radio", "wifi"], stderr=subprocess.DEVNULL, timeout=2
        ).decode().strip()
        data["wifi_enabled"] = (radio.lower() == "enabled")
    except Exception:
        data["wifi_enabled"] = True

    if not data["wifi_enabled"]:
        return data

    saved = set()
    try:
        lines = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
            stderr=subprocess.DEVNULL, timeout=2
        ).decode().splitlines()
        for ln in lines:
            parts = ln.split(":")
            if len(parts) >= 1 and parts[0].strip():
                saved.add(parts[0].strip())
    except Exception:
        pass

    try:
        ip_out = subprocess.check_output(
            ["ip", "-4", "addr", "show"], stderr=subprocess.DEVNULL, timeout=2
        ).decode()
        m = re.search(r"inet (\d+\.\d+\.\d+\.\d+)/\d+.*(wlan|wlp|wlx|wlo)", ip_out)
        if m:
            data["active_ip"] = m.group(1)
    except Exception:
        pass

    seen_ssids = set()
    try:
        scan_out = subprocess.check_output(
            ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"],
            stderr=subprocess.DEVNULL, timeout=4
        ).decode().splitlines()

        for line in scan_out:
            parts = line.split(":")
            if len(parts) < 3:
                continue
            in_use = (parts[0].strip() == "*")
            ssid = parts[1].strip()
            if not ssid or ssid in seen_ssids:
                continue
            seen_ssids.add(ssid)

            signal_val = 0
            try:
                signal_val = int(parts[2].strip())
            except Exception:
                signal_val = 50

            bars = 1
            if signal_val >= 75:
                bars = 4
            elif signal_val >= 50:
                bars = 3
            elif signal_val >= 25:
                bars = 2

            sec = parts[3].strip() if len(parts) > 3 else ""
            is_locked = bool(sec and sec != "--")

            if in_use:
                data["active_ssid"] = ssid

            data["networks"].append({
                "ssid": ssid,
                "signal": signal_val,
                "bars": bars,
                "security": sec if is_locked else "Open",
                "is_locked": is_locked,
                "is_connected": in_use,
                "is_saved": (ssid in saved)
            })
    except Exception:
        pass

    data["networks"].sort(key=lambda x: (
        not x["is_connected"],
        not x["is_saved"],
        -x["signal"]
    ))

    return data


def toggle_wifi():
    try:
        radio = subprocess.check_output(
            ["nmcli", "radio", "wifi"], stderr=subprocess.DEVNULL, timeout=2
        ).decode().strip().lower()
        new_state = "off" if radio == "enabled" else "on"
        subprocess.run(["nmcli", "radio", "wifi", new_state], check=True, timeout=3)
        return {"success": True, "state": new_state}
    except Exception as e:
        return {"success": False, "error": str(e)}


def connect_wifi(ssid, password=None):
    try:
        # Check if already a saved connection
        saved = set()
        try:
            lines = subprocess.check_output(
                ["nmcli", "-t", "-f", "NAME", "connection", "show"],
                stderr=subprocess.DEVNULL, timeout=2
            ).decode().splitlines()
            saved = {ln.strip() for ln in lines if ln.strip()}
        except Exception:
            pass

        if not password and ssid in saved:
            cmd = ["nmcli", "connection", "up", "id", ssid]
        elif password:
            cmd = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        else:
            cmd = ["nmcli", "dev", "wifi", "connect", ssid]

        res = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
        if res.returncode == 0:
            return {"success": True, "message": f"Connected to {ssid}"}
        else:
            err = res.stderr.strip() or res.stdout.strip()
            return {"success": False, "message": err or "Failed to connect"}
    except Exception as e:
        return {"success": False, "message": str(e)}


def disconnect_wifi(ssid=None):
    try:
        if ssid:
            cmd = ["nmcli", "connection", "down", "id", ssid]
        else:
            cmd = ["nmcli", "dev", "disconnect", "wlan0"]
            # Fallback to finding wireless device
            try:
                devs = subprocess.check_output(
                    ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"],
                    stderr=subprocess.DEVNULL, timeout=2
                ).decode().splitlines()
                for d in devs:
                    p = d.split(":")
                    if len(p) >= 2 and p[1] == "wifi":
                        cmd = ["nmcli", "dev", "disconnect", p[0]]
                        break
            except Exception:
                pass

        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return {"success": (res.returncode == 0), "message": res.stdout.strip() or res.stderr.strip()}
    except Exception as e:
        return {"success": False, "message": str(e)}


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"

    if action == "scan":
        print(json.dumps(get_wifi_status()))
    elif action == "toggle":
        print(json.dumps(toggle_wifi()))
    elif action == "connect":
        target_ssid = sys.argv[2] if len(sys.argv) > 2 else ""
        target_pwd = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(connect_wifi(target_ssid, target_pwd)))
    elif action == "disconnect":
        target_ssid = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(disconnect_wifi(target_ssid)))
    else:
        print(json.dumps({"error": f"Unknown action: {action}"}))
