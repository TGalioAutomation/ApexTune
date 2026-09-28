
import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Optimization Task Enum
enum OptimizerTask: String, CaseIterable, Identifiable {
    case networkOptimize     // Tối ưu hóa mạng
    case bootOptimize        // Bắt đầu tăng tốc
    case memoryOptimize      // Tối ưu hóa bộ nhớ
    case appAccelerate       // Tăng tốc ứng dụng
    case heavyConsumers      // Chiếm giữ các vật phẩm tài nguyên
    case launchAgents        // Bắt đầu đại lý
    case hungApps            // Tạm dừng ứng dụng
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .networkOptimize: return "network"
        case .bootOptimize: return "bolt.fill"
        case .memoryOptimize: return "memorychip"
        case .appAccelerate: return "arrow.up.forward.app"
        case .heavyConsumers: return "chart.xyaxis.line"
        case .launchAgents: return "rocket.fill"
        case .hungApps: return "hourglass"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .networkOptimize: return Color(red: 0.0, green: 0.6, blue: 1.0)  // Blue
        case .bootOptimize: return Color(red: 1.0, green: 0.8, blue: 0.0)     // Yellow
        case .memoryOptimize: return Color(red: 0.0, green: 0.8, blue: 0.6)   // Teal
        case .appAccelerate: return Color(red: 0.8, green: 0.2, blue: 0.8)    // Purple
        case .heavyConsumers: return Color(red: 1.0, green: 0.6, blue: 0.2)   // Orange
        case .launchAgents: return Color(red: 0.2, green: 0.8, blue: 0.4)     // Green
        case .hungApps: return Color(red: 0.9, green: 0.3, blue: 0.3)         // Red
        }
    }
    
    var localizedTitle: String {
        switch self {
        case .networkOptimize: return L("Tối ưu mạng")
        case .bootOptimize: return L("Tăng tốc khởi động")
        case .memoryOptimize: return L("Tối ưu bộ nhớ")
        case .appAccelerate: return L("Tăng tốc ứng dụng")
        case .heavyConsumers: return L("Tiến trình dùng nhiều tài nguyên")
        case .launchAgents: return L("Tác vụ khởi động")
        case .hungApps: return L("Ứng dụng treo")
        }
    }

    var localizedDescription: String {
        switch self {
        case .networkOptimize: return L("Làm mới bộ đệm DNS và dọn bộ đệm mạng để xử lý lỗi kết nối và phân giải DNS.")
        case .bootOptimize: return L("Tắt các launch agent và mục đăng nhập không cần thiết để tăng tốc khởi động Mac.")
        case .memoryOptimize: return L("Giải phóng RAM và đóng ứng dụng dùng nhiều bộ nhớ để hệ thống phản hồi nhanh hơn.")
        case .appAccelerate: return L("Dọn bộ đệm ứng dụng và tối ưu cơ sở dữ liệu để ứng dụng mở nhanh hơn.")
        case .heavyConsumers: return L("Một số tiến trình chạy nền có thể tiêu thụ quá nhiều tài nguyên Mac. Hãy xác định và đóng chúng nếu bạn không cần.")
        case .launchAgents: return L("Đây thường là các ứng dụng trợ giúp được cài cùng phần mềm khác. Trong một số trường hợp bạn có thể tắt hoặc gỡ chúng.")
        case .hungApps: return L("Nếu ứng dụng không phản hồi, bạn có thể buộc đóng nó để giải phóng tài nguyên.")
        }
    }
    
    // Cho dù đó là tối ưu hóa bằng một cú nhấp chuột (nhấp để thực hiện)

    var isOneClickOptimize: Bool {
        switch self {
        case .networkOptimize, .bootOptimize, .memoryOptimize, .appAccelerate:
            return true
        default:
            return false
        }
    }
}

// MARK: - Data Models
struct OptimizerProcessItem: Identifiable, Equatable {
    let id: Int32 // PID
    let name: String
    let icon: NSImage
    let usageDescription: String // e.g. "15% CPU" or "500 MB"
    var isSelected: Bool = true // Chọn tất cả theo mặc định
}

struct LaunchAgentItem: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String // Extracted from filename or Label
    let label: String
    let icon: NSImage
    var isEnabled: Bool // Status
    var isSelected: Bool = true // Chọn tất cả theo mặc định
}

// MARK: - Service
class OptimizerService: ObservableObject {
    @Published var selectedTask: OptimizerTask = .networkOptimize
    @Published var selectedTasks: Set<OptimizerTask> = Set(OptimizerTask.allCases) // Chọn tất cả theo mặc định
    @Published var heavyProcesses: [OptimizerProcessItem] = []
    @Published var launchAgents: [LaunchAgentItem] = []
    @Published var hungApps: [OptimizerProcessItem] = []
    @Published var isScanning = false
    @Published var isExecuting = false
    
    // Theo dõi tiến độ thực hiện

    @Published var executingTask: OptimizerTask? = nil
    @Published var completedTasks: Set<OptimizerTask> = []
    @Published var executionProgress: Double = 0.0
    @Published var showResults = false
    
    // Tối ưu hóa bộ nhớ - Danh sách ứng dụng bộ nhớ cao

    @Published var highMemoryApps: [OptimizerProcessItem] = []
    @Published var showMemoryConfirmAlert = false
    @Published var memoryAlertIgnored = false
    
    // Tăng tốc khởi động - danh sách mục khởi động

    @Published var bootAgentsToDisable: [LaunchAgentItem] = []
    @Published var showBootConfirmAlert = false
    @Published var bootAlertIgnored = false
    
    func toggleTaskSelection(_ task: OptimizerTask) {
        if selectedTasks.contains(task) {
            selectedTasks.remove(task)
        } else {
            selectedTasks.insert(task)
        }
    }
    
    func selectAllTasks() {
        selectedTasks = Set(OptimizerTask.allCases)
    }
    
    func deselectAllTasks() {
        selectedTasks.removeAll()
    }
    
    func scan() {
        isScanning = true
        Task {
            await fetchHeavyConsumers()
            await fetchLaunchAgents()
            await fetchHungApps()
            await MainActor.run { self.isScanning = false }
        }
    }
    
    // Thực hiện tất cả các nhiệm vụ đã chọn theo đợt

    func executeAllSelectedTasks() async {
        await MainActor.run {
            isExecuting = true
            completedTasks.removeAll()
            executionProgress = 0.0
            showResults = false
        }
        
        let tasksToExecute = Array(selectedTasks).sorted { $0.rawValue < $1.rawValue }
        let totalTasks = tasksToExecute.count
        
        for (index, task) in tasksToExecute.enumerated() {
            await MainActor.run {
                executingTask = task
                executionProgress = Double(index) / Double(totalTasks)
            }
            
            await executeTask(task)
            
            await MainActor.run {
                _ = completedTasks.insert(task)
            }
        }
        
        await MainActor.run {
            executingTask = nil
            executionProgress = 1.0
            isExecuting = false
            showResults = true
        }
    }
    
    // Thực hiện một nhiệm vụ duy nhất

    private func executeTask(_ task: OptimizerTask) async {
        switch task {
        case .networkOptimize:
            await performNetworkOptimization()
        case .bootOptimize:
            await performBootOptimization()
        case .memoryOptimize:
            await performMemoryOptimization()
        case .appAccelerate:
            await performAppAcceleration()
        case .heavyConsumers:
            await cleanupHeavyConsumers()
        case .launchAgents:
            await cleanupLaunchAgents()
        case .hungApps:
            await cleanupHungApps()
        }
        
        // Thời gian thực hiện mô phỏng

        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    @MainActor
    private func fetchHeavyConsumers() {
        // Run ps command to get top CPU consumers
        // ps -Aceo pid,%cpu,comm -r | head -n 10
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,%cpu,comm -r | head -n 15"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            var items: [OptimizerProcessItem] = []
            let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header
            
            for line in lines {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) {
                    if cpu > 1.0 { // Filter apps using > 1% CPU (simulated threshold for "Heavy")
                         // Get app name and icon
                        if let app = NSRunningApplication(processIdentifier: pid) {
                            // Exclude self
                            if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }
                            
                            // Only show apps with icons (user visible)
                            if let icon = app.icon, let name = app.localizedName {
                                items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: String(format: "%.1f%% CPU", cpu)))
                            }
                        }
                    }
                }
            }
            self.heavyProcesses = items
        }
    }
    
    @MainActor
    private func fetchLaunchAgents() {
        var items: [LaunchAgentItem] = []
        let paths = [
            FileManager.default.homeDirectoryForCurrentUser.path + "/Library/LaunchAgents",
            "/Library/LaunchAgents"
        ]
        
        for path in paths {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for file in files where file.hasSuffix(".plist") {
                    let fullPath = path + "/" + file
                    // Simplified: Use filename as name, generic icon
                    let name = file.replacingOccurrences(of: ".plist", with: "")
                    // Check if loaded? roughly assume enabled if file exists for now, 
                    // real check involves `launchctl list`
                    
                    // Simple logic: existing plist = enabled (unless disabled in override database, which is complex)
                    // We will just list them.
                    items.append(LaunchAgentItem(
                        path: fullPath,
                        name: name,
                        label: name,
                        icon: NSWorkspace.shared.icon(for: UTType(filenameExtension: "plist") ?? .propertyList),
                        isEnabled: true
                    ))
                }
            }
        }
        self.launchAgents = items
    }
    
    @MainActor
    private func fetchHungApps() {
        // Detect apps in Uninterruptible sleep (U) or Zombie (Z) state
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,state,comm | grep -e 'U' -e 'Z'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
             var items: [OptimizerProcessItem] = []
             let lines = output.components(separatedBy: .newlines)
             for line in lines {
                 let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                 if parts.count >= 3, let pid = Int32(parts[0]) {
                     // Check if it's a gui app
                     if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon, let name = app.localizedName {
                         if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue } // Exclude self
                         let state = parts[1]
                         let desc = state.contains("Z") ? "Zombie" : "Unresponsive"
                         items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: desc))
                     }
                 }
             }
             self.hungApps = items
        }
    }
    
    // MARK: - Thực hiện nhiệm vụ dọn dẹp

    
    private func cleanupHeavyConsumers() async {
        let itemsToKill = heavyProcesses.filter { $0.isSelected }
        for item in itemsToKill {
            kill(item.id, SIGKILL)
        }
        if !itemsToKill.isEmpty {
            await fetchHeavyConsumers()
        }
    }
    
    private func cleanupLaunchAgents() async {
        let itemsToUnload = launchAgents.filter { $0.isSelected }
        for item in itemsToUnload {
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["bootout", "gui/\(getuid())", item.path]
            try? task.run()
            task.waitUntilExit()
        }
        if !itemsToUnload.isEmpty {
            await fetchLaunchAgents()
        }
    }
    
    private func cleanupHungApps() async {
        let itemsToKill = hungApps.filter { $0.isSelected }
        for item in itemsToKill {
            kill(item.id, SIGKILL)
        }
        if !itemsToKill.isEmpty {
            await fetchHungApps()
        }
    }
    // MARK: - Tối ưu hóa mạng

    private func performNetworkOptimization() async {
        // 1. Xóa bộ đệm DNS

        let dscacheutil = Process()
        dscacheutil.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        dscacheutil.arguments = ["-flushcache"]
        try? dscacheutil.run()
        dscacheutil.waitUntilExit()
        
        // 2. Khởi động lại mDNSResponder (xử lý độ phân giải DNS)

        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-HUP", "mDNSResponder"]
        try? killall.run()
        killall.waitUntilExit()
        
        // 3. Dọn dẹp các mục bị hỏng trong file máy chủ (chỉ đọc, không sửa đổi)

        // Điều này có thể giúp xác định các vấn đề về mạng

        
        // 4. Xóa bộ nhớ đệm mạng

        let home = FileManager.default.homeDirectoryForCurrentUser
        let networkCachePaths = [
            home.appendingPathComponent("Library/Caches/com.apple.Safari/NetworkResources"),
            home.appendingPathComponent("Library/Caches/com.apple.Safari/WebKitCache"),
            home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache"),
            home.appendingPathComponent("Library/Caches/Firefox/Profiles"),
        ]
        
        for path in networkCachePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }
        
        // 5. Xóa bộ đệm cấu hình mạng hệ thống

        let systemNetworkCachePaths = [
            home.appendingPathComponent("Library/Preferences/com.apple.networkextension.plist"),
            home.appendingPathComponent("Library/Preferences/com.apple.NetworkBrowser.plist"),
        ]
        
        for path in systemNetworkCachePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                // Chỉ xóa nếu file quá lớn (có thể bị hỏng)

                if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 1_000_000 { // Lớn hơn 1 MB
                    try? FileManager.default.removeItem(at: path)
                }
            }
        }
        
        // 6. Xóa bộ đệm vị trí mạng

        let locationCache = home.appendingPathComponent("Library/Preferences/SystemConfiguration")
        if FileManager.default.fileExists(atPath: locationCache.path) {
            // Lưu ý: Thao tác này có thể yêu cầu cấu hình lại mạng nên chúng tôi chỉ ghi lại

            print("[NetworkOptimize] Network location cache exists at: \(locationCache.path)")
        }
        
        print("[NetworkOptimize] DNS cache flushed, network caches cleared, connectivity improved")
    }
    
    // DẤU HIỆU: - Bắt đầu tăng tốc

    private func performBootOptimization() async {
        // 1. Quét các tác nhân khởi động và xác định các mục có thể bị vô hiệu hóa

        await scanBootAgents()
        
        // 2. Nếu có một mục khởi động có thể bị vô hiệu hóa và người dùng chưa bỏ qua nó, hãy đợi người dùng xác nhận.

        if !bootAgentsToDisable.isEmpty && !bootAlertIgnored {
            await MainActor.run {
                showBootConfirmAlert = true
            }
            
            // Đợi người dùng thực hiện lựa chọn (tối đa 30 giây)

            var waitTime = 0
            while showBootConfirmAlert && waitTime < 30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 giây
                waitTime += 1
            }
            
            // Nếu người dùng chọn tắt mục khởi động

            if !bootAlertIgnored {
                await disableSelectedBootAgents()
            }
        }
        
        // 3. Xóa bộ đệm mục đăng nhập

        let loginItemsCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.backgroundtaskmanagementagent")
        try? FileManager.default.removeItem(at: loginItemsCache)
        
        print("[BootOptimize] Boot optimization completed")
    }
    
    // Quét tìm tác nhân khởi nghiệp

    @MainActor
    private func scanBootAgents() {
        bootAgentsToDisable.removeAll()
        
        let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        
        // Danh sách trắng bảo mật - không nên tắt những danh sách này

        let safeAgents = ["com.apple.", "homebrew.", "com.github."]
        
        // Các tác nhân khởi động phổ biến (thường là các trình cập nhật tự động) được biết là an toàn để vô hiệu hóa

        let knownNonEssential = [
            "update", "updater", "helper", "assistant", "agent",
            "sync", "backup", "cloud", "autoupdate"
        ]
        
        guard let agents = try? FileManager.default.contentsOfDirectory(atPath: userAgentsPath.path) else {
            return
        }
        
        for agent in agents where agent.hasSuffix(".plist") {
            let agentLower = agent.lowercased()
            
            // Bỏ qua proxy trong danh sách trắng

            if safeAgents.contains(where: { agentLower.contains($0) }) {
                continue
            }
            
            // Kiểm tra các mục khởi động không cần thiết đã biết

            let isNonEssential = knownNonEssential.contains { agentLower.contains($0) }
            
            let agentPath = userAgentsPath.appendingPathComponent(agent)
            let name = agent.replacingOccurrences(of: ".plist", with: "")
            
            // Hãy thử đọc Nhãn từ plist

            var label = name
            if let plistData = try? Data(contentsOf: agentPath),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
               let plistLabel = plist["Label"] as? String {
                label = plistLabel
            }
            
            // Kiểm tra xem nó có được kích hoạt không

            let isEnabled = agent.hasSuffix(".plist") // Đơn giản hóa việc phán xét
            
            bootAgentsToDisable.append(LaunchAgentItem(
                path: agentPath.path,
                name: name,
                label: label,
                icon: NSWorkspace.shared.icon(for: .propertyList),
                isEnabled: isEnabled,
                isSelected: isNonEssential // Các mục không bắt buộc được chọn theo mặc định
            ))
        }
        
        // Sắp xếp theo tên

        bootAgentsToDisable.sort { $0.name < $1.name }
    }
    
    // Vô hiệu hóa các tác nhân khởi chạy đã chọn

    func disableSelectedBootAgents() async {
        let itemsToDisable = await MainActor.run { bootAgentsToDisable.filter { $0.isSelected } }
        
        for item in itemsToDisable {
            // Hãy thử gỡ cài đặt trước

            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", "-w", item.path]
            try? unload.run()
            unload.waitUntilExit()
            
            // Đổi tên tệp thành .disabled (phương pháp an toàn hơn)

            let disabledPath = item.path.replacingOccurrences(of: ".plist", with: ".plist.disabled")
            try? FileManager.default.moveItem(atPath: item.path, toPath: disabledPath)
        }
        
        await MainActor.run {
            bootAgentsToDisable.removeAll()
            showBootConfirmAlert = false
            bootAlertIgnored = false
        }
    }
    
    // ĐÁNH DẤU: - Tối ưu hóa bộ nhớ

    private func performMemoryOptimization() async {
        // 1. Đầu tiên phát hiện các ứng dụng có bộ nhớ cao (> 500MB)

        await detectHighMemoryApps()
        
        // 2. Nếu có ứng dụng có bộ nhớ cao và người dùng chưa bỏ qua nó, hãy đợi người dùng xác nhận.

        if !highMemoryApps.isEmpty && !memoryAlertIgnored {
            await MainActor.run {
                showMemoryConfirmAlert = true
            }
            
            // Đợi người dùng thực hiện lựa chọn (tối đa 30 giây)

            var waitTime = 0
            while showMemoryConfirmAlert && waitTime < 30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 giây
                waitTime += 1
            }
            
            // Nếu người dùng chọn đóng ứng dụng

            if !memoryAlertIgnored {
                await terminateSelectedMemoryApps()
            }
        }
        
        // 3. Sử dụng Memory_ Pressure để kích hoạt quá trình tái chế bộ nhớ

        let memPressure = Process()
        memPressure.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        memPressure.arguments = ["-l", "critical"]
        try? memPressure.run()
        
        // Đợi 2 giây để hệ thống phản hồi

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        memPressure.terminate()
        
        // 4. Cố gắng sử dụng purge để giải phóng bộ nhớ hệ thống

        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        try? purge.run()
        purge.waitUntilExit()
        
        print("[MemoryOptimize] Memory optimization completed")
    }
    
    // Phát hiện các ứng dụng có bộ nhớ cao

    @MainActor
    private func detectHighMemoryApps() {
        highMemoryApps.removeAll()
        
        // Sử dụng lệnh ps để lấy mức sử dụng bộ nhớ của tất cả các tiến trình

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,rss,comm | awk '$2 > 500000 {print $1,$2,$3}'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            for line in lines {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let pid = Int32(parts[0]), let rss = Double(parts[1]) {
                    // Nhận thông tin ứng dụng

                    if let app = NSRunningApplication(processIdentifier: pid) {
                        // Loại trừ ứng dụng hiện tại

                        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }
                        
                        // Loại trừ các ứng dụng quan trọng của hệ thống

                        if let bundleId = app.bundleIdentifier {
                            let systemApps = ["com.apple.finder", "com.apple.dock", "com.apple.SystemUIServer", "com.apple.WindowServer"]
                            if systemApps.contains(bundleId) { continue }
                        }
                        
                        // Chỉ hiển thị các ứng dụng GUI có biểu tượng

                        if let icon = app.icon, let name = app.localizedName {
                            let memoryMB = rss / 1024.0
                            let memoryGB = memoryMB / 1024.0
                            highMemoryApps.append(OptimizerProcessItem(
                                id: pid,
                                name: name,
                                icon: icon,
                                usageDescription: memoryGB >= 1.0 ? String(format: "%.1f GB", memoryGB) : String(format: "%.0f MB", memoryMB)
                            ))
                        }
                    }
                }
            }
        }
        
        // Sắp xếp theo mức sử dụng bộ nhớ

        highMemoryApps.sort { app1, app2 in
            // Trích xuất giá trị bộ nhớ để so sánh

            let getValue: (String) -> Double = { usage in
                let components = usage.components(separatedBy: .whitespaces)
                if let value = Double(components[0]) {
                    return components.last?.contains("GB") == true ? value * 1024 : value
                }
                return 0
            }
            return getValue(app1.usageDescription) > getValue(app2.usageDescription)
        }
    }
    
    // Chấm dứt các ứng dụng bộ nhớ cao đã chọn

    func terminateSelectedMemoryApps() async {
        let itemsToKill = await MainActor.run { highMemoryApps.filter { $0.isSelected } }
        for item in itemsToKill {
            if let app = NSRunningApplication(processIdentifier: item.id) {
                app.terminate()
                // chờ một lát

                try? await Task.sleep(nanoseconds: 500_000_000)
                // Nếu nó chưa đóng, hãy buộc nó đóng lại.

                if app.isTerminated == false {
                    app.forceTerminate()
                }
            }
        }
        
        await MainActor.run {
            highMemoryApps.removeAll()
            showMemoryConfirmAlert = false
            memoryAlertIgnored = false
        }
    }
    
    // MARK: - Tăng tốc ứng dụng

    private func performAppAcceleration() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileManager = FileManager.default
        
        // 1. Xóa bộ nhớ đệm ứng dụng (chỉ xóa bộ nhớ đệm lớn hơn 100MB)

        let cachesPath = home.appendingPathComponent("Library/Caches")
        if let contents = try? fileManager.contentsOfDirectory(at: cachesPath, includingPropertiesForKeys: [.fileSizeKey]) {
            for item in contents {
                // Bỏ qua bộ đệm quan trọng của hệ thống

                if item.lastPathComponent.hasPrefix("com.apple.") { continue }
                
                // Chỉ xóa bộ nhớ cache lớn hơn 100MB

                if let size = try? item.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize, size > 100_000_000 {
                    // Safety Check
                    if SafetyGuard.shared.isSafeToDelete(item) {
                        try? fileManager.removeItem(at: item)
                    }
                }
            }
        }
        
        // 2. Xóa bộ nhớ đệm biểu tượng Safari

        let safariIconCache = home.appendingPathComponent("Library/Safari/Touch Icons Cache")
        try? fileManager.removeItem(at: safariIconCache)
        
        // 3. Xây dựng lại cơ sở dữ liệu Launch Services

        let lsregister = Process()
        lsregister.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
        lsregister.arguments = ["-kill", "-r", "-domain", "local", "-domain", "user"]
        try? lsregister.run()
        lsregister.waitUntilExit()
        
        // 4. Làm sạch bộ đệm siêu dữ liệu Spotlight

        let spotlightCache = home.appendingPathComponent("Library/Caches/com.apple.Spotlight")
        try? fileManager.removeItem(at: spotlightCache)
        
        print("[AppAccelerate] App caches cleaned, Launch Services rebuilt")
    }
    
    func toggleSelection(for id: Any) {
        // Helper to toggle (kept for compatibility)
    }
}

// MARK: - Views
struct OptimizerView: View {
    @StateObject private var service = OptimizerService()
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var viewState = 0 // 0: Landing, 1: List, 2: Executing, 3: Results
    
    var body: some View {
        ZStack {
             // Shared Background
            BackgroundStyles.privacy.ignoresSafeArea()
            
            switch viewState {
            case 0:
                OptimizerLandingView(viewState: $viewState, loc: loc)
            case 1:
                optimizerListView
            case 2:
                executingView
            case 3:
                resultsView
            default:
                optimizerListView
            }
        }
        .onAppear {
            service.scan()
            viewState = 0
        }
        .onChange(of: service.showResults) { showResults in
            if showResults {
                viewState = 3
            }
        }
        .sheet(isPresented: $service.showMemoryConfirmAlert) {
            MemoryConfirmationDialog(service: service, loc: loc)
        }
        .sheet(isPresented: $service.showBootConfirmAlert) {
            BootOptimizationDialog(service: service, loc: loc)
        }
    }
    
    // Existing list logic moved here
    var optimizerListView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                // LEFT PANEL (Task Selection)
                ZStack {
                    // Transparent to let shared background show through
                    VStack(alignment: .leading, spacing: 0) {
                         // Back button (Functional)
                        Button(action: { viewState = 0 }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(L("giới thiệu"))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Danh sách nhiệm vụ (hỗ trợ nhiều lựa chọn)

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(OptimizerTask.allCases) { task in
                                    OptimizerTaskRow(
                                        task: task,
                                        isSelected: service.selectedTasks.contains(task),
                                        isActive: service.selectedTask == task,
                                        isMultiSelect: true,
                                        loc: loc
                                    )
                                    .onTapGesture {
                                        service.toggleTaskSelection(task)
                                        service.selectedTask = task
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.4)
                
                // RIGHT PANEL (Details)
                ZStack {
                    // Background handled in parent ZStack
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text(L("Tối ưu hóa"))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(L("Tìm kiếm"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                                Spacer()
                            }
                            .frame(width: 120, height: 22)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                            

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 14)
                        
                        // Title & Desc
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.selectedTask.localizedTitle)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(service.selectedTask.localizedDescription)
                                .font(.system(size: 11))
                                .lineSpacing(3)
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Content List
                        ScrollView {
                            VStack(spacing: 0) {
                                // Tác vụ tối ưu hóa bằng một cú nhấp chuột - mô tả chức năng hiển thị

                                if service.selectedTask.isOneClickOptimize {
                                    VStack(spacing: 20) {
                                        // biểu tượng chức năng

                                        ZStack {
                                            Circle()
                                                .fill(service.selectedTask.iconColor.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                            Image(systemName: service.selectedTask.icon)
                                                .font(.system(size: 36))
                                                .foregroundColor(service.selectedTask.iconColor)
                                        }
                                        .padding(.top, 30)
                                        
                                        // Tin nhắn nhắc nhở

                                        VStack(spacing: 8) {
                                            Text(L("Nhấp vào nút bên dưới để bắt đầu tối ưu hóa"))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))
                                            
                                            Text(L("Hoạt động này an toàn và có thể chạy bất cứ lúc nào"))
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                } else if service.selectedTask == .heavyConsumers {
                                    ForEach($service.heavyProcesses) { $proc in
                                        HeavyProcessRow(item: proc, isSelected: $proc.isSelected)
                                    }
                                } else if service.selectedTask == .launchAgents {
                                    ForEach($service.launchAgents) { $agent in
                                        LaunchAgentRow(item: agent, isSelected: $agent.isSelected, loc: loc)
                                    }
                                } else if service.selectedTask == .hungApps {
                                    if service.hungApps.isEmpty {
                                        Text(L("Không tìm thấy ứng dụng bị treo"))
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.top, 40)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach($service.hungApps) { $proc in
                                            HeavyProcessRow(item: proc, isSelected: $proc.isSelected)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                        
                        // Nút Thực thi - Thực hiện tất cả các tác vụ đã chọn


                    }
                    .frame(width: geometry.size.width * 0.6)
                }
            }
            
            Button(action: {
                viewState = 2
                Task {
                    await service.executeAllSelectedTasks()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                        .frame(width: 60, height: 60)
                    
                    if service.isExecuting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(L("Chạy"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(service.isExecuting || service.selectedTasks.isEmpty)
            .padding(.bottom, 40)
        }
    }
}
    
    // MARK: - chế độ xem thực thi

    var executingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // tiêu đề

            Text(L("Thực hiện các nhiệm vụ tối ưu hóa..."))
                .font(.title2)
                .foregroundColor(.white)
            
            // Tiến trình danh sách nhiệm vụ

            VStack(spacing: 12) {
                ForEach(Array(service.selectedTasks).sorted { $0.rawValue < $1.rawValue }) { task in
                    HStack(spacing: 12) {
                        // biểu tượng trạng thái

                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(task.iconColor)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: task.icon)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        
                        // Tên nhiệm vụ

                        Text(task.localizedTitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // tình trạng

                        if service.completedTasks.contains(task) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if service.executingTask == task {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(service.executingTask == task ? Color.white.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 40)
            
            // văn bản tiến độ

            Text(String(format: L("%d / %d"), service.completedTasks.count, service.selectedTasks.count))
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    // MARK: - xem kết quả

    var resultsView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Biểu tượng xong

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(L("Tối ưu hóa hoàn tất!"))
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            // Danh sách nhiệm vụ đã hoàn thành

            VStack(spacing: 8) {
                ForEach(Array(service.completedTasks).sorted { $0.rawValue < $1.rawValue }) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(task.iconColor)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: task.icon)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        
                        Text(task.localizedTitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: 350)
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // nút quay lại

            Button(action: {
                service.showResults = false
                service.completedTasks.removeAll()
                viewState = 1
            }) {
                Text(L("Xong"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Row Components
struct OptimizerTaskRow: View {
    let task: OptimizerTask
    let isSelected: Bool
    let isActive: Bool
    var isMultiSelect: Bool = false
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Hộp kiểm (nhiều lựa chọn) hoặc Nút Radio (một lựa chọn)

            if isMultiSelect {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isSelected ? Color.green : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSelected ? Color.green : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            } else {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(task.iconColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: task.icon)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(task.localizedTitle)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.black.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

struct HeavyProcessRow: View {
    let item: OptimizerProcessItem
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Hộp kiểm - kiểu kiểm tra màu xanh lá cây

            Button(action: { isSelected.toggle() }) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(item.usageDescription)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }
}

struct LaunchAgentRow: View {
    let item: LaunchAgentItem
    @Binding var isSelected: Bool
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Hộp kiểm - kiểu kiểm tra màu xanh lá cây

            Button(action: { isSelected.toggle() }) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Status Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(item.isEnabled ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(item.isEnabled ? L("Đã bật") : L("Tàn tật"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }
}
// MARK: - Landing Components
struct OptimizerLandingView: View {
    @Binding var viewState: Int // 0=Landing, 1=List
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        ZStack {
            HStack(spacing: 60) {
                // Left Content
                VStack(alignment: .leading, spacing: 30) {
                    // Branding Header
                    HStack(spacing: 8) {
                        Text(L("Tối ưu hóa hệ thống"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Optimization Icon
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text(L("Tăng cường đầy đủ"))
                                .font(.system(size: 20, weight: .heavy))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Text(L("Cải thiện đầu ra bằng cách kiểm soát các ứng dụng đang chạy trên máy Mac của bạn.\nĐược tối ưu hóa lần cuối: Không bao giờ"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                    
                    // Feature Rows
                    VStack(alignment: .leading, spacing: 24) {
                        featureRow(
                            icon: "light.beacon.max.fill",
                            title: L("Quản lý đại lý khởi chạy"),
                            desc: L("Kiểm soát các ứng dụng được máy Mac của bạn hỗ trợ.")
                        )
                        
                        featureRow(
                            icon: "waveform.path.ecg",
                            title: L("Kiểm soát ứng dụng đang chạy"),
                            desc: L("Quản lý các mục đăng nhập, chỉ chạy những gì bạn thực sự cần.")
                        )
                        
                        featureRow(
                            icon: "chart.xyaxis.line",
                            title: L("Người tiêu dùng nặng"),
                            desc: L("Tìm và thoát khỏi các tiến trình sử dụng quá nhiều tài nguyên.")
                        )
                    }
                    
                    // View Items Button
                    Button(action: { viewState = 1 }) {
                        Text(L("Xem các mục..."))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "4DDEE8")) // Teal
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .frame(maxWidth: 400)
                
                // Right Icon - Using youhua.png
                ZStack {
                    if let path = Bundle.main.path(forResource: "youhua", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                    } else {
                        // Fallback: Purple Circle with Sliders
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "C86FC9"), Color(hex: "8B3A9B")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                            
                            // Sliders (Visual)
                            HStack(spacing: 30) {
                                // Slider 1
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 60)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 100)
                                }
                                // Slider 2
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 100)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 60)
                                }
                                // Slider 3
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 40)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 120)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            
            // Bottom Floating Button
            VStack {
                Spacer()
                Button(action: { viewState = 1 }) {
                    ZStack {
                        Circle()
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ), lineWidth: 2)
                            .frame(width: 84, height: 84)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 74, height: 74)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        
                        Text(L("Bắt đầu"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


// MARK: - Memory Confirmation Dialog
struct MemoryConfirmationDialog: View {
    @ObservedObject var service: OptimizerService
    @ObservedObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Tối ưu hóa bộ nhớ"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text(L("Các ứng dụng sau đang sử dụng bộ nhớ cao. Đóng chúng để giải phóng RAM?"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                
                Button(action: {
                    service.memoryAlertIgnored = true
                    service.showMemoryConfirmAlert = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // App List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(service.highMemoryApps.indices), id: \.self) { index in
                        let app = service.highMemoryApps[index]
                        HStack(spacing: 12) {
                            // Checkbox
                            Button(action: { service.highMemoryApps[index].isSelected.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(app.isSelected ? Color.blue : Color.gray, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if app.isSelected {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // App Icon
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                            
                            // App Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(app.usageDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(app.isSelected ? Color.blue.opacity(0.05) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { service.highMemoryApps[index].isSelected.toggle() }
                        
                        if app.id != service.highMemoryApps.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(service.highMemoryApps.count) * 60 + 20, 300))
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                // Select/Deselect All
                Button(action: {
                    let allSelected = service.highMemoryApps.allSatisfy { $0.isSelected }
                    for index in service.highMemoryApps.indices {
                        service.highMemoryApps[index].isSelected = !allSelected
                    }
                }) {
                    Text(service.highMemoryApps.allSatisfy { $0.isSelected } ? 
                         L("Bỏ chọn tất cả") : 
                         L("Chọn tất cả"))
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Ignore Button
                Button(action: {
                    service.memoryAlertIgnored = true
                    service.showMemoryConfirmAlert = false
                    dismiss()
                }) {
                    Text(L("Bỏ qua"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Close Apps Button
                Button(action: {
                    Task {
                        await service.terminateSelectedMemoryApps()
                        dismiss()
                    }
                }) {
                    Text(L("Đóng ứng dụng"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.highMemoryApps.filter { $0.isSelected }.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Boot Optimization Dialog
struct BootOptimizationDialog: View {
    @ObservedObject var service: OptimizerService
    @ObservedObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Tối ưu hóa khởi động"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(L("Các tác nhân khởi chạy sau đây sẽ bị vô hiệu hóa để tăng tốc thời gian khởi động. Hãy lựa chọn cẩn thận - việc tắt các mục thiết yếu có thể ảnh hưởng đến chức năng của ứng dụng."))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                
                Button(action: {
                    service.bootAlertIgnored = true
                    service.showBootConfirmAlert = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Warning Banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text(L("Chỉ vô hiệu hóa các tác nhân khởi chạy mà bạn chắc chắn mình không cần"))
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            
            // Agent List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($service.bootAgentsToDisable) { $agent in
                        HStack(spacing: 12) {
                            // Checkbox
                            Button(action: { agent.isSelected.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(agent.isSelected ? Color.blue : Color.gray, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if agent.isSelected {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Icon
                            Image(nsImage: agent.icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                            
                            // Agent Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(agent.label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Status Badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(agent.isEnabled ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(agent.isEnabled ? 
                                     L("Đã bật") : 
                                     L("Tàn tật"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(agent.isSelected ? Color.blue.opacity(0.05) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { agent.isSelected.toggle() }
                        
                        if agent.id != service.bootAgentsToDisable.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(service.bootAgentsToDisable.count) * 60 + 20, 350))
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                // Select/Deselect All
                Button(action: {
                    let allSelected = service.bootAgentsToDisable.allSatisfy { $0.isSelected }
                    for index in service.bootAgentsToDisable.indices {
                        service.bootAgentsToDisable[index].isSelected = !allSelected
                    }
                }) {
                    Text(service.bootAgentsToDisable.allSatisfy { $0.isSelected } ? 
                         L("Bỏ chọn tất cả") : 
                         L("Chọn tất cả"))
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Skip Button
                Button(action: {
                    service.bootAlertIgnored = true
                    service.showBootConfirmAlert = false
                    dismiss()
                }) {
                    Text(L("Nhảy"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Disable Button
                Button(action: {
                    Task {
                        await service.disableSelectedBootAgents()
                        dismiss()
                    }
                }) {
                    Text(L("Vô hiệu hóa đã chọn"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.bootAgentsToDisable.filter { $0.isSelected }.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
