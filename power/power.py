#!/usr/bin/env python3
"""
glyph-shell Smart Safe Power Manager
For logout / reboot / poweroff:
  1. Sends graceful close to all open windows so apps can save or prompt confirmation.
  2. Waits briefly (~1.2s) and checks if any window refused to close.
  3. If a blocker window remains, focuses it (switching to its workspace), sends a
     notification, and aborts the exit so nothing unsaved is lost.
  4. If all windows closed cleanly (or --force is passed), executes the power action.
"""

import json
import os
import shutil
import subprocess
import sys
import time


def hypr_env():
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        h_dir = f"/run/user/{os.getuid()}/hypr"
        if os.path.isdir(h_dir):
            entries = sorted(os.listdir(h_dir))
            if entries:
                env["HYPRLAND_INSTANCE_SIGNATURE"] = entries[0]
    return env


def get_open_clients(env):
    try:
        res = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )
        if res.returncode != 0 or not res.stdout.strip():
            return []
        clients = json.loads(res.stdout)
        return [c for c in clients if c.get("mapped", False) and c.get("address")]
    except Exception:
        return []


def notify(title, body):
    if shutil.which("notify-send"):
        try:
            subprocess.run(["notify-send", "-u", "normal", title, body], check=False)
        except Exception:
            pass


def safe_close_all_and_check(env):
    clients = get_open_clients(env)
    if not clients:
        return True

    # Send graceful close to every mapped window
    cmds = [f"dispatch hl.dsp.window.close('address:{c['address']}')" for c in clients]
    subprocess.run(
        ["hyprctl", "--batch", " ; ".join(cmds)],
        capture_output=True,
        env=env,
        check=False,
    )

    # Give apps time to close cleanly or pop up a Save / Confirm dialog
    time.sleep(1.2)

    remaining = get_open_clients(env)
    if remaining:
        blocker = remaining[0]
        addr = blocker.get("address", "")
        title = (blocker.get("title") or blocker.get("class") or "Window").strip()
        cls = (blocker.get("class") or "").strip()

        # Focus the blocking window (automatically switches to its workspace)
        if addr:
            subprocess.run(
                ["hyprctl", "dispatch", f"hl.dsp.focus({{ window = 'address:{addr}' }})"],
                capture_output=True,
                env=env,
                check=False,
            )

        label = f"{title} ({cls})" if cls and cls.lower() not in title.lower() else title
        notify("Power Action Paused", f"Simpan atau tutup window ini dulu:\n{label}")
        return False

    return True


def execute_power_action(action, force=False):
    env = hypr_env()

    if action == "lock":
        lock_script = os.path.expanduser("~/.config/quickshell/DesktopWidgetsApp/lockscreen/lock.sh")
        subprocess.Popen([lock_script], start_new_session=True)
        return

    if action == "suspend":
        subprocess.run(["systemctl", "suspend"], check=False)
        return

    if action not in ("logout", "reboot", "poweroff"):
        sys.stderr.write(f"Unknown action: {action}\n")
        sys.exit(1)

    if not force:
        if not safe_close_all_and_check(env):
            return

    has_hyprshutdown = shutil.which("hyprshutdown") is not None

    if action == "logout":
        if has_hyprshutdown:
            subprocess.Popen(["hyprshutdown"], env=env, start_new_session=True)
        else:
            subprocess.run(["hyprctl", "dispatch", "hl.dsp.exit()"], env=env, check=False)
    elif action == "reboot":
        if has_hyprshutdown:
            subprocess.Popen(
                ["hyprshutdown", "-t", "Restarting...", "--post-cmd", "reboot"],
                env=env,
                start_new_session=True,
            )
        else:
            subprocess.run(["systemctl", "reboot"], check=False)
    elif action == "poweroff":
        if has_hyprshutdown:
            subprocess.Popen(
                ["hyprshutdown", "-t", "Shutting down...", "--post-cmd", "shutdown -P 0"],
                env=env,
                start_new_session=True,
            )
        else:
            subprocess.run(["systemctl", "poweroff"], check=False)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: power.py <lock|suspend|logout|reboot|poweroff> [--force]\n")
        sys.exit(1)
    act = sys.argv[1].strip().lower()
    is_force = "--force" in sys.argv[2:]
    execute_power_action(act, force=is_force)

