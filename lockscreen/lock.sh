#!/usr/bin/env bash
set -euo pipefail

LOCK_DIR="/home/azhehe/.config/quickshell/DesktopWidgetsApp/lockscreen"
CONF="$LOCK_DIR/hyprlock.conf"
WP_LINK="/tmp/nothing_lock_wallpaper"

# Prevent duplicate hyprlock instances
if pgrep -u "$(id -u)" -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Resolve active desktop wallpaper dynamically for Frosted Glass blur
WP_PATH=""
if [[ -f "$HOME/.cache/glyph-shell/current_wallpaper" ]]; then
    WP_PATH="$(tr -d '\r\n' < "$HOME/.cache/glyph-shell/current_wallpaper")"
elif [[ -f "$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper" ]]; then
    WP_PATH="$(tr -d '\r\n' < "$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper")"
fi

if [[ -z "$WP_PATH" || ! -f "$WP_PATH" ]]; then
    WP_PATH="$HOME/.config/quickshell/DesktopWidgetsApp/wallpapers/default.jpg"
fi
if [[ ! -f "$WP_PATH" ]]; then
    WP_PATH="$HOME/.config/ml4w/wallpapers/clay-banks-CtmO3PZaxmU-unsplash.jpg"
fi

if [[ -f "$WP_PATH" ]]; then
    ln -sf "$WP_PATH" "$WP_LINK"
fi

exec hyprlock --config "$CONF"
