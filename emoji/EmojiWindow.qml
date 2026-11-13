import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// =============================================================================
// Nothing OS 3.0 / glyph-shell Native Emoji Picker Modal (Super + Ctrl + E)
// Fast Unicode search, category pills, dot-matrix styling, and instant auto-type
// directly into the active window via wtype + wl-copy.
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:emoji"
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

    readonly property int modalW: 540
    readonly property int modalH: 450

    property var allEmojis: []
    property var filteredEmojis: []
    property string searchQuery: ""
    property string activeCategory: "all" // all, smileys, gestures, animals, food, objects, symbols
    property int selectedIndex: 0
    property string hoveredEmojiName: ""

    // Official Nothing OS Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // Theme Tokens — Chameleon Frosted Glass (0.58 alpha matching launcher & clipboard)
    readonly property color glassBg: Qt.rgba(0.06, 0.07, 0.09, 0.58)
    readonly property color glassBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color nothingRed: "#D71921"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.72)
    readonly property color textMuted: Qt.rgba(1.0, 1.0, 1.0, 0.42)

    property bool wasFrozenByScreenshot: false

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
                        // Screenshot just finished: restore focus grab without closing
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
                // If screenshot tool is running or freeze flag exists, DO NOT close!
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

    // Process to load emojis once
    Process {
        id: loadProcess
        command: ["python3", Qt.resolvedUrl("emoji.py").toString().replace("file://", ""), "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.allEmojis = JSON.parse(data);
                    root.applyFilter();
                } catch (e) {
                    console.log("[EmojiPicker] JSON parse error:", e);
                }
            }
        }
    }

    // Process to paste selected emoji
    Process {
        id: pasteProcess
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    function open() {
        isOpen = true;
        showWindow = true;
        searchQuery = "";
        searchInput.text = "";
        activeCategory = "all";
        selectedIndex = 0;
        hoveredEmojiName = "";

        if (allEmojis.length === 0) {
            loadProcess.running = true;
        } else {
            applyFilter();
        }

        grabDelayTimer.restart();
    }

    function close() {
        focusGrab.active = false;
        isOpen = false;
        showWindow = false;
        searchQuery = "";
        searchInput.text = "";
    }

    function selectEmoji(emojiChar, emojiName) {
        if (!emojiChar) return;
        
        // Close modal first so focus returns to the underlying application
        close();

        // Trigger python background worker: wl-copy + dual paste mechanism
        var pyPath = Qt.resolvedUrl("emoji.py").toString().replace("file://", "");
        pasteProcess.command = ["python3", pyPath, "paste", emojiChar];
        pasteProcess.running = true;
    }

    function applyFilter() {
        var q = searchQuery.toLowerCase().trim();
        var cat = activeCategory;

        var res = [];
        for (var i = 0; i < allEmojis.length; i++) {
            var item = allEmojis[i];
            if (cat !== "all" && item.c !== cat) {
                continue;
            }
            if (q.length > 0) {
                var matchName = item.n && item.n.toLowerCase().indexOf(q) !== -1;
                var matchKey = item.k && item.k.toLowerCase().indexOf(q) !== -1;
                if (!matchName && !matchKey) {
                    continue;
                }
            }
            res.push(item);
        }
        filteredEmojis = res;
        selectedIndex = 0;
        if (filteredEmojis.length > 0) {
            hoveredEmojiName = filteredEmojis[0].n;
        } else {
            hoveredEmojiName = "";
        }
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: root.close()
    }

    // =========================================================================
    // Center Floating Glass Modal
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

        // Catch clicks inside modal
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
            // Header Bar
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Red Status Dot
                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.nothingRed
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "EMOJI PICKER"
                    font.family: fontNdot55.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: root.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Count badge
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
                        text: root.filteredEmojis.length + " ITEMS"
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
                        text: "🔍"
                        font.pixelSize: 13
                        opacity: 0.7
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
                            text: "Type to search emojis (e.g. fire, smile, heart)..."
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
                            var cols = 8;
                            if (root.selectedIndex + cols < root.filteredEmojis.length) {
                                root.selectedIndex += cols;
                                emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                                root.hoveredEmojiName = root.filteredEmojis[root.selectedIndex].n;
                            }
                        }

                        Keys.onUpPressed: {
                            var cols = 8;
                            if (root.selectedIndex - cols >= 0) {
                                root.selectedIndex -= cols;
                                emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                                root.hoveredEmojiName = root.filteredEmojis[root.selectedIndex].n;
                            }
                        }

                        Keys.onRightPressed: {
                            if (root.selectedIndex < root.filteredEmojis.length - 1) {
                                root.selectedIndex += 1;
                                emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                                root.hoveredEmojiName = root.filteredEmojis[root.selectedIndex].n;
                            }
                        }

                        Keys.onLeftPressed: {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex -= 1;
                                emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                                root.hoveredEmojiName = root.filteredEmojis[root.selectedIndex].n;
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.filteredEmojis.length > 0 && root.selectedIndex < root.filteredEmojis.length) {
                                var item = root.filteredEmojis[root.selectedIndex];
                                root.selectEmoji(item.e, item.n);
                            }
                        }
                    }

                    // Clear button
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
                    { id: "smileys", label: "😊 Faces" },
                    { id: "gestures", label: "👍 Hands" },
                    { id: "animals", label: "🐱 Nature" },
                    { id: "food", label: "🍕 Food" },
                    { id: "objects", label: "💡 Objects" },
                    { id: "symbols", label: "❤️ Symbols" }
                ]

                Repeater {
                    model: parent.categories
                    delegate: Rectangle {
                        readonly property bool isActive: root.activeCategory === modelData.id
                        height: 24
                        width: catText.implicitWidth + 14
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
            // Emoji Grid View
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                GridView {
                    id: emojiGrid
                    anchors.fill: parent
                    cellWidth: width / 8
                    cellHeight: 46
                    model: root.filteredEmojis
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }

                    delegate: Item {
                        width: emojiGrid.cellWidth
                        height: emojiGrid.cellHeight

                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property bool isHovered: cellArea.containsMouse

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 6
                            height: parent.height - 6
                            radius: 10
                            color: isSelected ? Qt.rgba(1, 1, 1, 0.22) : (isHovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                            border.color: isSelected ? root.nothingRed : (isHovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
                            border.width: isSelected ? 1.5 : 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.e
                                font.pixelSize: 22
                            }
                        }

                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.hoveredEmojiName = modelData.n;
                                root.selectedIndex = index;
                            }
                            onClicked: {
                                root.selectEmoji(modelData.e, modelData.n);
                            }
                        }
                    }
                }

                // Empty State
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.filteredEmojis.length === 0

                    Text {
                        text: "👻"
                        font.pixelSize: 32
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "NO EMOJIS FOUND"
                        font.family: fontNdot55.name
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        color: root.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // =================================================================
            // Bottom Status / Tooltip Bar
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                height: 24
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        text: root.hoveredEmojiName ? root.hoveredEmojiName.toUpperCase() : "CLICK OR ENTER TO PASTE INSTANTLY"
                        font.family: fontNMono.name
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: root.hoveredEmojiName ? root.textSecondary : root.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "AUTO-PASTE ACTIVE"
                        font.family: fontNdot55.name
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: Qt.rgba(0.2, 0.9, 0.4, 0.8)
                    }
                }
            }
        }
    }
}
