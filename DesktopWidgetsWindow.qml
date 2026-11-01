import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root

    // Pinned to desktop background layer behind normal windows
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: WlrLayershell.Ignore

    anchors {
        top: true
        left: true
    }

    margins {
        top: 65
        left: 65
    }

    implicitWidth: 300
    implicitHeight: 480
    color: "transparent"

    // Theme Tokens - Dark Frosted Glass
    readonly property color cardBg: Qt.rgba(0.09, 0.12, 0.16, 0.72)
    readonly property color cardBorder: Qt.rgba(1.0, 1.0, 1.0, 0.08)
    readonly property color accentColor: "#7c9bf2"
    readonly property color textPrimary: "#ffffff"
    readonly property color textMuted: "#96a4b2"
    readonly property color barTrack: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    readonly property int cardRadius: 18
    readonly property int pillRadius: 14

    // Dynamic stats fetched from helper script
    property var stats: ({
        "root_used": "111.6 GB",
        "root_total": "712.8 GB",
        "root_pct": 16,
        "home_used": "111.6 GB",
        "home_total": "712.8 GB",
        "home_pct": 16,
        "trash_size": "38 MB",
        "weather_temp": "27°C",
        "weather_condition": "🌧️",
        "battery_pct": 85,
        "battery_status": "Charging"
    })

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
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 10000
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
                if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
            }
            return players[0];
        }
        return null;
    }

    // Main Column Container
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ==========================================
        // ROW 1: Clock & Weather Cards
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            spacing: 12

            // Clock & Date Card
            Rectangle {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                radius: root.cardRadius
                color: root.cardBg
                border.color: root.cardBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: Qt.formatDateTime(liveClock.date, "ddd")
                            font.pixelSize: 22
                            font.bold: true
                            color: root.textPrimary
                            font.family: "Fira Sans"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Qt.formatDateTime(liveClock.date, "hh:mm ap")
                            font.pixelSize: 16
                            font.bold: true
                            color: root.textPrimary
                            font.family: "Fira Sans"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: Qt.formatDateTime(liveClock.date, "MMM")
                            font.pixelSize: 13
                            color: root.textMuted
                            font.family: "Fira Sans"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Qt.formatDateTime(liveClock.date, "dd/MM/yyyy")
                            font.pixelSize: 13
                            color: root.textMuted
                            font.family: "Fira Sans"
                        }
                    }
                }
            }

            // Weather Card
            Rectangle {
                Layout.preferredWidth: 108
                Layout.fillHeight: true
                radius: root.cardRadius
                color: root.cardBg
                border.color: root.cardBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.stats.weather_condition || "🌧️"
                        font.pixelSize: 26
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.stats.weather_temp || "27°C"
                        font.pixelSize: 15
                        font.bold: true
                        color: root.textPrimary
                        font.family: "Fira Sans"
                    }
                }
            }
        }

        // ==========================================
        // ROW 2: Music / Media Player Card
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: root.cardRadius
            color: root.cardBg
            border.color: root.cardBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Album Art
                Rectangle {
                    implicitWidth: 76
                    implicitHeight: 76
                    radius: 12
                    clip: true
                    color: "#181d24"
                    border.color: root.cardBorder
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        source: (root.activePlayer && root.activePlayer.trackArtUrl)
                            ? root.activePlayer.trackArtUrl
                            : "assets/album.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                // Track details
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    Text {
                        text: "You're listening :"
                        font.pixelSize: 13
                        font.italic: true
                        color: root.textMuted
                        font.family: "Fira Sans"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (root.activePlayer && root.activePlayer.trackTitle)
                                return root.activePlayer.trackTitle;
                            return "No Track Playing";
                        }
                        font.pixelSize: 15
                        font.bold: true
                        color: root.textPrimary
                        elide: Text.ElideRight
                        font.family: "Fira Sans"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            let artist = "";
                            if (root.activePlayer) {
                                if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
                                else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
                                    artist = root.activePlayer.trackArtists[0];
                                else if (root.activePlayer.identity) artist = root.activePlayer.identity;
                            }
                            return "BY : " + (artist ? artist : "—");
                        }
                        font.pixelSize: 12
                        color: root.textMuted
                        elide: Text.ElideRight
                        font.family: "Fira Sans"
                    }
                }
            }
        }

        // ==========================================
        // ROW 3: Media Controls & Trash Pill
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 12

            // Media Controls Pill
            Rectangle {
                Layout.preferredWidth: 155
                Layout.fillHeight: true
                radius: root.pillRadius
                color: root.cardBg
                border.color: root.cardBorder
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 18

                    // Previous Button
                    Text {
                        text: "󰒮"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 17
                        color: prevMouse.containsMouse ? root.textPrimary : root.textMuted
                        scale: prevMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.activePlayer) root.activePlayer.previous();
                        }
                    }

                    // Play/Pause Button
                    Text {
                        text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                            ? "󰏤" : "󰐊"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 19
                        color: playMouse.containsMouse ? root.accentColor : root.textPrimary
                        scale: playMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.activePlayer) root.activePlayer.playPause();
                        }
                    }

                    // Next Button
                    Text {
                        text: "󰒭"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 17
                        color: nextMouse.containsMouse ? root.textPrimary : root.textMuted
                        scale: nextMouse.pressed ? 0.9 : 1.0

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.activePlayer) root.activePlayer.next();
                        }
                    }
                }
            }

            // Trash Pill
            Rectangle {
                Layout.preferredWidth: 133
                Layout.fillHeight: true
                radius: root.pillRadius
                color: trashMouse.containsMouse ? Qt.rgba(0.12, 0.16, 0.22, 0.85) : root.cardBg
                border.color: root.cardBorder
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰩹"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 16
                        color: root.textMuted
                    }

                    Text {
                        text: root.stats.trash_size || "38 MB"
                        font.pixelSize: 12
                        font.bold: true
                        color: root.textPrimary
                        font.family: "Fira Sans"
                    }
                }

                MouseArea {
                    id: trashMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", "trash://"])
                }
            }
        }

        // ==========================================
        // ROW 4: Photo Frame & System Monitor + Power
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 205
            spacing: 12

            // Photo Card (Left)
            Rectangle {
                Layout.preferredWidth: 120
                Layout.fillHeight: true
                radius: root.cardRadius
                clip: true
                color: root.cardBg
                border.color: root.cardBorder
                border.width: 1

                Image {
                    anchors.fill: parent
                    source: "assets/poster.jpg"
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                }
            }

            // Right Column: System Monitor + Power Pill
            ColumnLayout {
                Layout.preferredWidth: 168
                Layout.fillHeight: true
                spacing: 10

                // System Monitor Card (C:, D:, Battery)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.cardRadius
                    color: root.cardBg
                    border.color: root.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7

                        // Disk C:
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "C:"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.textPrimary
                                font.family: "Fira Sans"
                            }
                            Text {
                                text: (root.stats.root_used || "150.9 GB") + " / " + (root.stats.root_total || "475.4 GB")
                                font.pixelSize: 10
                                color: root.textMuted
                                font.family: "Fira Sans"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 5
                                radius: 3
                                color: root.barTrack
                                Rectangle {
                                    width: parent.width * Math.min(1.0, (root.stats.root_pct || 16) / 100.0)
                                    height: parent.height
                                    radius: 3
                                    color: root.accentColor
                                }
                            }
                        }

                        // Disk D:
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "D:"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.textPrimary
                                font.family: "Fira Sans"
                            }
                            Text {
                                text: (root.stats.home_used || "614.1 GB") + " / " + (root.stats.home_total || "953.9 GB")
                                font.pixelSize: 10
                                color: root.textMuted
                                font.family: "Fira Sans"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 5
                                radius: 3
                                color: root.barTrack
                                Rectangle {
                                    width: parent.width * Math.min(1.0, (root.stats.home_pct || 16) / 100.0)
                                    height: parent.height
                                    radius: 3
                                    color: root.accentColor
                                }
                            }
                        }

                        // Battery
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Battery:"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.textPrimary
                                font.family: "Fira Sans"
                            }
                            Text {
                                text: (root.stats.battery_pct || 100) + "%"
                                font.pixelSize: 10
                                color: root.textMuted
                                font.family: "Fira Sans"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 5
                                radius: 3
                                color: root.barTrack
                                Rectangle {
                                    width: parent.width * Math.min(1.0, (root.stats.battery_pct || 100) / 100.0)
                                    height: parent.height
                                    radius: 3
                                    color: root.accentColor
                                }
                            }
                        }
                    }
                }

                // Power Controls Pill
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: root.pillRadius
                    color: root.cardBg
                    border.color: root.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 24

                        // Suspend / Sleep
                        Text {
                            text: "󰤄"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 16
                            color: sleepMouse.containsMouse ? root.accentColor : root.textMuted
                            scale: sleepMouse.pressed ? 0.9 : 1.0

                            MouseArea {
                                id: sleepMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                            }
                        }

                        // Power Off
                        Text {
                            text: "󰐥"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 16
                            color: powerMouse.containsMouse ? "#ff6b6b" : root.textMuted
                            scale: powerMouse.pressed ? 0.9 : 1.0

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                            }
                        }

                        // Reboot
                        Text {
                            text: "󰑐"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 16
                            color: rebootMouse.containsMouse ? root.accentColor : root.textMuted
                            scale: rebootMouse.pressed ? 0.9 : 1.0

                            MouseArea {
                                id: rebootMouse
                                anchors.fill: parent
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
}
