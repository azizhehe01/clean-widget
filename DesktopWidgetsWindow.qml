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

    // Pinned to desktop background layer behind normal windows
    WlrLayershell.namespace: "quickshell:desktop-widgets"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: WlrLayershell.Ignore

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080

    // Explicit row heights so QML never distorts or squishes any row
    readonly property int gridGap: 12
    readonly property int row1H: 205
    readonly property int row2H: root.hasLyrics ? 235 : 128
    readonly property int row3H: 365
    readonly property int totalW: 420
    readonly property int totalH: row1H + gridGap + row2H + gridGap + row3H

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
    // Theme Tokens — Warm Milky Frosted Glass (Matched to Reference Mockup)
    // =========================================================================
    readonly property color cardWarmTint: Qt.rgba(78 / 255, 62 / 255, 48 / 255, 0.32)
    readonly property color cardMilkyFrost: Qt.rgba(236 / 255, 218 / 255, 200 / 255, 0.15)
    readonly property color textPrimary: "#FAF6F0"
    readonly property color textSecondary: "#DED4C8"
    readonly property color barTrack: Qt.rgba(1.0, 0.96, 0.92, 0.18)
    readonly property color barFill: "#E6CCB2"
    readonly property color posterTint: "#EADFD3"
    readonly property int cardRadius: 20

    // Dynamic stats & synced lyrics fetched from helper script
    property var stats: ({
        "wallpaper": Quickshell.env("HOME") + "/.config/ml4w/wallpapers/default.jpg",
        "root_used": "114.7 GB",
        "root_total": "712.8 GB",
        "root_pct": 16,
        "home_used": "114.7 GB",
        "home_total": "712.8 GB",
        "home_pct": 16,
        "trash_size": "38 MB",
        "weather_temp": "28°C",
        "weather_condition": "🌦️",
        "battery_pct": 100,
        "battery_status": "Full",
        "lyrics": []
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
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/DesktopWidgetsApp/stats.py"]
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
    // Reusable Frosted Glass Card Component (True Live Blur + Warm Inner Glow)
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

            // 1. Live Blurred Desktop Wallpaper (Active scene-graph branch so FastBlur always executes)
            Item {
                x: -(root.winX + cardRoot.globalOffsetX)
                y: -(root.winY + cardRoot.globalOffsetY)
                width: root.screenW
                height: root.screenH

                Image {
                    id: cardWpSource
                    anchors.fill: parent
                    source: root.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                    visible: false
                }

                FastBlur {
                    anchors.fill: parent
                    source: cardWpSource
                    radius: 90
                    transparentBorder: false
                }
            }

            // 2. Warm Taupe-Espresso Translucent Base Tint (not overly dark)
            Rectangle {
                anchors.fill: parent
                color: root.cardWarmTint
                border.width: 0
            }

            // 3. Milky Warm Frost Diffusion Layer (lifts dark background areas like the wooden door)
            Rectangle {
                anchors.fill: parent
                color: root.cardMilkyFrost
                border.width: 0
            }

            // 4. Soft Ambient Top-to-Bottom Frost Gradient
            Rectangle {
                anchors.fill: parent
                border.width: 0
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(1.0, 0.96, 0.91, 0.10) }
                    GradientStop { position: 0.5; color: Qt.rgba(1.0, 0.95, 0.90, 0.03) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.09, 0.07, 0.12) }
                }
            }

            // 5. Diffused Inner Frosted Edge Cushion (matches reference inset glow around each card)
            Item {
                id: innerGlowRing
                anchors.fill: parent
                visible: false

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -6
                    radius: cardRoot.cornerRadius + 4
                    color: "transparent"
                    border.width: 20
                    border.color: Qt.rgba(255 / 255, 244 / 255, 232 / 255, 0.46)
                }
            }

            FastBlur {
                anchors.fill: parent
                source: innerGlowRing
                radius: 42
                transparentBorder: true
            }

            // 6. Subtle Translucent Glass Edge Catchlight (soft specular sheen, not a hard border)
            Rectangle {
                anchors.fill: parent
                radius: cardRoot.cornerRadius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(255 / 255, 246 / 255, 236 / 255, 0.22)
            }
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
        // ROW 1: Clock & Weather (2 Columns: 60% Left, 40% Right)
        // =====================================================================
        Item {
            id: row1
            x: 0
            y: 0
            width: root.totalW
            height: root.row1H

            readonly property int leftW: Math.round((root.totalW - root.gridGap) * 0.60)
            readonly property int rightW: root.totalW - root.gridGap - leftW

            // Left Card (60%): Large Clock on top, Full Date on bottom
            FrostedCard {
                x: 0
                y: 0
                width: row1.leftW
                height: row1.height
                cornerRadius: root.cardRadius
                globalOffsetX: 0
                globalOffsetY: 0

                Column {
                    anchors.centerIn: parent
                    spacing: 28

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(liveClock.date, "hh:mm ap")
                        font.pixelSize: 38
                        font.bold: true
                        color: root.textPrimary
                        font.family: "Fira Sans"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(liveClock.date, "ddd, MMM dd, yyyy")
                        font.pixelSize: 16
                        font.bold: false
                        color: root.textSecondary
                        font.family: "Fira Sans"
                    }
                }
            }

            // Right Card (40%): Weather Icon on top, Temperature on bottom
            FrostedCard {
                x: row1.leftW + root.gridGap
                y: 0
                width: row1.rightW
                height: row1.height
                cornerRadius: root.cardRadius
                globalOffsetX: row1.leftW + root.gridGap
                globalOffsetY: 0

                Column {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stats.weather_condition || "🌦️"
                        font.pixelSize: 48
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stats.weather_temp || "28°C"
                        font.pixelSize: 21
                        font.bold: true
                        color: root.textPrimary
                        font.family: "Fira Sans"
                    }
                }
            }
        }

        // =====================================================================
        // ROW 2: Media Player + Controls + 3-Line Lyrics (1 Unified Card)
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

            // Top Section: Album Art (80x80, r=12) + Track Info + Top-Right Controls
            Item {
                id: playerTopSection
                x: 22
                y: 22
                width: parent.width - 44
                height: 84

                // Album Cover (80x80px, radius 12px)
                Item {
                    id: albumBox
                    x: 0
                    y: 2
                    width: 80
                    height: 80

                    Rectangle {
                        id: albumMask
                        anchors.fill: parent
                        radius: 12
                        visible: false
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: albumMask
                        }

                        Image {
                            anchors.fill: parent
                            source: (root.activePlayer && root.activePlayer.trackArtUrl)
                                ? root.activePlayer.trackArtUrl
                                : "assets/album.jpg"
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }

                // Track Info + Top-Right Media Controls
                Item {
                    x: albumBox.width + 18
                    y: 0
                    width: parent.width - (albumBox.width + 18)
                    height: 84

                    // Top Line: "You've listening" + Prev/Play/Next Controls
                    Item {
                        x: 0
                        y: 2
                        width: parent.width
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "You've listening"
                            font.pixelSize: 14
                            color: root.textSecondary
                            font.family: "Fira Sans"
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 18

                            // Previous
                            Text {
                                text: "󰒮"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 20
                                color: prevMouse.containsMouse ? root.barFill : root.textPrimary
                                scale: prevMouse.pressed ? 0.9 : 1.0

                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "previous"])
                                }
                            }

                            // Play / Pause
                            Text {
                                text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                                    ? "󰏤" : "󰐊"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 21
                                color: playMouse.containsMouse ? root.barFill : root.textPrimary
                                scale: playMouse.pressed ? 0.9 : 1.0

                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                                }
                            }

                            // Next
                            Text {
                                text: "󰒭"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 20
                                color: nextMouse.containsMouse ? root.barFill : root.textPrimary
                                scale: nextMouse.pressed ? 0.9 : 1.0

                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "next"])
                                }
                            }
                        }
                    }

                    // Middle Line: Song Title
                    Text {
                        x: 0
                        y: 30
                        width: parent.width
                        text: {
                            if (root.activePlayer && root.activePlayer.trackTitle)
                                return root.activePlayer.trackTitle;
                            return "No Track Playing";
                        }
                        font.pixelSize: 19
                        font.bold: true
                        color: root.textPrimary
                        elide: Text.ElideRight
                        font.family: "Fira Sans"
                    }

                    // Bottom Line: Artist
                    Text {
                        x: 0
                        y: 58
                        width: parent.width
                        text: {
                            let artist = "";
                            if (root.activePlayer) {
                                if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
                                else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
                                    artist = root.activePlayer.trackArtists[0];
                                else if (root.activePlayer.identity) artist = root.activePlayer.identity;
                            }
                            return "BY: " + (artist ? artist : "—");
                        }
                        font.pixelSize: 14
                        color: root.textSecondary
                        elide: Text.ElideRight
                        font.family: "Fira Sans"
                    }
                }
            }

            // Bottom Section: 3-Line Lyrics (Centered, auto-hidden when unavailable)
            Column {
                x: 22
                y: 124
                width: parent.width - 44
                spacing: 8
                visible: root.hasLyrics

                Repeater {
                    model: root.lyricsList
                    delegate: Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.text || ""
                        font.pixelSize: 14
                        font.bold: modelData.active ? true : false
                        color: modelData.active ? root.textPrimary : root.textSecondary
                        opacity: modelData.active ? 1.0 : 0.85
                        elide: Text.ElideRight
                        font.family: "Fira Sans"
                    }
                }
            }
        }

        // =====================================================================
        // ROW 3: Character Poster (42% Left) & System Monitor + Power (58% Right)
        // =====================================================================
        Item {
            id: row3
            x: 0
            y: root.row1H + root.gridGap + root.row2H + root.gridGap
            width: root.totalW
            height: root.row3H

            readonly property int leftColW: Math.round((root.totalW - root.gridGap) * 0.42)
            readonly property int rightColW: root.totalW - root.gridGap - leftColW
            readonly property int powerPillH: 58
            readonly property int sysCardH: root.row3H - root.gridGap - powerPillH

            // Left Column (42%): Character Poster with 20px Rounded Corners & Warm Cream Tint (#EADFD3)
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
                    layer.effect: OpacityMask {
                        maskSource: posterMask
                    }

                    Image {
                        id: rawPosterImg
                        anchors.fill: parent
                        source: "assets/poster.jpg"
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        layer.enabled: true
                    }

                    Rectangle {
                        id: creamTintRect
                        anchors.fill: parent
                        color: root.posterTint
                        visible: false
                        layer.enabled: true
                    }

                    // Multiply blend turns pure white (#FFFFFF) into warm cream (#EADFD3)
                    // while keeping dark line-art crisp black
                    Blend {
                        anchors.fill: parent
                        source: rawPosterImg
                        foregroundSource: creamTintRect
                        mode: "multiply"
                    }
                }
            }

            // Right Column Top: System Monitor Card (Linux Partitions: Root (/), Home (/home), Battery)
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
                    x: 22
                    y: 22
                    width: parent.width - 44
                    spacing: 22

                    // Linux Root Partition: Root (/)
                    Column {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: "Root (/)"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.textPrimary
                            font.family: "Fira Sans"
                        }
                        Text {
                            text: (root.stats.root_used || "114.7 GB") + " / " + (root.stats.root_total || "712.8 GB")
                            font.pixelSize: 13
                            color: root.textSecondary
                            font.family: "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 7
                            radius: 3.5
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.root_pct || 16) / 100.0))
                                height: parent.height
                                radius: 3.5
                                color: root.barFill
                            }
                        }
                    }

                    // Linux Home Partition: Home (/home)
                    Column {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: "Home (/home)"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.textPrimary
                            font.family: "Fira Sans"
                        }
                        Text {
                            text: (root.stats.home_used || "114.7 GB") + " / " + (root.stats.home_total || "712.8 GB")
                            font.pixelSize: 13
                            color: root.textSecondary
                            font.family: "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 7
                            radius: 3.5
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.home_pct || 16) / 100.0))
                                height: parent.height
                                radius: 3.5
                                color: root.barFill
                            }
                        }
                    }

                    // Battery:
                    Column {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: "Battery"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.textPrimary
                            font.family: "Fira Sans"
                        }
                        Text {
                            text: (root.stats.battery_pct || 100) + "%"
                            font.pixelSize: 13
                            color: root.textSecondary
                            font.family: "Fira Sans"
                        }
                        Rectangle {
                            width: parent.width
                            height: 7
                            radius: 3.5
                            color: root.barTrack
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.06, (root.stats.battery_pct || 100) / 100.0))
                                height: parent.height
                                radius: 3.5
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
                    spacing: 42

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
