#!/usr/bin/env bash
# =============================================================================
#  GLYPH-SHELL INSTALLER & ENVIRONMENT SETUP
#  Nothing OS 3.0 Dot-Matrix & Chameleon Frosted Glass Shell Suite for Hyprland
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/quickshell/glyph-shell"
FONTS_DIR="$HOME/.local/share/fonts/NothingOS"
FONTCONFIG_DIR="$HOME/.config/fontconfig/conf.d"
HYPR_DIR="$HOME/.config/hypr"

# Color helpers
C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_WHITE="\033[1;37m"
C_GRAY="\033[0;37m"
C_BOLD="\033[1m"

clear 2>/dev/null || true
cat << "EOF"
  ██████╗ ██╗  ██╗   ██╗██████╗ ██╗  ██╗      ███████╗██╗  ██╗███████╗██╗     ██╗     
 ██╔════╝ ██║  ╚██╗ ██╔╝██╔══██╗██║  ██║      ██╔════╝██║  ██║██╔════╝██║     ██║     
 ██║  ███╗██║   ╚████╔╝ ██████╔╝███████║█████╗███████╗███████║█████╗  ██║     ██║     
 ██║   ██║██║    ╚██╔╝  ██╔═══╝ ██╔══██║╚════╝╚════██║██╔══██║██╔══╝  ██║     ██║     
 ╚██████╔╝███████╗██║   ██║     ██║  ██║      ███████║██║  ██║███████╗███████╗███████╗
  ╚═════╝ ╚══════╝╚═╝   ╚═╝     ╚═╝  ╚═╝      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
 [:::] NOTHING OS 3.0 DOT-MATRIX & CHAMELEON FROSTED GLASS SHELL SUITE FOR HYPRLAND
EOF
echo ""

# -----------------------------------------------------------------------------
# 1. Directory & Symlink Setup
# -----------------------------------------------------------------------------
printf "${C_BOLD}[1/5] Memeriksa direktori instalasi...${C_RESET}\n"

mkdir -p "$HOME/.config/quickshell"
if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
    if [[ -d "$TARGET_DIR" && ! -L "$TARGET_DIR" ]]; then
        printf "  ${C_GRAY}Direktori %s sudah ada.${C_RESET}\n" "$TARGET_DIR"
    else
        ln -sfn "$SCRIPT_DIR" "$TARGET_DIR"
        printf "  ${C_GREEN}✓${C_RESET} Symlink dibuat: %s -> %s\n" "$TARGET_DIR" "$SCRIPT_DIR"
    fi
fi

# Compatibility symlink for DesktopWidgetsApp if cloned as glyph-shell
LEGACY_DIR="$HOME/.config/quickshell/DesktopWidgetsApp"
if [[ "$SCRIPT_DIR" == "$TARGET_DIR" && ! -e "$LEGACY_DIR" ]]; then
    ln -sfn "$TARGET_DIR" "$LEGACY_DIR"
    printf "  ${C_GREEN}✓${C_RESET} Symlink backward-compatibility dibuat: %s\n" "$LEGACY_DIR"
elif [[ "$SCRIPT_DIR" == "$LEGACY_DIR" && ! -e "$TARGET_DIR" ]]; then
    ln -sfn "$LEGACY_DIR" "$TARGET_DIR"
    printf "  ${C_GREEN}✓${C_RESET} Symlink modern dibuat: %s -> %s\n" "$TARGET_DIR" "$LEGACY_DIR"
fi

# -----------------------------------------------------------------------------
# 2. Install Nothing OS Official Fonts
# -----------------------------------------------------------------------------
printf "\n${C_BOLD}[2/5] Menginstall Font Resmi Nothing OS & Dot-Matrix...${C_RESET}\n"
mkdir -p "$FONTS_DIR" "$FONTCONFIG_DIR"

if [[ -d "$SCRIPT_DIR/assets/fonts" ]]; then
    cp -f "$SCRIPT_DIR/assets/fonts"/*.otf "$FONTS_DIR/"
    printf "  ${C_GREEN}✓${C_RESET} Font Ndot55, Ndot57, NType82, LetteraMonoLL disalin ke %s\n" "$FONTS_DIR"
fi

# Fontconfig Pango alias fix (ensures Ndot 57 & NType 82 resolve in Pango/hyprlock)
cat > "$FONTCONFIG_DIR/99-dotmatrix-fonts.conf" << "CONF"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>Ndot</family>
    <prefer><family>Ndot 57</family></prefer>
  </alias>
  <alias>
    <family>Ndot57</family>
    <prefer><family>Ndot 57</family></prefer>
  </alias>
  <alias>
    <family>Ndot55</family>
    <prefer><family>Ndot 55</family></prefer>
  </alias>
  <alias>
    <family>NType</family>
    <prefer><family>NType 82</family></prefer>
  </alias>
  <alias>
    <family>NType82</family>
    <prefer><family>NType 82</family></prefer>
  </alias>
</fontconfig>
CONF
printf "  ${C_GREEN}✓${C_RESET} Konfigurasi Fontconfig Pango di-install ke %s\n" "$FONTCONFIG_DIR/99-dotmatrix-fonts.conf"

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONTS_DIR" >/dev/null 2>&1 || true
    printf "  ${C_GREEN}✓${C_RESET} Font cache berhasil diperbarui!\n"
fi

# -----------------------------------------------------------------------------
# 3. Permissions Check & Script Executables
# -----------------------------------------------------------------------------
printf "\n${C_BOLD}[3/5] Mengatur hak akses script (*.sh & *.py)...${C_RESET}\n"
find "$SCRIPT_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
printf "  ${C_GREEN}✓${C_RESET} Seluruh background service & launcher script sudah executable.\n"

# -----------------------------------------------------------------------------
# 4. Hyprland & Hyprlock Integrasi
# -----------------------------------------------------------------------------
printf "\n${C_BOLD}[4/5] Mengintegrasikan Lock Screen & Hyprland...${C_RESET}\n"
mkdir -p "$HYPR_DIR"

# Symlink hyprlock.conf
if [[ -f "$SCRIPT_DIR/lockscreen/hyprlock.conf" ]]; then
    ln -sfn "$SCRIPT_DIR/lockscreen/hyprlock.conf" "$HYPR_DIR/hyprlock.conf"
    printf "  ${C_GREEN}✓${C_RESET} Symlink Hyprlock aktif: %s/hyprlock.conf\n" "$HYPR_DIR"
fi

# Wallpaper cache symlink
WP_CACHE="$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper"
if [[ -f "$WP_CACHE" ]]; then
    WP_PATH="$(tr -d '\r\n' < "$WP_CACHE")"
    if [[ -f "$WP_PATH" ]]; then
        ln -sfn "$WP_PATH" "/tmp/nothing_lock_wallpaper"
    fi
fi

# -----------------------------------------------------------------------------
# 5. Dependency & Runtime Diagnostics
# -----------------------------------------------------------------------------
printf "\n${C_BOLD}[5/5] Memeriksa paket pendukung (dependencies)...${C_RESET}\n"
missing_deps=()

for cmd in qs playerctl brightnessctl nmcli python3 hyprlock; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  ${C_GREEN}✓${C_RESET} %-14s : terpasang (%s)\n" "$cmd" "$(command -v "$cmd")"
    else
        printf "  ${C_RED}✗${C_RESET} %-14s : ${C_RED}BELUM TERPASANG${C_RESET}\n" "$cmd"
        missing_deps+=("$cmd")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo ""
    printf "${C_RED}Perhatian:${C_RESET} Paket berikut belum terpasang: ${C_BOLD}%s${C_RESET}\n" "${missing_deps[*]}"
    printf "Silakan pasang via package manager distro lo:\n"
    printf "  • Fedora: ${C_GRAY}sudo dnf install %s${C_RESET}\n" "${missing_deps[*]}"
    printf "  • Arch:   ${C_GRAY}sudo pacman -S %s${C_RESET}\n" "${missing_deps[*]}"
fi

echo ""
printf "${C_GREEN}${C_BOLD}Selamat! Instalasi GLYPH-SHELL selesai sempurna!${C_RESET}\n"
printf "Untuk menjalankan / me-reload glyph-shell sekarang:\n"
printf "  ${C_BOLD}qs -p %s &${C_RESET}\n\n" "$TARGET_DIR"

if pgrep -u "$(id -u)" -x quickshell >/dev/null 2>&1; then
    printf "${C_GRAY}Quickshell sedang berjalan di latar belakang.${C_RESET}\n"
fi
