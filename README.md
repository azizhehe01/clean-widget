# Chameleon Frosted Glass Desktop Widgets & Notifications for Quickshell & Hyprland

A modern **Chameleon Frosted Glass Bento Grid** desktop widget suite and native **Notification Popup Server** for Wayland/Hyprland, built natively with **Quickshell (Qt6 / QML)** and a lightweight Python background service.

![Preview](assets/preview.png)

---

## ✨ Features

- 🕒 **Nothing OS Clock & Date Card**: Large digital clock rendered in Nothing's signature dot-matrix typeface (`Ndot57`) paired with a technical monospace date (`LetteraMonoLL`) via `Quickshell.SystemClock`.
- 🌦️ **Nothing OS Live Weather & Location Card**:
  - Dot-matrix weather icon (`assets/weather-dot.svg`), daily High/Low (`H/L`), and large dot-matrix temperature (`Ndot55`).
  - Real-time weather condition, auto-detected city location (`ip-api.com`), and humidity + wind speed (`Open-Meteo` / `wttr.in`) with 15-minute local caching.
- 🎵 **Unified Media Player & Real-Time Synced Lyrics Card**:
  - Live **MPRIS** integration (Spotify, YouTube/Brave/Firefox, VLC, Amberol, etc.).
  - Dynamic **Album Cover Art** with automatic fallback (`assets/album.jpg`).
  - Interactive playback controls (*Previous*, *Play/Pause*, *Next*).
  - **3-Line Real-Time Synced Lyrics** that automatically highlight the active line and collapse smoothly when no lyrics are available.
- 🖼️ **Character / Photo Poster Card**: Rounded `20px` portrait frame with a subtle glass edge border.
- 📊 **Linux System Monitor Card**:
  - **`Root (/)`** and **`Home (/home)`** partition usage & progress bars.
  - **`Battery`** percentage & progress bar.
- ⚡ **Power Controls Capsule**: Quick capsule buttons for *Suspend/Sleep*, *Power Off*, and *Reboot*.
- 🔔 **Native Frosted Glass Notification Popups (`NotificationPopupWindow.qml`)**:
  - Replaces `swaync` / `dunst` / `mako` using `Quickshell.Services.Notifications` (`org.freedesktop.Notifications`).
  - Matches the **Real-Time GPU Chameleon Frosted Glass** aesthetic of the desktop widgets (`20px` corner radius, specular glass border, and live Hyprland Dual-Kawase GPU blur).
  - Features smooth slide/fade transitions, scrollable long notification bodies (`Flickable` + `WheelHandler`), interactive D-Bus action buttons, smart multi-workspace window focus via `xdg_activation_v1`, click-anywhere dismissal, and a bottom auto-dismiss progress bar that pauses on hover.

---

## 🔍 Data Sources & How It Works

Every piece of data shown on the widget is fetched automatically without requiring paid API keys:

| Component | Source / Protocol | How It Works |
| :--- | :--- | :--- |
| **Album Cover Art** | `Quickshell.Services.Mpris` (`mpris:artUrl`) | Read directly in QML from the active media player's D-Bus MPRIS metadata (`activePlayer.trackArtUrl`). Falls back to `assets/album.jpg` when idle. |
| **Song Title & Artist** | `Quickshell.Services.Mpris` & `playerctl` | Read live from D-Bus MPRIS (`xesam:title` & `xesam:artist`), prioritizing whichever player is currently in the `Playing` state. |
| **Real-Time Synced Lyrics** | **[LRCLIB API](https://lrclib.net/)** (`https://lrclib.net/api/search`) + `playerctl position` | `stats.py` reads the active track title, artist, and playback timestamp (`position` in seconds) via `playerctl`, queries the open-source **LRCLIB** database for time-synced `.lrc` lyrics (`[mm:ss.xx]`), caches them locally in `/tmp/ml4w_desktop_lyrics_cache_v2.json`, and syncs the 3 visible lines to the current playback second. Works even for songs where Spotify hides or lacks lyrics, as well as YouTube playback! |
| **Weather, Temp & Location** | **[Open-Meteo API](https://open-meteo.com/)** + **[ip-api.com](http://ip-api.com/)** (fallback: **[wttr.in](https://wttr.in/)**) | Automatically detects city coordinates via IP geolocation, fetches current temperature, daily High/Low (`H/L`), weather condition, humidity (`%`), and wind speed (`KM/H`), and caches for 15 minutes in `/tmp/ml4w_desktop_widgets_cache_v3.json`. |
| **Disk Partitions (`Root /`, `Home /home`)** | Python `shutil.disk_usage()` | Queries native Linux filesystem usage for `/` and `~` (`/home`) every 2.5 seconds. |
| **Battery Status** | Linux `/sys/class/power_supply/BAT*` | Reads hardware battery capacity (`/capacity`) and charging status (`/status`) directly from `sysfs`. |
| **Desktop Notifications** | `Quickshell.Services.Notifications` (`NotificationServer`) | Listens directly on D-Bus (`org.freedesktop.Notifications`) for system notifications (`notify-send`, Antigravity IDE, Spotify, Discord, browser alerts, etc.) and renders them as stacked frosted-glass cards at the top-right corner. |
| **Real-Time GPU Frosted Glass** | Hyprland `layerrule` (`blur`, `ignorealpha 0.1`) | Uses Hyprland's real-time GPU Dual-Kawase blur (`size = 10`, `passes = 3`, `xray = false`) so both widgets and notifications dynamically blur whatever wallpaper or application window is directly behind them in real-time. |

---

## 📦 Requirements

Make sure the following packages are installed on your system:

1. **[Quickshell](https://quickshell.outfoxxed.me/)** (`qs`)
   - **Fedora**: `sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell`
   - **Arch Linux**: `yay -S quickshell-git` or `paru -S quickshell-git`
2. **Python 3** (`python3`)
3. **playerctl** (required for media controls & timestamped lyrics sync)
   - **Fedora**: `sudo dnf install playerctl`
   - **Arch Linux**: `sudo pacman -S playerctl`
4. **Fonts**:
   - Official Nothing OS fonts (`Ndot55`, `Ndot57`, `NType82`, `LetteraMonoLL`) are **bundled directly inside `assets/fonts/`** and loaded automatically via QML `FontLoader`.
   - `FiraCode Nerd Font` (Media & Power icons)

---

## 🚀 Installation

### 1. Clone the repository
Clone directly into your `~/.config/quickshell/` folder:

```bash
git clone https://github.com/<your-username>/<repo-name>.git ~/.config/quickshell/DesktopWidgetsApp
```

### 2. Make the helper script executable
```bash
chmod +x ~/.config/quickshell/DesktopWidgetsApp/stats.py
```

### 3. Run the widget
```bash
qs -p ~/.config/quickshell/DesktopWidgetsApp
```

---

## 🌫️ Hyprland Blur & Autostart Configuration

### Option A: Standard Hyprland (`~/.config/hypr/hyprland.conf`)
Add these lines to your `hyprland.conf`:

```ini
# Autostart Desktop Widgets
exec-once = qs -p ~/.config/quickshell/DesktopWidgetsApp

# Frosted Glass Blur Settings
decoration {
    blur {
        enabled = true
        size = 10
        passes = 3
        new_optimizations = true
        xray = false
        vibrancy = 0.25
        brightness = 1.05
    }
}

# Blur only the cards and ignore transparent gaps
layerrule = blur, quickshell:desktop-widgets
layerrule = ignorealpha 0.2, quickshell:desktop-widgets
layerrule = blur, quickshell:notifications
layerrule = ignorealpha 0.2, quickshell:notifications
```

### Option B: ML4W Dotfiles (Hyprland Lua Config)
1. In `~/.config/hypr/conf/decorations/default.lua`, add:
   ```lua
   hl.layer_rule({
       name = "quickshell-desktop-widgets",
       match = { namespace = "quickshell:desktop-widgets" },
       blur = true,
       ignore_alpha = 0.2,
   })

   hl.layer_rule({
       name = "quickshell-notifications",
       match = { namespace = "quickshell:notifications" },
       blur = true,
       ignore_alpha = 0.2,
   })
   ```
2. In `~/.config/ml4w/scripts/ml4w-autostart`, add:
   ```bash
   qs -p $HOME/.config/quickshell/DesktopWidgetsApp &
   ```

---

## 🎨 Customization

### Changing the Character / Poster Image
Replace `assets/poster.jpg` with your own vertical image:

```bash
cp /path/to/your-image.jpg ~/.config/quickshell/DesktopWidgetsApp/assets/poster.jpg
```

### Safe Reload Command
To restart the widget cleanly after editing QML or replacing `assets/poster.jpg`:

```bash
kill $(pgrep -f 'quickshell/DesktopWidgetsApp') 2>/dev/null
qs -p ~/.config/quickshell/DesktopWidgetsApp &
```

---

## 📄 License
MIT License. Feel free to fork, customize, and share!
