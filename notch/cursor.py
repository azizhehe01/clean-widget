#!/usr/bin/env python3
import glob
import json
import os
import socket
import sys
import threading
import time

# Find Hyprland socket
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")


def find_sockets():
    sock = None
    sock2 = None
    if sig:
        base = os.path.join(xdg, "hypr", sig)
        s = os.path.join(base, ".socket.sock")
        s2 = os.path.join(base, ".socket2.sock")
        if os.path.exists(s):
            sock = s
        if os.path.exists(s2):
            sock2 = s2
    if not sock:
        candidates = glob.glob(os.path.join(xdg, "hypr", "*", ".socket.sock"))
        if candidates:
            sock = candidates[0]
            sock2 = sock.replace(".socket.sock", ".socket2.sock")
    return sock, sock2


active_class = "none"
workspace_windows = 0
lock = threading.Lock()
sock_path_global = None


def query_cmd(sock_path, cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.15)
        s.connect(sock_path)
        s.sendall(cmd.encode("utf-8"))
        data = b""
        while True:
            chunk = s.recv(2048)
            if not chunk:
                break
            data += chunk
        s.close()
        return data.decode("utf-8", errors="ignore").strip()
    except Exception:
        return None


def refresh_workspace_state(sock_path):
    global active_class, workspace_windows
    if not sock_path:
        return
    # Check active workspace windows
    out_ws = query_cmd(sock_path, "j/activeworkspace")
    if out_ws and '"windows"' in out_ws:
        try:
            j = json.loads(out_ws)
            w_cnt = int(j.get("windows", 0))
            with lock:
                workspace_windows = w_cnt
        except Exception:
            pass

    # Check active window class
    out_win = query_cmd(sock_path, "j/activewindow")
    if out_win:
        try:
            j = json.loads(out_win)
            cls = j.get("class", "none") or "none"
            with lock:
                active_class = cls if cls else "none"
        except Exception:
            with lock:
                active_class = "none"


def event_listener(sock2_path, sock_path):
    global active_class, workspace_windows
    while True:
        try:
            if not sock2_path or not os.path.exists(sock2_path):
                time.sleep(1)
                continue
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock2_path)
            f = s.makefile("r", encoding="utf-8", errors="ignore")
            for line in f:
                line_str = line.strip()
                if line_str.startswith("activewindow>>"):
                    payload = line_str[len("activewindow>>"):].strip()
                    parts = payload.split(",", 1)
                    cls = parts[0].strip() if parts else ""
                    with lock:
                        active_class = cls if cls else "none"
                elif any(
                    line_str.startswith(ev)
                    for ev in (
                        "openwindow>>",
                        "closewindow>>",
                        "workspace>>",
                        "focusedmon>>",
                        "movewindow>>",
                    )
                ):
                    # Trigger a state refresh when windows/workspaces change
                    refresh_workspace_state(sock_path)
            s.close()
        except Exception:
            time.sleep(1)


def main():
    global active_class, workspace_windows
    sock_path, sock2_path = find_sockets()

    # Initial query
    if sock_path:
        refresh_workspace_state(sock_path)

    if sock2_path:
        t = threading.Thread(
            target=event_listener, args=(sock2_path, sock_path), daemon=True
        )
        t.start()

    last_refresh_time = time.time()

    while True:
        now = time.time()
        if not sock_path or not os.path.exists(sock_path):
            sock_path, sock2_path = find_sockets()
            time.sleep(0.5)
            continue

        # Periodic refresh every 3 seconds as a safety heartbeat
        if now - last_refresh_time > 3.0:
            refresh_workspace_state(sock_path)
            last_refresh_time = now

        raw = query_cmd(sock_path, "cursorpos")
        if raw:
            try:
                coords = [c.strip() for c in raw.split(",")]
                if len(coords) == 2:
                    x = int(coords[0])
                    y = int(coords[1])
                    with lock:
                        cls = active_class
                        w_cnt = workspace_windows
                    sys.stdout.write(f"{x} {y} {cls} {w_cnt}\n")
                    sys.stdout.flush()
            except Exception:
                pass
        time.sleep(0.033)  # ~30 FPS


if __name__ == "__main__":
    main()
