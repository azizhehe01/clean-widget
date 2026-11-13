import Quickshell
import Quickshell.Wayland
import QtQuick
import "widgets"
import "notifications"
import "notch"
import "sidebar"
import "launcher"
import "wallpaper"
import "clipboard"
import "emoji"

ShellRoot {
    DesktopWidgetsWindow {
        id: desktopWidgets
    }

    NotificationPopupWindow {
        id: notifPopup
        wallpaperUrl: desktopWidgets.wallpaperUrl
    }

    NotchWindow {
        id: topNotch
    }

    // Fullscreen invisible backdrop: click outside or ESC to close Notch menus
    PanelWindow {
        id: notchBackdrop
        WlrLayershell.namespace: "quickshell:notch-backdrop"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: WlrLayershell.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        visible: topNotch.isMenuOpen

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: topNotch.closeAllMenus()
        }

        Shortcut {
            sequence: "Escape"
            enabled: topNotch.isMenuOpen
            onActivated: topNotch.closeAllMenus()
        }
    }

    SidebarWindow {
        id: musicSidebar
        notifServer: notifPopup
    }

    LauncherWindow {
        id: appLauncher
    }

    WallpaperWindow {
        id: wallpaperSelector
        desktopWidgetsRef: desktopWidgets
    }

    ClipboardWindow {
        id: clipboardHistory
    }

    EmojiWindow {
        id: emojiPicker
    }
}
