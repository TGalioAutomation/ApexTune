import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application icon for all windows
        if let appIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let appIcon = NSImage(contentsOfFile: appIconPath) {
            NSApp.applicationIconImage = appIcon
        }
        
        MenuBarManager.shared.ensureSetup()
        NSApp.setActivationPolicy(.accessory)
        hideMainWindowsOnLaunch()
        registerWindowObservers()
        openDashboardForUiTestingIfNeeded()
    }

    /// Mở sẵn bảng điều khiển khi khởi động bằng `--open-dashboard`,
    /// phục vụ kiểm thử UI tự động không thao tác được qua status item.
    private func openDashboardForUiTestingIfNeeded() {
        guard CommandLine.arguments.contains("--open-dashboard") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MenuBarManager.shared.toggleWindow()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func hideMainWindowsOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.hideStandardWindows()
            NSApp.hide(nil)
        }
    }
    
    private func registerWindowObservers() {
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow, !(window is MenuBarWindow) else { return }
            DispatchQueue.main.async {
                self?.restoreAccessoryModeIfNeeded()
            }
        }
        
        observers.append(closeObserver)
    }
    
    private func hideStandardWindows() {
        for window in NSApp.windows where !(window is MenuBarWindow) {
            window.orderOut(nil)
        }
    }
    
    private func restoreAccessoryModeIfNeeded() {
        let hasVisibleStandardWindow = NSApp.windows.contains { window in
            !(window is MenuBarWindow) && window.isVisible
        }
        
        guard !hasVisibleStandardWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
