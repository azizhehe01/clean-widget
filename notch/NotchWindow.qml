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
    // User Configurations (Bisa Diatur Di Sini)
    // =========================================================================
    // Durasi berapa lama HUD volume muncul sebelum kembali jadi mata (dalam milidetik)
    // 1000 = 1.0 detik, 1200 = 1.2 detik, 1800 = 1.8 detik
    property int volumeTimeoutMs: 1000

    // Durasi berapa lama HUD kecerahan (brightness) muncul sebelum kembali jadi mata (dalam milidetik)
    property int brightnessTimeoutMs: 1000

    // Durasi berapa lama menu display HDMI (Super+P) muncul sebelum otomatis terpilih & menutup (ms)
    // 1000 = 1.0 detik, 1400 = 1.4 detik, 2000 = 2.0 detik, 2800 = 2.8 detik
    property int displayTimeoutMs: 1000

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


    // ---------------------------------------------------------------------
    // WiFi Manager Properties
    // ---------------------------------------------------------------------
    property bool showWifiMenu: false
    property var wifiData: ({ "wifi_enabled": true, "active_ssid": "", "active_ip": "", "networks": [] })
    readonly property var wifiNetworks: (root.wifiData && root.wifiData.networks) ? root.wifiData.networks : []
    readonly property bool isWifiConnected: root.wifiData && (root.wifiData.active_ssid !== "" && root.wifiData.active_ssid !== null)
    property bool isScanningWifi: false
    property string passwordPromptSsid: ""
    property string enteredPassword: ""

    property bool showVolume: false
    property int lastVolumePercent: -1
    property bool lastMutedState: false
    property bool audioSyncReady: false

    // ---------------------------------------------------------------------
    // Display Brightness Integration (Nothing OS Dot-Matrix HUD)
    // ---------------------------------------------------------------------
    property real brightnessLevel: 0.36
    readonly property int brightnessPercent: Math.round(brightnessLevel * 100)
    property bool showBrightness: false
    property int lastBrightnessPercent: -1
    property bool brightnessSyncReady: false
    readonly property int brightnessBodyW: 248

    Component.onCompleted: {
        root.queryWifi();
        root.queryBrightness();
    }

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
        root.showBrightness = false;
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
    // Brightness Control & Hardware Sync Functions
    // ---------------------------------------------------------------------
    Timer {
        interval: 1000
        running: true
        onTriggered: {
            root.brightnessSyncReady = true;
            root.queryBrightness();
        }
    }

    function triggerBrightnessOsd(): void {
        root.showVolume = false;
        root.showBrightness = true;
        brightnessDismissTimer.restart();
    }

    Timer {
        id: brightnessDismissTimer
        interval: root.brightnessTimeoutMs
        onTriggered: root.showBrightness = false
    }

    function adjustBrightnessDelta(delta: int): void {
        var currentPct = root.brightnessPercent;
        var newPct = Math.max(1, Math.min(100, currentPct + delta));
        root.brightnessLevel = newPct / 100.0;
        root.lastBrightnessPercent = newPct;
        root.triggerBrightnessOsd();

        if (delta > 0) {
            Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", delta + "%+"]);
        } else {
            Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", Math.abs(delta) + "%-"]);
        }
        brightnessSyncTimer.restart();
    }

    function setBrightnessPercent(pct: int): void {
        var target = Math.max(1, Math.min(100, pct));
        root.brightnessLevel = target / 100.0;
        root.lastBrightnessPercent = target;
        root.triggerBrightnessOsd();
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", target + "%"]);
        brightnessSyncTimer.restart();
    }

    Timer {
        id: brightnessSyncTimer
        interval: 150
        repeat: false
        onTriggered: root.queryBrightness()
    }

    Process {
        id: queryBrightnessProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim();
                // Format: intel_backlight,backlight,34248,36%,96000
                var parts = out.split(",");
                if (parts.length >= 4) {
                    var pctStr = parts[3].replace("%", "").trim();
                    var pct = parseInt(pctStr);
                    if (!isNaN(pct)) {
                        if (root.brightnessSyncReady && root.lastBrightnessPercent !== -1 && Math.abs(pct - root.lastBrightnessPercent) >= 2) {
                            root.brightnessLevel = pct / 100.0;
                            root.lastBrightnessPercent = pct;
                            root.triggerBrightnessOsd();
                        } else {
                            root.brightnessLevel = pct / 100.0;
                            root.lastBrightnessPercent = pct;
                        }
                    }
                }
            }
        }
    }

    function queryBrightness(): void {
        if (!queryBrightnessProc.running) {
            queryBrightnessProc.running = true;
        }
    }

    Timer {
        id: backlightWatcher
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!root.showBrightness) {
                root.queryBrightness();
            }
        }
    }

    // ---------------------------------------------------------------------
    // Quickshell IPC Handler for Brightness: qs ipc call brightness <cmd>
    // ---------------------------------------------------------------------
    IpcHandler {
        target: "brightness"

        function up(): void {
            root.adjustBrightnessDelta(5);
        }
        function down(): void {
            root.adjustBrightnessDelta(-5);
        }
        function show(): void {
            root.queryBrightness();
            root.triggerBrightnessOsd();
        }
        function set(pct: int): void {
            root.setBrightnessPercent(pct);
        }
    }

    // ---------------------------------------------------------------------
    // Geometry & Smooth Hardware-Accelerated Sizing
    // ---------------------------------------------------------------------
    readonly property int baseBodyW: 168
    readonly property int volumeBodyW: 248
    readonly property int displayBodyW: 460
    readonly property int wifiBodyW: 340
    property real animatedBodyW: {
        if (showWifiMenu) return wifiBodyW;
        if (showDisplayMenu) return displayBodyW;
        if (showBrightness) return brightnessBodyW;
        if (showVolume) return volumeBodyW;
        return baseBodyW;
    }

    Behavior on animatedBodyW {
        NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic }
    }

    readonly property int baseNotchH: 38
    readonly property int displayNotchH: 84
    readonly property int wifiNotchH: 284
    property real animatedNotchH: {
        if (showWifiMenu) return wifiNotchH;
        if (showDisplayMenu) return displayNotchH;
        return baseNotchH;
    }

    Behavior on animatedNotchH {
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
    readonly property int windowWidth: 500
    readonly property int windowHeight: root.showWifiMenu ? 320 : (root.showDisplayMenu ? 110 : 96)
    anchors.top: true
    implicitWidth: windowWidth
    implicitHeight: windowHeight
    color: "transparent"


    // ---------------------------------------------------------------------
    // WiFi Manager Integration (Nothing OS Dot-Matrix Style)
    // ---------------------------------------------------------------------
    function toggleWifiMenu(): void {
        if (root.showWifiMenu) {
            root.closeWifiMenu();
        } else {
            root.openWifiMenu();
        }
    }

    function openWifiMenu(): void {
        root.showDisplayMenu = false;
        root.showVolume = false;
        root.showWifiMenu = true;
        root.passwordPromptSsid = "";
        root.enteredPassword = "";
        root.queryWifi();
    }

    function closeWifiMenu(): void {
        root.showWifiMenu = false;
        root.passwordPromptSsid = "";
        root.enteredPassword = "";
    }

    function queryWifi(): void {
        root.isScanningWifi = true;
        queryWifiProc.running = false;
        queryWifiProc.running = true;
    }

    function toggleWifiRadio(): void {
        toggleWifiProc.running = false;
        toggleWifiProc.running = true;
    }

    function connectToNetwork(ssid, pwd): void {
        connectWifiProc.targetSsid = ssid;
        connectWifiProc.targetPwd = pwd ? pwd : "";
        connectWifiProc.running = false;
        connectWifiProc.running = true;
    }

    function disconnectCurrent(): void {
        disconnectWifiProc.running = false;
        disconnectWifiProc.running = true;
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.toggleWifiMenu(); }
        function scan(): void { root.queryWifi(); }
        function open(): void { root.openWifiMenu(); }
        function close(): void { root.closeWifiMenu(); }
    }

    Process {
        id: queryWifiProc
        command: ["python3", Quickshell.shellDir + "/notch/wifi.py", "scan"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isScanningWifi = false;
                try {
                    let raw = this.text.trim();
                    if (raw) root.wifiData = JSON.parse(raw);
                } catch (e) {}
            }
        }
    }

    Process {
        id: toggleWifiProc
        command: ["python3", Quickshell.shellDir + "/notch/wifi.py", "toggle"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.queryWifi()
        }
    }

    Process {
        id: connectWifiProc
        property string targetSsid: ""
        property string targetPwd: ""
        command: targetPwd ? ["python3", Quickshell.shellDir + "/notch/wifi.py", "connect", targetSsid, targetPwd]
                           : ["python3", Quickshell.shellDir + "/notch/wifi.py", "connect", targetSsid]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.passwordPromptSsid = "";
                root.enteredPassword = "";
                root.queryWifi();
            }
        }
    }

    Process {
        id: disconnectWifiProc
        command: ["python3", Quickshell.shellDir + "/notch/wifi.py", "disconnect"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.queryWifi()
        }
    }

    // ---------------------------------------------------------------------
    // Display / HDMI Projection Management (Super + P Windows-Style)
    // ---------------------------------------------------------------------
    property bool showDisplayMenu: false
    property int selectedDisplayIndex: 0
    property string activeDisplayMode: "laptop"

    ListModel {
        id: displayModesModel
        ListElement { modeId: "laptop";    label: "PC ONLY";   desc: "Laptop";  iconSource: "../assets/display-laptop.svg" }
        ListElement { modeId: "duplicate"; label: "DUPLICATE"; desc: "Mirror";  iconSource: "../assets/display-duplicate.svg" }
        ListElement { modeId: "extend";    label: "EXTEND";    desc: "Dual";    iconSource: "../assets/display-extend.svg" }
        ListElement { modeId: "second";    label: "SECOND";    desc: "HDMI";    iconSource: "../assets/display-second.svg" }
    }

    Timer {
        id: displayAutoApplyTimer
        interval: root.displayTimeoutMs
        onTriggered: root.confirmAndCloseDisplay()
    }

    Timer {
        id: displayDismissTimer
        interval: 600
        onTriggered: root.showDisplayMenu = false
    }

    function triggerDisplayMenu(): void {
        if (!showDisplayMenu) {
            showDisplayMenu = true;
            queryDisplayProc.running = true;
        } else {
            // Cycle through options on subsequent Super + P
            selectedDisplayIndex = (selectedDisplayIndex + 1) % displayModesModel.count;
        }
        displayAutoApplyTimer.restart();
    }

    function selectAndApply(idx: int): void {
        selectedDisplayIndex = idx;
        applyCurrentDisplayMode();
        displayDismissTimer.restart();
    }

    function confirmAndCloseDisplay(): void {
        applyCurrentDisplayMode();
        root.showDisplayMenu = false;
    }

    function applyCurrentDisplayMode(): void {
        if (selectedDisplayIndex >= 0 && selectedDisplayIndex < displayModesModel.count) {
            let m = displayModesModel.get(selectedDisplayIndex).modeId;
            activeDisplayMode = m;
            applyDisplayProc.targetMode = m;
            applyDisplayProc.running = true;
        }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { root.triggerDisplayMenu(); }
        function next(): void {
            root.selectedDisplayIndex = (root.selectedDisplayIndex + 1) % displayModesModel.count;
            displayAutoApplyTimer.restart();
        }
        function prev(): void {
            root.selectedDisplayIndex = (root.selectedDisplayIndex + displayModesModel.count - 1) % displayModesModel.count;
            displayAutoApplyTimer.restart();
        }
        function select(idx: int): void { root.selectAndApply(idx); }
        function apply(): void { root.confirmAndCloseDisplay(); }
        function close(): void { root.showDisplayMenu = false; }
    }

    Process {
        id: queryDisplayProc
        command: ["python3", Quickshell.shellDir + "/notch/display.py", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let current = this.text.trim();
                for (let i = 0; i < displayModesModel.count; ++i) {
                    if (displayModesModel.get(i).modeId === current) {
                        root.selectedDisplayIndex = i;
                        root.activeDisplayMode = current;
                        break;
                    }
                }
            }
        }
    }

    Process {
        id: applyDisplayProc
        property string targetMode: "laptop"
        command: ["python3", Quickshell.shellDir + "/notch/display.py", targetMode]
        running: false
    }

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
        // Jangan sembunyikan jika menu WiFi sedang dibuka
        if (showWifiMenu) return false;
        // Jangan sembunyikan jika menu Display / HDMI sedang dibuka
        if (showDisplayMenu) return false;
        // Jangan sembunyikan jika volume atau brightness HUD sedang aktif
        if (showVolume || showBrightness) return false;
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
        height: root.shouldHide ? 0 : Math.round(notchVisual.height + notchVisual.y)
    }

    // ---------------------------------------------------------------------
    // Visual Notch Container (Smoothly animates width inside stable window)
    // ---------------------------------------------------------------------
    Item {
        id: notchVisual
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shouldHide ? -notchVisual.height : 0
        opacity: root.shouldHide ? 0.0 : 1.0
        width: Math.round(root.animatedBodyW + root.shoulder * 2)
        height: Math.round(root.animatedNotchH)

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
                    y: notchVisual.height - root.bottomRadius
                }

                // Bottom-Left Rounded Corner
                PathQuad {
                    x: root.shoulder + root.bottomRadius
                    y: notchVisual.height
                    controlX: root.shoulder
                    controlY: notchVisual.height
                }

                // Bottom Edge across to bottom-right corner
                PathLine {
                    x: notchVisual.width - root.shoulder - root.bottomRadius
                    y: notchVisual.height
                }

                // Bottom-Right Rounded Corner
                PathQuad {
                    x: notchVisual.width - root.shoulder
                    y: notchVisual.height - root.bottomRadius
                    controlX: notchVisual.width - root.shoulder
                    controlY: notchVisual.height
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
            enabled: !root.showDisplayMenu && !root.showWifiMenu
            onWheel: function(event) {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
                if (root.showBrightness) {
                    if (delta > 0) root.adjustBrightnessDelta(5);
                    else if (delta < 0) root.adjustBrightnessDelta(-5);
                } else {
                    if (delta > 0) root.setVolumeDelta(0.05);
                    else if (delta < 0) root.setVolumeDelta(-0.05);
                }
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.showDisplayMenu && !root.showWifiMenu && !root.showVolume && !root.showBrightness
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
        }


        // Left-click on notch to toggle WiFi menu
        MouseArea {
            anchors.fill: parent
            enabled: !root.showDisplayMenu && !root.showWifiMenu && !root.showVolume && !root.showBrightness
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleWifiMenu()
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

            opacity: (!root.showVolume && !root.showBrightness && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.0
            scale: (!root.showVolume && !root.showBrightness && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.85
            visible: !root.showVolume && !root.showBrightness && !root.showDisplayMenu && !root.showWifiMenu

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

            opacity: (root.showVolume && !root.showBrightness && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.0
            scale: (root.showVolume && !root.showBrightness && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.85
            visible: !root.showDisplayMenu && !root.showWifiMenu && !root.showBrightness && (!root.showVolume || opacity > 0.05)

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

        // -----------------------------------------------------------------
        // BRIGHTNESS VIEW: Nothing OS Dot-Matrix Brightness OSD
        // -----------------------------------------------------------------
        Row {
            id: brightnessOsdRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            opacity: (root.showBrightness && !root.showVolume && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.0
            scale: (root.showBrightness && !root.showVolume && !root.showDisplayMenu && !root.showWifiMenu) ? 1.0 : 0.85
            visible: !root.showDisplayMenu && !root.showWifiMenu && !root.showVolume && (!root.showBrightness || opacity > 0.05)

            Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            // 1. Dot-Matrix Sun / Brightness Icon (Nothing OS Dot-Matrix Style)
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [
                        // Core Ring
                        {x: 9, y: 6.5, r: 1.0}, {x: 9, y: 11.5, r: 1.0},
                        {x: 6.5, y: 9, r: 1.0}, {x: 11.5, y: 9, r: 1.0},
                        {x: 7.2, y: 7.2, r: 0.9}, {x: 10.8, y: 7.2, r: 0.9},
                        {x: 7.2, y: 10.8, r: 0.9}, {x: 10.8, y: 10.8, r: 0.9},
                        // Cardinal Rays
                        {x: 9, y: 3.5, r: 1.0}, {x: 9, y: 1.5, r: 0.9},
                        {x: 9, y: 14.5, r: 1.0}, {x: 9, y: 16.5, r: 0.9},
                        {x: 3.5, y: 9, r: 1.0}, {x: 1.5, y: 9, r: 0.9},
                        {x: 14.5, y: 9, r: 1.0}, {x: 16.5, y: 9, r: 0.9},
                        // Diagonal Rays
                        {x: 4.8, y: 4.8, r: 0.95}, {x: 13.2, y: 4.8, r: 0.95},
                        {x: 4.8, y: 13.2, r: 0.95}, {x: 13.2, y: 13.2, r: 0.95}
                    ]
                    Rectangle {
                        x: modelData.x - modelData.r
                        y: modelData.y - modelData.r
                        width: modelData.r * 2
                        height: modelData.r * 2
                        radius: modelData.r
                        color: "#FFFFFF"
                    }
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
                        readonly property bool active: root.brightnessLevel >= dotThreshold
                        color: active ? "#FFFFFF" : Qt.rgba(1.0, 1.0, 1.0, 0.18)

                        Behavior on color {
                            ColorAnimation { duration: 70 }
                        }
                    }
                }
            }

            // 3. Dot-Matrix Numerical Brightness Percentage (Ndot57)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                text: root.brightnessPercent + "%"
                font.pixelSize: 13
                font.family: fontNdot57.name || "Fira Sans"
                font.letterSpacing: 0.5
                color: "#FFFFFF"
            }
        }

        // -----------------------------------------------------------------
        // DISPLAY / HDMI PROJECTION MENU (NOTHING OS DOT-MATRIX STYLE)
        // -----------------------------------------------------------------
        Item {
            id: displayMenuContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            width: parent.width - root.shoulder * 2 - 14
            height: parent.height - 8

            opacity: root.showDisplayMenu ? 1.0 : 0.0
            scale: root.showDisplayMenu ? 1.0 : 0.92
            visible: root.showDisplayMenu

            Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            // Header: Red Dot Indicator + Title + Keyboard shortcut hints
            Row {
                id: displayHeader
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 4
                spacing: 7

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#D71921"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "PROJECT DISPLAY"
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: "#FFFFFF"
                }

                Text {
                    text: "·  HDMI"
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                    color: "#666666"
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 5
                text: "[SUPER+P] CYCLE"
                font.family: fontNMono.name || "monospace"
                font.pixelSize: 9
                color: "#777777"
            }

            // Cards Row: 4 Projection Options (PC ONLY, DUPLICATE, EXTEND, SECOND)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: displayHeader.bottom
                anchors.topMargin: 7
                spacing: 8

                Repeater {
                    model: displayModesModel

                    Rectangle {
                        id: modeCard
                        width: Math.floor((displayMenuContainer.width - 24) / 4)
                        height: 44
                        radius: 8

                        readonly property bool isSelected: root.selectedDisplayIndex === index

                        color: isSelected ? "#FFFFFF" : (cardMouse.containsMouse ? "#242424" : "#121212")
                        border.color: isSelected ? "#FFFFFF" : (cardMouse.containsMouse ? "#444444" : "#222222")
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Item {
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: cardIcon
                                    anchors.fill: parent
                                    source: Qt.resolvedUrl(model.iconSource)
                                    sourceSize: Qt.size(24, 24)
                                    visible: false
                                }

                                ColorOverlay {
                                    anchors.fill: cardIcon
                                    source: cardIcon
                                    color: modeCard.isSelected ? "#000000" : (cardMouse.containsMouse ? "#FFFFFF" : "#888888")
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: model.label
                                    font.family: fontNType.name || "Fira Sans"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: modeCard.isSelected ? "#000000" : (cardMouse.containsMouse ? "#FFFFFF" : "#E0E0E0")
                                }

                                Text {
                                    text: modeCard.isSelected ? "● ACTIVE" : model.desc
                                    font.family: fontNMono.name || "monospace"
                                    font.pixelSize: 8
                                    color: modeCard.isSelected ? "#333333" : "#666666"
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectAndApply(index)
                            onEntered: {
                                root.selectedDisplayIndex = index;
                                displayAutoApplyTimer.restart();
                            }
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // WIFI MANAGER MENU (NOTHING OS DOT-MATRIX STYLE)
        // -----------------------------------------------------------------
        Item {
            id: wifiMenuContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            width: parent.width - root.shoulder * 2 - 12
            height: parent.height - 8

            opacity: (root.showWifiMenu && !root.showDisplayMenu) ? 1.0 : 0.0
            scale: (root.showWifiMenu && !root.showDisplayMenu) ? 1.0 : 0.94
            visible: root.showWifiMenu && !root.showDisplayMenu

            Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            // 1. Header: Red Dot + "WIFI" + Status + Rescan + Radio Toggle + Close
            Item {
                id: wifiHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: "#D71921"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "WIFI"
                        font.family: fontNMono.name || "monospace"
                        font.pixelSize: 11
                        font.letterSpacing: 1.4
                        font.bold: true
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.isScanningWifi ? "· SCANNING..." : (root.isWifiConnected ? ("· " + root.wifiData.active_ssid) : "· DISCONNECTED")
                        font.family: fontNMono.name || "monospace"
                        font.pixelSize: 9
                        font.letterSpacing: 0.6
                        color: root.isWifiConnected ? "#88FF88" : "#777777"
                        elide: Text.ElideRight
                        width: 130
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Rescan Button
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: rescanMa.containsMouse ? "#2A2A2A" : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: Qt.resolvedUrl("../assets/refresh-dot.svg")
                            sourceSize: Qt.size(28, 28)
                        }

                        MouseArea {
                            id: rescanMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.queryWifi()
                        }
                    }

                    // Radio Toggle Switch
                    Rectangle {
                        width: 38
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: (root.wifiData && root.wifiData.wifi_enabled) ? "#222222" : "#181818"
                        border.color: (root.wifiData && root.wifiData.wifi_enabled) ? "#444444" : "#333333"
                        border.width: 1

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.wifiData && root.wifiData.wifi_enabled) ? 22 : 4
                            color: (root.wifiData && root.wifiData.wifi_enabled) ? "#FFFFFF" : "#555555"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleWifiRadio()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: closeWifiMa.containsMouse ? "#333333" : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: "#888888"
                        }

                        MouseArea {
                            id: closeWifiMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeWifiMenu()
                        }
                    }
                }
            }

            // Separator Line
            Rectangle {
                id: wifiSep
                anchors.top: wifiHeader.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#1F1F1F"
            }

            // 2. Network List (ListView)
            ListView {
                id: wifiListView
                anchors.top: wifiSep.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: wifiFooter.top
                anchors.bottomMargin: 8
                clip: true
                spacing: 3
                model: root.wifiNetworks

                delegate: Rectangle {
                    id: netItem
                    width: wifiListView.width
                    height: (root.passwordPromptSsid === modelData.ssid) ? 66 : 34
                    radius: 6
                    color: netMouse.containsMouse ? "#1E1E1E" : "#121212"
                    border.color: modelData.is_connected ? "#333333" : (netMouse.containsMouse ? "#2A2A2A" : "transparent")
                    border.width: 1

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Row when not prompting password
                    Item {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 34

                        // Left: Indicator + SSID
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: modelData.is_connected ? "#D71921" : (modelData.is_saved ? "#888888" : "transparent")
                                border.color: modelData.is_connected ? "#D71921" : (modelData.is_saved ? "#888888" : "#444444")
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.ssid
                                font.family: fontNType.name || "Fira Sans"
                                font.pixelSize: 11
                                font.bold: modelData.is_connected
                                color: modelData.is_connected ? "#FFFFFF" : (netMouse.containsMouse ? "#FFFFFF" : "#CCCCCC")
                                elide: Text.ElideRight
                                width: 175
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Right: Sinyal Dot-Matrix + Lock Icon
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Lock Icon (if secured)
                            Image {
                                width: 12
                                height: 12
                                source: Qt.resolvedUrl("../assets/lock-dot.svg")
                                sourceSize: Qt.size(24, 24)
                                visible: modelData.is_locked
                                opacity: 0.7
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Nothing OS Dot-Matrix Signal Bar (4 discrete vertical dot columns)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2.5

                                Rectangle {
                                    width: 2.5
                                    height: 4
                                    radius: 1
                                    color: (modelData.bars >= 1) ? "#FFFFFF" : "#333333"
                                    anchors.bottom: parent.bottom
                                }
                                Rectangle {
                                    width: 2.5
                                    height: 7
                                    radius: 1
                                    color: (modelData.bars >= 2) ? "#FFFFFF" : "#333333"
                                    anchors.bottom: parent.bottom
                                }
                                Rectangle {
                                    width: 2.5
                                    height: 10
                                    radius: 1
                                    color: (modelData.bars >= 3) ? "#FFFFFF" : "#333333"
                                    anchors.bottom: parent.bottom
                                }
                                Rectangle {
                                    width: 2.5
                                    height: 13
                                    radius: 1
                                    color: (modelData.bars >= 4) ? "#FFFFFF" : "#333333"
                                    anchors.bottom: parent.bottom
                                }
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.is_connected) {
                                    root.disconnectCurrent();
                                } else if (modelData.is_saved || !modelData.is_locked) {
                                    root.connectToNetwork(modelData.ssid, "");
                                } else {
                                    root.passwordPromptSsid = (root.passwordPromptSsid === modelData.ssid) ? "" : modelData.ssid;
                                    root.enteredPassword = "";
                                }
                            }
                        }
                    }

                    // Inline Password Input Drawer
                    Item {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 30
                        visible: root.passwordPromptSsid === modelData.ssid

                        Row {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 6

                            Rectangle {
                                width: parent.width - 68
                                height: parent.height
                                radius: 4
                                color: "#000000"
                                border.color: pwdInput.activeFocus ? "#D71921" : "#444444"
                                border.width: 1

                                TextInput {
                                    id: pwdInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: fontNMono.name || "monospace"
                                    font.pixelSize: 10
                                    color: "#FFFFFF"
                                    echoMode: TextInput.Password
                                    focus: root.passwordPromptSsid === modelData.ssid
                                    onTextChanged: root.enteredPassword = text
                                    onAccepted: {
                                        root.connectToNetwork(modelData.ssid, text);
                                    }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "ENTER PASSWORD..."
                                        font.family: fontNMono.name || "monospace"
                                        font.pixelSize: 9
                                        color: "#555555"
                                        visible: !pwdInput.text
                                    }
                                }
                            }

                            Rectangle {
                                width: 56
                                height: parent.height
                                radius: 4
                                color: "#D71921"

                                Text {
                                    anchors.centerIn: parent
                                    text: "CONNECT"
                                    font.family: fontNMono.name || "monospace"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: "#FFFFFF"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.connectToNetwork(modelData.ssid, root.enteredPassword)
                                }
                            }
                        }
                    }
                }
            }

            // 3. Footer: Shortcuts & status hint
            Item {
                id: wifiFooter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.wifiData && root.wifiData.active_ip) ? ("IP: " + root.wifiData.active_ip) : "NO INTERNET"
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 9
                    color: "#666666"
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "[SUPER+W] TOGGLE"
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 9
                    color: "#666666"
                }
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
