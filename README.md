# Chameleon Frosted Glass Desktop Widgets, Notifikasi & Interactive Notch

Koleksi widget desktop modern bertema **Chameleon Frosted Glass Bento Grid**, **Server Notifikasi Native**, dan **Top Notch Interaktif** (Dynamic Island bergaya Nothing OS Volume OSD & Angry Eyes) untuk Wayland / Hyprland. Dibuat secara native menggunakan **[Quickshell](https://quickshell.outfoxxed.me/) (Qt6 / QML)** dengan akselerasi penuh GPU Hyprland dan background daemon Python yang sangat ringan.

---

## ✨ Fitur-Fitur Utama

### 1. 👁️ Interactive Top Notch & Nothing OS Volume OSD (`notch/`)
* **Mata Interaktif Pelacak Kursor:** Sepasang mata putih bergaya *angry eyes* dengan efek paralaks 2-layer yang melacak posisi kursor mouse secara *real-time* di seluruh layar melalui Hyprland IPC daemon (`cursor.py`), dilengkapi animasi kedipan acak (*random blinks*).
* **Nothing OS Dot-Matrix Volume OSD:** Saat volume suara diubah (via tombol shortcut keyboard, scroll wheel di notch, atau mixer), notch akan bermorfosis secara mulus menjadi HUD Volume bergaya Nothing OS lengkap dengan icon speaker dot-matrix, 16 kapsul titik bar progress, dan persentase angka font `Ndot57`.
* **Smart Auto-Hide (`autoHideMode: "any_window"`):**
  * Notch otomatis **meluncur naik dan bersembunyi** saat ada jendela aplikasi terbuka atau aktif (misal saat membuka terminal lewat `Super + Enter`, browser, atau editor).
  * Layar tetap **100% lega tanpa terpotong** (`reserveSpace: false` / `exclusiveZone: 0`).
  * Saat mengubah volume, notch otomatis meluncur turun menampilkan indikator volume Nothing OS, lalu kembali bersembunyi setelah timeout.
* **Hover-to-Reveal:** Cukup tempelkan kursor ke ujung paling atas layar (`y <= 8px`), notch akan meluncur turun agar lo bisa melihat mata atau mengubah volume langsung via scroll.
* **Kontrol Mouse Cepat:** Scroll wheel di atas notch untuk menaikkan/menurunkan volume (step 5%), klik kanan untuk toggle Mute/Unmute.

### 2. 🕒 Jam Digital & Tanggal Nothing OS (`widgets/`)
* Jam digital besar berdesain titik-titik khas Nothing OS menggunakan font resmi `Ndot57`.
* Hari dan tanggal bergaya technical monospace menggunakan font resmi `LetteraMonoLL`.
* Didukung langsung oleh `Quickshell.SystemClock` yang hemat daya dan sinkron per menit.

### 3. 🌦️ Kartu Cuaca & Lokasi Real-Time (`widgets/`)
* Icon cuaca dot-matrix putih (`assets/weather-dot.svg`).
* Suhu harian tertinggi & terendah (`H 29°` / `L 23°`), serta suhu besar `Ndot55`.
* Kondisi cuaca, deteksi lokasi kota otomatis berdasarkan IP publik (`ip-api.com` / `wttr.in`), serta kelembapan dan kecepatan angin (`74% · 7 KM/H`) dengan sistem caching lokal 15 menit agar tidak membebani jaringan.

### 4. 🎵 Media Player & Lirik Tersinkronisasi Real-Time (`widgets/`)
* **Integrasi MPRIS:** Terhubung langsung ke media player aktif (Spotify, YouTube di browser Brave/Firefox/Chrome, VLC, Amberol, dll.).
* **Cover Album Dinamis:** Menampilkan cover album lagu secara otomatis dari D-Bus MPRIS, dengan fallback ke gambar lokal [`assets/album.jpg`](assets/album.jpg).
* **Kontrol Playback:** Tombol interaktif *Previous*, *Play/Pause*, dan *Next*.
* **Lirik Sinkron Real-Time (3 Baris):** Mengambil lirik dari database terbuka [LRCLIB](https://lrclib.net/) dan disinkronkan langsung per detik dengan posisi playback lagu (`playerctl position`). Baris yang aktif otomatis disorot putih terang dan membesar halus.

### 5. 🖼️ Frame Poster / Foto Estetik (`widgets/`)
* Frame foto portrait elegan ber-radius 20px dengan pinggiran kaca halus.
* Menampilkan gambar lokal dari [`assets/poster.jpg`](assets/poster.jpg).

### 6. 📊 Monitor Sistem Linux (`widgets/`)
* Pemantau partisi Linux: penggunaan ruang `Root (/)` dan `Home (/home)` lengkap dengan bar kapasitas.
* Indikator persentase baterai laptop langsung dari `sysfs` hardware.

### 7. ⚡ Kapsul Tombol Daya (`widgets/`)
* Tombol cepat dengan icon Nerd Font untuk *Sleep/Suspend*, *Power Off (Shutdown)*, dan *Reboot*.

### 8. 🔔 Server & Popup Notifikasi Frosted Glass Native (`notifications/`)
* Menggantikan daemon notifikasi eksternal seperti `swaync`, `dunst`, atau `mako` via D-Bus `org.freedesktop.Notifications`.
* Menggunakan estetika **Chameleon Frosted Glass** yang serasi dengan widget desktop (radius 20px, border highlight kaca, dan real-time GPU Dual-Kawase blur).
* **Scrollable:** Notifikasi panjang tidak terpotong, bisa di-scroll menggunakan mouse wheel / dua jari touchpad.
* **Tombol Aksi D-Bus:** Mendukung tombol interaktif (Approve, Deny, Open, dll.).
* **Fokus Cepat Window:** Khusus notifikasi aplikasi tertentu (mis. Antigravity IDE), otomatis menampilkan tombol aksi dengan aktivasi workspace akurat via `xdg_activation_v1`.
* **Dismiss Cepat:** Klik di mana saja pada kartu notifikasi untuk menutupnya. Timer auto-dismiss otomatis berhenti saat kursor berada di atas kartu.

---

## 📦 Kebutuhan Sistem (Dependencies)

Pastikan paket-paket berikut sudah terpasang di sistem Linux lo:

### 1. Quickshell (`qs`)
* **Fedora:**
  ```bash
  sudo dnf copr enable errornointernet/quickshell
  sudo dnf install quickshell
  ```
* **Arch Linux:**
  ```bash
  yay -S quickshell-git
  # atau
  paru -S quickshell-git
  ```

### 2. Paket Pendukung
* **Python 3** (untuk background service cuaca, lirik, partisi, dan pelacak kursor)
* **playerctl** (untuk kontrol media & sinkronisasi lirik)
  * Fedora: `sudo dnf install playerctl`
  * Arch: `sudo pacman -S playerctl`
* **ImageMagick** (`magick`, untuk efek blur wallpaper)
  * Fedora: `sudo dnf install ImageMagick`
  * Arch: `sudo pacman -S imagemagick`
* **Fonts:**
  * Font resmi Nothing OS (`Ndot55`, `Ndot57`, `NType82`, `LetteraMonoLL`) **sudah disertakan langsung di dalam folder `assets/fonts/`** dan otomatis dimuat oleh QML.
  * **FiraCode Nerd Font** (untuk icon media, baterai, dan power):
    * Fedora: `sudo dnf install fira-code-fonts`
    * Arch: `sudo pacman -S ttf-fira-code`

---

## 🚀 Panduan Instalasi & Menjalankan

### Langkah 1: Pasang ke Direktori Quickshell
Pastikan folder ditaruh di `~/.config/quickshell/DesktopWidgetsApp`:

```bash
# Jika clone repository baru:
git clone https://github.com/azizhehe01/DesktopWidgetsApp.git ~/.config/quickshell/DesktopWidgetsApp
```

### Langkah 2: Berikan Izin Eksekusi pada Script Pembantu
```bash
chmod +x ~/.config/quickshell/DesktopWidgetsApp/widgets/stats.py
chmod +x ~/.config/quickshell/DesktopWidgetsApp/notch/cursor.py
```

### Langkah 3: Uji Coba Menjalankan
Jalankan melalui terminal untuk melihat output:
```bash
qs -p ~/.config/quickshell/DesktopWidgetsApp
```

---

## 🌫️ Konfigurasi Autostart & Blur Hyprland

### 1. Konfigurasi Autostart
Tambahkan baris berikut ke konfigurasi Hyprland lo (misalnya `~/.config/hypr/hyprland.conf` atau `~/.config/ml4w/scripts/ml4w-autostart`):

```ini
# Autostart DesktopWidgetsApp (Widgets, Notifikasi & Notch)
exec-once = qs -p ~/.config/quickshell/DesktopWidgetsApp
```

> **Catatan untuk Pengguna Dotfiles ML4W:**
> Jika lo sebelumnya menggunakan statusbar bawaan ML4W, pastikan baris `StatusbarWindow {}` di `~/.config/quickshell/shell.qml` dikomentari atau dinonaktifkan agar tidak tumpang tindih dengan Notch.

### 2. Konfigurasi Blur GPU Dual-Kawase di Hyprland
Agar efek frosted glass transparan menghasilkan blur kaca buram yang mewah di Wayland, tambahkan `layerrule` berikut ke `~/.config/hypr/hyprland.conf` (atau konfigurasi dekorasi Hyprland lo):

```ini
# Rule blur untuk Desktop Widgets & Notifikasi
layerrule = blur, quickshell:desktop-widgets
layerrule = ignorealpha 0.1, quickshell:desktop-widgets

layerrule = blur, quickshell:notifications
layerrule = ignorealpha 0.1, quickshell:notifications
```

---

## ⚙️ Panduan Pengaturan & Kustomisasi (Cara Setting)

Semua pengaturan utama telah diletakkan di bagian paling atas file masing-masing komponen agar sangat mudah diubah:

### 1. Mengatur Top Notch & Volume OSD ([`notch/NotchWindow.qml`](notch/NotchWindow.qml))
Buka file `notch/NotchWindow.qml` dan perhatikan baris konfigurasi berikut:

```qml
    // =========================================================================
    // User Configurations (Bisa Diatur Di Sini)
    // =========================================================================
    
    // 1. Durasi berapa lama HUD volume muncul sebelum kembali sembunyi / jadi mata (dalam ms)
    // 1000 = 1.0 detik, 1200 = 1.2 detik, 1800 = 1.8 detik
    property int volumeTimeoutMs: 1000

    // 2. Kecepatan animasi transisi pembesaran/morphing notch (ms)
    property int animDuration: 200

    // 3. Mode Auto-Hide Notch:
    //    "any_window"      : Sembunyi jika ada jendela aplikasi apapun terbuka/aktif (Default)
    //    "not_antigravity" : Sembunyi jika aplikasi yang aktif BUKAN Antigravity
    //    "antigravity"     : Sembunyi jika aplikasi aktif ADALAH Antigravity
    //    "never"           : Selalu tampilkan notch (tidak pernah sembunyi)
    property string autoHideMode: "any_window"

    // 4. Reservasi ruang layar untuk jendela aplikasi:
    //    false = Jendela aplikasi dapat layar penuh 100% tanpa terpotong 38px (Rekomendasi)
    //    true  = Hyprland memesan 38px di atas layar untuk notch
    property bool reserveSpace: false
```

### 2. Mengganti Poster Karakter / Foto
Untuk mengganti foto pada frame poster di widget:
* Cukup timpa file gambar di [`assets/poster.jpg`](assets/poster.jpg) dengan gambar foto portrait pilihan lo (rasio disarankan 9:16 atau 3:4).
* Gambar akan langsung terpasang otomatis dengan sudut membulat 20px.

### 3. Mengganti Cover Album Default
Jika pemutar musik sedang tidak aktif, widget menampilkan cover default dari [`assets/album.jpg`](assets/album.jpg). Lo bisa menggantinya dengan artwork album favorit lo.

### 4. Mengatur Kota & Layanan Cuaca ([`widgets/stats.py`](widgets/stats.py))
* Secara default, script mendeteksi lokasi kota lo secara otomatis menggunakan IP Geolocation publik.
* Jika lo ingin menentukan kota tertentu secara manual, lo bisa mengedit pemanggilan URL di baris 176 file `widgets/stats.py`:
  ```python
  # Ganti "NamaKota" dengan nama kota lo (misal: "Jakarta", "Banyumas", "Bandung")
  req = urllib.request.Request("https://wttr.in/Jakarta?format=%c+%t", headers={"User-Agent": "curl/7.68.0"})
  ```

---

## 📁 Struktur Direktori Proyek

```text
DesktopWidgetsApp/
├── assets/                       # Aset gambar, font Nothing OS, dan icon SVG
│   ├── fonts/
│   │   ├── Ndot55-Regular.otf    # Font angka cuaca
│   │   ├── Ndot57-Regular.otf    # Font jam digital & volume Nothing OS
│   │   ├── NType82-Regular.otf   # Font sans-serif bento grid
│   │   └── LetteraMonoLL-Regular.otf # Font tanggal & teks teknikal monospace
│   ├── album.jpg                 # Fallback cover album
│   ├── poster.jpg                # Foto pada frame poster
│   ├── volume-dot.svg            # Icon speaker dot-matrix
│   ├── volume-mute-dot.svg       # Icon speaker mute dot-matrix
│   ├── weather-dot.svg           # Icon cuaca dot-matrix
│   └── rocket.svg                # Icon aksi notifikasi
├── notch/
│   ├── NotchWindow.qml           # Window Top Notch interaktif & Volume HUD Nothing OS
│   └── cursor.py                 # Daemon IPC Hyprland pelacak kursor & active window
├── notifications/
│   └── NotificationPopupWindow.qml # Server notifikasi native frosted glass
├── widgets/
│   ├── DesktopWidgetsWindow.qml  # Window utama bento grid widget desktop
│   └── stats.py                  # Service pengambil data lirik, cuaca, & sistem
├── shell.qml                     # Entry point Quickshell yang memuat seluruh window
└── README.md                     # Dokumentasi panduan lengkap
```

---

## 📜 Lisensi & Kredit
* Dibuat untuk ekosistem Wayland / Hyprland menggunakan framework hebat [Quickshell](https://quickshell.outfoxxed.me/).
* Tipografi & gaya dot-matrix terinspirasi dari desain hardware dan software [Nothing OS](https://nothing.tech/).
* Database lirik musik didukung oleh komunitas terbuka [LRCLIB](https://lrclib.net/).
