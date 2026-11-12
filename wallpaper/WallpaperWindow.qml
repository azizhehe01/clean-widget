import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// =============================================================================
// Nothing OS 3.0 / glyph-shell Native Wallpaper Carousel
// Shortcut: Ctrl + Super + W (Toggle Selector) | Super + Shift + W (Random)
// Bottom-edge Horizontal Filmstrip with 60fps Live Instant Desktop Preview
// =============================================================================
PanelWindow {
    id: root

    // Reference to DesktopWidgetsWindow to refresh frosted glass blur on apply
    property var desktopWidgetsRef: null

    WlrLayershell.namespace: "quickshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showWindow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: WlrLayershell.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    property bool isOpen: false
    property bool showWindow: false
    visible: showWindow

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080
    readonly property int dockW: Math.min(root.screenW - 72, 1240)
    readonly property int dockH: 226

    property var wallpapers: []
    property string folderPath: "~/.config/quickshell/DesktopWidgetsApp/wallpapers"
    property string originalWallpaper: ""
    property string previewedWallpaper: ""
    property int selectedIndex: 0

    readonly property var currentSelectedObj: (root.wallpapers && root.wallpapers.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.wallpapers.length)
        ? root.wallpapers[root.selectedIndex]
        : null

    readonly property bool isPreviewingNew: (root.currentSelectedObj && root.originalWallpaper !== "" && root.currentSelectedObj.path !== root.originalWallpaper)

    // Official Nothing OS Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // Theme Tokens — Chameleon Frosted Glass (High Transparency, Aligned with App Launcher)
    readonly property color glassBg: Qt.rgba(0.05, 0.06, 0.08, 0.30)
    readonly property color glassBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color nothingRed: "#D71921"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.72)
    readonly property color textMuted: Qt.rgba(1.0, 1.0, 1.0, 0.42)

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: {
            if (root.isOpen) {
                root.cancelAndClose();
            }
        }
    }

    Timer {
        id: grabDelayTimer
        interval: 40
        repeat: false
        onTriggered: {
            focusGrab.active = root.isOpen;
            if (root.isOpen) {
                keyCatcher.forceActiveFocus();
            }
        }
    }

    // Debounce timer for buttery-smooth Live Instant Preview when scrubbing with arrow keys
    Timer {
        id: previewDebounceTimer
        interval: 75
        repeat: false
        onTriggered: {
            if (!root.isOpen || !root.currentSelectedObj) return;
            var targetPath = root.currentSelectedObj.path;
            if (targetPath && targetPath !== root.previewedWallpaper) {
                root.previewedWallpaper = targetPath;
                Quickshell.execDetached([
                    "python3",
                    Quickshell.shellDir + "/wallpaper/wallpaper.py",
                    "preview",
                    targetPath
                ]);
            }
        }
    }

    // Delayed refresh of desktop widgets after applying new wallpaper
    Timer {
        id: refreshWidgetsTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.desktopWidgetsRef) {
                root.desktopWidgetsRef.refreshStats();
            }
        }
    }

    // Load wallpapers list from wallpaper/wallpaper.py
    Process {
        id: loadWallpapersProc
        command: ["python3", Quickshell.shellDir + "/wallpaper/wallpaper.py", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = this.text.trim();
                    if (!raw) return;
                    var data = JSON.parse(raw);
                    var list = data.wallpapers || [];
                    root.wallpapers = list;
                    if (data.folder) root.folderPath = data.folder;
                    if (data.current) {
                        root.originalWallpaper = data.current;
                        if (!root.previewedWallpaper) {
                            root.previewedWallpaper = data.current;
                        }
                    }

                    // Position selection on active wallpaper
                    var activeIdx = 0;
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].active || list[i].path === root.originalWallpaper) {
                            activeIdx = i;
                            root.originalWallpaper = list[i].path;
                            root.previewedWallpaper = list[i].path;
                            break;
                        }
                    }
                    root.selectedIndex = activeIdx;
                    centerTimer.restart();
                } catch (e) {}
            }
        }
    }

    Timer {
        id: centerTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (filmstripList.count > 0) {
                filmstripList.positionViewAtIndex(root.selectedIndex, ListView.Center);
            }
        }
    }

    // Process to commit wallpaper & update frosted glass blur
    Process {
        id: applyWallpaperProc
        property string targetPath: ""
        property bool alreadyPreviewed: false
        command: {
            var args = ["python3", Quickshell.shellDir + "/wallpaper/wallpaper.py", "apply", targetPath];
            if (alreadyPreviewed) args.push("--already-previewed");
            return args;
        }
        running: false
        onExited: (exitCode, exitStatus) => {
            if (root.desktopWidgetsRef) {
                root.desktopWidgetsRef.refreshStats();
            }
        }
    }

    // Process for random wallpaper shortcut (Super + Shift + W)
    Process {
        id: randomWallpaperProc
        command: ["python3", Quickshell.shellDir + "/wallpaper/wallpaper.py", "random"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (root.desktopWidgetsRef) {
                root.desktopWidgetsRef.refreshStats();
            }
            if (!loadWallpapersProc.running) {
                loadWallpapersProc.running = true;
            }
        }
    }

    function selectIndex(idx: int, triggerPreview: bool): void {
        var count = root.wallpapers ? root.wallpapers.length : 0;
        if (count <= 0) return;
        var clamped = idx;
        // Wrap around smoothly at ends
        if (clamped < 0) clamped = count - 1;
        if (clamped >= count) clamped = 0;

        root.selectedIndex = clamped;
        filmstripList.positionViewAtIndex(clamped, ListView.Center);
        if (triggerPreview) {
            previewDebounceTimer.restart();
        }
    }

    function moveSelection(delta: int): void {
        selectIndex(root.selectedIndex + delta, true);
    }

    function pickRandomPreview(): void {
        var count = root.wallpapers ? root.wallpapers.length : 0;
        if (count <= 1) return;
        var next = root.selectedIndex;
        for (var tries = 0; tries < 10; tries++) {
            var cand = Math.floor(Math.random() * count);
            if (cand !== root.selectedIndex) {
                next = cand;
                break;
            }
        }
        selectIndex(next, true);
    }

    function openWallpaperFolder(): void {
        Quickshell.execDetached([
            "python3",
            Quickshell.shellDir + "/wallpaper/wallpaper.py",
            "open-folder"
        ]);
    }

    function confirmSelection(): void {
        previewDebounceTimer.stop();
        if (!root.currentSelectedObj) {
            root.closeInternal();
            return;
        }
        var chosenPath = root.currentSelectedObj.path;
        var wasPreviewed = (root.previewedWallpaper === chosenPath);
        root.originalWallpaper = chosenPath;
        root.previewedWallpaper = chosenPath;

        applyWallpaperProc.targetPath = chosenPath;
        applyWallpaperProc.alreadyPreviewed = wasPreviewed;
        applyWallpaperProc.running = false;
        applyWallpaperProc.running = true;

        refreshWidgetsTimer.restart();
        root.closeInternal();
    }

    function cancelAndClose(): void {
        previewDebounceTimer.stop();
        // Revert to original wallpaper if Live Preview changed it
        if (root.originalWallpaper !== "" && root.previewedWallpaper !== "" && root.previewedWallpaper !== root.originalWallpaper) {
            root.previewedWallpaper = root.originalWallpaper;
            Quickshell.execDetached([
                "python3",
                Quickshell.shellDir + "/wallpaper/wallpaper.py",
                "preview",
                root.originalWallpaper
            ]);
        }
        root.closeInternal();
    }

    function open(): void {
        if (!loadWallpapersProc.running) {
            loadWallpapersProc.running = true;
        }
        root.showWindow = true;
        root.isOpen = true;
        grabDelayTimer.restart();
        centerTimer.restart();
    }

    function closeInternal(): void {
        focusGrab.active = false;
        root.isOpen = false;
        if (!dockAnim.running) {
            root.showWindow = false;
        }
    }

    function toggle(): void {
        if (root.isOpen) root.cancelAndClose();
        else root.open();
    }

    function triggerRandomDirect(): void {
        if (root.isOpen) {
            root.pickRandomPreview();
        } else {
            randomWallpaperProc.running = false;
            randomWallpaperProc.running = true;
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.cancelAndClose(); }
        function random(): void { root.triggerRandomDirect(); }
    }

    // Fullscreen invisible click-outside catcher (keeps desktop 100% clear for Live Preview)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: root.cancelAndClose()
    }

    // Keyboard navigation handler
    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                root.selectIndex(0, true);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                root.selectIndex(Math.max(0, root.wallpapers.length - 1), true);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.pickRandomPreview();
                event.accepted = true;
            } else if (event.key === Qt.Key_O) {
                root.openWallpaperFolder();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.confirmSelection();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelAndClose();
                event.accepted = true;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: root.cancelAndClose()
    }

    Shortcut {
        sequence: "Ctrl+Meta+W"
        enabled: root.isOpen
        onActivated: root.cancelAndClose()
    }

    // =========================================================================
    // Bottom-Edge Horizontal Filmstrip Drawer
    // =========================================================================
    Item {
        id: dockWrapper
        width: root.dockW
        height: root.dockH
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24

        opacity: root.isOpen ? 1.0 : 0.0
        transform: Translate {
            y: root.isOpen ? 0 : 260
            Behavior on y {
                NumberAnimation {
                    id: dockAnim
                    duration: 240
                    easing.type: Easing.OutCubic
                    onRunningChanged: {
                        if (!dockAnim.running && !root.isOpen) {
                            root.showWindow = false;
                        }
                    }
                }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Prevent clicks inside the dock from triggering the outside backdrop
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => { mouse.accepted = true; }
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                    root.moveSelection(-1);
                } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                    root.moveSelection(1);
                }
                wheel.accepted = true;
            }
        }

        // Main Frosted Obsidian Container (Aligned with Launcher & Sidebar)
        Rectangle {
            id: dockCard
            anchors.fill: parent
            radius: 26
            color: root.glassBg
            border.width: 1
            border.color: root.glassBorder
            clip: true

            // Top Specular Highlight Line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 26
                anchors.rightMargin: 26
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.24)
            }

            // Subtle Nothing OS Dot-Matrix Background Accent along header
            Canvas {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52
                opacity: 0.08
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#FFFFFF";
                    var step = 10;
                    for (var x = 14; x < width - 14; x += step) {
                        for (var y = 10; y < height; y += step) {
                            ctx.beginPath();
                            ctx.arc(x, y, 1.0, 0, Math.PI * 2);
                            ctx.fill();
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 10

                // =============================================================
                // Top Header Bar: Status, Title, Active Filename, Quick Actions
                // =============================================================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    spacing: 12

                    // Left: Recording-style LED dot + Dot-Matrix Title + Count
                    RowLayout {
                        spacing: 9

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: root.isPreviewingNew ? root.nothingRed : "#FFFFFF"

                            SequentialAnimation on opacity {
                                running: root.isOpen && root.isPreviewingNew
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 550; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0;  duration: 550; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            text: "WALLPAPER"
                            font.family: fontNdot57.name
                            font.pixelSize: 16
                            font.letterSpacing: 1.8
                            color: root.textPrimary
                        }

                        // Counter Pill [ 03 / 17 ]
                        Rectangle {
                            height: 22
                            width: countLabel.implicitWidth + 16
                            radius: 11
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: {
                                    var total = root.wallpapers ? root.wallpapers.length : 0;
                                    var cur = total > 0 ? (root.selectedIndex + 1) : 0;
                                    var curStr = cur < 10 ? ("0" + cur) : ("" + cur);
                                    var totStr = total < 10 ? ("0" + total) : ("" + total);
                                    return curStr + " / " + totStr;
                                }
                                font.family: fontNMono.name
                                font.pixelSize: 11
                                color: root.textSecondary
                            }
                        }

                        // Live Preview Indicator Badge
                        Rectangle {
                            visible: root.isPreviewingNew
                            height: 22
                            width: liveLabel.implicitWidth + 16
                            radius: 11
                            color: Qt.rgba(0.84, 0.10, 0.13, 0.22)
                            border.width: 1
                            border.color: root.nothingRed

                            Text {
                                id: liveLabel
                                anchors.centerIn: parent
                                text: "LIVE PREVIEW"
                                font.family: fontNMono.name
                                font.pixelSize: 10
                                font.letterSpacing: 0.8
                                color: "#FF5A60"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Center: Currently Selected Wallpaper Title & Resolution
                    RowLayout {
                        spacing: 8
                        visible: root.currentSelectedObj !== null

                        Text {
                            text: root.currentSelectedObj ? root.currentSelectedObj.title.toUpperCase() : ""
                            font.family: fontNType.name
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            color: root.textPrimary
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: 280
                        }

                        Rectangle {
                            visible: root.currentSelectedObj && root.currentSelectedObj.res !== ""
                            height: 20
                            width: resText.implicitWidth + 12
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.07)

                            Text {
                                id: resText
                                anchors.centerIn: parent
                                text: root.currentSelectedObj ? root.currentSelectedObj.res : ""
                                font.family: fontNMono.name
                                font.pixelSize: 10
                                color: root.textMuted
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Right: Interactive Action Pills & Key Hints
                    RowLayout {
                        spacing: 6

                        // [R] RANDOM Button
                        Rectangle {
                            height: 26
                            width: randRow.implicitWidth + 16
                            radius: 13
                            color: randMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)

                            RowLayout {
                                id: randRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "[R]"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: root.nothingRed
                                }
                                Text {
                                    text: "RANDOM"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: root.textSecondary
                                }
                            }

                            MouseArea {
                                id: randMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickRandomPreview()
                            }
                        }

                        // [O] FOLDER Button
                        Rectangle {
                            height: 26
                            width: folderRow.implicitWidth + 16
                            radius: 13
                            color: folderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)

                            RowLayout {
                                id: folderRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "[O]"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: root.textMuted
                                }
                                Text {
                                    text: "FOLDER"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: root.textSecondary
                                }
                            }

                            MouseArea {
                                id: folderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openWallpaperFolder()
                            }
                        }

                        // [↵] APPLY Primary Button (Nothing Red)
                        Rectangle {
                            height: 26
                            width: applyRow.implicitWidth + 18
                            radius: 13
                            color: applyMouse.containsMouse ? "#EA222A" : root.nothingRed

                            RowLayout {
                                id: applyRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "[↵]"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: "APPLY"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: applyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmSelection()
                            }
                        }

                        // [ESC] Close/Cancel Button
                        Rectangle {
                            height: 26
                            width: escRow.implicitWidth + 14
                            radius: 13
                            color: escMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.10)

                            RowLayout {
                                id: escRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "ESC"
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    color: root.textMuted
                                }
                            }

                            MouseArea {
                                id: escMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelAndClose()
                            }
                        }
                    }
                }

                // Hairline Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // =============================================================
                // Horizontal Wallpaper Filmstrip (ListView)
                // =============================================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Empty State if no wallpapers found
                    Item {
                        visible: !root.wallpapers || root.wallpapers.length === 0
                        anchors.fill: parent

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                text: "[!] NO WALLPAPERS FOUND IN FOLDER"
                                font.family: fontNMono.name
                                font.pixelSize: 12
                                font.letterSpacing: 1.0
                                color: root.textMuted
                            }

                            Rectangle {
                                height: 28
                                width: emptyBtnRow.implicitWidth + 20
                                radius: 14
                                color: emptyBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.20)

                                RowLayout {
                                    id: emptyBtnRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "[O]"
                                        font.family: fontNMono.name
                                        font.pixelSize: 11
                                        color: root.nothingRed
                                    }
                                    Text {
                                        text: "OPEN WALLPAPERS FOLDER"
                                        font.family: fontNMono.name
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                    }
                                }

                                MouseArea {
                                    id: emptyBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openWallpaperFolder()
                                }
                            }
                        }
                    }

                    ListView {
                        id: filmstripList
                        visible: root.wallpapers && root.wallpapers.length > 0
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 14
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 220

                        model: root.wallpapers

                        Behavior on contentX {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: cardSlot
                            width: 212
                            height: filmstripList.height

                            readonly property bool isSelected: (index === root.selectedIndex)
                            readonly property bool isOriginalActive: (modelData.path === root.originalWallpaper)

                            Item {
                                id: cardVisual
                                width: 198
                                height: 112
                                anchors.centerIn: parent

                                scale: cardSlot.isSelected ? 1.07 : (cardMouse.containsMouse ? 1.02 : 0.95)
                                opacity: cardSlot.isSelected ? 1.0 : (cardMouse.containsMouse ? 0.88 : 0.54)

                                Behavior on scale {
                                    NumberAnimation { duration: 190; easing.type: Easing.OutBack }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }

                                // Nothing Red Glow behind active selected card
                                RectangularGlow {
                                    visible: cardSlot.isSelected
                                    anchors.fill: thumbMaskContainer
                                    glowRadius: 14
                                    spread: 0.2
                                    color: Qt.rgba(0.843, 0.098, 0.129, 0.55)
                                    cornerRadius: 18
                                }

                                // Thumbnail Image Mask Container
                                Item {
                                    id: thumbMaskContainer
                                    anchors.fill: parent

                                    Rectangle {
                                        id: thumbMask
                                        anchors.fill: parent
                                        radius: 15
                                        visible: false
                                    }

                                    Image {
                                        id: thumbImg
                                        anchors.fill: parent
                                        source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                                        sourceSize: Qt.size(384, 216)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        visible: false
                                    }

                                    OpacityMask {
                                        anchors.fill: parent
                                        source: thumbImg
                                        maskSource: thumbMask
                                    }

                                    // Bottom Dark Gradient Scrim for Title Readability
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 44
                                        radius: 15
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                                        }
                                    }

                                    // Top-left Badge: [ ACTIVE ] for current desktop wallpaper
                                    Rectangle {
                                        visible: cardSlot.isOriginalActive
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.topMargin: 8
                                        anchors.leftMargin: 8
                                        height: 18
                                        width: activeBadgeText.implicitWidth + 12
                                        radius: 9
                                        color: Qt.rgba(0, 0, 0, 0.72)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.35)

                                        Text {
                                            id: activeBadgeText
                                            anchors.centerIn: parent
                                            text: "ACTIVE"
                                            font.family: fontNdot57.name
                                            font.pixelSize: 9
                                            font.letterSpacing: 1.0
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Top-right Index Number (#01)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 8
                                        anchors.rightMargin: 8
                                        height: 18
                                        width: idxBadgeText.implicitWidth + 10
                                        radius: 9
                                        color: cardSlot.isSelected ? root.nothingRed : Qt.rgba(0, 0, 0, 0.62)

                                        Text {
                                            id: idxBadgeText
                                            anchors.centerIn: parent
                                            text: (index + 1) < 10 ? ("0" + (index + 1)) : ("" + (index + 1))
                                            font.family: fontNMono.name
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Bottom Filename Caption
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.bottomMargin: 7
                                        text: modelData.title
                                        font.family: fontNMono.name
                                        font.pixelSize: 10
                                        color: cardSlot.isSelected ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.80)
                                        elide: Text.ElideRight
                                    }

                                    // Selection Border Frame
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: "transparent"
                                        border.width: cardSlot.isSelected ? 2.5 : 1
                                        border.color: cardSlot.isSelected
                                            ? root.nothingRed
                                            : (cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.14))
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (cardSlot.isSelected) {
                                            // Second click on already-previewed card applies & closes
                                            root.confirmSelection();
                                        } else {
                                            root.selectIndex(index, true);
                                        }
                                    }
                                    onDoubleClicked: {
                                        root.selectIndex(index, false);
                                        root.confirmSelection();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

