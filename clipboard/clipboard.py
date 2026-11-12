#!/usr/bin/env python3
"""
glyph-shell Native Clipboard History Engine
Extracts, categorizes, and caches clipboard items from cliphist.
"""

import json
import os
import re
import subprocess
import sys

CACHE_DIR = os.path.expanduser("~/.cache/glyph-shell/clip_thumbs")
os.makedirs(CACHE_DIR, exist_ok=True)


def detect_type(preview_str):
    s = preview_str.strip()
    if s.startswith("[[ binary data"):
        return "image"
    if re.match(r"^(https?://|www\.)\S+", s):
        return "url"
    if any(
        kw in s
        for kw in (
            "git ",
            "sudo ",
            "php ",
            "npm ",
            "yarn ",
            "curl ",
            "cat ",
            "docker ",
            "bash",
            "import ",
            "function ",
            "def ",
            "class ",
            "SELECT ",
            "INSERT ",
            "UPDATE ",
            "{",
            "}",
            "=>",
            "::",
            "#!/",
            "export ",
        )
    ) or ("\n" in s and ("=" in s or ";" in s)):
        return "code"
    return "text"


def list_clipboard(limit=75):
    try:
        raw = subprocess.check_output(
            ["cliphist", "list"], stderr=subprocess.DEVNULL, timeout=2
        ).decode("utf-8", errors="ignore")
    except Exception:
        return []

    lines = raw.splitlines()
    items = []

    for line in lines[:limit]:
        if not line.strip():
            continue
        parts = line.split("\t", 1)
        if len(parts) < 2:
            continue
        clip_id = parts[0].strip()
        preview = parts[1].strip()

        item_type = detect_type(preview)
        thumb_url = ""

        if item_type == "image":
            thumb_path = os.path.join(CACHE_DIR, f"{clip_id}.png")
            if not os.path.exists(thumb_path):
                try:
                    dec = subprocess.Popen(
                        ["cliphist", "decode"],
                        stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                    )
                    img_data, _ = dec.communicate(clip_id.encode("utf-8"), timeout=1.5)
                    if img_data and len(img_data) > 32:
                        with open(thumb_path, "wb") as f:
                            f.write(img_data)
                except Exception:
                    pass

            if os.path.exists(thumb_path):
                thumb_url = "file://" + thumb_path
                # Clean up binary data preview string for display
                m = re.search(r"(\d+x\d+)", preview)
                res_str = m.group(1) if m else "Image"
                preview = f"Image / Screenshot ({res_str})"

        # Clean display preview
        clean_preview = preview.replace("\t", " ").strip()
        if len(clean_preview) > 160:
            clean_preview = clean_preview[:157] + "..."

        items.append({
            "id": clip_id,
            "type": item_type,
            "preview": clean_preview,
            "raw": preview,
            "thumb": thumb_url,
        })

    return items


def copy_item(clip_id):
    try:
        # Decode cliphist id directly and feed into wl-copy
        dec = subprocess.Popen(
            ["cliphist", "decode"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        data, _ = dec.communicate(clip_id.encode("utf-8"), timeout=2)
        if data:
            cp = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
            cp.communicate(data, timeout=2)
            return True
    except Exception:
        pass
    return False


def delete_item(clip_id):
    try:
        dec = subprocess.Popen(
            ["cliphist", "delete"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        dec.communicate(clip_id.encode("utf-8"), timeout=2)
        thumb_path = os.path.join(CACHE_DIR, f"{clip_id}.png")
        if os.path.exists(thumb_path):
            os.remove(thumb_path)
        return True
    except Exception:
        pass
    return False


def clear_all():
    try:
        subprocess.run(["cliphist", "wipe"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for f in os.listdir(CACHE_DIR):
            try:
                os.remove(os.path.join(CACHE_DIR, f))
            except Exception:
                pass
        return True
    except Exception:
        return False


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

    if cmd == "list":
        print(json.dumps(list_clipboard()))
    elif cmd == "copy":
        if len(sys.argv) > 2:
            copy_item(sys.argv[2])
    elif cmd == "delete":
        if len(sys.argv) > 2:
            delete_item(sys.argv[2])
    elif cmd == "clear":
        clear_all()


if __name__ == "__main__":
    main()
