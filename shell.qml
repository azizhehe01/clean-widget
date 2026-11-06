import Quickshell
import "widgets"
import "notifications"
import "notch"
import "sidebar"

ShellRoot {
    DesktopWidgetsWindow {
        id: desktopWidgets
    }

    NotificationPopupWindow {
        wallpaperUrl: desktopWidgets.wallpaperUrl
    }

    NotchWindow {}

    SidebarWindow {
        id: musicSidebar
    }
}
