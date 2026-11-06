import Quickshell
import "widgets"
import "notifications"
import "notch"

ShellRoot {
    DesktopWidgetsWindow {
        id: desktopWidgets
    }

    NotificationPopupWindow {
        wallpaperUrl: desktopWidgets.wallpaperUrl
    }

    NotchWindow {}
}
