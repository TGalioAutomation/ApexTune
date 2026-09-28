import Foundation
import Combine
import AppKit

// MARK: - Loại hàm tối ưu hóa

enum OptimizationType: String, CaseIterable, Identifiable {
    case freeMemory = "Giải phóng bộ nhớ"
    case flushDNS = "Làm mới DNS"
    case rebuildSpotlight = "Xây dựng lại chỉ mục Spotlight"
    case rebuildLaunchServices = "Xây dựng lại cơ sở dữ liệu Launch Services"
    case clearFontCache = "Xóa bộ đệm phông chữ"
    case repairPermissions = "Xác minh quyền ổ đĩa"
    case killBackgroundApps = "Đóng ứng dụng nền"
    case clearClipboard = "Xóa khay nhớ tạm"
    case clearRecentItems = "Xóa lịch sử gần đây"
    case restartFinder = "Khởi động lại Finder"
    case restartDock = "Khởi động lại Dock"
    case freePurgeableSpace = "Giải phóng dung lượng có thể dọn"
    case speedUpMail = "Tăng tốc Mail"
    case timeMachineThinning = "Dọn snapshot Time Machine"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .freeMemory: return "memorychip"
        case .flushDNS: return "network"
        case .rebuildSpotlight: return "magnifyingglass"
        case .rebuildLaunchServices: return "arrow.triangle.2.circlepath"
        case .clearFontCache: return "textformat"
        case .repairPermissions: return "lock.shield"
        case .killBackgroundApps: return "xmark.app"
        case .clearClipboard: return "doc.on.clipboard"
        case .clearRecentItems: return "clock.arrow.circlepath"
        case .restartFinder: return "folder"
        case .restartDock: return "dock.rectangle"
        case .freePurgeableSpace: return "server.rack"
        case .speedUpMail: return "envelope"
        case .timeMachineThinning: return "camera.on.rectangle"
        }
    }
    
    var description: String {
        switch self {
        case .freeMemory: return L("Dọn bộ nhớ hệ thống và giải phóng RAM không dùng đến")
        case .flushDNS: return L("Xóa bộ đệm DNS để khắc phục sự cố mạng")
        case .rebuildSpotlight: return L("Xây dựng lại chỉ mục tìm kiếm để sửa lỗi Spotlight")
        case .rebuildLaunchServices: return L("Làm mới Launch Services để sửa menu Mở bằng")
        case .clearFontCache: return L("Xóa bộ đệm phông chữ để sửa lỗi hiển thị chữ")
        case .repairPermissions: return L("Kiểm tra và sửa quyền truy cập thư mục hệ thống")
        case .killBackgroundApps: return L("Buộc đóng các ứng dụng nền không hoạt động")
        case .clearClipboard: return L("Xóa nội dung hiện có trong khay nhớ tạm")
        case .clearRecentItems: return L("Xóa danh sách tệp gần đây trong Finder")
        case .restartFinder: return L("Khởi động lại Finder để xử lý hiện tượng treo")
        case .restartDock: return L("Khởi động lại Dock để sửa lỗi biểu tượng")
        case .freePurgeableSpace: return L("Dọn dung lượng hệ thống có thể giải phóng")
        case .speedUpMail: return L("Tối ưu cơ sở dữ liệu Mail để tăng tốc")
        case .timeMachineThinning: return L("Dọn các snapshot Time Machine cũ trên máy")
        }
    }
    
    var requiresAdmin: Bool {
        switch self {
        case .rebuildSpotlight, .rebuildLaunchServices, .repairPermissions, .flushDNS, .timeMachineThinning, .freePurgeableSpace:
            return true
        default:
            return false
        }
    }
    
    var command: String {
        switch self {
        case .freeMemory:
            return "sudo purge"
        case .flushDNS:
            return "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
        case .rebuildSpotlight:
            return "sudo mdutil -E /"
        case .rebuildLaunchServices:
            return "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"
        case .clearFontCache:
            return "sudo atsutil databases -remove"
        case .repairPermissions:
            return "diskutil verifyPermissions /"
        case .killBackgroundApps:
            return "" // xử lý đặc biệt
        case .clearClipboard:
            return "pbcopy < /dev/null"
        case .clearRecentItems:
            return "rm -rf ~/Library/Application\\ Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/*"
        case .restartFinder:
            return "killall Finder"
        case .restartDock:
            return "killall Dock"
        case .freePurgeableSpace:
            return "tmutil thinlocalsnapshots / 1000000000 1" // 1GB, urgency 1
        case .speedUpMail:
            return "find ~/Library/Mail -name 'Envelope Index' -exec sqlite3 {} vacuum \\;"
        case .timeMachineThinning:
            return "tmutil thinlocalsnapshots / 100000000000 4" // 100GB, urgency 4
        }
    }
}

// MARK: - mô hình mục khởi động
class LaunchItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    
    @Published var isEnabled: Bool
    @Published var isSelected: Bool = true
    
    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.isEnabled = url.pathExtension == "plist"
    }
}

// MARK: - Áp dụng mô hình một cách nhanh chóng
class RunningAppItem: Identifiable, ObservableObject {
    let id = UUID()
    let app: NSRunningApplication
    let name: String
    let icon: NSImage
    @Published var isSelected: Bool = true
    
    init(app: NSRunningApplication) {
        self.app = app
        self.name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        self.icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

// MARK: - Dịch vụ tối ưu hóa hệ thống
class SystemOptimizer: ObservableObject {
    @Published var launchAgents: [LaunchItem] = []
    @Published var runningApps: [RunningAppItem] = []
    @Published var isScanning: Bool = false
    @Published var isOptimizing: Bool = false
    @Published var optimizationResult: String = ""
    @Published var backgroundApps: [NSRunningApplication] = []
    
    private let fileManager = FileManager.default
    private let agentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    
    // MARK: - Tối ưu hóa bằng một cú nhấp chuột
    func performOneClickOptimization() async -> (success: Bool, message: String) {
        await MainActor.run {
            isOptimizing = true
        }
        
        var results: [String] = []
        
        // 1. Đóng các ứng dụng đã chọn
        let selectedApps = runningApps.filter { $0.isSelected }
        var closedCount = 0
        for appItem in selectedApps {
            if appItem.app.terminate() {
                closedCount += 1
            }
        }
        if closedCount > 0 {
            results.append(String(format: L("đóng cửa %d ứng dụng"), closedCount))
        }
        
        // 2. bộ nhớ trống
        _ = runCommand("sudo purge 2>/dev/null || true")
        results.append(L("Tối ưu hóa bộ nhớ"))
        
        // 3. Xóa bảng nhớ tạm
        NSPasteboard.general.clearContents()
        results.append(L("Đã xóa bảng nhớ tạm"))
        
        // 4. Làm mới danh sách ứng dụng nền
        await MainActor.run {
            scanRunningApps()
        }
        
        let message = results.joined(separator: "，")
        
        await MainActor.run {
            isOptimizing = false
            optimizationResult = message
        }
        
        return (true, message)
    }
    
    // MARK: - Quét các ứng dụng đang chạy
    func scanRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontApp = NSWorkspace.shared.frontmostApplication
        
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer",
            "com.apple.TextInputMenuAgent",
            "com.apple.Spotlight",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter"
        ]
        
        let filteredApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            if protectedBundleIds.contains(bundleId) { return false }
            if bundleId == Bundle.main.bundleIdentifier { return false }
            if app == frontApp { return false }
            if app.activationPolicy != .regular { return false }
            return true
        }
        
        self.runningApps = filteredApps.map { RunningAppItem(app: $0) }
    }
    
    // MARK: - Đóng các ứng dụng đã chọn
    func terminateSelectedApps() async -> Int {
        var count = 0
        for appItem in runningApps where appItem.isSelected {
            if appItem.app.terminate() {
                count += 1
            }
        }
        await MainActor.run {
            scanRunningApps()
        }
        return count
    }
    
    // MARK: - Chọn tất cả/Bỏ chọn tất cả
    func selectAllApps(_ select: Bool) {
        for app in runningApps {
            app.isSelected = select
        }
        objectWillChange.send()
    }
    
    // MARK: - Thực hiện tối ưu hóa
    func performOptimization(_ type: OptimizationType) async -> (success: Bool, message: String) {
        await MainActor.run {
            isOptimizing = true
        }
        
        var success = false
        var message = ""
        
        switch type {
        case .killBackgroundApps:
            let count = await killBackgroundApps()
            success = true
            message = String(format: L("Đã đóng %d ứng dụng nền"), count)
            
        case .clearClipboard:
            NSPasteboard.general.clearContents()
            success = true
            message = L("Đã xóa bảng nhớ tạm")
            
        case .freeMemory, .flushDNS, .rebuildSpotlight, .rebuildLaunchServices, 
             .clearFontCache, .repairPermissions, .clearRecentItems, .restartFinder, .restartDock,
             .freePurgeableSpace, .speedUpMail, .timeMachineThinning:
            
            if type.requiresAdmin {
                let result = await executeWithAdminPrivileges(type.command)
                success = result.success
                message = result.success ? getSuccessMessage(for: type) : String(format: L("Thực thi không thành công: %@"), result.output)
            } else {
                _ = runCommand(type.command)
                success = true
                message = getSuccessMessage(for: type)
            }
        }
        
        await MainActor.run { [message] in
            isOptimizing = false
            optimizationResult = message
        }
        
        return (success, message)
    }
    
    private func getSuccessMessage(for type: OptimizationType) -> String {
        switch type {
        case .freeMemory: return L("bộ nhớ được giải phóng")
        case .flushDNS: return L("DNS xóa bộ nhớ cache")
        case .rebuildSpotlight: return L("Spotlight Chỉ số đang được xây dựng lại")
        case .rebuildLaunchServices: return L("Cơ sở dữ liệu dịch vụ khởi động đã được xây dựng lại")
        case .clearFontCache: return L("Bộ đệm phông chữ đã bị xóa, nên khởi động lại")
        case .repairPermissions: return L("Đã hoàn tất xác minh quyền")
        case .killBackgroundApps: return L("Ứng dụng nền đã bị đóng")
        case .clearClipboard: return L("Đã xóa bảng nhớ tạm")
        case .clearRecentItems: return L("Lịch sử sử dụng gần đây đã bị xóa")
        case .restartFinder: return L("Finder Đã khởi động lại")
        case .restartDock: return L("Dock Đã khởi động lại")
        case .freePurgeableSpace: return L("Không gian có thể xóa được phát hành")
        case .speedUpMail: return L("Cơ sở dữ liệu thư đã được tối ưu hóa")
        case .timeMachineThinning: return L("Ảnh chụp nhanh cỗ máy thời gian được làm sạch")
        }
    }
    
    // MARK: - Đóng ứng dụng nền
    private func killBackgroundApps() async -> Int {
        let runningApps = NSWorkspace.shared.runningApplications
        var killedCount = 0
        
        // Nhận các ứng dụng hiện đang hoạt động và ứng dụng hệ thống
        let frontApp = NSWorkspace.shared.frontmostApplication
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer",
            "com.apple.TextInputMenuAgent",
            "com.apple.Spotlight",
            "com.apple.notificationcenterui"
        ]
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            
            // Bỏ qua các ứng dụng bảo vệ
            if protectedBundleIds.contains(bundleId) { continue }
            // Bỏ qua ứng dụng hiện tại
            if bundleId == Bundle.main.bundleIdentifier { continue }
            // Bỏ qua ứng dụng nền trước hiện tại
            if app == frontApp { continue }
            // Bỏ qua các tiến trình nền không có giao diện
            if app.activationPolicy == .prohibited { continue }
            
            // Cố gắng tắt máy một cách duyên dáng
            if app.terminate() {
                killedCount += 1
            }
        }
        
        return killedCount
    }
    
    // MARK: - Thực thi với quyền quản trị viên
    private func executeWithAdminPrivileges(_ command: String) async -> (success: Bool, output: String) {
        // Escape đủ 2 lớp cho literal AppleScript (thoát \\ trước rồi ").
        let script = """
        do shell script "\(PrivilegedShell.appleScriptEscape(command))" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            
            if error == nil {
                return (true, result.stringValue ?? "")
            } else {
                let errorMsg = error?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                return (false, errorMsg)
            }
        }
        
        return (false, "Failed to create script")
    }
    
    // MARK: - Quét các mục khởi động
    func scanLaunchAgents() async {
        await MainActor.run {
            isScanning = true
            launchAgents.removeAll()
        }
        
        guard fileManager.fileExists(atPath: agentsPath.path) else {
            await MainActor.run { isScanning = false }
            return
        }
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: agentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            let items = urls
                .filter { $0.pathExtension == "plist" || $0.pathExtension == "disabled" }
                .map { LaunchItem(url: $0) }
                .sorted { $0.name < $1.name }
            
            await MainActor.run {
                self.launchAgents = items
                isScanning = false
            }
        } catch {
            print("Error scanning agents: \(error)")
            await MainActor.run { isScanning = false }
        }
    }
    
    // MARK: - Quét các ứng dụng nền
    func scanBackgroundApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontApp = NSWorkspace.shared.frontmostApplication
        
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer"
        ]
        
        backgroundApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            if protectedBundleIds.contains(bundleId) { return false }
            if bundleId == Bundle.main.bundleIdentifier { return false }
            if app == frontApp { return false }
            if app.activationPolicy == .prohibited { return false }
            return true
        }
    }
    
    // MARK: - Chuyển đổi trạng thái đã bật
    func toggleAgent(_ item: LaunchItem) async -> Bool {
        let currentUrl = item.url
        let newExtension = item.isEnabled ? "disabled" : "plist"
        let newUrl = currentUrl.deletingPathExtension().appendingPathExtension(newExtension)
        
        do {
            try fileManager.moveItem(at: currentUrl, to: newUrl)
            
            if item.isEnabled {
                _ = runCommand("launchctl unload \"\(currentUrl.path)\"")
            } else {
                _ = runCommand("launchctl load \"\(newUrl.path)\"")
            }
            
            await scanLaunchAgents()
            return true
        } catch {
            print("Failed to toggle agent: \(error)")
            return false
        }
    }
    
    // MARK: - Xóa các mục khởi động
    func removeAgent(_ item: LaunchItem) async {
        do {
            if item.isEnabled {
                _ = runCommand("launchctl unload \"\(item.url.path)\"")
            }
            // ⚠️ Sửa lỗi bảo mật: sử dụngtrashItemthay thếremoveItem
            try fileManager.trashItem(at: item.url, resultingItemURL: nil)
            print("[Optimizer] ✅ Moved launch agent to trash: \(item.name)")
            await scanLaunchAgents()
        } catch {
            print("[Optimizer] ⚠️ Failed to remove agent: \(error)")
        }
    }
    
    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
