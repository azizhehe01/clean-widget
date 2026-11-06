#!/usr/bin/env python3
"""
My Playlist Manager for Quickshell DesktopWidgetsApp
Stores and manages favorite tracks saved via the '+' button in the Music Sidebar.
"""
import sys
import os
import json
import time
import subprocess
import re

PLAYLIST_PATH = os.path.expanduser("~/.config/quickshell/DesktopWidgetsApp/sidebar/playlist.json")

def load_playlist():
    if not os.path.exists(PLAYLIST_PATH):
        return []
    try:
        with open(PLAYLIST_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_playlist(items):
    os.makedirs(os.path.dirname(PLAYLIST_PATH), exist_ok=True)
    with open(PLAYLIST_PATH, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2, ensure_ascii=False)

def get_current_player_url():
    try:
        out = subprocess.check_output(
            ["playerctl", "metadata", "xesam:url"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        if out:
            return out
    except Exception:
        pass
    try:
        out = subprocess.check_output(
            ["playerctl", "metadata", "mpris:trackid"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        if out:
            # Format: /com/spotify/track/31TZQkPSm5SRum1ZyUDUSS
            m = re.search(r"track[/:]([a-zA-Z0-9]+)", out)
            if m:
                return f"https://open.spotify.com/track/{m.group(1)}"
    except Exception:
        pass
    return ""

def to_spotify_uri(url):
    if not url:
        return ""
    if url.startswith("spotify:"):
        return url
    m = re.search(r"track[/:]([a-zA-Z0-9]+)", url)
    if m:
        return f"spotify:track:{m.group(1)}"
    return url

def add_track(title, artist, album="", art_url="", url="", duration=""):
    title = (title or "").strip()
    artist = (artist or "").strip()
    if not title or title.lower() in ("no track playing", "none", "unknown"):
        print(json.dumps({"status": "ignored", "reason": "invalid_track"}))
        return

    # Auto-detect URL from playerctl if missing
    if not url:
        url = get_current_player_url()

    items = load_playlist()
    for idx, it in enumerate(items):
        if it.get("title", "").strip().lower() == title.lower() and \
           it.get("artist", "").strip().lower() == artist.lower():
            # Update URL if it was missing
            if url and not it.get("url"):
                it["url"] = url
                it["spotify_uri"] = to_spotify_uri(url)
                save_playlist(items)
            print(json.dumps({"status": "already_exists", "count": len(items), "item": it}))
            return

    new_item = {
        "id": str(int(time.time() * 1000)),
        "title": title,
        "artist": artist,
        "album": album or "",
        "art_url": art_url or "",
        "url": url or "",
        "spotify_uri": to_spotify_uri(url),
        "duration": duration or "",
        "added_at": int(time.time())
    }
    items.insert(0, new_item)
    save_playlist(items)
    print(json.dumps({"status": "added", "count": len(items), "item": new_item}))

def remove_track(track_id=None, title=None, artist=None):
    items = load_playlist()
    initial_len = len(items)
    if track_id:
        items = [it for it in items if str(it.get("id")) != str(track_id)]
    elif title:
        items = [it for it in items if not (
            it.get("title", "").strip().lower() == title.strip().lower() and
            (not artist or it.get("artist", "").strip().lower() == artist.strip().lower())
        )]
    save_playlist(items)
    print(json.dumps({"status": "removed", "count": len(items), "changed": len(items) != initial_len}))

def check_saved(title, artist=""):
    title = (title or "").strip().lower()
    artist = (artist or "").strip().lower()
    if not title or title in ("no track playing", "none"):
        print(json.dumps({"saved": False}))
        return
    items = load_playlist()
    found = any(
        it.get("title", "").strip().lower() == title and
        (not artist or it.get("artist", "").strip().lower() == artist)
        for it in items
    )
    print(json.dumps({"saved": found, "count": len(items)}))

def play_track(uri_or_url):
    if not uri_or_url:
        subprocess.run(["playerctl", "play"], stderr=subprocess.DEVNULL)
        return
    spotify_uri = to_spotify_uri(uri_or_url)
    if spotify_uri.startswith("spotify:track:"):
        # Try native D-Bus OpenUri directly on Spotify
        res = subprocess.run([
            "dbus-send", "--print-reply", "--dest=org.mpris.MediaPlayer2.spotify",
            "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.OpenUri",
            f"string:{spotify_uri}"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode == 0:
            print(json.dumps({"status": "played_dbus", "uri": spotify_uri}))
            return
    # Fallback to xdg-open
    subprocess.Popen(["xdg-open", uri_or_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({"status": "opened_xdg", "url": uri_or_url}))

def list_tracks():
    items = load_playlist()
    print(json.dumps(items))

def main():
    if len(sys.argv) < 2:
        list_tracks()
        return

    cmd = sys.argv[1].lower()
    if cmd == "list":
        list_tracks()
    elif cmd == "add":
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        album = sys.argv[4] if len(sys.argv) > 4 else ""
        art_url = sys.argv[5] if len(sys.argv) > 5 else ""
        url = sys.argv[6] if len(sys.argv) > 6 else ""
        duration = sys.argv[7] if len(sys.argv) > 7 else ""
        add_track(title, artist, album, art_url, url, duration)
    elif cmd == "remove":
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        if target.isdigit() and len(target) >= 12:
            remove_track(track_id=target)
        else:
            remove_track(title=target, artist=artist)
    elif cmd == "check":
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        check_saved(title, artist)
    elif cmd == "play":
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        play_track(target)
    else:
        list_tracks()

if __name__ == "__main__":
    main()
