import Quickshell

ShellRoot {
    DesktopWidgetsWindow {
        id: desktopWidgets
    }

    NotificationPopupWindow {
        wallpaperUrl: desktopWidgets.wallpaperUrl
    }
}
