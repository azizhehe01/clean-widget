import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root

    // Shared blurred wallpaper URL from DesktopWidgetsWindow
    property string wallpaperUrl: ""

    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080

    readonly property int cardWidth: 370
    readonly property int cardGap: 12
    readonly property int marginTop: 24
    readonly property int marginRight: 28
    readonly property int cardRadius: 20

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.marginTop
        right: root.marginRight
    }

    implicitWidth: root.cardWidth
    implicitHeight: Math.max(1, notifColumn.implicitHeight)
    color: "transparent"

    // Only map the overlay surface when there is at least one active notification
    visible: notifModel.count > 0

    // Official Nothing OS & nothing.tech Typography
    FontLoader { id: fontNType; source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono; source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // =========================================================================
    // Theme Tokens — Real-Time GPU Chameleon Frosted Glass (100% Pure Neutral)
    // =========================================================================
    readonly property color cardBg: Qt.rgba(0.0, 0.0, 0.0, 0.24)
    readonly property color cardEdgeHighlight: Qt.rgba(1.0, 1.0, 1.0, 0.14)
    readonly property color cardSpecularTopLeft: Qt.rgba(1.0, 1.0, 1.0, 0.08)
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1.0, 1.0, 1.0, 0.80)
    readonly property color textMuted: Qt.rgba(1.0, 1.0, 1.0, 0.56)
    readonly property color barFill: Qt.rgba(1.0, 1.0, 1.0, 0.78)

    // =========================================================================
    // Native Quickshell Notification Server (org.freedesktop.Notifications)
    // =========================================================================
    ListModel {
        id: notifModel
    }

    // Store live Notification object references by id for actions/dismissal
    property var liveNotifs: ({})

    function removeById(nid) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                notifModel.remove(i);
                break;
            }
        }
        if (root.liveNotifs[nid]) {
            delete root.liveNotifs[nid];
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: function(notif) {
            notif.tracked = true;
            let nid = notif.id;
            root.liveNotifs[nid] = notif;

            let appNameStr = notif.appName || "System";
            let summaryStr = notif.summary || "Notification";
            let cleanBody = (notif.body || "").replace(/<[^>]*>?/gm, "");
            let isAgy = /antigravity|agy|code/i.test(appNameStr + " " + summaryStr);
            let isPermRequest = /permission|approve|allow|confirm|sandbox|command|input|review/i.test(summaryStr + " " + cleanBody);

            // Default timeout: longer for long messages or permission requests
            let timeoutMs = (cleanBody.length > 120 || isPermRequest || isAgy) ? 8000 : 4500;
            if (notif.expireTimeout > 0) {
                timeoutMs = notif.expireTimeout > 100 ? notif.expireTimeout : notif.expireTimeout * 1000;
            } else if (notif.urgency === NotificationUrgency.Critical) {
                timeoutMs = 10000;
            } else if (notif.urgency === NotificationUrgency.Low) {
                timeoutMs = 3500;
            }

            // Extract up to 4 D-Bus actions + smart focus action for Antigravity IDE
            let actList = [];
            let hasDefaultIdx = -1;
            if (notif.actions && notif.actions.length > 0) {
                for (let a = 0; a < notif.actions.length; a++) {
                    let act = notif.actions[a];
                    let idStr = (act.identifier || "").toLowerCase();
                    let txtStr = (act.text || "").trim();
                    if (idStr === "default") {
                        hasDefaultIdx = a;
                        if (txtStr && txtStr.toLowerCase() !== "default" && txtStr.toLowerCase() !== "activate") {
                            actList.push({
                                "idx": a,
                                "label": txtStr,
                                "focusAgy": isAgy
                            });
                        }
                    } else if (actList.length < 4) {
                        actList.push({
                            "idx": a,
                            "label": txtStr || act.identifier || "Action",
                            "focusAgy": false
                        });
                    }
                }
            }

            // If notification is from Antigravity IDE (or has a default action on a permission request)
            // and no explicit buttons were added yet, add a quick action button to invoke & focus it
            if (actList.length === 0 && (isAgy || isPermRequest || hasDefaultIdx >= 0)) {
                actList.push({
                    "idx": hasDefaultIdx,
                    "label": isAgy ? "Buka Antigravity" : "Buka Aplikasi",
                    "focusAgy": isAgy
                });
            }

            let entry = {
                "nid": nid,
                "appName": appNameStr,
                "summary": summaryStr,
                "body": cleanBody,
                "iconSource": notif.image || "",
                "isCritical": false,
                "timeoutMs": timeoutMs,
                "actionsJson": JSON.stringify(actList)
            };

            // Replace existing notification with same ID or insert at top
            let replaced = false;
            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).nid === nid) {
                    notifModel.set(i, entry);
                    replaced = true;
                    break;
                }
            }
            if (!replaced) {
                // Keep maximum 4 stacked popups on screen
                while (notifModel.count >= 4) {
                    notifModel.remove(notifModel.count - 1);
                }
                notifModel.insert(0, entry);
            }

            notif.closed.connect(function() {
                root.removeById(nid);
            });
        }
    }

    // =========================================================================
    // Stacked Notification Cards Container
    // =========================================================================
    Column {
        id: notifColumn
        width: root.cardWidth
        spacing: root.cardGap

        Repeater {
            id: popupList
            model: notifModel

            delegate: Item {
                id: cardDelegate
                width: root.cardWidth
                height: contentCol.implicitHeight + 34

                property real slideOffset: 40
                opacity: 0.0

                Component.onCompleted: {
                    slideOffset = 0;
                    opacity = 1.0;
                }

                Behavior on slideOffset {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                readonly property var parsedActions: {
                    try {
                        return JSON.parse(model.actionsJson || "[]");
                    } catch (e) {
                        return [];
                    }
                }

                // Auto-expire countdown timer (pauses while hovered)
                property real remainingRatio: 1.0
                readonly property int stepMs: 40
                property real elapsedMs: 0

                Timer {
                    id: lifeTimer
                    interval: cardDelegate.stepMs
                    running: !cardHover.hovered
                    repeat: true
                    onTriggered: {
                        cardDelegate.elapsedMs += cardDelegate.stepMs;
                        cardDelegate.remainingRatio = Math.max(
                            0.0,
                            1.0 - (cardDelegate.elapsedMs / Math.max(1000, model.timeoutMs))
                        );
                        if (cardDelegate.elapsedMs >= model.timeoutMs) {
                            lifeTimer.stop();
                            let targetId = model.nid;
                            let nObj = root.liveNotifs[targetId];
                            root.removeById(targetId);
                            if (nObj) nObj.expire();
                        }
                    }
                }

                HoverHandler {
                    id: cardHover
                }

                // Card visual wrapper shifted by slideOffset for smooth entry
                Item {
                    x: cardDelegate.slideOffset
                    y: 0
                    width: parent.width
                    height: parent.height

                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: root.cardRadius
                        visible: false
                    }

                    // Real-Time GPU Chameleon Frosted Glass Backdrop (blurred live by Hyprland)
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: cardMask
                        }

                        // 1. Neutral Translucent Glass Surface (triggers Hyprland GPU Dual-Kawase blur)
                        Rectangle {
                            anchors.fill: parent
                            color: root.cardBg
                            border.width: 0
                        }

                        // 2. Top-Left to Bottom-Right Specular Shine
                        LinearGradient {
                            anchors.fill: parent
                            start: Qt.point(0, 0)
                            end: Qt.point(width, height)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.cardSpecularTopLeft }
                                GradientStop { position: 0.55; color: Qt.rgba(1.0, 1.0, 1.0, 0.02) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Bottom Timeout Progress Bar
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 3
                            width: parent.width * cardDelegate.remainingRatio
                            radius: 1.5
                            color: root.barFill
                            opacity: 0.65
                        }
                    }

                    // 3. Subtle 1px Specular Glass Edge Highlight
                    Rectangle {
                        anchors.fill: parent
                        radius: root.cardRadius
                        color: "transparent"
                        border.width: 1
                        border.color: root.cardEdgeHighlight
                    }

                    // Click anywhere on card to dismiss
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            let targetId = model.nid;
                            let nObj = root.liveNotifs[targetId];
                            root.removeById(targetId);
                            if (nObj) nObj.dismiss();
                        }
                    }

                    // Card Content
                    Column {
                        id: contentCol
                        x: 18
                        y: 16
                        width: parent.width - 36
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 14

                            // Left Icon / Image Badge (46x46, r=12)
                            Item {
                                width: 46
                                height: 46

                                Rectangle {
                                    id: iconBadgeMask
                                    anchors.fill: parent
                                    radius: 12
                                    visible: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                    border.width: 1
                                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                }

                                Item {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: iconBadgeMask
                                    }

                                    Image {
                                        id: notifIconImg
                                        anchors.fill: parent
                                        source: {
                                            let s = model.iconSource || "";
                                            if (!s) return "";
                                            if (s.startsWith("/") && !s.startsWith("file://"))
                                                return "file://" + s;
                                            if (s.startsWith("file://") || s.startsWith("http") || s.startsWith("image://"))
                                                return s;
                                            return "image://icon/" + s;
                                        }
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: notifIconImg.status !== Image.Ready
                                    text: model.isCritical ? "󰀦" : "󰂚"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 22
                                    color: root.textPrimary
                                }
                            }

                            // Right Text Column (App Name, Summary, Body)
                            Column {
                                width: parent.width - 60
                                spacing: 3

                                // Header: App Name (Nothing Technical Mono)
                                Text {
                                    width: parent.width
                                    text: (model.appName || "Notification").toUpperCase()
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.0
                                    color: root.textMuted
                                    elide: Text.ElideRight
                                    font.family: fontNMono.name || "Fira Sans"
                                }

                                // Summary (Title in Nothing NType82 Sans)
                                Text {
                                    width: parent.width
                                    text: model.summary || ""
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: root.textPrimary
                                    elide: Text.ElideRight
                                    font.family: fontNType.name || "Fira Sans"
                                }

                                // Scrollable Body Text (supports mouse wheel & touchpad scroll for long content)
                                Item {
                                    width: parent.width
                                    readonly property int maxBodyH: 120
                                    readonly property bool isScrollable: bodyText.implicitHeight > maxBodyH
                                    height: Math.min(bodyText.implicitHeight, maxBodyH)
                                    visible: (model.body || "") !== ""

                                    Flickable {
                                        id: bodyFlick
                                        anchors.fill: parent
                                        contentWidth: width
                                        contentHeight: bodyText.implicitHeight
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        interactive: parent.isScrollable

                                        WheelHandler {
                                            enabled: bodyText.implicitHeight > 120
                                            onWheel: function(event) {
                                                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
                                                let step = (event.pixelDelta.y !== 0) ? -event.pixelDelta.y : -(delta / 120) * 38;
                                                let maxY = Math.max(0, bodyFlick.contentHeight - bodyFlick.height);
                                                bodyFlick.contentY = Math.max(0, Math.min(maxY, bodyFlick.contentY + step));
                                                event.accepted = true;
                                            }
                                        }

                                        Text {
                                            id: bodyText
                                            width: bodyFlick.width - 8
                                            text: model.body || ""
                                            font.pixelSize: 13
                                            color: root.textSecondary
                                            wrapMode: Text.Wrap
                                            font.family: fontNType.name || "Fira Sans"
                                        }
                                    }

                                    // Slim Frosted Scrollbar Indicator (only visible when content overflows)
                                    Rectangle {
                                        visible: parent.isScrollable
                                        anchors.right: parent.right
                                        y: 0
                                        width: 3
                                        height: parent.height
                                        radius: 1.5
                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                                        Rectangle {
                                            width: parent.width
                                            radius: 1.5
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.45)
                                            height: Math.max(18, (bodyFlick.height / Math.max(1, bodyFlick.contentHeight)) * bodyFlick.height)
                                            y: (bodyFlick.contentY / Math.max(1, bodyFlick.contentHeight - bodyFlick.height)) * (bodyFlick.height - height)
                                        }
                                    }
                                }
                            }
                        }

                        // Action Buttons Row (Clean Frosted Button without 1,2,3,4 numbering)
                        Row {
                            width: parent.width
                            spacing: 8
                            visible: cardDelegate.parsedActions.length > 0

                            Repeater {
                                model: cardDelegate.parsedActions
                                delegate: Rectangle {
                                    height: 30
                                    width: (contentCol.width - (cardDelegate.parsedActions.length - 1) * 8) / cardDelegate.parsedActions.length
                                    radius: 10
                                    color: actMouse.containsMouse
                                        ? Qt.rgba(1.0, 1.0, 1.0, 0.24)
                                        : Qt.rgba(1.0, 1.0, 1.0, 0.13)
                                    border.width: 1
                                    border.color: actMouse.containsMouse
                                        ? Qt.rgba(1.0, 1.0, 1.0, 0.30)
                                        : Qt.rgba(1.0, 1.0, 1.0, 0.18)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Image {
                                            visible: !!modelData.focusAgy
                                            width: 14
                                            height: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: Qt.resolvedUrl("../assets/rocket.svg")
                                            sourceSize: Qt.size(14, 14)
                                            opacity: 0.9
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (modelData.label || "Action").toUpperCase()
                                            font.pixelSize: 11
                                            font.letterSpacing: 0.8
                                            color: root.textPrimary
                                            elide: Text.ElideRight
                                            font.family: fontNMono.name || "Fira Sans"
                                        }
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let targetId = model.nid;
                                            let actIdx = modelData.idx;
                                            let shouldFocusAgy = !!modelData.focusAgy;
                                            let nObj = root.liveNotifs[targetId];
                                            if (nObj && actIdx >= 0 && nObj.actions && nObj.actions[actIdx]) {
                                                // Invoking the D-Bus "default" action tells Electron to activate
                                                // the EXACT BrowserWindow that sent this notification via xdg_activation_v1
                                                nObj.actions[actIdx].invoke();
                                            } else if (shouldFocusAgy) {
                                                // Fallback only for manual notify-send tests without a D-Bus action
                                                Hyprland.dispatch('hl.dsp.focus({ window = "class:antigravity-ide" })');
                                            }
                                            root.removeById(targetId);
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
}
