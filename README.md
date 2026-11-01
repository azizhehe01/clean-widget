# Aesthetic Desktop Widgets for Quickshell & Hyprland

A minimal, modern, dark frosted-glass desktop widget suite inspired by aesthetic ricing setups, built natively using **Quickshell** on Wayland.

![Preview](assets/preview.png)

---

## ✨ Features

- 🕒 **Clock & Calendar Card**: Displays day, digital time, month, and formatted date.
- 🌦️ **Live Weather Card**: Fetches live temperature & weather icons via `wttr.in` with local caching.
- 🎵 **Media Player Card**:
  - Live MPRIS integration (Spotify, Brave, Chrome, etc.).
  - Album cover art with smooth fallback placeholder.
  - Interactive controls: *Previous*, *Play/Pause*, *Next*.
- 🗑️ **Trash Monitor Pill**: Live trash size calculation + click to open file manager trash.
- 🖼️ **Photo Frame Card**: Aesthetic vertical poster frame (easily replaceable with any personal image).
- 📊 **System Monitor**:
  - Root drive (`C:`) & Home drive (`D:`) storage meters.
  - Live battery percentage bar & charging state.
- ⚡ **Power Controls Pill**: Quick actions for *Sleep*, *Power Off*, and *Restart*.

---

## 📦 Requirements

Before installing, ensure you have the following installed:

1. **[Quickshell](https://quickshell.outfoxxed.me/)** (>= `0.3.0`)
   - Fedora: available in COPR (e.g. `copr enable lionheartp/Hyprland && dnf install quickshell`)
   - Arch Linux: `paru -S quickshell` / `yay -S quickshell`
2. **Python 3** (used by the lightweight background statistics monitor)
3. **Nerd Font** (e.g., `FiraCode Nerd Font`, `JetBrainsMono Nerd Font`) for icons.

---

## 🚀 Installation

### 1. Clone the repository
Clone directly to your Quickshell directory:

```bash
git clone https://github.com/<your-username>/<repo-name>.git ~/.config/quickshell/DesktopWidgetsApp
```

### 2. Make the statistics helper script executable
```bash
chmod +x ~/.config/quickshell/DesktopWidgetsApp/stats.py
```

### 3. Test running the widgets
```bash
qs -p ~/.config/quickshell/DesktopWidgetsApp
```

---

## ⚙️ Autostart Setup

### Option A: Standard Hyprland (`hyprland.conf`)
Add the following line to your `hyprland.conf`:

```ini
exec-once = qs -p ~/.config/quickshell/DesktopWidgetsApp
```

### Option B: ML4W Dotfiles Users
If you are using ML4W Dotfiles, open `~/.config/ml4w/scripts/ml4w-autostart` and add:

```bash
# Start Desktop Widgets
qs -p $HOME/.config/quickshell/DesktopWidgetsApp &
```

---

## 🎨 Customization

### Changing the Poster Photo
Replace `assets/poster.jpg` with any image of your choice (vertical 2:3 or 3:4 aspect ratio looks best):

```bash
cp /path/to/your/image.jpg ~/.config/quickshell/DesktopWidgetsApp/assets/poster.jpg
```
*Note: The widget has `cache: false` enabled, so restarting the widget will immediately load your new image.*

### Changing Widget Position
In `DesktopWidgetsWindow.qml`, adjust the `margins` block:

```qml
margins {
    top: 65    // Distance from the top of your screen (in px)
    left: 65   // Distance from the left edge of your screen (in px)
}
```

### Restarting / Reloading
To quickly refresh the widgets after making edits:

```bash
pkill -f DesktopWidgetsApp && qs -p ~/.config/quickshell/DesktopWidgetsApp &
```

---

## 📄 License
MIT License. Feel free to fork, customize, and share!
