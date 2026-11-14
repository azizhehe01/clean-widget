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
import signal
import subprocess
import sys
import time

STATE_FILE = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}",
    "glyph-power-pending.json",
)
WAIT_TIMEOUT_SEC = 600
POLL_INTERVAL_SEC = 0.5


def is_pid_alive(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def read_pending_state():
    if not os.path.exists(STATE_FILE):
        return None
    try:
        with open(STATE_FILE, "r") as f:
            data = json.load(f)
        if is_pid_alive(data.get("pid")):
            return data
    except Exception:
        pass
    remove_pending_state()
    return None


def write_pending_state(action):
    try:
        with open(STATE_FILE, "w") as f:
            json.dump({"pid": os.getpid(), "action": action}, f)
    except Exception:
        pass


def remove_pending_state():
    try:
        if os.path.exists(STATE_FILE):
            os.remove(STATE_FILE)
    except Exception:
        pass


def cancel_pending(silent=False):
    state = read_pending_state()
    if not state:
        return False
    pid = state.get("pid")
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        pass
    remove_pending_state()
    if not silent:
        notify("Power Action Cancelled", "Permintaan power dibatalkan.")
    return True


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


def safe_close_all_and_check(env, action):
    clients = get_open_clients(env)
    if not clients:
        return True

    cancelled = False

    def handle_sigterm(_signum, _frame):
        nonlocal cancelled
        cancelled = True

    old_handler = signal.signal(signal.SIGTERM, handle_sigterm)
    write_pending_state(action)

    try:
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

        last_blocker_addr = None
        start_time = time.monotonic()

        while not cancelled:
            remaining = get_open_clients(env)
            if not remaining:
                return True

            if time.monotonic() - start_time >= WAIT_TIMEOUT_SEC:
                notify("Power Action Timed Out", "Waktu tunggu habis, aksi power dibatalkan.")
                return False

            blocker = remaining[0]
            addr = blocker.get("address", "")

            # Focus and notify only when moving to a new blocking window
            if addr != last_blocker_addr:
                title = (blocker.get("title") or blocker.get("class") or "Window").strip()
                cls = (blocker.get("class") or "").strip()

                if addr:
                    subprocess.run(
                        ["hyprctl", "dispatch", f"hl.dsp.focus({{ window = 'address:{addr}' }})"],
                        capture_output=True,
                        env=env,
                        check=False,
                    )

                label = f"{title} ({cls})" if cls and cls.lower() not in title.lower() else title
                count_note = f" ({len(remaining)} window tersisa)" if len(remaining) > 1 else ""
                notify(
                    "Power Action Waiting",
                    f"Simpan atau tutup window ini dulu{count_note}:\n{label}",
                )
                last_blocker_addr = addr

            time.sleep(POLL_INTERVAL_SEC)

        return False
    finally:
        signal.signal(signal.SIGTERM, old_handler)
        state = read_pending_state()
        if state and state.get("pid") == os.getpid():
            remove_pending_state()


def execute_power_action(action, force=False):
    if action == "status":
        state = read_pending_state()
        if state and state.get("action"):
            print(state["action"])
            sys.exit(0)
        sys.exit(1)

    if action == "cancel":
        cancel_pending(silent=False)
        return

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

    if force:
        cancel_pending(silent=True)
    else:
        if read_pending_state():
            cancel_pending(silent=False)
            return
        if not safe_close_all_and_check(env, action):
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
        sys.stderr.write("Usage: power.py <lock|suspend|logout|reboot|poweroff|status|cancel> [--force]\n")
        sys.exit(1)
    act = sys.argv[1].strip().lower()
    is_force = "--force" in sys.argv[2:]
    execute_power_action(act, force=is_force)

