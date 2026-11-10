#!/usr/bin/env python3
"""
glyph-shell Native Wallpaper Engine & Manager
Replaces ml4w-wallpaper-app and ml4w-wallpaper with a standalone, fast,
Nothing OS 3.0 / glyph-shell native implementation.

Features:
- Dedicated wallpaper directory: ~/.config/quickshell/DesktopWidgetsApp/wallpapers
- Automatic one-time migration from ~/.config/ml4w/wallpapers if needed
- Fast 16:9 thumbnail caching in ~/.cache/glyph-shell/thumbs/
- Instant 60fps Live Preview via awww / swww / hyprpaper
- Full ecosystem sync on apply (glyph-shell frosted glass, hyprlock, matugen)
"""

import glob
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
from PIL import Image

SHELL_DIR = os.path.expanduser("~/.config/quickshell/DesktopWidgetsApp")
PRIMARY_WP_DIR = os.path.join(SHELL_DIR, "wallpapers")
USER_PICTURES_WP_DIR = os.path.expanduser("~/Pictures/Wallpapers")
LEGACY_ML4W_WP_DIR = os.path.expanduser("~/.config/ml4w/wallpapers")

GLYPH_CACHE_DIR = os.path.expanduser("~/.cache/glyph-shell")
THUMBS_DIR = os.path.join(GLYPH_CACHE_DIR, "thumbs")
GLYPH_CURRENT_WP = os.path.join(GLYPH_CACHE_DIR, "current_wallpaper")

# Legacy compatibility paths so other tools/configs never break
ML4W_CACHE_DIR = os.path.expanduser("~/.cache/ml4w/hyprland-dotfiles")
ML4W_CURRENT_WP = os.path.join(ML4W_CACHE_DIR, "current_wallpaper")
ML4W_BLURRED_WP = os.path.join(ML4W_CACHE_DIR, "blurred_wallpaper.png")
LOCK_SYMLINK = "/tmp/nothing_lock_wallpaper"

VALID_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def ensure_dirs_and_migrate():
    os.makedirs(PRIMARY_WP_DIR, exist_ok=True)
    os.makedirs(THUMBS_DIR, exist_ok=True)
    os.makedirs(ML4W_CACHE_DIR, exist_ok=True)

    # Auto-migrate wallpapers from ~/.config/ml4w/wallpapers if PRIMARY_WP_DIR is empty
    existing = [
        f for f in os.listdir(PRIMARY_WP_DIR)
        if os.path.splitext(f)[1].lower() in VALID_EXTS
    ]
    if not existing and os.path.isdir(LEGACY_ML4W_WP_DIR):
        try:
            for fname in os.listdir(LEGACY_ML4W_WP_DIR):
                ext = os.path.splitext(fname)[1].lower()
                if ext in VALID_EXTS:
                    src = os.path.join(LEGACY_ML4W_WP_DIR, fname)
                    dst = os.path.join(PRIMARY_WP_DIR, fname)
                    if os.path.isfile(src) and not os.path.exists(dst):
                        shutil.copy2(src, dst)
        except Exception:
            pass


def get_current_wallpaper():
    for cache_f in (GLYPH_CURRENT_WP, ML4W_CURRENT_WP):
        if os.path.exists(cache_f):
            try:
                with open(cache_f, "r") as f:
                    p = f.read().strip()
                if p and os.path.exists(p):
                    # If it points to legacy folder and exists in primary folder, prefer primary
                    bname = os.path.basename(p)
                    primary_cand = os.path.join(PRIMARY_WP_DIR, bname)
                    if os.path.exists(primary_cand):
                        return primary_cand
                    return p
            except Exception:
                pass

    for daemon_cmd in ("awww", "swww"):
        if shutil.which(daemon_cmd):
            try:
                out = subprocess.check_output(
                    [daemon_cmd, "query"], stderr=subprocess.DEVNULL, timeout=1
                ).decode("utf-8", errors="ignore")
                m = re.search(r"image:\s*(.+)$", out, flags=re.MULTILINE)
                if m:
                    p = m.group(1).strip()
                    if p and os.path.exists(p):
                        return p
            except Exception:
                pass
    return ""


def get_thumb_and_meta(img_path):
    try:
        st = os.stat(img_path)
        sig = f"{img_path}:{int(st.st_mtime)}:{st.st_size}:v1"
        h = hashlib.md5(sig.encode("utf-8")).hexdigest()[:12]
        thumb_path = os.path.join(THUMBS_DIR, f"{h}.jpg")
        meta_path = os.path.join(THUMBS_DIR, f"{h}.json")

        if os.path.exists(thumb_path) and os.path.exists(meta_path):
            try:
                with open(meta_path, "r") as mf:
                    meta = json.load(mf)
                return thumb_path, meta.get("res", "")
            except Exception:
                pass

        with Image.open(img_path) as im:
            w, h_px = im.size
            res_str = f"{w}×{h_px}"
            im_rgb = im.convert("RGB")
            # Center crop to 16:9 (384x216) for crisp, ultra-lightweight carousel cards
            target_w, target_h = 384, 216
            src_ratio = w / max(1, h_px)
            target_ratio = target_w / target_h
            if src_ratio > target_ratio:
                new_w = int(h_px * target_ratio)
                left = (w - new_w) // 2
                im_crop = im_rgb.crop((left, 0, left + new_w, h_px))
            else:
                new_h = int(w / target_ratio)
                top = (h_px - new_h) // 2
                im_crop = im_rgb.crop((0, top, w, top + new_h))

            im_thumb = im_crop.resize((target_w, target_h), Image.Resampling.LANCZOS)
            im_thumb.save(thumb_path, "JPEG", quality=86, optimize=True)

            with open(meta_path, "w") as mf:
                json.dump({"res": res_str}, mf)

            return thumb_path, res_str
    except Exception:
        return img_path, ""


def collect_wallpapers():
    ensure_dirs_and_migrate()
    current_wp = get_current_wallpaper()
    current_base = os.path.basename(current_wp) if current_wp else ""

    dirs_to_scan = [PRIMARY_WP_DIR]
    if os.path.isdir(USER_PICTURES_WP_DIR) and os.path.abspath(USER_PICTURES_WP_DIR) != os.path.abspath(PRIMARY_WP_DIR):
        dirs_to_scan.append(USER_PICTURES_WP_DIR)

    seen_names = set()
    items = []

    for d in dirs_to_scan:
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d), key=lambda s: s.lower()):
            ext = os.path.splitext(fname)[1].lower()
            if ext not in VALID_EXTS:
                continue
            if fname.lower() in seen_names:
                continue
            full_path = os.path.join(d, fname)
            if not os.path.isfile(full_path):
                continue

            seen_names.add(fname.lower())
            thumb_path, res_str = get_thumb_and_meta(full_path)
            raw_title = os.path.splitext(fname)[0]
            clean_title = re.sub(r"[-_]+", " ", raw_title).strip()

            is_active = (
                os.path.abspath(full_path) == os.path.abspath(current_wp)
                if current_wp
                else False
            ) or (fname == current_base and current_base != "")

            items.append({
                "name": fname,
                "title": clean_title,
                "path": full_path,
                "thumb": thumb_path,
                "res": res_str,
                "active": is_active,
            })

    return {
        "current": current_wp,
        "folder": PRIMARY_WP_DIR,
        "count": len(items),
        "wallpapers": items,
    }


def ensure_awww_daemon():
    if not shutil.which("awww"):
        return False
    try:
        res = subprocess.run(
            ["awww", "query"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
        if res.returncode == 0:
            return True
        if shutil.which("awww-daemon"):
            subprocess.Popen(
                ["awww-daemon"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            import time
            for _ in range(15):
                time.sleep(0.08)
                if subprocess.run(
                    ["awww", "query"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                ).returncode == 0:
                    return True
    except Exception:
        pass
    return False


def set_display_wallpaper(img_path, transition="fade", duration="0.45", angle="30"):
    if not os.path.isfile(img_path):
        return False

    if ensure_awww_daemon():
        cmd = [
            "awww", "img", img_path,
            "--resize", "crop",
            "--crop-gravity", "center",
            "--transition-type", transition,
            "--transition-duration", str(duration),
            "--transition-fps", "60",
        ]
        if transition in ("wipe", "wave", "any", "outer"):
            cmd.extend(["--transition-angle", str(angle)])
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
            return True
        except Exception:
            pass

    if shutil.which("swww"):
        try:
            subprocess.run(
                [
                    "swww", "img", img_path,
                    "--transition-type", transition,
                    "--transition-duration", str(duration),
                    "--transition-fps", "60",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3,
            )
            return True
        except Exception:
            pass

    return False


def update_blurred_and_ecosystem(img_path):
    ensure_dirs_and_migrate()

    # 1. Record active wallpaper in glyph-shell and legacy ml4w cache
    for target_file in (GLYPH_CURRENT_WP, ML4W_CURRENT_WP):
        try:
            with open(target_file, "w") as f:
                f.write(img_path + "\n")
        except Exception:
            pass

    # 2. Update lockscreen wallpaper symlink (/tmp/nothing_lock_wallpaper)
    try:
        if os.path.lexists(LOCK_SYMLINK):
            os.remove(LOCK_SYMLINK)
        os.symlink(img_path, LOCK_SYMLINK)
    except Exception:
        pass

    # 3. Generate frosted glass blur for DesktopWidgetsWindow & NotificationPopupWindow
    try:
        src_sig = f"{img_path}:{int(os.path.getmtime(img_path))}:v5"
        wp_hash = hashlib.md5(src_sig.encode("utf-8")).hexdigest()[:10]
        custom_blurred_wp = f"/tmp/ml4w_widget_frost_{wp_hash}.jpg"

        if not os.path.exists(custom_blurred_wp):
            for old_f in glob.glob("/tmp/ml4w_widget_frost_*.jpg"):
                try:
                    os.remove(old_f)
                except Exception:
                    pass

            if shutil.which("magick"):
                subprocess.run(
                    [
                        "magick",
                        img_path,
                        "-resize", "1920x1080^",
                        "-gravity", "center",
                        "-extent", "1920x1080",
                        "-blur", "0x16",
                        custom_blurred_wp,
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
            else:
                from PIL import ImageFilter
                with Image.open(img_path) as im:
                    im_rgb = im.convert("RGB").resize((1920, 1080), Image.Resampling.LANCZOS)
                    im_blur = im_rgb.filter(ImageFilter.GaussianBlur(radius=16))
                    im_blur.save(custom_blurred_wp, "JPEG", quality=85)

        if os.path.exists(custom_blurred_wp):
            shutil.copy2(custom_blurred_wp, ML4W_BLURRED_WP)
    except Exception:
        pass

    # 4. Run matugen in background if available (for GTK/system colors)
    for m_bin in (
        shutil.which("matugen"),
        os.path.expanduser("~/.cargo/bin/matugen"),
        os.path.expanduser("~/.local/bin/matugen"),
    ):
        if m_bin and os.path.isfile(m_bin):
            try:
                subprocess.Popen(
                    [m_bin, "image", img_path, "--source-color-index", "0", "-m", "dark"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
            except Exception:
                pass
            break


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

    if cmd == "list":
        print(json.dumps(collect_wallpapers()))

    elif cmd == "preview":
        if len(sys.argv) < 3:
            sys.exit(1)
        target = os.path.expanduser(sys.argv[2])
        set_display_wallpaper(target, transition="fade", duration="0.38")
        print(json.dumps({"status": "previewed", "path": target}))

    elif cmd == "apply":
        if len(sys.argv) < 3:
            sys.exit(1)
        target = os.path.expanduser(sys.argv[2])
        skip_display = ("--already-previewed" in sys.argv)
        if not skip_display:
            set_display_wallpaper(target, transition="wipe", duration="0.65", angle="30")
        update_blurred_and_ecosystem(target)
        print(json.dumps({"status": "applied", "path": target}))

    elif cmd == "random":
        info = collect_wallpapers()
        wps = info.get("wallpapers", [])
        if not wps:
            sys.exit(1)
        current = info.get("current", "")
        candidates = [w for w in wps if os.path.abspath(w["path"]) != os.path.abspath(current)]
        chosen = random.choice(candidates if candidates else wps)
        set_display_wallpaper(chosen["path"], transition="wipe", duration="0.7", angle="30")
        update_blurred_and_ecosystem(chosen["path"])
        print(json.dumps({"status": "applied", "path": chosen["path"], "name": chosen["name"]}))

    elif cmd == "open-folder":
        ensure_dirs_and_migrate()
        subprocess.Popen(
            ["xdg-open", PRIMARY_WP_DIR],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


if __name__ == "__main__":
    main()
