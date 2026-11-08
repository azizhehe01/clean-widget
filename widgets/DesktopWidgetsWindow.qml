import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root

    // Pinned to desktop background layer; blurred by Hyprland layer_rule
    WlrLayershell.namespace: "quickshell:desktop-widgets"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: WlrLayershell.Ignore

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080

    // Tight, zero-dead-space Bento Grid heights
    readonly property int gridGap: 12
    readonly property int row1H: 164
    readonly property int row2H: root.hasLyrics ? 470 : 416
    readonly property int row3H: 306
    readonly property int totalW: 436
    readonly property int totalH: row1H + gridGap + row2H + gridGap + row3H

    // =========================================================================
    // Official Nothing OS & nothing.tech Typography System
    // - Ndot55 / Ndot57: Dot-Matrix Display Font (for large numbers: Clock & Temp)
    // - NType82: Clean Geometric Grotesk from nothing.tech (for titles, lyrics, body)
    // - LetteraMonoLL: Technical Monospace from nothing.tech (for metadata, location, stats)
    // =========================================================================
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    readonly property int winX: 32
    readonly property int winY: Math.max(24, Math.round((screenH - totalH) / 2))

    anchors {
        top: true
        left: true
    }

    margins {
        left: root.winX
        top: root.winY
    }

    implicitWidth: root.totalW
    implicitHeight: root.totalH
    color: "transparent"

    // =========================================================================
    // Theme Tokens — Real-Time GPU Chameleon Frosted Glass (Zero Color Cast)
    // =========================================================================
    readonly property color cardBg: Qt.rgba(0.0, 0.0, 0.0, 0.14)
    readonly property color cardEdgeHighlight: Qt.rgba(1.0, 1.0, 1.0, 0.14)
    readonly property color cardSpecularTopLeft: Qt.rgba(1.0, 1.0, 1.0, 0.07)
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.78)
    readonly property color barTrack: Qt.rgba(1.0, 1.0, 1.0, 0.18)
    readonly property color barFill: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    readonly property int cardRadius: 20

    // Dynamic stats & synced lyrics fetched from helper script
    property var stats: ({
        "wallpaper": "",
        "root_used": "114.7 GB",
        "root_total": "712.8 GB",
        "root_pct": 16,
        "home_used": "114.7 GB",
        "home_total": "712.8 GB",
        "home_pct": 16,
        "trash_size": "38 MB",
        "weather_temp": "29°",
        "weather_high": "H 31°",
        "weather_low": "L 25°",
        "weather_desc": "PARTLY CLOUDY",
        "weather_location": "JAKARTA",
        "weather_meta": "78% · 14 KM/H",
        "battery_pct": 100,
        "battery_status": "Full",
        "lyrics": [],
        "album_color": "#2c2628",
        "track_position": 0.0,
        "track_duration": 0.0,
        "track_progress": 0.0,
        "position_str": "0:00",
        "duration_str": "--:--",
        "poster_mtime": 0
    })

    readonly property var lyricsList: (root.stats && root.stats.lyrics && root.stats.lyrics.length > 0)
        ? root.stats.lyrics
        : []
    readonly property bool hasLyrics: root.lyricsList.length > 0

    readonly property string wallpaperUrl: (root.stats && root.stats.wallpaper)
        ? ("file://" + root.stats.wallpaper)
        : ""

    Process {
        id: statsProc
        command: ["python3", Quickshell.shellDir + "/widgets/stats.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let raw = this.text.trim();
                    if (raw) {
                        root.stats = JSON.parse(raw);
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            statsProc.running = false;
            statsProc.running = true;
        }
    }

    // Live Clock
    SystemClock {
        id: liveClock
        precision: SystemClock.Minutes
    }

    // Active Media Player via MPRIS
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        if (players.length > 0) {
            for (let i = 0; i < players.length; i++) {
                if (players[i].playbackState === MprisPlaybackState.Playing)
                    return players[i];
            }
            return players[0];
        }
        return null;
    }

    // =========================================================================
    // Reusable Frosted Glass Card Component
    // Pure Neutral Transparent Glass — takes 100% of its color from the active
    // blurred wallpaper behind it, with zero brown/color cast
    // =========================================================================
    component FrostedCard: Item {
        id: cardRoot
        property int cornerRadius: root.cardRadius
        property real globalOffsetX: 0
        property real globalOffsetY: 0

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: cardRoot.cornerRadius
            visible: false
        }

        Item {
            id: cardBackdrop
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: cardMask
            }

            // 1. Pure Neutral Translucent Glass Surface (triggers Hyprland real-time GPU Dual-Kawase blur)
            Rectangle {
                anchors.fill: parent
                color: root.cardBg
                border.width: 0
            }

            // 2. Subtle Neutral Glass Top-Left Specular Shine
            LinearGradient {
                anchors.fill: parent
                start: Qt.point(0, 0)
                end: Qt.point(width, height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.cardSpecularTopLeft }
                    GradientStop { position: 0.55; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // 4. Subtle 1px Neutral Glass Edge Highlight
        Rectangle {
            anchors.fill: parent
            radius: cardRoot.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: root.cardEdgeHighlight
        }
    }

    // =========================================================================
    // Main Bento Grid Container (Explicit Positions & Dimensions)
    // =========================================================================
    Item {
        id: mainContainer
        width: root.totalW
        height: root.totalH

        // =====================================================================
        // ROW 1: Clock (Left) & Nothing OS Weather + Location Card (Right)
        // =====================================================================
        Item {
            id: row1
            x: 0
            y: 0
            width: root.totalW
            height: root.row1H

            readonly property int leftW: Math.round((root.totalW - root.gridGap) * 0.56)
            readonly property int rightW: root.totalW - root.gridGap - leftW

            // Left Card (56%): Nothing Dot-Matrix Clock & Technical Mono Date
            FrostedCard {
                x: 0
                y: 0
                width: row1.leftW
                height: row1.height
                cornerRadius: root.cardRadius
                globalOffsetX: 0
                globalOffsetY: 0

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(liveClock.date, "hh:mm ap").toUpperCase()
                    font.pixelSize: 38
                    color: root.textPrimary
                    font.family: fontNdot57.name || "Fira Sans"
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(liveClock.date, "ddd, MMM dd, yyyy").toUpperCase()
                    font.pixelSize: 12
                    font.letterSpacing: 1.2
                    color: root.textSecondary
                    font.family: fontNMono.name || "Fira Sans"
                }
            }

            // Right Card (44%): Nothing OS Weather & Location Card (matches reference image)
            FrostedCard {
                x: row1.leftW + root.gridGap
                y: 0
                width: row1.rightW
                height: row1.height
                cornerRadius: root.cardRadius
                globalOffsetX: row1.leftW + root.gridGap
                globalOffsetY: 0

                // Top-Left: Nothing Dot-Matrix Weather Icon (Sun + Cloud)
                Image {
                    x: 15
                    y: 13
                    width: 38
                    height: 31
                    source: Qt.resolvedUrl("../assets/weather-dot.svg")
                    sourceSize: Qt.size(38, 31)
                }

                // Top-Right: High / Low Temperatures (H 31° / L 25°)
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    y: 13
                    spacing: 2

                    Text {
                        anchors.right: parent.right
                        text: root.stats.weather_high || "H 31°"
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                        color: root.textSecondary
                        font.family: fontNMono.name || "Fira Sans"
                    }

                    Text {
                        anchors.right: parent.right
                        text: root.stats.weather_low || "L 25°"
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                        color: root.textSecondary
                        font.family: fontNMono.name || "Fira Sans"
                    }
                }

                // Center: Large Nothing Dot-Matrix Temperature (e.g. 29°)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 44
                    text: root.stats.weather_temp || "29°"
                    font.pixelSize: 48
                    color: root.textPrimary
                    font.family: fontNdot55.name || "Fira Sans"
                }

                // Bottom Section: Condition (PARTLY CLOUDY) + Location (Left) & Humidity/Wind (Right)
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    anchors.bottomMargin: 12
                    spacing: 3

                    Text {
                        width: parent.width
                        text: (root.stats.weather_desc || "PARTLY CLOUDY").toUpperCase()
                        font.pixelSize: 11
                        font.letterSpacing: 0.4
                        color: root.textPrimary
                        elide: Text.ElideRight
                        font.family: fontNType.name || "Fira Sans"
                    }

                    Item {
                        width: parent.width
                        height: 13

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(40, parent.width - weatherMetaText.implicitWidth - 6)
                            text: (root.stats.weather_location || "JAKARTA").toUpperCase()
                            font.pixelSize: 9
                            font.letterSpacing: 0.4
                            color: root.textSecondary
                            elide: Text.ElideRight
                            font.family: fontNMono.name || "Fira Sans"
                        }

                        Text {
                            id: weatherMetaText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.stats.weather_meta || "78% · 14 KM/H").toUpperCase()
                            font.pixelSize: 9
                            font.letterSpacing: 0.3
                            color: root.textSecondary
                            font.family: fontNMono.name || "Fira Sans"
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: BitChord & AutoMix Media Player (True Continuous Blur Bleed + Dot Matrix)
        // =====================================================================
        FrostedCard {
            id: row2
            x: 0
            y: root.row1H + root.gridGap
            width: root.totalW
            height: root.row2H
            cornerRadius: root.cardRadius
            globalOffsetX: 0
            globalOffsetY: root.row1H + root.gridGap

            readonly property color glassTint: Qt.color(root.stats && root.stats.album_color ? root.stats.album_color : "#282426")

            // =================================================================
            // Continuous Background Surface (AutoMix / BitChord Style):
            // 1. Hidden source image for FastBlur and sharp layer
            // 2. Full-card FastBlur (dreamy ambient album backdrop)
            // 3. Sharp uncropped album art at top (AlignTop) with smoothstep alpha dissolve
            // 4. Ambient glass wash gradient matching bottom album color (row2.glassTint)
            // Result: Zero seams, zero lines, and full uncropped album cover!
            // =================================================================
            Item {
                id: cardVisualSurface
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: row2.width
                        height: row2.height
                        radius: root.cardRadius
                    }
                }

                // 1. Source Image for Effects
                Image {
                    id: albumSourceImg
                    anchors.fill: parent
                    source: (root.activePlayer && root.activePlayer.trackArtUrl)
                        ? root.activePlayer.trackArtUrl
                        : Qt.resolvedUrl("../assets/album.jpg")
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    visible: false
                    sourceSize: Qt.size(row2.width * 2, row2.height * 2)
                }

                // 2. Full-Card Dreamy Album Ambient Blur (FastBlur)
                FastBlur {
                    anchors.fill: parent
                    source: albumSourceImg
                    radius: 56
                    opacity: 0.70
                }

                // 3. Sharp Uncropped Album Art Layer (Top-Aligned + Wide S-Curve Mask)
                Item {
                    id: sharpArtLayer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 295
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: LinearGradient {
                            width: sharpArtLayer.width
                            height: sharpArtLayer.height
                            start: Qt.point(0, 0)
                            end: Qt.point(0, height)
                            gradient: Gradient {
                                GradientStop { position: 0.00; color: "#FFFFFFFF" }
                                GradientStop { position: 0.40; color: "#FFFFFFFF" }
                                GradientStop { position: 0.52; color: "#F0FFFFFF" }
                                GradientStop { position: 0.64; color: "#C0FFFFFF" }
                                GradientStop { position: 0.76; color: "#78FFFFFF" }
                                GradientStop { position: 0.86; color: "#34FFFFFF" }
                                GradientStop { position: 0.94; color: "#0CFFFFFF" }
                                GradientStop { position: 1.00; color: "#00FFFFFF" }
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: albumSourceImg.source
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(row2.width * 2, 600)
                    }
                }

                // 4. Ambient Glass Color Wash Gradient (AutoMix Style - Gambar 2)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: "transparent" }
                        GradientStop { position: 0.38; color: "transparent" }
                        GradientStop { position: 0.52; color: Qt.rgba(row2.glassTint.r, row2.glassTint.g, row2.glassTint.b, 0.15) }
                        GradientStop { position: 0.68; color: Qt.rgba(row2.glassTint.r, row2.glassTint.g, row2.glassTint.b, 0.40) }
                        GradientStop { position: 0.84; color: Qt.rgba(row2.glassTint.r, row2.glassTint.g, row2.glassTint.b, 0.62) }
                        GradientStop { position: 1.00; color: Qt.rgba(row2.glassTint.r, row2.glassTint.g, row2.glassTint.b, 0.78) }
                    }
                }
            }

            // Top Banner Header ("NOW PLAYING")
            Item {
                id: topBannerHeader
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 22

                Rectangle {
                    anchors.centerIn: parent
                    width: bannerRow.width + 18
                    height: 22
                    radius: 11
                    color: Qt.rgba(0, 0, 0, 0.36)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                }

                Row {
                    id: bannerRow
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                            ? "#FF3B30"
                            : Qt.rgba(1, 1, 1, 0.5)
                    }

                    Text {
                        text: "NOW PLAYING"
                        font.pixelSize: 9
                        font.letterSpacing: 1.3
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.92)
                        font.family: fontNMono.name || "Fira Sans"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Structure: Judul Lagu -> Nama Artis -> Lirik (BitChord Layout)
            Column {
                id: trackInfoCol
                anchors.top: parent.top
                anchors.topMargin: root.hasLyrics ? 238 : 226
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 4

                // A. Judul Lagu (Song Title)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (root.activePlayer && root.activePlayer.trackTitle)
                            return root.activePlayer.trackTitle;
                        return "No Track Playing";
                    }
                    font.pixelSize: 20
                    font.bold: true
                    color: root.textPrimary
                    elide: Text.ElideRight
                    font.family: fontNType.name || "Fira Sans"
                }

                // B. Nama Artis (Artist Name)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        let artist = "";
                        if (root.activePlayer) {
                            if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
                            else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
                                artist = root.activePlayer.trackArtists[0];
                            else if (root.activePlayer.identity) artist = root.activePlayer.identity;
                        }
                        return (artist ? artist : "—").toUpperCase();
                    }
                    font.pixelSize: 11
                    font.letterSpacing: 0.9
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.76)
                    elide: Text.ElideRight
                    font.family: fontNMono.name || "Fira Sans"
                }

                // C. Lirik (Synced Lyrics)
                Item {
                    width: parent.width
                    height: root.hasLyrics ? 34 : 6
                    visible: root.hasLyrics

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 3

                        // Active Lyric Line (Bold White)
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.lyricsList.length > 0 ? (root.lyricsList[0].text || "") : ""
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            font.family: fontNType.name || "Fira Sans"
                        }

                        // Upcoming Lyric Line (Subtle)
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.lyricsList.length > 1 ? (root.lyricsList[1].text || "") : ""
                            font.pixelSize: 12
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.45)
                            elide: Text.ElideRight
                            font.family: fontNType.name || "Fira Sans"
                            visible: text !== ""
                        }
                    }
                }
            }

            // Timeline Progress Bar (Timestamps + Capsule Track)
            Item {
                id: progressTimeline
                anchors.top: trackInfoCol.bottom
                anchors.topMargin: root.hasLyrics ? 14 : 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                height: 20

                Text {
                    id: timeElapsed
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: root.stats.position_str || "0:00"
                    font.pixelSize: 10
                    font.family: fontNMono.name || "Fira Sans"
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                }

                Text {
                    id: timeRemaining
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: root.stats.duration_str || "--:--"
                    font.pixelSize: 10
                    font.family: fontNMono.name || "Fira Sans"
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                }

                Rectangle {
                    id: progressTrack
                    anchors.top: timeElapsed.bottom
                    anchors.topMargin: 5
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3.5
                    radius: 2
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.20)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(3.5, parent.width * (root.stats.track_progress || 0.0))
                        radius: 2
                        color: root.barFill
                    }
                }
            }

            // Dot-Matrix Media Controls (Nothing OS Aesthetics)
            Row {
                id: dotMatrixControls
                anchors.top: progressTimeline.bottom
                anchors.topMargin: root.hasLyrics ? 14 : 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 30

                // Previous Button
                Item {
                    width: 36
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: Qt.resolvedUrl("../assets/media-prev-dot.svg")
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                        opacity: prevBtnArea.containsMouse ? 1.0 : 0.85
                        scale: prevBtnArea.pressed ? 0.90 : 1.0
                    }

                    MouseArea {
                        id: prevBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "previous"])
                    }
                }

                // Play / Pause Capsule
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: playBtnArea.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Qt.rgba(1.0, 1.0, 1.0, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.32)
                    scale: playBtnArea.pressed ? 0.92 : 1.0

                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                            ? Qt.resolvedUrl("../assets/media-pause-dot.svg")
                            : Qt.resolvedUrl("../assets/media-play-dot.svg")
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.95
                    }

                    MouseArea {
                        id: playBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
                                root.activePlayer.togglePlaying();
                            } else {
                                Quickshell.execDetached(["playerctl", "play-pause"]);
                            }
                        }
                    }
                }

                // Next Button
                Item {
                    width: 36
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: Qt.resolvedUrl("../assets/media-next-dot.svg")
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                        opacity: nextBtnArea.containsMouse ? 1.0 : 0.85
                        scale: nextBtnArea.pressed ? 0.90 : 1.0
                    }

                    MouseArea {
                        id: nextBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "next"])
                    }
                }
            }
        }

        // =====================================================================
        // ROW 3: Character Poster (178px Left) & System Monitor + Power (Right)
        // =====================================================================
        Item {
            id: row3
            x: 0
            y: root.row1H + root.gridGap + root.row2H + root.gridGap
            width: root.totalW
            height: root.row3H

            readonly property int leftColW: 178
            readonly property int rightColW: root.totalW - root.gridGap - leftColW
            readonly property int powerPillH: 52
            readonly property int sysCardH: root.row3H - root.gridGap - powerPillH

            // Left Column (178px): Character Poster with 20px Rounded Corners (Clean Neutral)
            Item {
                id: posterCard
                x: 0
                y: 0
                width: row3.leftColW
                height: row3.height

                Rectangle {
                    id: posterMask
                    anchors.fill: parent
                    radius: root.cardRadius
                    visible: false
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4
                    layer.effect: OpacityMask {
                        maskSource: posterMask
                    }

                    Image {
                        id: rawPosterImg
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../assets/poster.jpg") + (root.stats && root.stats.poster_mtime ? ("?v=" + root.stats.poster_mtime) : "")
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(posterCard.width * 2, posterCard.height * 2)
                    }
                }
            }

            // Right Column Top: System Monitor Card (Fills 100% height cleanly with zero empty gap below Battery)
            FrostedCard {
                id: sysMonitorCard
                x: row3.leftColW + root.gridGap
                y: 0
                width: row3.rightColW
                height: row3.sysCardH
                cornerRadius: root.cardRadius
                globalOffsetX: row3.leftColW + root.gridGap
                globalOffsetY: row3.y

                Column {
                    x: 20
                    y: 18
                    width: parent.width - 40
                    spacing: 16

                    // Linux Root Partition: Root (/)
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "ROOT (/)"
                            font.pixelSize: 14
                            font.letterSpacing: 0.8
                            color: root.textPrimary
                            font.family: fontNType.name || "Fira Sans"
                        }
                        Text {
                            text: (root.stats.root_used || "114.7 GB") + " / " + (root.stats.root_total || "712.8 GB")
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                            color: root.textSecondary
                            font.family: fontNMono.name || "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.root_pct || 16) / 100.0))
                                height: parent.height
                                radius: 4
                                color: root.barFill
                            }
                        }
                    }

                    // Linux Home Partition: Home (/home)
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "HOME (/HOME)"
                            font.pixelSize: 14
                            font.letterSpacing: 0.8
                            color: root.textPrimary
                            font.family: fontNType.name || "Fira Sans"
                        }
                        Text {
                            text: (root.stats.home_used || "114.7 GB") + " / " + (root.stats.home_total || "712.8 GB")
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                            color: root.textSecondary
                            font.family: fontNMono.name || "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.home_pct || 16) / 100.0))
                                height: parent.height
                                radius: 4
                                color: root.barFill
                            }
                        }
                    }

                    // Battery:
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "BATTERY"
                            font.pixelSize: 14
                            font.letterSpacing: 0.8
                            color: root.textPrimary
                            font.family: fontNType.name || "Fira Sans"
                        }
                        Text {
                            text: (root.stats.battery_pct || 100) + "%"
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                            color: root.textSecondary
                            font.family: fontNMono.name || "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.battery_pct || 100) / 100.0))
                                height: parent.height
                                radius: 4
                                color: root.barFill
                            }
                        }
                    }
                }
            }

            // Right Column Bottom: Power Controls Capsule (border-radius: 999px equivalent)
            FrostedCard {
                id: powerCapsuleCard
                x: row3.leftColW + root.gridGap
                y: row3.sysCardH + root.gridGap
                width: row3.rightColW
                height: row3.powerPillH
                cornerRadius: height / 2
                globalOffsetX: row3.leftColW + root.gridGap
                globalOffsetY: row3.y + row3.sysCardH + root.gridGap

                Row {
                    anchors.centerIn: parent
                    spacing: 30

                    // Lock Screen (Nothing OS Lockscreen)
                    Text {
                        text: "󰌾"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 20
                        color: lockMouse.containsMouse ? root.barFill : root.textPrimary
                        scale: lockMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: lockMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([Quickshell.shellDir + "/lockscreen/lock.sh"])
                        }
                    }

                    // Sleep / Suspend
                    Text {
                        text: "󰤄"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 21
                        color: sleepMouse.containsMouse ? root.barFill : root.textPrimary
                        scale: sleepMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: sleepMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                        }
                    }

                    // Power Off
                    Text {
                        text: "󰐥"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 21
                        color: powerMouse.containsMouse ? "#ff7b7b" : root.textPrimary
                        scale: powerMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                        }
                    }

                    // Restart / Reboot
                    Text {
                        text: "󰑐"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 21
                        color: rebootMouse.containsMouse ? root.barFill : root.textPrimary
                        scale: rebootMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: rebootMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                        }
                    }
                }
            }
        }
    }
}
