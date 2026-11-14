import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// =============================================================================
// Nothing OS 3.0 / glyph-shell Native Keybindings Viewer (Super + Ctrl + K)
// Dynamic Hyprland keybind cheat sheet with real-time search, category pills,
// keycap badges, and screenshot-safe focus handling.
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:keybinds"
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

    readonly property int modalW: 680
    readonly property int modalH: 540

    property var allBinds: []
    property var filteredBinds: []
    property string searchQuery: ""
    property string activeCategory: "all" // all, shell, windows, workspaces, media
    property int selectedIndex: 0
    property bool wasFrozenByScreenshot: false

    // Official Nothing OS Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // Theme Tokens — Chameleon Frosted Glass (Harmonized with Launcher, Clipboard, Emoji)
    readonly property color glassBg: Qt.rgba(0.06, 0.07, 0.09, 0.58)
    readonly property color glassBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color nothingRed: "#D71921"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.72)
    readonly property color textMuted: Qt.rgba(1.0, 1.0, 1.0, 0.42)

    // Check if screenshot tool (slurp/grim) is currently active to prevent auto-close
    Process {
        id: checkFreezeProc
        command: ["python3", "-c", "import os, subprocess; print(os.path.exists('/tmp/glyph_freeze_dismiss') or subprocess.run(['pgrep', '-x', 'slurp'], capture_output=True).returncode == 0)"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var isFrozen = data.trim() === "True";
                if (isFrozen && root.isOpen) {
                    root.wasFrozenByScreenshot = true;
                    recheckTimer.restart();
                } else if (!isFrozen && root.isOpen) {
                    if (root.wasFrozenByScreenshot) {
                        root.wasFrozenByScreenshot = false;
                        focusGrab.active = true;
                        searchInput.forceActiveFocus();
                    } else {
                        root.close();
                    }
                }
            }
        }
    }

    Timer {
        id: recheckTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                checkFreezeProc.running = true;
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: {
            if (root.isOpen) {
                checkFreezeProc.running = true;
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

    Process {
        id: loadProcess
        command: ["python3", Qt.resolvedUrl("keybinds.py").toString().replace("file://", "")]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.allBinds = JSON.parse(data);
                    root.applyFilter();
                } catch (e) {
                    console.log("[Keybinds] JSON parse error:", e);
                }
            }
        }
    }

    function toggle(): void {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    function open(): void {
        isOpen = true;
        showWindow = true;
        wasFrozenByScreenshot = false;
        searchQuery = "";
        searchInput.text = "";
        activeCategory = "all";
        selectedIndex = 0;

        // Refresh dynamically from hyprctl binds -j each time opened
        loadProcess.running = false;
        loadProcess.running = true;

        grabDelayTimer.restart();
    }

    function close(): void {
        focusGrab.active = false;
        wasFrozenByScreenshot = false;
        isOpen = false;
        showWindow = false;
        searchQuery = "";
        searchInput.text = "";
    }

    function applyFilter(): void {
        var q = searchQuery.toLowerCase().trim();
        var cat = activeCategory;
        var res = [];

        var tokens = q.length > 0 ? q.split(/[\s+]+/).filter(function(t) { return t.length > 0; }) : [];

        for (var i = 0; i < allBinds.length; i++) {
            var item = allBinds[i];
            if (cat !== "all" && item.cat !== cat) {
                continue;
            }
            if (tokens.length > 0) {
                var descL = (item.search_desc || item.desc || "").toLowerCase();
                var comboL = (item.combo || "").toLowerCase();
                var keysArr = (item.search_keys || item.keys || []).map(function(k) { return k.toLowerCase(); });

                // Match if all tokens appear in desc, OR all tokens appear in combo/keys
                var allInDesc = true;
                var allInCombo = true;
                for (var t = 0; t < tokens.length; t++) {
                    var tok = tokens[t];
                    if (descL.indexOf(tok) === -1) {
                        allInDesc = false;
                    }
                    var inKeys = false;
                    for (var k = 0; k < keysArr.length; k++) {
                        // Exact key match for 1-char keys (e.g. 'v' shouldn't match 'vol +') or substring for longer tokens
                        if (tok.length === 1 ? keysArr[k] === tok : keysArr[k].indexOf(tok) !== -1) {
                            inKeys = true;
                            break;
                        }
                    }
                    if (!inKeys) {
                        allInCombo = false;
                    }
                }
                if (!allInDesc && !allInCombo) {
                    continue;
                }
            }
            res.push(item);
        }

        filteredBinds = res;
        selectedIndex = 0;
        if (bindsList.count > 0) {
            bindsList.positionViewAtBeginning();
        }
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: root.close()
    }

    // =========================================================================
    // Center Floating Frosted Glass Modal
    // =========================================================================
    Rectangle {
        id: modal
        width: root.modalW
        height: root.modalH
        anchors.centerIn: parent
        radius: 24
        color: root.glassBg
        border.color: root.glassBorder
        border.width: 1
        clip: true

        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: {}
        }

        // Top Subtle Highlight Bar
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 48
            height: 1
            color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // =================================================================
            // Header Bar (Minimalist Hyprland style — no X button)
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.nothingRed
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "KEYBINDINGS"
                    font.family: fontNdot55.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: root.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 22
                    width: countText.implicitWidth + 20
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.filteredBinds.length + " BINDS"
                        font.family: fontNType.name
                        font.pixelSize: 11
                        font.letterSpacing: 0.5
                        color: root.textSecondary
                    }
                }
            }

            // =================================================================
            // Search Input Box
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: searchInput.activeFocus ? root.nothingRed : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "⌘"
                        font.pixelSize: 14
                        color: root.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: fontNType.name
                        font.pixelSize: 13
                        color: root.textPrimary
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search shortcut or key (e.g. emoji, float, ctrl, tab)..."
                            font.family: fontNType.name
                            font.pixelSize: 13
                            color: root.textMuted
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.applyFilter();
                        }

                        Keys.onEscapePressed: root.close()

                        Keys.onDownPressed: {
                            if (root.selectedIndex < root.filteredBinds.length - 1) {
                                root.selectedIndex += 1;
                                bindsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }

                        Keys.onUpPressed: {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex -= 1;
                                bindsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }
                    }

                    Text {
                        text: "✕"
                        font.pixelSize: 11
                        color: root.textMuted
                        visible: searchInput.text.length > 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // =================================================================
            // Category Filter Pills
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                property var categories: [
                    { id: "all", label: "All" },
                    { id: "shell", label: "Shell" },
                    { id: "windows", label: "Windows" },
                    { id: "workspaces", label: "Workspaces" },
                    { id: "media", label: "Media & Tools" }
                ]

                Repeater {
                    model: parent.categories
                    delegate: Rectangle {
                        readonly property bool isActive: root.activeCategory === modelData.id
                        height: 24
                        width: catText.implicitWidth + 16
                        radius: 12
                        color: isActive ? Qt.rgba(1, 1, 1, 0.20) : (catArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.color: isActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: fontNType.name
                            font.pixelSize: 11
                            color: isActive ? root.textPrimary : root.textSecondary
                        }

                        MouseArea {
                            id: catArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCategory = modelData.id;
                                root.applyFilter();
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // =================================================================
            // Keybindings List View
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: bindsList
                    anchors.fill: parent
                    spacing: 5
                    model: root.filteredBinds
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }

                    delegate: Rectangle {
                        width: bindsList.width - 8
                        height: 44
                        radius: 12

                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property bool isHovered: rowArea.containsMouse

                        color: isSelected
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : (isHovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                        border.color: isSelected
                            ? Qt.rgba(1, 1, 1, 0.28)
                            : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = index
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12

                            // Action Description
                            Text {
                                Layout.fillWidth: true
                                text: modelData.desc
                                font.family: fontNType.name
                                font.pixelSize: 13
                                color: root.textPrimary
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Keycap Badges
                            Row {
                                spacing: 5
                                Layout.alignment: Qt.AlignVCenter

                                Repeater {
                                    model: modelData.keys
                                    delegate: Rectangle {
                                        height: 24
                                        width: Math.max(26, keyLabel.implicitWidth + 14)
                                        radius: 7
                                        color: modelData === "SUPER"
                                            ? Qt.rgba(0.84, 0.10, 0.13, 0.24)
                                            : Qt.rgba(1, 1, 1, 0.10)
                                        border.color: modelData === "SUPER"
                                            ? Qt.rgba(0.84, 0.10, 0.13, 0.55)
                                            : Qt.rgba(1, 1, 1, 0.18)
                                        border.width: 1

                                        Text {
                                            id: keyLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.family: fontNMono.name
                                            font.pixelSize: 10
                                            font.letterSpacing: 0.5
                                            color: root.textPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty State
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.filteredBinds.length === 0

                    Text {
                        text: "⌘"
                        font.pixelSize: 28
                        color: root.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "NO SHORTCUTS FOUND"
                        font.family: fontNdot55.name
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        color: root.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // =================================================================
            // Bottom Status Bar
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "ESC OR CLICK OUTSIDE TO CLOSE"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: root.textMuted
                    Layout.fillWidth: true
                }

                Text {
                    text: "LIVE HYPRLAND BINDS"
                    font.family: fontNdot55.name
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }
    }
}
