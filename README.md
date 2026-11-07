# Chameleon Frosted Glass Desktop Widgets, Notifikasi, Interactive Notch & Sidebar

Koleksi widget desktop modern bertema **Chameleon Frosted Glass Bento Grid**, **Server Notifikasi Native**, **Top Notch Interaktif** (Dynamic Island bergaya Nothing OS Volume & Brightness OSD, Angry Eyes, WiFi Manager, & Display Projection), serta **Music Sidebar & Playlist Drawer** untuk Wayland / Hyprland. Dibuat secara native menggunakan **[Quickshell](https://quickshell.outfoxxed.me/) (Qt6 / QML)** dengan akselerasi penuh GPU Hyprland dan background daemon Python yang sangat ringan.

<p align="center">
  <img src="assets/preview.png" alt="Desktop Widgets & Notch Preview" width="100%" />
</p>

---

## ✨ Fitur-Fitur Utama

### 1. 👁️ Interactive Top Notch & Nothing OS Volume/Brightness OSD (`notch/`)
* **Mata Interaktif Pelacak Kursor:** Sepasang mata putih bergaya *angry eyes* dengan efek paralaks 2-layer yang melacak posisi kursor mouse secara *real-time* di seluruh layar melalui Hyprland IPC daemon (`cursor.py`), dilengkapi animasi kedipan acak (*random blinks*).
* **Nothing OS Dot-Matrix Volume HUD:** Saat volume suara diubah (via tombol shortcut keyboard, scroll wheel di notch, atau mixer), notch bermorfosis secara mulus menjadi HUD Volume Nothing OS dengan icon speaker dot-matrix, 16 kapsul titik bar progress, dan persentase angka font `Ndot57`.
* **Nothing OS Dot-Matrix Brightness HUD:** Saat kecerahan layar diubah (`XF86MonBrightnessUp/Down` atau Shift + Scroll pada notch), notch menampilkan HUD Kecerahan Layar dengan icon matahari bersinar dot-matrix (`assets/brightness-dot.svg`), 16 kapsul bar, dan persentase angka `Ndot57`.
* **Smart Auto-Hide (`autoHideMode: "any_window"`):**
  * Notch otomatis **meluncur naik dan bersembunyi** saat ada jendela aplikasi terbuka atau aktif (misal saat membuka terminal lewat `Super + Enter`, browser, atau editor).
  * Layar tetap **100% lega tanpa terpotong** (`reserveSpace: false` / `exclusiveZone: 0`).
  * Saat mengubah volume/kecerahan, notch otomatis meluncur turun menampilkan HUD indikator Nothing OS, lalu kembali bersembunyi setelah timeout (1 detik).
* **Hover-to-Reveal:** Cukup tempelkan kursor ke ujung paling atas layar (`y <= 8px`), notch akan meluncur turun agar lo bisa melihat mata atau mengubah volume langsung via scroll.
* **Kontrol Cepat Mouse:**
  * **Scroll:** Naik/turunkan volume suara (step 5%).
  * **Shift + Scroll:** Naik/turunkan kecerahan layar (step 5%).
  * **Klik Kiri (Idle):** Membuka WiFi Network Manager.
  * **Klik Tengah (Scroll Click):** Membuka Display / HDMI Projection Manager.
  * **Klik Kanan:** Toggle Mute/Unmute audio.

---

### 2. 📶 WiFi Network Manager Nothing OS Dot-Matrix (`Super + W`)
* **Akses Cepat & Zero-Dependency:** Menggunakan daemon Python ringan yang terhubung langsung ke `nmcli` bawaan Linux.
* **Shortcut Universal (`Super + W`):** Notch meluncur turun dan bertransformasi (*morphing*) menjadi popover WiFi dot-matrix lengkap.
* **Klik Langsung di Notch:** Selain shortcut keyboard, notch juga bisa langsung diklik saat idle untuk membuka menu WiFi.
* **Tampilan Jaringan Nothing OS:**
  * **Bar Sinyal Dot-Matrix:** 4 kolom titik bertingkat (`:` `::` `:::` `::::`) yang menyala presisi sesuai kekuatan sinyal.
  * **Icon Gembok Dot-Matrix:** Menandai jaringan yang diproteksi password.
  * **Titik Merah (Red Dot):** Menandai jaringan WiFi yang sedang terhubung aktif.
  * **Info IP Address:** Menampilkan alamat IP lokal aktif (misal `IP: 192.168.1.41`) di bagian footer.
* **Koneksi Pintar (1-Click Connect & Inline Password):**
  * Jaringan yang sudah tersimpan / pernah terkoneksi: cukup 1x klik, langsung terhubung otomatis tanpa nanya password.
  * Jaringan baru: muncul kolom input password mini di dalam notch, ketik password lalu tekan Enter!
* **Toggle Radio WiFi ON/OFF:** Switch kapsul dot-matrix untuk mematikan/menyalakan radio WiFi laptop dengan cepat.

---

### 3. 🖥️ Display & HDMI Projection Manager (`Super + P`)
* **Menu Proyeksi Layar Windows-Style:** Morphing menu proyeksi monitor bergaya Nothing OS dot-matrix yang dipicu lewat shortcut keyboard `Super + P` atau klik tengah pada notch.
* **4 Pilihan Mode Proyeksi:**
  1. **PC Screen Only (`PC ONLY`):** Hanya menggunakan monitor internal laptop (`eDP-1`), mematikan output HDMI eksternal.
  2. **Duplicate (`DUPLICATE`):** Mode cermin (*mirroring*), menampilkan gambar yang sama di laptop dan monitor HDMI.
  3. **Extend (`EXTEND`):** Memperluas area kerja ke kanan (`eDP-1` di kiri, `HDMI-A-1` di kanan secara side-by-side).
  4. **Second Screen Only (`SECOND`):** Hanya menampilkan gambar di monitor eksternal HDMI, mematikan layar laptop.
* **Indikator Aktif Dot-Matrix:** Status mode yang sedang aktif ditandai dengan titik merah (*red dot indicator*) dan border highlight.
* **Eksekusi Native Hyprland:** Mengatur monitor secara instan menggunakan perintah `hyprctl keyword monitor` tanpa perlu reload konfigurasi atau aplikasi pihak ketiga.

---

### 4. 🎛️ Music Sidebar & Playlist Drawer (`Ctrl + Super + S`)
Fitur sidebar pengganti ML4W yang dirancang khusus untuk produktivitas tanpa mengganggu alur kerja (*workspace switching*):
* **Panel Slide-Out Kanan:** Dibuka dengan shortcut `Ctrl + Super + S` atau tombol `ESC` untuk menutup.
* **Multi-Player Switcher Tabs:**
  * Mendeteksi otomatis semua media player yang aktif (misal **Spotify** dan browser **YouTube · Brave**).
  * Cukup 1x klik tab untuk berganti kontrol antar pemutar musik dan video browser tanpa perlu berpindah jendela atau workspace!
* **Kontrol Cepat Audio & Kecerahan:** Dilengkapi slider volume dan brightness bergaya Nothing OS di bagian atas panel.
* **Now Playing Card:**
  * Menampilkan artwork album ber-radius, judul lagu tebal, artis, live timeline scrubber, dan kontrol pemutaran dot-matrix (*Prev, Play/Pause, Next*).
* **Tombol `+` (Save to Playlist):**
  * Menambahkan lagu yang sedang diputar ke playlist lokal tersimpan (`sidebar/playlist.json`) dalam 1x klik.
  * Menampilkan feedback animasi icon checklist hijau setelah lagu berhasil disimpan.
* **My Playlist Drawer:**
  * Menampilkan daftar lagu tersimpan lengkap dengan nomor urut, judul, artis, dan badge jumlah lagu.
  * **Tombol Play (`▶`):** Terintegrasi langsung dengan D-Bus Spotify (`org.mpris.MediaPlayer2.Player.OpenUri`) untuk langsung memutar track Spotify secara instan!
  * **Tombol Hapus (`✕`):** Menghapus lagu dari playlist secara cepat.

---

### 5. 🎵 BitChord & AutoMix Media Player (`widgets/`)
* **Desain Cover Bleed ke Blurred Glass:** Cover album lagu tampil di bagian atas kartu dan bertransisi secara halus (*smoothstep S-curve opacity mask*) ke lapisan frosted glass di bawahnya tanpa garis pemisah yang kaku.
* **Ambient Glass Color Wash (AutoMix Style):** Warna latar belakang frosted glass secara dinamis mengekstrak dan mengikuti warna dominan pada bagian bawah cover album lagu yang sedang diputar.
* **Hierarki BitChord Bersih:**
  1. **Judul Lagu:** Ditampilkan mencolok di bagian atas dengan font Nothing `NType82` putih tegas.
  2. **Nama Artis:** Ditampilkan tepat di bawah judul lagu dengan font technical monospace `LetteraMonoLL`.
  3. **Lirik Tersinkronisasi Real-Time:** Menampilkan lirik lagu tersinkron dari [LRCLIB](https://lrclib.net/) berdasarkan posisi playback lagu (`playerctl position`), dengan baris aktif yang disorot jelas.
* **Progress Bar & Durasi:** Timeline kapsul minimalis dengan penunjuk waktu berjalan (*elapsed*) dan sisa durasi lagu (*remaining*).
* **Kontrol Dot-Matrix Nothing OS:** Tombol *Previous*, *Play/Pause* kapsul melingkar, dan *Next* didesain khusus bergaya titik-titik dot-matrix khas Nothing OS.

---

### 6. 🕒 Jam Digital & Tanggal Nothing OS (`widgets/`)
* Jam digital besar berdesain titik-titik khas Nothing OS menggunakan font resmi `Ndot57`.
* Hari dan tanggal bergaya technical monospace menggunakan font resmi `LetteraMonoLL`.
* Didukung langsung oleh `Quickshell.SystemClock` yang hemat daya dan sinkron per menit.

---

### 7. 🌦️ Kartu Cuaca & Lokasi Real-Time (`widgets/`)
* Icon cuaca dot-matrix putih (`assets/weather-dot.svg`).
* Suhu harian tertinggi & terendah (`H 29°` / `L 23°`), serta suhu besar `Ndot55`.
* Kondisi cuaca, deteksi lokasi kota otomatis berdasarkan IP publik (`ip-api.com` / `wttr.in`), serta kelembapan dan kecepatan angin (`74% · 7 KM/H`) dengan sistem caching lokal 15 menit agar tidak membebani jaringan.

---

### 8. 🖼️ Frame Poster / Foto Estetik (`widgets/`)
* Frame foto portrait elegan ber-radius 20px dengan pinggiran kaca halus.
* Menampilkan gambar lokal dari [`assets/poster.jpg`](assets/poster.jpg).
* Auto-reload otomatis saat file gambar ditimpa tanpa perlu me-restart Quickshell.

---

### 9. 📊 Monitor Sistem Linux (`widgets/`)
* Pemantau partisi Linux: penggunaan ruang `Root (/)` dan `Home (/home)` lengkap dengan bar kapasitas.
* Indikator persentase baterai laptop langsung dari `sysfs` hardware.

---

### 10. ⚡ Kapsul Tombol Daya (`widgets/`)
* Tombol cepat dengan icon Nerd Font untuk *Sleep/Suspend*, *Power Off (Shutdown)*, dan *Reboot*.

---

### 11. 🔔 Server & Popup Notifikasi Frosted Glass Native (`notifications/`)
* Menggantikan daemon notifikasi eksternal seperti `swaync`, `dunst`, atau `mako` via D-Bus `org.freedesktop.Notifications`.
* Menggunakan estetika **Chameleon Frosted Glass** yang serasi dengan widget desktop (radius 20px, border highlight kaca, dan real-time GPU Dual-Kawase blur).
* **Scrollable:** Notifikasi panjang tidak terpotong, bisa di-scroll menggunakan mouse wheel / dua jari touchpad.
* **Tombol Aksi D-Bus:** Mendukung tombol interaktif (Approve, Deny, Open, dll.).
* **Fokus Cepat Window:** Khusus notifikasi aplikasi tertentu (mis. Antigravity IDE), otomatis menampilkan tombol aksi dengan aktivasi workspace akurat via `xdg_activation_v1`.
* **Suara Notifikasi Native (`assets/notif.mp3`):** Memutar efek suara notifikasi secara otomatis lewat PipeWire (`pw-play`) dilengkapi *anti-spam cooldown* agar suara tidak tumpang tindih saat banyak notifikasi masuk bersamaan.
* **Dismiss Cepat:** Klik di mana saja pada kartu notifikasi untuk menutupnya. Timer auto-dismiss otomatis berhenti saat kursor berada di atas kartu.

---

## ⌨️ Shortcut Keyboard & Kontrol Cepat

| Shortcut / Aksi | Fungsi | Deskripsi |
| :--- | :--- | :--- |
| **`Super + W`** | **WiFi Manager** | Buka/tutup menu WiFi dot-matrix di Notch |
| **`Super + P`** | **Display Projection** | Buka/tutup menu proyeksi monitor (PC, Mirror, Extend, Second) |
| **`Ctrl + Super + S`** | **Music Sidebar** | Buka/tutup panel sidebar pemutar musik & playlist drawer |
| **`XF86AudioRaiseVolume`** | Volume Up | Naikkan volume + munculkan HUD Volume Nothing OS |
| **`XF86AudioLowerVolume`** | Volume Down | Turunkan volume + munculkan HUD Volume Nothing OS |
| **`XF86AudioMute`** | Toggle Mute | Mute/unmute audio |
| **`XF86MonBrightnessUp`** | Brightness Up | Naikkan kecerahan + munculkan HUD Brightness Nothing OS |
| **`XF86MonBrightnessDown`** | Brightness Down | Turunkan kecerahan + munculkan HUD Brightness Nothing OS |
| **Scroll di atas Notch** | Atur Volume | Naik/turunkan volume langsung dengan mouse/touchpad |
| **Shift + Scroll di Notch** | Atur Kecerahan | Naik/turunkan kecerahan layar langsung |
| **Klik Kiri di Notch** | Toggle WiFi | Buka daftar jaringan WiFi jika notch sedang idle |
| **Klik Tengah di Notch** | Toggle HDMI | Buka menu pilihan proyeksi monitor HDMI |
| **Klik Kanan di Notch** | Toggle Mute | Mute / Unmute audio |

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
* **Python 3** (untuk background service cuaca, lirik, partisi, pelacak kursor, WiFi, dan playlist)
* **playerctl** (untuk kontrol media & sinkronisasi lirik)
  * Fedora: `sudo dnf install playerctl`
  * Arch: `sudo pacman -S playerctl`
* **brightnessctl** (untuk kontrol kecerahan layar)
  * Fedora: `sudo dnf install brightnessctl`
  * Arch: `sudo pacman -S brightnessctl`
* **NetworkManager (`nmcli`)** (bawaan sebagian besar distro Linux untuk manajemen WiFi)
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
git clone https://github.com/azizhehe01/clean-widget.git ~/.config/quickshell/DesktopWidgetsApp
```

### Langkah 2: Berikan Izin Eksekusi pada Script Pembantu
```bash
chmod +x ~/.config/quickshell/DesktopWidgetsApp/widgets/stats.py
chmod +x ~/.config/quickshell/DesktopWidgetsApp/notch/cursor.py
chmod +x ~/.config/quickshell/DesktopWidgetsApp/sidebar/playlist.py
```

### Langkah 3: Uji Coba Menjalankan
Jalankan melalui terminal untuk melihat output:
```bash
qs -p ~/.config/quickshell/DesktopWidgetsApp
```

---

## 🌫️ Konfigurasi Autostart & Blur Hyprland

### 1. Konfigurasi Autostart
Tambahkan baris berikut ke konfigurasi Hyprland lo (misalnya `~/.config/hypr/hyprland.conf` atau script autostart lo):

```ini
# Autostart DesktopWidgetsApp (Widgets, Notifikasi, Notch & Sidebar)
exec-once = qs -p ~/.config/quickshell/DesktopWidgetsApp
```

### 2. Konfigurasi Blur GPU Dual-Kawase di Hyprland
Agar efek frosted glass transparan menghasilkan blur kaca buram yang mewah di Wayland, tambahkan `layerrule` berikut ke `~/.config/hypr/hyprland.conf` (atau konfigurasi dekorasi Hyprland lo):

```ini
# Rule blur untuk Desktop Widgets, Notifikasi & Sidebar
layerrule = blur, quickshell:desktop-widgets
layerrule = ignorealpha 0.1, quickshell:desktop-widgets

layerrule = blur, quickshell:notifications
layerrule = ignorealpha 0.1, quickshell:notifications

layerrule = blur, quickshell:sidebar
layerrule = ignorealpha 0.1, quickshell:sidebar
```

### 3. Konfigurasi Shortcut Keyboard di Hyprland
Tambahkan binding berikut ke file keybindings Hyprland lo (misal `~/.config/hypr/conf/keybindings/default.lua` atau `keybindings.conf`):

```lua
-- WiFi Network Manager (Super + W)
hl.bind("SUPER", "w", hl.dsp.exec_cmd("qs ipc call notch wifi toggle"), { description = "Toggle WiFi Manager" })

-- Display / HDMI Projection Manager (Super + P)
hl.bind("SUPER", "p", hl.dsp.exec_cmd("qs ipc call notch display toggle"), { description = "Toggle HDMI Projection Manager" })

-- Music Sidebar & Playlist Drawer (Ctrl + Super + S)
hl.bind("CTRL_SUPER", "s", hl.dsp.exec_cmd("qs ipc call sidebar toggle"), { description = "Toggle Music Sidebar" })

-- Volume Control dengan Notch OSD
hl.bind("", "XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call notch volume up"), { description = "Volume Up" })
hl.bind("", "XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call notch volume down"), { description = "Volume Down" })
hl.bind("", "XF86AudioMute", hl.dsp.exec_cmd("qs ipc call notch volume mute"), { description = "Mute Audio" })

-- Brightness Control dengan Notch OSD
hl.bind("", "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+ && qs ipc call notch brightness up"), { description = "Brightness Up" })
hl.bind("", "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%- && qs ipc call notch brightness down"), { description = "Brightness Down" })
```

---

## ⚙️ Panduan Pengaturan & Kustomisasi (Cara Setting)

Semua pengaturan utama telah diletakkan di bagian paling atas file masing-masing komponen agar sangat mudah diubah:

### 1. Mengatur Top Notch, Volume & Brightness ([`notch/NotchWindow.qml`](notch/NotchWindow.qml))
Buka file `notch/NotchWindow.qml` dan perhatikan baris konfigurasi:

```qml
    // 1. Durasi berapa lama HUD volume/kecerahan muncul sebelum kembali sembunyi / jadi mata (dalam ms)
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
    //    false = Jendela aplikasi dapat layar penuh 100% tanpa terpotong (Rekomendasi)
    //    true  = Hyprland memesan 38px di atas layar untuk notch
    property bool reserveSpace: false
```

### 2. Mengganti Poster Karakter / Foto
Untuk mengganti foto pada frame poster di widget:
* Cukup timpa file gambar di [`assets/poster.jpg`](assets/poster.jpg) dengan gambar foto portrait pilihan lo (rasio disarankan 9:16 atau 3:4).
* Gambar akan langsung terpasang otomatis dengan sudut membulat 20px (otomatis ter-reload dalam 2 detik tanpa perlu restart).

### 3. Mengganti Suara Notifikasi
* Suara notifikasi diambil dari [`assets/notif.mp3`](assets/notif.mp3). Cukup timpa file tersebut dengan file audio `.mp3` atau `.wav` pilihan lo.
* Untuk mematikan suara notifikasi, ubah `property bool soundEnabled: false` di bagian atas [`notifications/NotificationPopupWindow.qml`](notifications/NotificationPopupWindow.qml).

### 4. Mengganti Cover Album Default
Jika pemutar musik sedang tidak aktif, widget menampilkan cover default dari [`assets/album.jpg`](assets/album.jpg). Lo bisa menggantinya dengan artwork album favorit lo.

### 5. Mengatur Kota & Layanan Cuaca ([`widgets/stats.py`](widgets/stats.py))
* Secara default, script mendeteksi lokasi kota lo secara otomatis menggunakan IP Geolocation publik.
* Jika lo ingin menentukan kota tertentu secara manual, lo bisa mengedit pemanggilan URL di file `widgets/stats.py`:
  ```python
  # Ganti "Jakarta" dengan nama kota lo (misal: "Banyumas", "Bandung", "Surabaya")
  req = urllib.request.Request("https://wttr.in/Jakarta?format=%c+%t", headers={"User-Agent": "curl/7.68.0"})
  ```

---

## 📁 Struktur Direktori Proyek

```text
DesktopWidgetsApp/
├── assets/                         # Aset gambar, font Nothing OS, dan icon SVG
│   ├── fonts/
│   │   ├── Ndot55-Regular.otf      # Font angka suhu cuaca
│   │   ├── Ndot57-Regular.otf      # Font jam digital, volume & brightness Nothing OS
│   │   ├── NType82-Regular.otf     # Font sans-serif bento grid & judul musik
│   │   └── LetteraMonoLL-Regular.otf # Font tanggal, artis & teks teknikal monospace
│   ├── notif.mp3                   # Efek suara notifikasi masuk
│   ├── album.jpg                   # Fallback cover album
│   ├── poster.jpg                  # Foto portrait frame poster
│   ├── preview.png                 # Gambar pratinjau desktop widgets
│   ├── brightness-dot.svg          # Icon matahari dot-matrix HUD brightness
│   ├── check-dot.svg               # Icon checklist dot-matrix konfirmasi simpan lagu
│   ├── plus-dot.svg                # Icon tambah playlist dot-matrix
│   ├── display-laptop.svg          # Icon mode layar PC Only dot-matrix
│   ├── display-duplicate.svg       # Icon mode layar Duplicate dot-matrix
│   ├── display-extend.svg          # Icon mode layar Extend dot-matrix
│   ├── display-second.svg          # Icon mode layar Second Screen Only dot-matrix
│   ├── wifi-dot.svg                # Icon WiFi dot-matrix
│   ├── wifi-off-dot.svg            # Icon WiFi off dot-matrix
│   ├── lock-dot.svg                # Icon gembok dot-matrix
│   ├── refresh-dot.svg             # Icon reload dot-matrix
│   ├── media-prev-dot.svg          # Tombol Previous dot-matrix Nothing OS
│   ├── media-play-dot.svg          # Tombol Play dot-matrix Nothing OS
│   ├── media-pause-dot.svg         # Tombol Pause dot-matrix Nothing OS
│   ├── media-next-dot.svg          # Tombol Next dot-matrix Nothing OS
│   ├── volume-dot.svg              # Icon speaker dot-matrix
│   ├── volume-mute-dot.svg         # Icon speaker mute dot-matrix
│   ├── weather-dot.svg             # Icon cuaca dot-matrix
│   └── rocket.svg                  # Icon aksi notifikasi
├── notch/
│   ├── NotchWindow.qml             # Window Top Notch interaktif, Angry Eyes, HUD OSD, WiFi & HDMI
│   └── cursor.py                   # Daemon IPC Hyprland pelacak kursor & active window
├── notifications/
│   └── NotificationPopupWindow.qml # Server notifikasi native frosted glass
├── sidebar/
│   ├── SidebarWindow.qml           # Panel slide-out musik, multi-player switcher & playlist drawer
│   └── playlist.py                 # Service D-Bus & JSON manager playlist lagu
├── widgets/
│   ├── DesktopWidgetsWindow.qml    # Window utama bento grid widget desktop
│   └── stats.py                    # Service pengambil data lirik, cuaca, & partisi sistem
├── shell.qml                       # Entry point Quickshell yang memuat seluruh window
└── README.md                       # Dokumentasi panduan lengkap
```

---

## 📜 Lisensi & Kredit
* Dibuat untuk ekosistem Wayland / Hyprland menggunakan framework hebat [Quickshell](https://quickshell.outfoxxed.me/).
* Tipografi & gaya dot-matrix terinspirasi dari filosofi desain hardware dan software [Nothing OS](https://nothing.tech/).
* Database lirik musik didukung oleh komunitas terbuka [LRCLIB](https://lrclib.net/).
