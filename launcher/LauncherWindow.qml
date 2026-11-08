import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// =============================================================================
// Dot-Matrix Chameleon Frosted Glass Application & Project Launcher
// Shortcut: Ctrl + Super + Enter
// Unified Search (Option B): Search Apps & Project Folders (opens in Antigravity IDE)
// 2D Grid Navigation: Left / Right / Up / Down arrow keys + Enter to launch
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:launcher"
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

    readonly property int modalW: 668
    readonly property int modalH: 512
    readonly property int gridCols: 5

    property var allItems: []
    property string searchQuery: ""
    property string filterMode: "all" // "all", "app", "folder"
    property int selectedIndex: 0

    // Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: {
            if (root.isOpen) {
                root.close();
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
                searchInput.forceActiveFocus();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: root.close()
    }

    Shortcut {
        sequence: "Ctrl+Meta+Return"
        enabled: root.isOpen
        onActivated: root.close()
    }

    // Load apps & project folders from launcher/apps.py
    Process {
        id: loadAppsProc
        command: ["python3", Quickshell.shellDir + "/launcher/apps.py", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = this.text.trim();
                    if (raw) {
                        root.allItems = JSON.parse(raw);
                    }
                } catch (e) {}
            }
        }
    }

    function refreshItems(): void {
        if (!loadAppsProc.running) {
            loadAppsProc.running = true;
        }
    }

    // Unified Smart Filter & Ranking (Option B: Apps + Antigravity IDE Folders)
    readonly property var filteredItems: {
        var q = (root.searchQuery || "").trim().toLowerCase();
        var mode = root.filterMode;
        var src = root.allItems || [];
        var matches = [];

        for (var i = 0; i < src.length; i++) {
            var it = src[i];
            if (mode !== "all" && it.type !== mode) continue;

            if (!q) {
                matches.push({ item: it, score: (it.type === "app" ? 0 : 50) + (it.priority || 50) });
            } else {
                var nameLow = (it.name || "").toLowerCase();
                var fullLow = (it.fullName || "").toLowerCase();
                var keyLow  = (it.searchKey || "").toLowerCase();

                var sc = -1;
                if (nameLow === q) sc = 0;
                else if (nameLow.indexOf(q) === 0) sc = 10 + (it.type === "folder" ? 2 : 0);
                else if (fullLow.indexOf(q) === 0) sc = 20;
                else if (nameLow.indexOf(q) !== -1) sc = 30;
                else if (fullLow.indexOf(q) !== -1) sc = 40;
                else if (keyLow.indexOf(q) !== -1) sc = 60;

                if (sc >= 0) {
                    matches.push({ item: it, score: sc });
                }
            }
        }

        matches.sort(function(a, b) {
            if (a.score !== b.score) return a.score - b.score;
            return (a.item.name || "").localeCompare(b.item.name || "");
        });

        var out = [];
        for (var j = 0; j < matches.length; j++) {
            out.push(matches[j].item);
        }
        return out;
    }

    onFilteredItemsChanged: {
        root.selectedIndex = 0;
        if (gridView.count > 0) {
            gridView.positionViewAtBeginning();
        }
    }

    function moveSelection(delta: int): void {
        var count = root.filteredItems.length;
        if (count <= 0) return;
        var next = root.selectedIndex + delta;
        if (next < 0) next = 0;
        if (next >= count) next = count - 1;
        root.selectedIndex = next;
        gridView.positionViewAtIndex(next, GridView.Contain);
    }

    function launchSelected(): void {
        var list = root.filteredItems;
        if (!list || list.length === 0) return;
        var idx = Math.max(0, Math.min(root.selectedIndex, list.length - 1));
        launchItem(list[idx]);
    }

    function launchItem(it): void {
        if (!it) return;
        if (it.type === "folder") {
            Quickshell.execDetached([
                "python3",
                Quickshell.shellDir + "/launcher/apps.py",
                "open-folder",
                it.path
            ]);
        } else {
            Quickshell.execDetached([
                "python3",
                Quickshell.shellDir + "/launcher/apps.py",
                "run-app",
                it.exec
            ]);
        }
        root.close();
    }

    function cycleFilterMode(): void {
        if (root.filterMode === "all") root.filterMode = "app";
        else if (root.filterMode === "app") root.filterMode = "folder";
        else root.filterMode = "all";
    }

    function open(): void {
        root.refreshItems();
        root.searchQuery = "";
        root.filterMode = "all";
        root.selectedIndex = 0;
        searchInput.text = "";
        root.showWindow = true;
        root.isOpen = true;
        grabDelayTimer.restart();
    }

    function close(): void {
        focusGrab.active = false;
        root.isOpen = false;
        if (!fadeAnim.running) {
            root.showWindow = false;
        }
    }

    function toggle(): void {
        if (root.isOpen) root.close();
        else root.open();
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    // Backdrop Scrim (click outside to close)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: root.close()
    }

    // =========================================================================
    // Center Chameleon Frosted Glass Launcher Modal
    // =========================================================================
    Item {
        id: modalContainer
        width: root.modalW
        height: root.modalH
        anchors.centerIn: parent

        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.94

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim
                duration: 220
                easing.type: Easing.OutQuint
                onRunningChanged: {
                    if (!running && !root.isOpen) {
                        root.showWindow = false;
                    }
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutQuint
            }
        }

        // Prevent clicks inside card from closing the modal
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                searchInput.forceActiveFocus();
            }
        }

        // Frosted Glass Card Surface
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: 26
            color: Qt.rgba(0.06, 0.07, 0.09, 0.62)
            border.width: 1
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)

            // Subtle Top Rim Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 26
                anchors.rightMargin: 26
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.24)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            // =================================================================
            // 1. TOP SEARCH CAPSULE + UNIFIED FILTER PILLS
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 26
                color: Qt.rgba(0.03, 0.04, 0.05, 0.68)
                border.width: 1
                border.color: searchInput.activeFocus
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.28)
                    : Qt.rgba(1.0, 1.0, 1.0, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12
                    spacing: 12

                    // Dot-Matrix Search Icon
                    Image {
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("../assets/search-dot.svg")
                        sourceSize: Qt.size(20, 20)
                        opacity: 0.85
                    }

                    // Search Input Field
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "SEARCH APPS OR IDE FOLDERS..."
                            visible: searchInput.text.length === 0
                            font.family: fontNMono.name || "monospace"
                            font.pixelSize: 12
                            font.letterSpacing: 1.1
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.42)
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#FFFFFF"
                            selectionColor: "#FF3B30"
                            selectedTextColor: "#FFFFFF"
                            font.family: fontNMono.name || "monospace"
                            font.pixelSize: 13
                            clip: true
                            focus: true

                            onTextChanged: {
                                root.searchQuery = text;
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    root.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launchSelected();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right) {
                                    root.moveSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left) {
                                    root.moveSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.moveSelection(root.gridCols);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.moveSelection(-root.gridCols);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    root.cycleFilterMode();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.MetaModifier)) {
                                    root.close();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Filter Mode Pills: [ ALL ] [ APPS ] [ FOLDERS ]
                    Row {
                        spacing: 6

                        Repeater {
                            model: [
                                { key: "all", label: "ALL" },
                                { key: "app", label: "APPS" },
                                { key: "folder", label: "FOLDERS" }
                            ]

                            delegate: Rectangle {
                                readonly property bool active: root.filterMode === modelData.key
                                width: pillText.implicitWidth + 18
                                height: 28
                                radius: 14
                                color: active
                                    ? Qt.rgba(1.0, 1.0, 1.0, 0.92)
                                    : (pillMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(1.0, 1.0, 1.0, 0.06))

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: fontNMono.name || "monospace"
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.8
                                    color: parent.active ? "#0D0F12" : Qt.rgba(1.0, 1.0, 1.0, 0.72)
                                }

                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.filterMode = modelData.key;
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 2. 2D ICON MATRIX GRID (5 COLUMNS · 4-DIRECTION ARROW NAVIGATION)
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: gridView
                    anchors.fill: parent
                    cellWidth: Math.floor(width / root.gridCols)
                    cellHeight: 112
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.selectedIndex
                    model: root.filteredItems

                    delegate: Item {
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property bool isFolder: modelData.type === "folder"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 18
                            color: parent.isSelected
                                ? Qt.rgba(1.0, 1.0, 1.0, 0.16)
                                : (cellMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.08) : Qt.rgba(1.0, 1.0, 1.0, 0.02))
                            border.width: parent.isSelected ? 1 : 0
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.34)

                            scale: cellMouse.pressed ? 0.95 : (parent.isSelected ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 14
                                spacing: 7

                                // App / Folder Icon Container (46x46)
                                Item {
                                    width: 46
                                    height: 46
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Image {
                                        id: itemIcon
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: status === Image.Ready
                                    }

                                    // Fallback Dot-Matrix Monogram when an app has no icon
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                        visible: itemIcon.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: (modelData.name || "?").slice(0, 2).toUpperCase()
                                            font.family: fontNdot57.name || "monospace"
                                            font.pixelSize: 18
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // IDE Badge for Project Folders
                                    Rectangle {
                                        visible: isFolder
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.rightMargin: -4
                                        anchors.bottomMargin: -2
                                        width: 24
                                        height: 13
                                        radius: 6
                                        color: "#D71921"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "IDE"
                                            font.family: fontNMono.name || "monospace"
                                            font.pixelSize: 7
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }
                                }

                                // Short Name
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.name || ""
                                    font.family: fontNType.name || "sans-serif"
                                    font.pixelSize: 12
                                    color: parent.parent.parent.isSelected
                                        ? "#FFFFFF"
                                        : Qt.rgba(1.0, 1.0, 1.0, 0.86)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // Subtitle Tag (APP vs IDE · FOLDER)
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: isFolder ? "ANTIGRAVITY" : "APP"
                                    font.family: fontNMono.name || "monospace"
                                    font.pixelSize: 8
                                    font.letterSpacing: 0.8
                                    color: isFolder
                                        ? Qt.rgba(1.0, 0.45, 0.42, 0.90)
                                        : Qt.rgba(1.0, 1.0, 1.0, 0.40)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    root.selectedIndex = index;
                                }
                                onClicked: {
                                    root.selectedIndex = index;
                                    root.launchItem(modelData);
                                }
                            }
                        }
                    }
                }

                // Empty State
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.filteredItems.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "[ NO MATCHING APPS OR FOLDERS ]"
                        font.family: fontNdot57.name || "monospace"
                        font.pixelSize: 18
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.65)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "TRY ANOTHER KEYWORD OR PRESS TAB TO SWITCH FILTER"
                        font.family: fontNMono.name || "monospace"
                        font.pixelSize: 10
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.40)
                    }
                }
            }

            // =================================================================
            // 3. BOTTOM NAVIGATION HINT BAR
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                Text {
                    text: {
                        var list = root.filteredItems;
                        if (!list || list.length === 0) return "0 ITEMS";
                        var cur = list[Math.max(0, Math.min(root.selectedIndex, list.length - 1))];
                        if (!cur) return list.length + " ITEMS";
                        if (cur.type === "folder") {
                            return "OPEN IN ANTIGRAVITY IDE  ·  " + cur.fullName;
                        }
                        return "LAUNCH APP  ·  " + cur.fullName.toUpperCase();
                    }
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 10
                    font.letterSpacing: 0.7
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.55)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "[←↑↓→] NAVIGATE   [TAB] FILTER   [ENTER] OPEN   [ESC] CLOSE"
                    font.family: fontNMono.name || "monospace"
                    font.pixelSize: 9
                    font.letterSpacing: 0.7
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.38)
                }
            }
        }
    }
}
