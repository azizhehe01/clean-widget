#!/usr/bin/env python3
import glob
import json
import os
import subprocess
import sys


def get_monitors():
    int_mon = "eDP-1"
    ext_mon = "HDMI-A-1"

    # 1. Check drm status in sysfs
    drm_connected = []
    for p in glob.glob("/sys/class/drm/card*-*"):
        status_file = os.path.join(p, "status")
        if os.path.exists(status_file):
            try:
                with open(status_file, "r") as f:
                    if f.read().strip() == "connected":
                        name = os.path.basename(p)
                        port = name.split("-", 1)[1] if "-" in name else name
                        drm_connected.append(port)
            except Exception:
                pass

    # 2. Query Hyprland monitors
    try:
        raw = subprocess.check_output(
            ["hyprctl", "monitors", "all", "-j"],
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
        monitors = json.loads(raw.decode("utf-8"))
        for m in monitors:
            m_name = m.get("name", "")
            if m_name.startswith("eDP"):
                int_mon = m_name
            elif not m_name.startswith("eDP"):
                ext_mon = m_name
    except Exception:
        pass

    for p in drm_connected:
        if p.startswith("eDP"):
            int_mon = p
        else:
            ext_mon = p

    return int_mon, ext_mon


def get_current_mode():
    int_mon, ext_mon = get_monitors()
    try:
        raw = subprocess.check_output(
            ["hyprctl", "monitors", "all", "-j"],
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
        monitors = json.loads(raw.decode("utf-8"))
        int_obj = next((m for m in monitors if m.get("name") == int_mon), None)
        ext_obj = next((m for m in monitors if m.get("name") == ext_mon), None)

        int_active = int_obj and not int_obj.get("disabled", False)
        ext_active = ext_obj and not ext_obj.get("disabled", False)

        if ext_obj and ext_obj.get("mirrorOf") == int_mon:
            return "duplicate"
        if not int_active and ext_active:
            return "second"
        if int_active and ext_active:
            return "extend"
        if int_active and not ext_active:
            return "laptop"
    except Exception:
        pass
    return "laptop"


def apply_mode(mode):
    int_mon, ext_mon = get_monitors()
    cmds = []
    msg = ""

    if mode == "laptop":
        cmds.append(["hyprctl", "keyword", "monitor", f"{ext_mon},disable"])
        cmds.append(
            ["hyprctl", "keyword", "monitor", f"{int_mon},preferred,auto,1"]
        )
        msg = f"PC Screen Only ({int_mon})"
    elif mode == "duplicate":
        cmds.append(
            ["hyprctl", "keyword", "monitor", f"{int_mon},preferred,auto,1"]
        )
        cmds.append(
            [
                "hyprctl",
                "keyword",
                "monitor",
                f"{ext_mon},preferred,auto,1,mirror,{int_mon}",
            ]
        )
        msg = f"Duplicate Display ({int_mon} = {ext_mon})"
    elif mode == "extend":
        cmds.append(
            ["hyprctl", "keyword", "monitor", f"{int_mon},preferred,0x0,1"]
        )
        cmds.append(
            ["hyprctl", "keyword", "monitor", f"{ext_mon},preferred,auto-right,1"]
        )
        msg = f"Extend Display ({int_mon} + {ext_mon})"
    elif mode == "second":
        cmds.append(
            ["hyprctl", "keyword", "monitor", f"{ext_mon},preferred,auto,1"]
        )
        cmds.append(["hyprctl", "keyword", "monitor", f"{int_mon},disable"])
        msg = f"Second Screen Only ({ext_mon})"
    else:
        return

    for c in cmds:
        try:
            subprocess.run(
                c,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=2,
            )
        except Exception:
            pass

    # Quick desktop notification for feedback
    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "Display Manager",
                "-u",
                "low",
                "-i",
                "video-display",
                "PROJECT DISPLAY",
                msg,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except Exception:
        pass


if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower().strip()
        if arg == "get":
            print(get_current_mode())
        elif arg in ("laptop", "duplicate", "extend", "second"):
            apply_mode(arg)
            print("OK")
    else:
        print(get_current_mode())
