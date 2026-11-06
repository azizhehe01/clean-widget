import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

// Interactive notch hanging from the top-center edge of the screen.
// • Default: Two angry white eyes tracking the cursor & blinking.
// • On Volume Change: Smoothly morphs into Nothing OS dot-matrix volume OSD.
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:notch"
    WlrLayershell.layer: WlrLayer.Top

    // =========================================================================
    // User Configurations (Bisa Diatur Di Sini)
    // =========================================================================
    // Durasi berapa lama HUD volume muncul sebelum kembali jadi mata (dalam milidetik)
    // 1000 = 1.0 detik, 1200 = 1.2 detik, 1800 = 1.8 detik
    property int volumeTimeoutMs: 1000

    // Kecepatan animasi transisi morphing (ms)
    property int animDuration: 200

    // Mode Auto-Hide Notch:
    //   "any_window"      : Sembunyikan notch jika ada jendela apapun aktif / terbuka (Default)
    //   "not_antigravity" : Sembunyikan notch jika aplikasi aktif BUKAN Antigravity
    //   "antigravity"     : Sembunyikan notch jika aplikasi aktif ADALAH Antigravity
    //   "never"           : Selalu tampilkan notch
    property string autoHideMode: "any_window"

    // Reserve the notch height so tiled windows start below it.
    // Default false agar jendela aplikasi dapat ruang layar penuh 100% tanpa terpotong 38px
    property bool reserveSpace: false
    exclusiveZone: reserveSpace ? notchH : 0

    // ---------------------------------------------------------------------
    // Nothing OS Typography
    // ---------------------------------------------------------------------
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // ---------------------------------------------------------------------
    // Pipewire Audio Volume Integration
    // ---------------------------------------------------------------------
    readonly property PwNode audioSink: Pipewire.defaultAudioSink
    readonly property bool audioReady: audioSink !== null && audioSink.ready && audioSink.audio !== null
    readonly property real volumeLevel: audioReady ? audioSink.audio.volume : 0.0
    readonly property bool isMuted: audioReady ? audioSink.audio.muted : false
    readonly property int volumePercent: isMuted ? 0 : Math.round(volumeLevel * 100)

    // Keep default audio sink properties live and responsive
    PwObjectTracker { objects: audioSink !== null ? [audioSink] : [] }

    property bool showVolume: false
    property int lastVolumePercent: -1
    property bool lastMutedState: false
    property bool audioSyncReady: false

    onVolumePercentChanged: {
        if (!audioSyncReady) {
            lastVolumePercent = volumePercent;
            return;
        }
        if (volumePercent !== lastVolumePercent) {
            lastVolumePercent = volumePercent;
            triggerVolumeOsd();
        }
    }

    onIsMutedChanged: {
        if (!audioSyncReady) {
            lastMutedState = isMuted;
            return;
        }
        if (isMuted !== lastMutedState) {
            lastMutedState = isMuted;
            triggerVolumeOsd();
        }
    }

    Timer {
        interval: 800
        running: true
        onTriggered: root.audioSyncReady = true
    }

    function triggerVolumeOsd() {
        root.showVolume = true;
        volumeDismissTimer.restart();
    }

    Timer {
        id: volumeDismissTimer
        interval: root.volumeTimeoutMs
        onTriggered: root.showVolume = false
    }

    function setVolumeDelta(delta: real): void {
        if (!audioReady) return;
        audioSink.audio.muted = false;
        audioSink.audio.volume = Math.max(0.0, Math.min(1.0, volumeLevel + delta));
    }

    function toggleMute(): void {
        if (!audioReady) return;
        audioSink.audio.muted = !audioSink.audio.muted;
    }

    // ---------------------------------------------------------------------
    // Geometry & Smooth Hardware-Accelerated Sizing
    // ---------------------------------------------------------------------
    readonly property int baseBodyW: 168
    readonly property int volumeBodyW: 248
    property real animatedBodyW: showVolume ? volumeBodyW : baseBodyW

    Behavior on animatedBodyW {
        NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic }
    }

    readonly property int notchH: 38
    readonly property int bottomRadius: 14
    readonly property int shoulder: 10     // concave fillet on each side

    readonly property int eyeW: 36
    readonly property int eyeH: 18
    readonly property int eyeGap: 26
    readonly property int pupilSize: 12

    // Fixed stable window dimensions (mencegah Wayland surface resize jitter)
    readonly property int windowWidth: 320
    anchors.top: true
    implicitWidth: windowWidth
    implicitHeight: notchH
    color: "transparent"

    // Stable screen-space center coordinate (tidak pernah goyang saat notch resize)
    readonly property real screenCenterX: root.screen ? (root.screen.x + root.screen.width / 2) : 960
    readonly property real originY: root.screen ? root.screen.y : 0

    // Latest global cursor position and active window class (fed by cursor.py)
    property real cursorX: screenCenterX
    property real cursorY: 400
    property string activeAppClass: "none"
    property int workspaceWindows: 0

    // Auto-hide & window focus intelligence
    readonly property bool isAntigravityActive: activeAppClass.toLowerCase().indexOf("antigravity") !== -1 || activeAppClass.toLowerCase().indexOf("code") !== -1
    readonly property bool hasActiveWindow: activeAppClass !== "none" && activeAppClass !== ""
    readonly property bool hasWindow: hasActiveWindow || workspaceWindows > 0
    readonly property bool isHoveringTop: cursorY <= 8 && Math.abs(cursorX - screenCenterX) <= (windowWidth / 2)

    readonly property bool shouldHide: {
        // Jangan sembunyikan jika volume HUD sedang aktif (selalu munculkan saat setting volume)
        if (showVolume) return false;
        // Munculkan jika user mengarahkan kursor ke ujung atas layar (hover-to-reveal)
        if (isHoveringTop) return false;

        if (autoHideMode === "any_window") {
            // Sembunyikan jika ada jendela aplikasi apapun terbuka/aktif (misal terminal, browser, dsb)
            return hasWindow;
        } else if (autoHideMode === "not_antigravity") {
            // Sembunyikan ketika window aktif dan window tersebut BUKAN Antigravity
            return hasActiveWindow && !isAntigravityActive;
        } else if (autoHideMode === "antigravity") {
            // Sembunyikan ketika window Antigravity sedang aktif
            return isAntigravityActive;
        }
        return false;
    }

    Process {
        id: cursorProc
        command: ["python3", Quickshell.shellDir + "/notch/cursor.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(" ");
                if (p.length >= 2) {
                    root.cursorX = Number(p[0]);
                    root.cursorY = Number(p[1]);
                    if (p.length >= 3) {
                        root.activeAppClass = p[2];
                    }
                    if (p.length >= 4) {
                        root.workspaceWindows = Number(p[3]);
                    }
                }
            }
        }
        onRunningChanged: if (!running) restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: cursorProc.running = true
    }

    // Only the visible black notch captures clicks/wheel (area transparan di luar notch click-through)
    mask: Region {
        x: Math.round(notchVisual.x)
        y: 0
        width: Math.round(notchVisual.width)
        height: root.shouldHide ? 0 : root.notchH
    }

    // ---------------------------------------------------------------------
    // Visual Notch Container (Smoothly animates width inside stable window)
    // ---------------------------------------------------------------------
    Item {
        id: notchVisual
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shouldHide ? -root.notchH : 0
        opacity: root.shouldHide ? 0.0 : 1.0
        width: Math.round(root.animatedBodyW + root.shoulder * 2)
        height: root.notchH

        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        // GPU-Accelerated Notch Shape with Smooth Concave Top Shoulders
        Shape {
            id: notchShape
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: "#000000"
                strokeColor: "transparent"
                startX: 0
                startY: 0

                // Top-Left Concave Shoulder
                PathQuad {
                    x: root.shoulder
                    y: root.shoulder
                    controlX: root.shoulder
                    controlY: 0
                }

                // Left Edge down to bottom-left corner
                PathLine {
                    x: root.shoulder
                    y: root.notchH - root.bottomRadius
                }

                // Bottom-Left Rounded Corner
                PathQuad {
                    x: root.shoulder + root.bottomRadius
                    y: root.notchH
                    controlX: root.shoulder
                    controlY: root.notchH
                }

                // Bottom Edge across to bottom-right corner
                PathLine {
                    x: notchVisual.width - root.shoulder - root.bottomRadius
                    y: root.notchH
                }

                // Bottom-Right Rounded Corner
                PathQuad {
                    x: notchVisual.width - root.shoulder
                    y: root.notchH - root.bottomRadius
                    controlX: notchVisual.width - root.shoulder
                    controlY: root.notchH
                }

                // Right Edge up to top-right shoulder
                PathLine {
                    x: notchVisual.width - root.shoulder
                    y: root.shoulder
                }

                // Top-Right Concave Shoulder
                PathQuad {
                    x: notchVisual.width
                    y: 0
                    controlX: notchVisual.width - root.shoulder
                    controlY: 0
                }
            }
        }

        // Wheel adjustment & Right-click to mute directly on notch
        WheelHandler {
            onWheel: function(event) {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
                if (delta > 0) root.setVolumeDelta(0.05);
                else if (delta < 0) root.setVolumeDelta(-0.05);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
        }

        // -----------------------------------------------------------------
        // DEFAULT VIEW: Interactive Angry Eyes
        // -----------------------------------------------------------------
        Row {
            id: eyeRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: root.eyeGap

            opacity: root.showVolume ? 0.0 : 1.0
            scale: root.showVolume ? 0.85 : 1.0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            Eye { side: -1 }
            Eye { side: 1 }
        }

        // -----------------------------------------------------------------
        // VOLUME VIEW: Nothing OS Dot-Matrix Volume OSD
        // -----------------------------------------------------------------
        Row {
            id: volumeOsdRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            opacity: root.showVolume ? 1.0 : 0.0
            scale: root.showVolume ? 1.0 : 0.85
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            // 1. Dot-Matrix Speaker Icon
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.isMuted
                        ? Qt.resolvedUrl("../assets/volume-mute-dot.svg")
                        : Qt.resolvedUrl("../assets/volume-dot.svg")
                    sourceSize: Qt.size(18, 18)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }
            }

            // 2. Nothing OS Dot-Matrix Segmented Bar (16 discrete dot-capsules)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: 16
                    Rectangle {
                        width: 4
                        height: 8
                        radius: 2
                        readonly property real dotThreshold: (index + 0.5) / 16.0
                        readonly property bool active: !root.isMuted && (root.volumeLevel >= dotThreshold)
                        color: active ? "#FFFFFF" : Qt.rgba(1.0, 1.0, 1.0, 0.18)

                        Behavior on color {
                            ColorAnimation { duration: 70 }
                        }
                    }
                }
            }

            // 3. Dot-Matrix Numerical Volume Percentage (Ndot57)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                text: root.isMuted ? "MUTED" : (root.volumePercent + "%")
                font.pixelSize: root.isMuted ? 10 : 13
                font.family: root.isMuted ? (fontNMono.name || "Fira Sans") : (fontNdot57.name || "Fira Sans")
                font.letterSpacing: 0.5
                color: root.isMuted ? Qt.rgba(1.0, 1.0, 1.0, 0.55) : "#FFFFFF"
            }
        }
    }

    // ---------------------------------------------------------------------
    // Blink: both eyes squash vertically every 3–6 s (sometimes double)
    // ---------------------------------------------------------------------
    property real lidScale: 1.0

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "lidScale"; to: 0.08; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "lidScale"; to: 1.0; duration: 110; easing.type: Easing.OutQuad }
    }

    Timer {
        id: blinkTimer
        interval: 3500
        running: true
        repeat: true
        onTriggered: {
            blinkAnim.restart();
            if (Math.random() < 0.2) doubleBlink.start();
            interval = 3000 + Math.random() * 3000;
        }
    }

    Timer {
        id: doubleBlink
        interval: 240
        onTriggered: blinkAnim.restart()
    }

    // ---------------------------------------------------------------------
    // Eyes Component with Stable Screen Coordinates
    // ---------------------------------------------------------------------
    component Eye: Item {
        id: eye
        property int side: 1

        width: root.eyeW + 10
        height: root.eyeH + 8

        // Eye center in stable screen coordinates (bebas getaran/jitter saat notch resize)
        readonly property real gx: root.screenCenterX + (eye.side * (root.eyeGap / 2 + root.eyeW / 2))
        readonly property real gy: root.originY + root.notchH / 2

        readonly property real dx: root.cursorX - gx
        readonly property real dy: root.cursorY - gy
        readonly property real dist: Math.max(1, Math.sqrt(dx * dx + dy * dy))
        readonly property real reach: Math.min(1, dist / 260)

        // Parallax 1: Sclera (bagian putih) ikut bergerak ke arah kursor
        readonly property real scleraShiftX: (dx / dist) * 4.5 * reach
        readonly property real scleraShiftY: (dy / dist) * 2.8 * reach

        // Parallax 2: Pupil bergerak lebih jauh di dalam bola mata
        readonly property real pupilMaxX: (root.eyeW - root.pupilSize) / 2 - 2
        readonly property real pupilMaxY: (root.eyeH - root.pupilSize) / 2 - 1

        transform: Scale {
            origin.x: eye.width / 2
            origin.y: eye.height / 2
            yScale: root.lidScale
        }

        // Eyeball wrapper yang bergeser dinamis mengikuti kursor
        Item {
            id: scleraWrapper
            width: root.eyeW
            height: root.eyeH
            x: (parent.width - width) / 2 + eye.scleraShiftX
            y: (parent.height - height) / 2 + eye.scleraShiftY

            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            // Sedikit rotasi dinamis agar tatapan mata makin hidup
            rotation: (-3 * eye.side) + ((eye.dx / eye.dist) * 3.5 * eye.reach)
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            Rectangle {
                id: eyeMask
                anchors.fill: parent
                radius: height / 2
                visible: false
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: eyeMask }

                // Sclera (Bagian Putih)
                Rectangle {
                    anchors.fill: parent
                    color: "#FFFFFF"
                }

                // Pupil (Hitam) yang bergerak di dalam bagian putih
                Rectangle {
                    width: root.pupilSize
                    height: root.pupilSize
                    radius: width / 2
                    color: "#000000"
                    x: scleraWrapper.width / 2 - width / 2 + (eye.dx / eye.dist) * eye.pupilMaxX * eye.reach
                    y: scleraWrapper.height / 2 - height / 2 + (eye.dy / eye.dist) * eye.pupilMaxY * eye.reach

                    Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    Behavior on y { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                }

                // Angry brow: kelopak atas / alis galak yang intensitasnya bereaksi saat menatap ke bawah
                Rectangle {
                    width: scleraWrapper.width * 1.4
                    height: scleraWrapper.height
                    color: "#000000"
                    x: (scleraWrapper.width - width) / 2
                    y: -height + scleraWrapper.height * 0.32 + Math.max(-1, (eye.dy / eye.dist) * 2.0 * eye.reach)
                    rotation: -14 * eye.side
                    transformOrigin: Item.Center
                    antialiasing: true

                    Behavior on y { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
