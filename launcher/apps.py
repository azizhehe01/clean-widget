#!/usr/bin/env python3
import configparser
import glob
import json
import os
import re
import subprocess
import sys

ICON_DIRS = [
    os.path.expanduser("~/.local/share/icons/hicolor/scalable/apps"),
    os.path.expanduser("~/.local/share/icons/hicolor/256x256/apps"),
    os.path.expanduser("~/.local/share/icons/hicolor/128x128/apps"),
    os.path.expanduser("~/.local/share/icons/hicolor/64x64/apps"),
    os.path.expanduser("~/.local/share/icons/hicolor/48x48/apps"),
    os.path.expanduser("~/.local/share/icons"),
    "/usr/share/icons/hicolor/scalable/apps",
    "/usr/share/icons/hicolor/256x256/apps",
    "/usr/share/icons/hicolor/128x128/apps",
    "/usr/share/icons/hicolor/64x64/apps",
    "/usr/share/icons/hicolor/48x48/apps",
    "/usr/share/icons/Adwaita/scalable/apps",
    "/usr/share/icons/Adwaita/symbolic/apps",
    "/usr/share/pixmaps",
    "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps",
    "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps",
]

ICON_CACHE = {}


def resolve_icon(icon_name):
    if not icon_name:
        return ""
    if icon_name in ICON_CACHE:
        return ICON_CACHE[icon_name]
    if os.path.isabs(icon_name) and os.path.isfile(icon_name):
        ICON_CACHE[icon_name] = "file://" + icon_name
        return ICON_CACHE[icon_name]

    for d in ICON_DIRS:
        if not os.path.isdir(d):
            continue
        for ext in (".svg", ".png", ".xpm"):
            cand = os.path.join(d, icon_name + ext)
            if os.path.isfile(cand):
                ICON_CACHE[icon_name] = "file://" + cand
                return ICON_CACHE[icon_name]
    ICON_CACHE[icon_name] = ""
    return ""


def shorten_app_name(name):
    short = name.strip()
    replacements = {
        "Bluetooth Manager": "Bluetooth",
        "PulseAudio Volume Control": "Volume",
        "Network Connections": "Network",
        "Disk Usage Analyzer": "Disk Usage",
        "Document Viewer": "Doc Viewer",
        "Image Viewer": "Images",
        "System Monitor": "Monitor",
        "Text Editor": "Editor",
        "Extension Manager": "Extensions",
        "dbeaver-ce": "DBeaver",
    }
    if short in replacements:
        return replacements[short]
    if " - " in short:
        short = short.split(" - ")[0].strip()
    return short


PRIORITY_APPS = [
    "antigravity",
    "zen",
    "spotify",
    "kitty",
    "org.gnome.nautilus",
    "nautilus",
    "dbeaver",
    "blueman",
    "pavucontrol",
    "obsidian",
    "discord",
    "code",
]


def load_apps():
    app_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications",
    ]
    seen_names = set()
    apps = []

    for d in app_dirs:
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".desktop"):
                continue
            path = os.path.join(d, fn)
            try:
                cp = configparser.ConfigParser(interpolation=None, strict=False)
                cp.read(path, encoding="utf-8")
                if "Desktop Entry" not in cp:
                    continue
                entry = cp["Desktop Entry"]
                if entry.get("NoDisplay", "false").lower() == "true":
                    continue
                if entry.get("Hidden", "false").lower() == "true":
                    continue
                if entry.get("Type", "Application") != "Application":
                    continue

                name = entry.get("Name", "").strip()
                exec_cmd = entry.get("Exec", "").strip()
                if not name or not exec_cmd:
                    continue

                clean_exec = re.sub(r"\s+(%[fFuUdDnNickvm]|@@u|@@)", "", exec_cmd).strip()
                key = name.lower()
                if key in seen_names:
                    continue
                seen_names.add(key)

                icon_raw = entry.get("Icon", "").strip()
                icon_url = resolve_icon(icon_raw)
                keywords = entry.get("Keywords", "") + " " + entry.get("Comment", "") + " " + fn[:-8]

                # Priority rank for initial order
                prio = 100
                low_all = (name + " " + fn).lower()
                for idx, p in enumerate(PRIORITY_APPS):
                    if p in low_all:
                        prio = idx
                        break

                apps.append({
                    "type": "app",
                    "name": shorten_app_name(name),
                    "fullName": name,
                    "subtitle": "APP",
                    "icon": icon_url,
                    "exec": clean_exec,
                    "path": "",
                    "searchKey": f"{name} {shorten_app_name(name)} {keywords}".lower(),
                    "priority": prio,
                })
            except Exception:
                continue

    apps.sort(key=lambda x: (x["priority"], x["name"].lower()))
    return apps


def load_project_folders():
    home = os.path.expanduser("~")
    folder_Svg = "file://" + os.path.expanduser(
        "~/.config/quickshell/DesktopWidgetsApp/assets/folder-dot.svg"
    )

    pinned_paths = [
        (
            "DesktopWidgetsApp",
            os.path.expanduser("~/.config/quickshell/DesktopWidgetsApp"),
        ),
        ("hypr", os.path.expanduser("~/.config/hypr")),
    ]

    skip_dirs = {
        ".cache",
        ".local",
        ".config",
        ".nvm",
        ".npm",
        ".cargo",
        ".rustup",
        ".gemini",
        ".pki",
        ".ssh",
        ".mozilla",
        ".zen",
        ".vscode",
        ".gradle",
        ".m2",
        "Desktop",
        "Public",
        "Templates",
        "Videos",
        "Music",
        "Pictures",
    }

    seen_paths = set()
    folders = []

    def add_folder(display_name, full_path, prio=50):
        real = os.path.realpath(full_path)
        if not os.path.isdir(full_path) or real in seen_paths:
            return
        seen_paths.add(real)
        rel = full_path.replace(home, "~")
        folders.append({
            "type": "folder",
            "name": display_name,
            "fullName": rel,
            "subtitle": "IDE · FOLDER",
            "icon": folder_Svg,
            "exec": "",
            "path": full_path,
            "searchKey": f"{display_name} {rel} folder project ide repo".lower(),
            "priority": prio,
        })

    for idx, (pname, ppath) in enumerate(pinned_paths):
        add_folder(pname, ppath, prio=idx)

    # Scan ~/Projects/* first if it exists
    proj_root = os.path.join(home, "Projects")
    if os.path.isdir(proj_root):
        for entry in sorted(os.listdir(proj_root)):
            if entry.startswith("."):
                continue
            p = os.path.join(proj_root, entry)
            if os.path.isdir(p):
                add_folder(entry, p, prio=10)
                # Also check 1 level deeper inside ~/Projects/<group>/<repo>
                for sub in sorted(os.listdir(p)):
                    if sub.startswith("."):
                        continue
                    sp = os.path.join(p, sub)
                    if os.path.isdir(sp) and os.path.isdir(os.path.join(sp, ".git")):
                        add_folder(sub, sp, prio=12)

    # Scan top-level directories in ~/
    for entry in sorted(os.listdir(home)):
        if entry.startswith(".") or entry in skip_dirs:
            continue
        p = os.path.join(home, entry)
        if os.path.isdir(p):
            is_git = os.path.isdir(os.path.join(p, ".git"))
            add_folder(entry, p, prio=15 if is_git else 30)

    folders.sort(key=lambda x: (x["priority"], x["name"].lower()))
    return folders


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        items = load_apps() + load_project_folders()
        print(json.dumps(items))
    elif cmd == "open-folder" and len(sys.argv) > 2:
        folder_path = sys.argv[2]
        ide_bin = "/opt/antigravity/antigravity-ide"
        if not os.path.exists(ide_bin):
            ide_bin = "antigravity"
        subprocess.Popen(
            [ide_bin, folder_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    elif cmd == "run-app" and len(sys.argv) > 2:
        exec_str = sys.argv[2]
        subprocess.Popen(
            ["bash", "-c", exec_str],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
