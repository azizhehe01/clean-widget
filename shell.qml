import Quickshell
import "widgets"
import "notifications"
import "notch"
import "sidebar"
import "launcher"

ShellRoot {
    DesktopWidgetsWindow {
        id: desktopWidgets
    }

    NotificationPopupWindow {
        id: notifPopup
        wallpaperUrl: desktopWidgets.wallpaperUrl
    }

    NotchWindow {}

    SidebarWindow {
        id: musicSidebar
        notifServer: notifPopup
    }

    LauncherWindow {
        id: appLauncher
    }
}
