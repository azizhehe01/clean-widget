import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// =============================================================================
// Nothing OS 3.0 / glyph-shell Native Workspace Overview (Super + Tab)
// Unified inside DesktopWidgetsApp (saves ~180 MB RAM vs standalone process).
// Zero background polling when closed; live ScreencopyView only while open.
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:overview"
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

    property bool wasFrozenByScreenshot: false

    // Monitor & workspace state refreshed on open()
    property int monX: 0
    property int monY: 0
    property int monW: 1920
    property int monH: 1080
    property int activeWsId: 1
    property var clientsList: [] // [{ address, wsId, wsName, x, y, w, h, cls, title, floating, toplevel }]
    property var specialNames: [] // e.g. ["scratchpad"]
    property string activeSpecialName: ""
    property int draggingTargetWs: -1
    property string draggingTargetSpecial: ""
    property string hoveredTitle: ""

    readonly property int cols: 5
    readonly property int tileW: Math.min(320, Math.max(240, Math.floor(((monW > 0 ? monW : 1920) * 0.88 - 88) / 5)))
    readonly property int tileH: Math.round(tileW * (monH > 0 ? monH : 1080) / (monW > 0 ? monW : 1920))
    readonly property int gridSpacing: 14
    readonly property bool showSecondRow: {
        if (activeWsId > 5) return true;
        for (var i = 0; i < clientsList.length; i++) {
            if (clientsList[i].wsId > 5) return true;
        }
        return false;
    }
    readonly property int wsCount: showSecondRow ? 10 : 5
    readonly property int rows: showSecondRow ? 2 : 1

    // Official Nothing OS Typography
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // Theme Tokens — Chameleon Frosted Glass (Harmonized with Launcher, Clipboard, Emoji, Keybinds)
    readonly property color glassBg: Qt.rgba(0.06, 0.07, 0.09, 0.58)
    readonly property color glassBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color nothingRed: "#D71921"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.72)
    readonly property color textMuted: Qt.rgba(1.0, 1.0, 1.0, 0.42)

    // Screenshot-safe focus grab
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
                        keyScope.forceActiveFocus();
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
                keyScope.forceActiveFocus();
            }
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 90
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                root.refreshState();
            }
        }
    }

    // Fetch Hyprland state cleanly on open / drag-drop
    Process {
        id: stateProc
        command: ["python3", "-c", "
import json, os, subprocess
env = os.environ.copy()
if not env.get('HYPRLAND_INSTANCE_SIGNATURE'):
    h = f'/run/user/{os.getuid()}/hypr'
    if os.path.isdir(h):
        e = sorted(os.listdir(h))
        if e: env['HYPRLAND_INSTANCE_SIGNATURE'] = e[0]
def run_j(args):
    r = subprocess.run(['hyprctl'] + args + ['-j'], capture_output=True, text=True, env=env)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None

APP_DIRS = [
    os.path.expanduser('~/.local/share/applications'),
    '/usr/share/applications',
    '/var/lib/flatpak/exports/share/applications',
]
icon_cache = {}
def resolve_app_icon(cls):
    if not cls:
        return ''
    key = cls.lower()
    if key in icon_cache:
        return icon_cache[key]
    icon_val = ''
    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for cand in (f'{cls}.desktop', f'{key}.desktop'):
            p = os.path.join(d, cand)
            if os.path.isfile(p):
                try:
                    with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                        for line in f:
                            if line.startswith('Icon='):
                                icon_val = line.split('=', 1)[1].strip()
                                break
                except Exception:
                    pass
                if icon_val:
                    break
        if icon_val:
            break
    res = ''
    if icon_val:
        if icon_val.startswith('/') and os.path.isfile(icon_val):
            res = 'file://' + icon_val
        else:
            res = icon_val
    elif os.path.isfile(f'/usr/share/pixmaps/{key}.png'):
        res = f'file:///usr/share/pixmaps/{key}.png'
    icon_cache[key] = res
    return res

mons = run_j(['monitors']) or []
mon = next((m for m in mons if m.get('focused')), mons[0] if mons else {})
ws = run_j(['activeworkspace']) or {}
clients = run_j(['clients']) or []
out = {
    'mon': {
        'id': mon.get('id', 0),
        'x': mon.get('x', 0),
        'y': mon.get('y', 0),
        'w': mon.get('width', 1920),
        'h': mon.get('height', 1080),
        'scale': mon.get('scale', 1.0),
    },
    'activeWs': ws.get('id', 1),
    'activeSpecial': ((mon.get('specialWorkspace') or {}).get('name', '') or '').removeprefix('special:'),
    'clients': [
        {
            'address': c.get('address', ''),
            'wsId': (c.get('workspace') or {}).get('id', -1),
            'wsName': (c.get('workspace') or {}).get('name', ''),
            'x': (c.get('at') or [0, 0])[0],
            'y': (c.get('at') or [0, 0])[1],
            'w': (c.get('size') or [100, 100])[0],
            'h': (c.get('size') or [100, 100])[1],
            'cls': c.get('class') or c.get('initialClass') or '',
            'icon': resolve_app_icon(c.get('class') or c.get('initialClass') or ''),
            'title': c.get('title') or c.get('class') or '',
            'floating': bool(c.get('floating', False)),
            'mapped': bool(c.get('mapped', True)),
        }
        for c in clients if c.get('mapped', True) and (
            (c.get('workspace') or {}).get('id', -1) >= 1 or
            ((c.get('workspace') or {}).get('name', '')).startswith('special:')
        )
    ]
}
print(json.dumps(out))
"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    var m = parsed.mon || {};
                    var s = m.scale > 0 ? m.scale : 1.0;
                    root.monX = m.x || 0;
                    root.monY = m.y || 0;
                    root.monW = Math.round((m.w || 1920) / s);
                    root.monH = Math.round((m.h || 1080) / s);
                    root.activeWsId = parsed.activeWs || 1;
                    root.activeSpecialName = parsed.activeSpecial || "";

                    // Map live Wayland toplevels by address
                    var tlMap = {};
                    var tls = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
                    for (var i = 0; i < tls.length; i++) {
                        var tl = tls[i];
                        if (tl && tl.HyprlandToplevel) {
                            tlMap["0x" + tl.HyprlandToplevel.address] = tl;
                        }
                    }

                    var rawClients = parsed.clients || [];
                    var enriched = [];
                    var specials = [];
                    var seenSpecial = {};
                    for (var j = 0; j < rawClients.length; j++) {
                        var c = rawClients[j];
                        c.toplevel = tlMap[c.address] || null;
                        enriched.push(c);
                        if (c.wsName && c.wsName.indexOf("special:") === 0) {
                            var sName = c.wsName.substring(8);
                            if (sName && !seenSpecial[sName]) {
                                seenSpecial[sName] = true;
                                specials.push(sName);
                            }
                        }
                    }
                    root.specialNames = specials;
                    root.clientsList = enriched;
                } catch (e) {
                    console.log("[Overview] parse error:", e);
                }
            }
        }
    }

    function refreshState(): void {
        stateProc.running = false;
        stateProc.running = true;
    }

    function dismissActiveSpecial(): void {
        if (root.activeSpecialName !== "") {
            var sName = root.activeSpecialName;
            root.activeSpecialName = "";
            if (Hyprland.usingLua) {
                Hyprland.dispatch("hl.dsp.workspace.toggle_special('" + sName + "')");
            } else {
                Hyprland.dispatch("togglespecialworkspace " + sName);
            }
        }
    }

    function dispatchWorkspace(wsId, keepOpen): void {
        dismissActiveSpecial();
        if (!keepOpen) {
            close();
        } else {
            root.activeWsId = wsId;
        }
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({workspace = '" + wsId + "'})");
        } else {
            Hyprland.dispatch("workspace " + wsId);
        }
    }

    function dispatchToggleSpecial(sName): void {
        close();
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.workspace.toggle_special('" + sName + "')");
        } else {
            Hyprland.dispatch("togglespecialworkspace " + sName);
        }
    }

    function dispatchMoveToSpecial(addr, sName): void {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.window.move({workspace = 'special:" + sName + "', follow = false, window = 'address:" + addr + "'})");
        } else {
            Hyprland.dispatch("movetoworkspacesilent special:" + sName + ", address:" + addr);
        }
        delayedRefreshTimer.restart();
    }

    function dispatchFocusWindow(addr): void {
        dismissActiveSpecial();
        close();
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + addr + "' })");
        } else {
            Hyprland.dispatch("focuswindow address:" + addr);
        }
    }

    function dispatchMoveWindow(addr, targetWs): void {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.window.move({workspace = '" + targetWs + "', follow = false, window = 'address:" + addr + "'})");
        } else {
            Hyprland.dispatch("movetoworkspacesilent " + targetWs + ", address:" + addr);
        }
        delayedRefreshTimer.restart();
    }

    function dispatchCloseWindow(addr): void {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.window.close('address:" + addr + "')");
        } else {
            Hyprland.dispatch("closewindow address:" + addr);
        }
        delayedRefreshTimer.restart();
    }

    function toggle(): void {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    function open(): void {
        isOpen = true;
        showWindow = true;
        wasFrozenByScreenshot = false;
        draggingTargetWs = -1;
        draggingTargetSpecial = "";
        hoveredTitle = "";
        refreshState();
        grabDelayTimer.restart();
    }

    function close(): void {
        focusGrab.active = false;
        wasFrozenByScreenshot = false;
        draggingTargetWs = -1;
        draggingTargetSpecial = "";
        isOpen = false;
        showWindow = false;
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    // Keyboard navigation scope (Arrow keys, Vim hjkl, 1-9/0, Enter, Esc)
    Item {
        id: keyScope
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: { root.dismissActiveSpecial(); root.close(); }
        Keys.onEnterPressed: { root.dismissActiveSpecial(); root.close(); }
        Keys.onPressed: event => {
            var idx = Math.max(0, root.activeWsId - 1);
            var col = idx % root.cols;
            var row = Math.floor(idx / root.cols);
            var maxRows = root.rows;

            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                col = (col - 1 + root.cols) % root.cols;
                root.dispatchWorkspace(row * root.cols + col + 1, true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                col = (col + 1) % root.cols;
                root.dispatchWorkspace(row * root.cols + col + 1, true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (row > 0) {
                    root.dispatchWorkspace((row - 1) * root.cols + col + 1, true);
                } else if (maxRows > 1) {
                    root.dispatchWorkspace(root.cols + col + 1, true);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                // Pressing Down from Row 1 expands Row 2 (WS 6-10) automatically!
                if (row === 0) {
                    root.dispatchWorkspace(root.cols + col + 1, true);
                } else {
                    root.dispatchWorkspace(col + 1, true);
                }
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                root.dispatchWorkspace(event.key - Qt.Key_0, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_0) {
                root.dispatchWorkspace(10, false);
                event.accepted = true;
            }
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
        width: (root.cols * root.tileW) + ((root.cols - 1) * root.gridSpacing) + 40
        height: (root.rows * root.tileH) + ((root.rows - 1) * root.gridSpacing)
                + (root.specialNames.length > 0 ? (root.tileH + 40) : 0) + 104
        anchors.centerIn: parent
        radius: 24
        color: root.glassBg
        border.color: root.glassBorder
        border.width: 1
        clip: true

        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.95

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: {}
        }

        // Top Subtle Highlight Bar
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 56
            height: 1
            color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

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
                    text: "WORKSPACES"
                    font.family: fontNdot55.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: root.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 22
                    width: statusText.implicitWidth + 20
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: "WS " + root.activeWsId + "  •  " + root.clientsList.length + " WINDOWS"
                        font.family: fontNType.name
                        font.pixelSize: 11
                        font.letterSpacing: 0.5
                        color: root.textSecondary
                    }
                }
            }

            // =================================================================
            // Workspace Grid (5 columns x 1 or 2 rows)
            // =================================================================
            GridLayout {
                id: wsGrid
                columns: root.cols
                columnSpacing: root.gridSpacing
                rowSpacing: root.gridSpacing
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.wsCount
                    delegate: Rectangle {
                        id: wsTile
                        readonly property int wsId: index + 1
                        readonly property bool isActive: wsId === root.activeWsId
                        readonly property bool isDropTarget: root.draggingTargetWs === wsId

                        width: root.tileW
                        height: root.tileH
                        radius: 14
                        clip: false

                        color: isDropTarget
                            ? Qt.rgba(0.84, 0.10, 0.13, 0.16)
                            : (isActive ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                        border.color: isDropTarget || isActive
                            ? root.nothingRed
                            : (wsHover.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12))
                        border.width: (isDropTarget || isActive) ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // Big subtle dot-matrix workspace number
                        Text {
                            anchors.centerIn: parent
                            text: wsTile.wsId
                            font.family: fontNdot55.name
                            font.pixelSize: 42
                            color: wsTile.isActive ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Click empty area of workspace to switch
                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dispatchWorkspace(wsTile.wsId, false)
                        }

                        // Drop target for dragging windows between workspaces
                        DropArea {
                            anchors.fill: parent
                            onEntered: {
                                root.draggingTargetSpecial = "";
                                root.draggingTargetWs = wsTile.wsId;
                            }
                            onExited: {
                                if (root.draggingTargetWs === wsTile.wsId) {
                                    root.draggingTargetWs = -1;
                                }
                            }
                        }

                        // Windows inside this workspace
                        Item {
                            id: winLayer
                            anchors.fill: parent
                            anchors.margins: 4

                            readonly property real scaleX: width / (root.monW > 0 ? root.monW : 1920)
                            readonly property real scaleY: height / (root.monH > 0 ? root.monH : 1080)

                            Repeater {
                                model: root.clientsList.filter(function(c) { return c.wsId === wsTile.wsId; })
                                delegate: Item {
                                    id: winCard
                                    required property var modelData

                                    readonly property real baseX: Math.max(0, Math.min(winLayer.width - 16, (modelData.x - root.monX) * winLayer.scaleX))
                                    readonly property real baseY: Math.max(0, Math.min(winLayer.height - 16, (modelData.y - root.monY) * winLayer.scaleY))
                                    readonly property real baseW: Math.max(24, Math.min(winLayer.width - baseX, modelData.w * winLayer.scaleX))
                                    readonly property real baseH: Math.max(20, Math.min(winLayer.height - baseY, modelData.h * winLayer.scaleY))

                                    x: baseX
                                    y: baseY
                                    width: baseW
                                    height: baseH
                                    z: dragArea.drag.active ? 999 : (modelData.floating ? 10 : 1)

                                    Drag.active: dragArea.drag.active
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2

                                    Rectangle {
                                        id: cardFrame
                                        anchors.fill: parent
                                        anchors.margins: 1.5
                                        radius: 8
                                        color: Qt.rgba(0.08, 0.09, 0.12, 0.85)
                                        border.color: dragArea.containsMouse ? root.nothingRed : Qt.rgba(1, 1, 1, 0.22)
                                        border.width: dragArea.containsMouse ? 1.5 : 1
                                        clip: true

                                        // Live window preview (only active when overview is open)
                                        ScreencopyView {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            captureSource: root.isOpen ? modelData.toplevel : null
                                            live: root.isOpen
                                        }

                                        // App Icon Badge (clear & readable)
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: Math.min(48, Math.max(26, parent.width * 0.34))
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(0.05, 0.06, 0.08, 0.78)
                                            border.color: Qt.rgba(1, 1, 1, 0.22)
                                            border.width: 1

                                            Image {
                                                anchors.centerIn: parent
                                                width: parent.width * 0.68
                                                height: parent.height * 0.68
                                                source: (modelData.icon && modelData.icon.indexOf("file://") === 0)
                                                    ? modelData.icon
                                                    : Quickshell.iconPath(modelData.icon || modelData.cls, "application-x-executable")
                                                sourceSize: Qt.size(64, 64)
                                                smooth: true
                                            }
                                        }

                                        // Subtle app label pill at bottom of window card
                                        Rectangle {
                                            visible: parent.height >= 54 && parent.width >= 60
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottomMargin: 4
                                            height: 16
                                            width: Math.min(parent.width - 10, appNameLbl.implicitWidth + 10)
                                            radius: 6
                                            color: Qt.rgba(0.04, 0.05, 0.07, 0.80)

                                            Text {
                                                id: appNameLbl
                                                anchors.centerIn: parent
                                                width: parent.width - 8
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.cls || modelData.title
                                                font.family: fontNType.name
                                                font.pixelSize: 9
                                                color: root.textPrimary
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        drag.target: winCard
                                        drag.threshold: 6

                                        onEntered: root.hoveredTitle = modelData.title
                                        onExited: {
                                            if (root.hoveredTitle === modelData.title) {
                                                root.hoveredTitle = "";
                                            }
                                        }

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                root.dispatchFocusWindow(modelData.address);
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                root.dispatchCloseWindow(modelData.address);
                                            }
                                        }

                                        onReleased: {
                                            var target = root.draggingTargetWs;
                                            var targetSpec = root.draggingTargetSpecial;
                                            if (drag.active && targetSpec !== "") {
                                                root.draggingTargetSpecial = "";
                                                root.draggingTargetWs = -1;
                                                root.dispatchMoveToSpecial(modelData.address, targetSpec);
                                            } else if (drag.active && target >= 1 && target !== wsTile.wsId) {
                                                root.draggingTargetWs = -1;
                                                root.draggingTargetSpecial = "";
                                                root.dispatchMoveWindow(modelData.address, target);
                                            } else {
                                                root.draggingTargetWs = -1;
                                                root.draggingTargetSpecial = "";
                                                winCard.x = winCard.baseX;
                                                winCard.y = winCard.baseY;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // Special / Scratchpad Workspaces (Super + S / Super + Shift + S)
            // =================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.specialNames.length > 0

                RowLayout {
                    spacing: 6
                    Text {
                        text: "SPECIAL / SCRATCHPAD"
                        font.family: fontNdot55.name
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        color: root.textMuted
                    }
                    Text {
                        text: "(SUPER + S)"
                        font.family: fontNMono.name
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.30)
                    }
                }

                RowLayout {
                    spacing: root.gridSpacing

                    Repeater {
                        model: root.specialNames
                        delegate: Rectangle {
                            id: specTile
                            required property string modelData
                            readonly property string sName: modelData
                            readonly property bool isDropTarget: root.draggingTargetSpecial === sName

                            width: root.tileW
                            height: root.tileH
                            radius: 14
                            clip: false

                            color: isDropTarget
                                ? Qt.rgba(0.84, 0.10, 0.13, 0.16)
                                : Qt.rgba(1, 1, 1, 0.05)
                            border.color: isDropTarget
                                ? root.nothingRed
                                : (specHover.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.14))
                            border.width: isDropTarget ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: specTile.sName.toUpperCase()
                                font.family: fontNdot55.name
                                font.pixelSize: 14
                                font.letterSpacing: 1.5
                                color: Qt.rgba(1, 1, 1, 0.14)
                            }

                            MouseArea {
                                id: specHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dispatchToggleSpecial(specTile.sName)
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWs = -1;
                                    root.draggingTargetSpecial = specTile.sName;
                                }
                                onExited: {
                                    if (root.draggingTargetSpecial === specTile.sName) {
                                        root.draggingTargetSpecial = "";
                                    }
                                }
                            }

                            Item {
                                id: specWinLayer
                                anchors.fill: parent
                                anchors.margins: 4

                                readonly property real scaleX: width / (root.monW > 0 ? root.monW : 1920)
                                readonly property real scaleY: height / (root.monH > 0 ? root.monH : 1080)

                                Repeater {
                                    model: root.clientsList.filter(function(c) { return c.wsName === ("special:" + specTile.sName); })
                                    delegate: Item {
                                        id: specCard
                                        required property var modelData

                                        readonly property real baseX: Math.max(0, Math.min(specWinLayer.width - 16, (modelData.x - root.monX) * specWinLayer.scaleX))
                                        readonly property real baseY: Math.max(0, Math.min(specWinLayer.height - 16, (modelData.y - root.monY) * specWinLayer.scaleY))
                                        readonly property real baseW: Math.max(24, Math.min(specWinLayer.width - baseX, modelData.w * specWinLayer.scaleX))
                                        readonly property real baseH: Math.max(20, Math.min(specWinLayer.height - baseY, modelData.h * specWinLayer.scaleY))

                                        x: baseX
                                        y: baseY
                                        width: baseW
                                        height: baseH
                                        z: specDragArea.drag.active ? 999 : (modelData.floating ? 10 : 1)

                                        Drag.active: specDragArea.drag.active
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1.5
                                            radius: 8
                                            color: Qt.rgba(0.08, 0.09, 0.12, 0.85)
                                            border.color: specDragArea.containsMouse ? root.nothingRed : Qt.rgba(1, 1, 1, 0.22)
                                            border.width: specDragArea.containsMouse ? 1.5 : 1
                                            clip: true

                                            ScreencopyView {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                captureSource: root.isOpen ? modelData.toplevel : null
                                                live: root.isOpen
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: Math.min(48, Math.max(26, parent.width * 0.34))
                                                height: width
                                                radius: width / 2
                                                color: Qt.rgba(0.05, 0.06, 0.08, 0.78)
                                                border.color: Qt.rgba(1, 1, 1, 0.22)
                                                border.width: 1

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: parent.width * 0.68
                                                    height: parent.height * 0.68
                                                    source: (modelData.icon && modelData.icon.indexOf("file://") === 0)
                                                        ? modelData.icon
                                                        : Quickshell.iconPath(modelData.icon || modelData.cls, "application-x-executable")
                                                    sourceSize: Qt.size(64, 64)
                                                    smooth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: specDragArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            drag.target: specCard
                                            drag.threshold: 6

                                            onEntered: root.hoveredTitle = modelData.title
                                            onExited: {
                                                if (root.hoveredTitle === modelData.title) {
                                                    root.hoveredTitle = "";
                                                }
                                            }

                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    root.dispatchToggleSpecial(specTile.sName);
                                                } else if (mouse.button === Qt.MiddleButton) {
                                                    root.dispatchCloseWindow(modelData.address);
                                                }
                                            }

                                            onReleased: {
                                                var target = root.draggingTargetWs;
                                                if (drag.active && target >= 1) {
                                                    root.draggingTargetWs = -1;
                                                    root.draggingTargetSpecial = "";
                                                    root.dispatchMoveWindow(modelData.address, target);
                                                } else {
                                                    root.draggingTargetWs = -1;
                                                    root.draggingTargetSpecial = "";
                                                    specCard.x = specCard.baseX;
                                                    specCard.y = specCard.baseY;
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

            // =================================================================
            // Bottom Status Bar
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.hoveredTitle
                        ? root.hoveredTitle
                        : "ARROWS NAVIGATE  •  CLICK TO FOCUS  •  DRAG TO MOVE  •  1-9 JUMP  •  MIDDLE CLICK CLOSE"
                    font.family: fontNMono.name
                    font.pixelSize: 10
                    font.letterSpacing: 0.8
                    color: root.hoveredTitle ? root.textPrimary : root.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "ESC TO CLOSE"
                    font.family: fontNdot55.name
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }
    }
}

