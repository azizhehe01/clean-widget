import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// =============================================================================
// Nothing OS 3.0 / glyph-shell Native Clipboard History Modal (Super + V)
// High-performance real-time search, image thumbnail previews, code detection,
// and pure Wayland cliphist integration.
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:clipboard"
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

    readonly property int modalW: 648
    readonly property int modalH: 540

    property var allItems: []
    property string searchQuery: ""
    property string filterType: "all" // "all", "text", "code", "image", "url"
    property int selectedIndex: 0

    // Official Nothing OS Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // Theme Tokens — Chameleon Frosted Glass (Harmonized with Launcher & Sidebar)
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

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: root.close()
    }

    Shortcut {
        sequence: "Meta+V"
        enabled: root.isOpen
        onActivated: root.close()
    }

    // Load clipboard entries from clipboard/clipboard.py
    Process {
        id: loadClipboardProc
        command: ["python3", Quickshell.shellDir + "/clipboard/clipboard.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = this.text.trim();
                    if (raw) {
                        root.allItems = JSON.parse(raw) || [];
                    } else {
                        root.allItems = [];
                    }
                } catch (e) {
                    root.allItems = [];
                }
            }
        }
    }

    function refreshItems(): void {
        if (!loadClipboardProc.running) {
            loadClipboardProc.running = true;
        }
    }

    // Filtered items based on Search Query and Type Pill
    readonly property var filteredItems: {
        var q = (root.searchQuery || "").trim().toLowerCase();
        var fType = root.filterType;
        var src = root.allItems || [];
        var matches = [];

        for (var i = 0; i < src.length; i++) {
            var it = src[i];
            if (fType !== "all" && it.type !== fType) continue;

            if (q.length > 0) {
                var p = (it.preview || "").toLowerCase();
                var r = (it.raw || "").toLowerCase();
                if (p.indexOf(q) === -1 && r.indexOf(q) === -1) {
                    continue;
                }
            }
            matches.push(it);
        }
        return matches;
    }

    onFilteredItemsChanged: {
        if (root.selectedIndex >= filteredItems.length) {
            root.selectedIndex = Math.max(0, filteredItems.length - 1);
        }
    }

    function moveSelection(delta: int): void {
        var count = root.filteredItems.length;
        if (count <= 0) return;
        var next = root.selectedIndex + delta;
        if (next < 0) next = 0;
        if (next >= count) next = count - 1;
        root.selectedIndex = next;
        clipListView.positionViewAtIndex(next, ListView.Contain);
    }

    function copySelected(): void {
        var list = root.filteredItems;
        if (!list || list.length === 0) return;
        var idx = Math.max(0, Math.min(root.selectedIndex, list.length - 1));
        copyItem(list[idx]);
    }

    function copyItem(it): void {
        if (!it || !it.id) return;
        Quickshell.execDetached([
            "python3",
            Quickshell.shellDir + "/clipboard/clipboard.py",
            "copy",
            it.id
        ]);
        root.close();
    }

    function deleteSelected(): void {
        var list = root.filteredItems;
        if (!list || list.length === 0) return;
        var idx = Math.max(0, Math.min(root.selectedIndex, list.length - 1));
        deleteItem(list[idx]);
    }

    function deleteItem(it): void {
        if (!it || !it.id) return;
        Quickshell.execDetached([
            "python3",
            Quickshell.shellDir + "/clipboard/clipboard.py",
            "delete",
            it.id
        ]);
        // Remove locally from allItems immediately for instant UI response
        var nextAll = [];
        for (var i = 0; i < root.allItems.length; i++) {
            if (root.allItems[i].id !== it.id) {
                nextAll.push(root.allItems[i]);
            }
        }
        root.allItems = nextAll;
    }

    function clearAll(): void {
        Quickshell.execDetached([
            "python3",
            Quickshell.shellDir + "/clipboard/clipboard.py",
            "clear"
        ]);
        root.allItems = [];
    }

    function open(): void {
        root.refreshItems();
        root.searchQuery = "";
        root.filterType = "all";
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
        target: "clipboard"
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
    // Center Frosted Glass Clipboard Modal
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

        // Prevent clicks inside card from closing modal
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                searchInput.forceActiveFocus();
            }
        }

        // Frosted Glass Base Layer
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: 26
            color: root.glassBg
            border.width: 1
            border.color: root.glassBorder

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
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // =================================================================
            // 1. TOP HEADER BAR: Dot-Matrix Title, Count, Action Buttons
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 10

                // Left: LED Dot + Dot-Matrix Title
                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.nothingRed
                    }

                    Text {
                        text: "CLIPBOARD"
                        font.family: fontNdot57.name
                        font.pixelSize: 16
                        font.letterSpacing: 1.6
                        color: root.textPrimary
                    }

                    // Count Badge
                    Rectangle {
                        height: 20
                        width: countTxt.implicitWidth + 14
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: (root.filteredItems ? root.filteredItems.length : 0) + " ITEMS"
                            font.family: fontNMono.name
                            font.pixelSize: 10
                            color: root.textSecondary
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right: Clear All & Close Pills
                RowLayout {
                    spacing: 6

                    // [DEL] DELETE ITEM Button
                    Rectangle {
                        visible: root.filteredItems.length > 0
                        height: 24
                        width: delRow.implicitWidth + 14
                        radius: 12
                        color: delMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            id: delRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "[DEL]"
                                font.family: fontNMono.name
                                font.pixelSize: 9
                                color: root.nothingRed
                            }
                            Text {
                                text: "DELETE"
                                font.family: fontNMono.name
                                font.pixelSize: 9
                                color: root.textSecondary
                            }
                        }

                        MouseArea {
                            id: delMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteSelected()
                        }
                    }

                    // [CLR] CLEAR ALL Button
                    Rectangle {
                        visible: root.allItems.length > 0
                        height: 24
                        width: clrRow.implicitWidth + 14
                        radius: 12
                        color: clrMouse.containsMouse ? Qt.rgba(0.84, 0.10, 0.13, 0.25) : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                        border.color: clrMouse.containsMouse ? root.nothingRed : Qt.rgba(1, 1, 1, 0.10)

                        RowLayout {
                            id: clrRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "CLEAR ALL"
                                font.family: fontNMono.name
                                font.pixelSize: 9
                                color: clrMouse.containsMouse ? "#FF6B6B" : root.textMuted
                            }
                        }

                        MouseArea {
                            id: clrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }

                    // [ESC] CLOSE Button
                    Rectangle {
                        height: 24
                        width: escTxt.implicitWidth + 14
                        radius: 12
                        color: escMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Text {
                            id: escTxt
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: fontNMono.name
                            font.pixelSize: 9
                            color: root.textMuted
                        }

                        MouseArea {
                            id: escMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }
            }

            // =================================================================
            // 2. SEARCH INPUT CAPSULE + REAL-TIME TYPE FILTERS
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 23
                color: Qt.rgba(0.03, 0.04, 0.05, 0.68)
                border.width: 1
                border.color: searchInput.activeFocus
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.32)
                    : Qt.rgba(1.0, 1.0, 1.0, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: ">"
                        font.family: fontNMono.name
                        font.pixelSize: 15
                        font.bold: true
                        color: searchInput.activeFocus ? root.nothingRed : root.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: fontNType.name
                        font.pixelSize: 14
                        color: root.textPrimary
                        clip: true
                        focus: true
                        selectByMouse: true
                        selectionColor: root.nothingRed

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Search clipboard history..."
                            font.family: fontNType.name
                            font.pixelSize: 14
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.35)
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.selectedIndex = 0;
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                root.moveSelection(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.copySelected();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete) {
                                root.deleteSelected();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                // Cycle filter type: all -> text -> code -> image -> url
                                var types = ["all", "text", "code", "image", "url"];
                                var curIdx = types.indexOf(root.filterType);
                                root.filterType = types[(curIdx + 1) % types.length];
                                event.accepted = true;
                            }
                        }
                    }

                    // Filter Type Pills [ALL] [TEXT] [CODE] [IMAGES] [URLS]
                    Row {
                        spacing: 4

                        Repeater {
                            model: [
                                { "id": "all",   "label": "ALL" },
                                { "id": "text",  "label": "TEXT" },
                                { "id": "code",  "label": "CODE" },
                                { "id": "image", "label": "IMAGES" },
                                { "id": "url",   "label": "LINKS" }
                            ]

                            delegate: Rectangle {
                                height: 26
                                width: filterLabel.implicitWidth + 14
                                radius: 13
                                color: root.filterType === modelData.id
                                    ? "#FFFFFF"
                                    : (fPillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")

                                Text {
                                    id: filterLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: fontNMono.name
                                    font.pixelSize: 10
                                    font.bold: root.filterType === modelData.id
                                    color: root.filterType === modelData.id ? "#0D0F12" : root.textMuted
                                }

                                MouseArea {
                                    id: fPillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.filterType = modelData.id;
                                        root.selectedIndex = 0;
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 3. CLIPBOARD ITEMS LIST (Rich Content & Image Preview)
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty State
                Item {
                    visible: root.filteredItems.length === 0
                    anchors.fill: parent

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "[!] NO CLIPBOARD HISTORY FOUND"
                            font.family: fontNMono.name
                            font.pixelSize: 12
                            font.letterSpacing: 1.2
                            color: root.textMuted
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.searchQuery ? "Try a different search keyword" : "Copy any text, code, or screenshot with Ctrl+C"
                            font.family: fontNType.name
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, 0.28)
                        }
                    }
                }

                ListView {
                    id: clipListView
                    anchors.fill: parent
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredItems

                    delegate: Item {
                        id: itemSlot
                        width: clipListView.width
                        height: modelData.type === "image" ? 64 : 52

                        readonly property bool isSelected: (index === root.selectedIndex)

                        Rectangle {
                            id: itemCard
                            anchors.fill: parent
                            radius: 14
                            color: itemSlot.isSelected
                                ? Qt.rgba(0.84, 0.10, 0.13, 0.18)
                                : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: itemSlot.isSelected
                                ? root.nothingRed
                                : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.06))

                            Behavior on color {
                                ColorAnimation { duration: 110 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                // Type Badge (IMG, URL, CODE, TXT)
                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 6
                                    color: {
                                        if (modelData.type === "image") return Qt.rgba(0.65, 0.35, 0.95, 0.22);
                                        if (modelData.type === "url")   return Qt.rgba(0.20, 0.70, 0.95, 0.22);
                                        if (modelData.type === "code")  return Qt.rgba(0.30, 0.85, 0.45, 0.20);
                                        return Qt.rgba(1.0, 1.0, 1.0, 0.10);
                                    }
                                    border.width: 1
                                    border.color: {
                                        if (modelData.type === "image") return "#A855F7";
                                        if (modelData.type === "url")   return "#38BDF8";
                                        if (modelData.type === "code")  return "#4ADE80";
                                        return Qt.rgba(1.0, 1.0, 1.0, 0.18);
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (modelData.type === "image") return "IMG";
                                            if (modelData.type === "url")   return "URL";
                                            if (modelData.type === "code")  return "CODE";
                                            return "TXT";
                                        }
                                        font.family: fontNMono.name
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: {
                                            if (modelData.type === "image") return "#C084FC";
                                            if (modelData.type === "url")   return "#7DD3FC";
                                            if (modelData.type === "code")  return "#86EFAC";
                                            return root.textSecondary;
                                        }
                                    }
                                }

                                // Image Thumbnail Preview (if image)
                                Rectangle {
                                    visible: modelData.type === "image" && modelData.thumb !== ""
                                    width: 76
                                    height: 44
                                    radius: 6
                                    color: "#000000"
                                    clip: true
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                // Content Preview Text
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.preview
                                    font.family: (modelData.type === "code" || modelData.type === "url") ? fontNMono.name : fontNType.name
                                    font.pixelSize: 12
                                    color: itemSlot.isSelected ? "#FFFFFF" : root.textSecondary
                                    elide: Text.ElideRight
                                    maximumLineCount: modelData.type === "image" ? 1 : 2
                                    wrapMode: Text.WrapAnywhere
                                }

                                // Right Pill: [↵] COPY
                                Rectangle {
                                    height: 24
                                    width: copyTxt.implicitWidth + 14
                                    radius: 12
                                    color: itemSlot.isSelected ? root.nothingRed : Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        id: copyTxt
                                        anchors.centerIn: parent
                                        text: itemSlot.isSelected ? "↵ COPY" : "COPY"
                                        font.family: fontNMono.name
                                        font.pixelSize: 9
                                        font.bold: itemSlot.isSelected
                                        color: itemSlot.isSelected ? "#FFFFFF" : root.textMuted
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = index;
                                    root.copyItem(modelData);
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 4. FOOTER HINTS BAR
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 12

                Text {
                    text: "[↑ / ↓] Navigate"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    color: root.textMuted
                }

                Text {
                    text: "•"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                Text {
                    text: "[Tab] Filter Type"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    color: root.textMuted
                }

                Text {
                    text: "•"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                Text {
                    text: "[Del] Remove"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    color: root.textMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "[↵] Copy to Active Clipboard"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    color: root.textSecondary
                }
            }
        }
    }
}

