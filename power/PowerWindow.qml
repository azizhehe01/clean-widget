import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:power"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Nothing OS / Glyph-shell Frosted Glass palette
    readonly property color glassBg: Qt.rgba(0.08, 0.09, 0.11, 0.58)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property color accentRed: "#D71921"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textMuted: "#C2C6CE"
    readonly property color circleIdleBg: Qt.rgba(1, 1, 1, 0.04)
    readonly property color circleIdleBorder: Qt.rgba(1, 1, 1, 0.24)
    readonly property color circleHoverBg: Qt.rgba(1, 1, 1, 0.12)
    readonly property color circleSelectedBg: Qt.rgba(1, 1, 1, 0.16)
    readonly property color circleDangerBg: Qt.rgba(215/255, 25/255, 33/255, 0.18)

    property int selectedIndex: 4 // Default highlight on Power Off
    property bool wasFrozenByScreenshot: false

    readonly property var actionsList: [
        {
            id: "lock",
            danger: false,
            matrix: [
                "..11111..",
                ".1.....1.",
                ".1.....1.",
                "111111111",
                "111111111",
                "1111.1111",
                "1111.1111",
                "111111111",
                ".1111111."
            ]
        },
        {
            id: "suspend",
            danger: false,
            matrix: [
                "..1111...",
                ".1111....",
                "111......",
                "111....1.",
                "111...111",
                "111....1.",
                "111......",
                ".1111....",
                "..1111..."
            ]
        },
        {
            id: "logout",
            danger: false,
            matrix: [
                "11111....",
                "1........",
                "1.....1..",
                "1......1.",
                "1..111111",
                "1......1.",
                "1.....1..",
                "1........",
                "11111...."
            ]
        },
        {
            id: "reboot",
            danger: false,
            matrix: [
                "..11111..",
                ".1....11.",
                "1....1111",
                "1........",
                "1........",
                "1.......1",
                "1.......1",
                ".1.....1.",
                "..11111.."
            ]
        },
        {
            id: "poweroff",
            danger: true,
            matrix: [
                "....1....",
                "..1.1.1..",
                ".1..1..1.",
                "1...1...1",
                "1...1...1",
                "1.......1",
                "1.......1",
                ".1.....1.",
                "..11111.."
            ]
        }
    ]

    Process {
        id: checkFreezeProc
        command: ["sh", "-c", "pgrep -x hyprpicker || pgrep -x slurp"]
        onExited: (exitCode) => {
            root.wasFrozenByScreenshot = (exitCode === 0);
            if (root.visible && !root.wasFrozenByScreenshot) {
                focusGrab.active = true;
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: {
            if (root.visible) root.close();
        }
    }

    function open() {
        root.selectedIndex = 4;
        root.visible = true;
        keyScope.forceActiveFocus();
        checkFreezeProc.running = true;
        openAnim.restart();
    }

    function close() {
        focusGrab.active = false;
        root.visible = false;
    }

    function toggle() {
        if (root.visible) close();
        else open();
    }

    function triggerAction(actionId, force) {
        var args = ["python3", "/home/azhehe/.config/quickshell/DesktopWidgetsApp/power/power.py", actionId];
        if (force) args.push("--force");
        root.close();
        Quickshell.execDetached(args);
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    // Backdrop click to close
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Keyboard navigation
    Item {
        id: keyScope
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onUpPressed: {
            root.selectedIndex = (root.selectedIndex - 1 + root.actionsList.length) % root.actionsList.length;
        }
        Keys.onLeftPressed: {
            root.selectedIndex = (root.selectedIndex - 1 + root.actionsList.length) % root.actionsList.length;
        }
        Keys.onDownPressed: {
            root.selectedIndex = (root.selectedIndex + 1) % root.actionsList.length;
        }
        Keys.onRightPressed: {
            root.selectedIndex = (root.selectedIndex + 1) % root.actionsList.length;
        }
        Keys.onReturnPressed: event => {
            var act = root.actionsList[root.selectedIndex];
            if (act) {
                root.triggerAction(act.id, (event.modifiers & Qt.ShiftModifier) !== 0);
            }
        }
        Keys.onEnterPressed: event => {
            var act = root.actionsList[root.selectedIndex];
            if (act) {
                root.triggerAction(act.id, (event.modifiers & Qt.ShiftModifier) !== 0);
            }
        }
        Keys.onPressed: event => {
            var force = (event.modifiers & Qt.ShiftModifier) !== 0;
            if (event.key === Qt.Key_L) { root.triggerAction("lock", force); event.accepted = true; }
            else if (event.key === Qt.Key_S) { root.triggerAction("suspend", force); event.accepted = true; }
            else if (event.key === Qt.Key_E) { root.triggerAction("logout", force); event.accepted = true; }
            else if (event.key === Qt.Key_R) { root.triggerAction("reboot", force); event.accepted = true; }
            else if (event.key === Qt.Key_P) { root.triggerAction("poweroff", force); event.accepted = true; }
        }
    }

    // Vertical Right-Anchored Icon-Only Capsule Pill
    Rectangle {
        id: modal
        width: 72
        height: 332
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        radius: 36
        color: root.glassBg
        border.color: root.glassBorder
        border.width: 1
        clip: true

        opacity: 0.0
        scale: 0.94

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: modal
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 160
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: modal
                property: "scale"
                from: 0.94
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // Prevent clicks inside pill from closing via backdrop
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: root.actionsList
                delegate: Rectangle {
                    id: iconBtn
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: root.selectedIndex === index
                    readonly property bool isHovered: btnMouse.containsMouse

                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    radius: 25

                    color: {
                        if (modelData.danger && (isSelected || isHovered)) return root.circleDangerBg;
                        if (isSelected) return root.circleSelectedBg;
                        if (isHovered) return root.circleHoverBg;
                        return root.circleIdleBg;
                    }

                    border.width: isSelected ? 2 : 1
                    border.color: {
                        if (modelData.danger && (isSelected || isHovered)) return root.accentRed;
                        if (isSelected) return root.textPrimary;
                        if (isHovered) return Qt.rgba(1, 1, 1, 0.45);
                        return root.circleIdleBorder;
                    }

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    // 9x9 Nothing OS Dot Matrix Icon
                    Grid {
                        anchors.centerIn: parent
                        columns: 9
                        rows: 9
                        spacing: 1

                        readonly property color activeDotColor: {
                            if (modelData.danger && (iconBtn.isSelected || iconBtn.isHovered)) return root.accentRed;
                            if (iconBtn.isSelected || iconBtn.isHovered) return root.textPrimary;
                            return root.textMuted;
                        }

                        Repeater {
                            model: 81
                            delegate: Rectangle {
                                required property int index
                                readonly property int r: Math.floor(index / 9)
                                readonly property int c: index % 9
                                readonly property bool dotOn: modelData.matrix[r].charAt(c) === "1"

                                width: 2
                                height: 2
                                radius: 1
                                color: dotOn ? parent.activeDotColor : Qt.rgba(1, 1, 1, 0.05)

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: mouse => {
                            var force = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                            root.triggerAction(modelData.id, force);
                        }
                    }
                }
            }
        }
    }
}
