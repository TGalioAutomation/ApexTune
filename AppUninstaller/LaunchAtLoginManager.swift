import Foundation
import ServiceManagement

/// Quản lý "Khởi động cùng macOS" qua SMAppService (macOS 13+).
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("[LaunchAtLogin] Lỗi: \(error.localizedDescription)")
        }
        refresh()
    }
}
