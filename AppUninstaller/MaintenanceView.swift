import SwiftUI
import Foundation

// MARK: - Maintenance Task Definition
enum MaintenanceTask: String, CaseIterable, Identifiable {
    case freeRam
    case purgeableSpace
    case flushDns
    case speedUpMail
    case rebuildSpotlight
    case repairPermissions
    case repairApps
    case timeMachine
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .freeRam: return L("Giải phóng RAM")
        case .purgeableSpace: return L("Giải phóng dung lượng có thể dọn")
        case .flushDns: return L("Làm mới bộ đệm DNS")
        case .speedUpMail: return L("Tăng tốc Mail")
        case .rebuildSpotlight: return L("Xây dựng lại chỉ mục Spotlight")
        case .repairPermissions: return L("Sửa quyền ổ đĩa")
        case .repairApps: return L("Sửa ứng dụng")
        case .timeMachine: return L("Dọn snapshot Time Machine")
        }
    }
    
    var icon: String {
        switch self {
        case .freeRam: return "memorychip"
        case .purgeableSpace: return "internaldrive"
        case .flushDns: return "network" // Or "globe"
        case .speedUpMail: return "envelope"
        case .rebuildSpotlight: return "magnifyingglass"
        case .repairPermissions: return "wrench.and.screwdriver"
        case .repairApps: return "ladybug"
        case .timeMachine: return "clock.arrow.circlepath"
        }
    }
    
    // Background color for the icon square
    var iconColor: Color {
        switch self {
        case .freeRam: return Color(red: 0.0, green: 0.6, blue: 0.8) // Cyan/Blue
        case .purgeableSpace: return Color(red: 0.5, green: 0.5, blue: 0.6) // Greyish
        case .flushDns: return Color(red: 0.0, green: 0.5, blue: 1.0) // Blue
        case .speedUpMail: return Color(red: 0.0, green: 0.6, blue: 0.9) // Blue
        case .rebuildSpotlight: return Color(red: 0.2, green: 0.4, blue: 0.8) // Darker Blue
        case .repairPermissions: return Color(red: 0.6, green: 0.6, blue: 0.65)
        case .repairApps: return Color(red: 0.9, green: 0.4, blue: 0.3)
        case .timeMachine: return Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }
    
    var description: String {
        switch self {
        case .freeRam:
            return L("Bộ nhớ trên máy Mac của bạn thường xuyên đầy, làm ứng dụng và tệp đang mở phản hồi chậm. Tác vụ này giải phóng phần bộ nhớ không còn dùng tới để nhường chỗ cho công việc hiện tại.")
        case .purgeableSpace:
            return L("macOS có thể giữ lại nhiều dữ liệu có thể dọn dẹp nhưng chưa tự giải phóng. Tác vụ này buộc hệ thống thu hồi phần dung lượng đó ngay khi bạn cần.")
        case .flushDns:
            return L("macOS lưu bộ đệm DNS trong một khoảng thời gian. Khi bản ghi máy chủ thay đổi hoặc mạng hoạt động bất thường, việc làm mới bộ đệm có thể giúp kết nối ổn định lại.")
        case .speedUpMail:
            return L("Apple Mail có thể chậm dần theo thời gian, nhất là khi hộp thư có nhiều email và tệp đính kèm. Tác vụ này tối ưu cơ sở dữ liệu Mail để tìm kiếm và duyệt thư nhanh hơn.")
        case .rebuildSpotlight:
            return L("Nếu Spotlight tìm chậm hoặc bỏ sót tệp, xây dựng lại chỉ mục sẽ giúp sửa lỗi. macOS sẽ quét lại dữ liệu và tạo chỉ mục tìm kiếm mới.")
        case .repairPermissions:
            return L("Tác vụ này kiểm tra và sửa quyền truy cập của các thư mục quan trọng để ứng dụng và tệp hệ thống hoạt động bình thường.")
        case .repairApps:
            return L("Quét và làm sạch các tệp tạm, bộ đệm lỗi và trạng thái lưu bị hỏng của ứng dụng để giảm hiện tượng treo hoặc crash.")
        case .timeMachine:
            return L("macOS có thể tạo snapshot Time Machine cục bộ và chiếm đáng kể dung lượng ổ đĩa. Bạn có thể xóa các snapshot cũ để lấy lại không gian.")
        }
    }
    
    var recommendations: [String] {
        switch self {
        case .freeRam:
            return [L("Máy phản hồi chậm"), L("Bạn sắp mở ứng dụng hoặc tệp lớn")]
        case .purgeableSpace:
            return [L("Bạn cần lấy lại vài GB dung lượng"), L("Tác vụ này có thể mất khá lâu")]
        case .flushDns:
            return [L("Không truy cập được một số website"), L("Mạng chậm thất thường")]
        case .speedUpMail:
            return [L("Mail khởi động chậm"), L("Tìm kiếm email mất nhiều thời gian")]
        case .rebuildSpotlight:
            return [L("Spotlight không tìm ra tệp đã biết"), L("Chỉ mục Spotlight có dấu hiệu hỏng")]
        case .repairPermissions:
            return [L("Ứng dụng hoạt động bất thường"), L("Bạn không thể di chuyển hoặc xóa một số tệp")]
        case .repairApps:
            return [L("Ứng dụng thường xuyên crash"), L("Ứng dụng không khởi động đúng cách")]
        case .timeMachine:
            return [L("Bạn cần giải phóng dung lượng ổ đĩa"), L("Bạn không cần giữ các snapshot Time Machine cũ")]
        }
    }
    
    var lastRunKey: String {
        return "maintenance_lastrun_\(rawValue)"
    }
}

// MARK: - Task Result Model
struct TaskResult {
    let task: MaintenanceTask
    let success: Bool
    let message: String
    let details: String?
}

// MARK: - Maintenance Service
class MaintenanceService: ObservableObject {
    static let shared = MaintenanceService()
    
    @Published var selectedTask: MaintenanceTask = .freeRam
    @Published var selectedTasks: Set<MaintenanceTask> = Set(MaintenanceTask.allCases)
    @Published var isRunning = false
    @Published var currentRunningTask: MaintenanceTask?
    @Published var completedTasks: Set<MaintenanceTask> = []
    @Published var taskResults: [TaskResult] = []
    
    // Xác nhận trạng thái hộp thoại

    @Published var showConfirmDialog = false
    @Published var confirmDialogTask: MaintenanceTask?
    @Published var confirmDialogMessage: String = ""
    @Published var userConfirmed = false
    
    // danh sách ảnh chụp nhanh cỗ máy thời gian

    @Published var timeMachineSnapshots: [String] = []
    @Published var showSnapshotSelector = false
    
    private init() {}
    
    func getLastRunDate(for task: MaintenanceTask) -> String {
        if let date = UserDefaults.standard.object(forKey: task.lastRunKey) as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.locale = Locale(identifier: "vi_VN")
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return L("Chưa từng chạy")
    }
    
    // MARK: - Run Tasks
    func runSelectedTasks() async {
        await MainActor.run {
            isRunning = true
            completedTasks = []
            taskResults = []
        }
        
        for task in MaintenanceTask.allCases {
            if selectedTasks.contains(task) {
                await MainActor.run { currentRunningTask = task }
                
                // Kiểm tra xem có cần xác nhận của người dùng không

                if needsConfirmation(task) {
                    await requestConfirmation(for: task)
                    
                    // Chờ xác nhận của người dùng

                    var waitTime = 0
                    while showConfirmDialog && waitTime < 30 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        waitTime += 1
                    }
                    
                    // Nếu người dùng hủy, bỏ qua tác vụ này

                    if !userConfirmed {
                        await MainActor.run {
                            taskResults.append(TaskResult(
                                task: task,
                                success: false,
                                message: L("Đã bỏ qua"),
                                details: L("Người dùng đã hủy thao tác")
                            ))
                        }
                        continue
                    }
                }
                
                // thực hiện nhiệm vụ

                let result = await executeTask(task)
                
                await MainActor.run {
                    completedTasks.insert(task)
                    taskResults.append(result)
                    UserDefaults.standard.set(Date(), forKey: task.lastRunKey)
                }
            }
        }
        
        await MainActor.run {
            currentRunningTask = nil
            isRunning = false
        }
    }
    
    // Kiểm tra xem tác vụ có yêu cầu xác nhận của người dùng không

    private func needsConfirmation(_ task: MaintenanceTask) -> Bool {
        switch task {
        case .repairApps, .timeMachine:
            return true  // Các hoạt động có rủi ro cao cần được xác nhận
        default:
            return false
        }
    }
    
    // Yêu cầu xác nhận người dùng

    @MainActor
    private func requestConfirmation(for task: MaintenanceTask) async {
        let message: String
        switch task {
        case .repairApps:
            message = L("Tác vụ này sẽ dọn trạng thái lưu và nhật ký crash của các ứng dụng. Đây là thao tác an toàn, nhưng một số ứng dụng có thể yêu cầu đăng nhập lại.")
        case .timeMachine:
            message = L("Tác vụ này sẽ xóa toàn bộ snapshot Time Machine cũ và chỉ giữ lại bản mới nhất. Bạn sẽ giải phóng được dung lượng, nhưng không thể khôi phục các snapshot đã xóa.")
        default:
            message = L("Bạn có muốn tiếp tục không?")
        }
        
        confirmDialogTask = task
        confirmDialogMessage = message
        userConfirmed = false
        showConfirmDialog = true
    }
    
    // Thao tác xác nhận người dùng

    func confirmAction() {
        userConfirmed = true
        showConfirmDialog = false
    }
    
    // Người dùng hủy thao tác

    func cancelAction() {
        userConfirmed = false
        showConfirmDialog = false
    }
    
    private func executeTask(_ task: MaintenanceTask) async -> TaskResult {
        let result: (success: Bool, message: String, details: String?)
        
        switch task {
        case .freeRam:
            result = await freeRAM()
        case .purgeableSpace:
            result = await freePurgeableSpace()
        case .flushDns:
            result = await flushDNS()
        case .speedUpMail:
            result = await speedUpMail()
        case .rebuildSpotlight:
            result = await rebuildSpotlight()
        case .repairPermissions:
            result = await repairPermissions()
        case .repairApps:
            result = await repairApps()
        case .timeMachine:
            result = await cleanTimeMachine()
        }
        
        return TaskResult(
            task: task,
            success: result.success,
            message: result.message,
            details: result.details
        )
    }
    
    // MARK: - Giải phóng RAM (dùng lệnh purge)

    private func freeRAM() async -> (success: Bool, message: String, details: String?) {
        // Nhận mức sử dụng bộ nhớ trước khi thực hiện

        let beforeMemory = getMemoryUsage()
        
        // Phương pháp 1: Sử dụng Memory_ Pressure để kích hoạt quá trình tái chế bộ nhớ

        let memPressure = Process()
        memPressure.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        memPressure.arguments = ["-l", "critical"]
        try? memPressure.run()
        
        // Đợi 2 giây để hệ thống phản hồi

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        memPressure.terminate()
        
        // Phương pháp 2: Thử thanh lọc (có thể yêu cầu công cụ dành cho nhà phát triển)

        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        try? purge.run()
        purge.waitUntilExit()
        
        // Đợi hệ thống cập nhật thống kê bộ nhớ

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Nhận mức sử dụng bộ nhớ sau khi thực hiện

        let afterMemory = getMemoryUsage()
        let freedMemoryGB = max(0, beforeMemory - afterMemory)
        
        if freedMemoryGB > 0.1 {
            return (true, String(format: L("Đã giải phóng %.2f GB bộ nhớ"), freedMemoryGB), L("Áp lực bộ nhớ đã giảm"))
        } else {
            return (true, L("Tối ưu bộ nhớ hoàn tất"), L("Bộ nhớ hệ thống hiện đang ở mức ổn định"))
        }
    }
    
    // Nhận mức sử dụng bộ nhớ (GB)

    private func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let pageSize = Double(vm_kernel_page_size)
        let usedMemory = Double(stats.active_count + stats.wire_count) * pageSize
        return usedMemory / (1024 * 1024 * 1024) // Convert to GB
    }
    
    // MARK: - Giải phóng không gian có thể xóa được

    private func freePurgeableSpace() async -> (success: Bool, message: String, details: String?) {
        var totalCleaned: Int64 = 0
        var filesDeleted = 0
        
        // 1. Dọn dẹp các tập tin hệ thống tạm thời

        let tempDirs = [
            FileManager.default.temporaryDirectory.path,
            "/private/var/folders"
        ]
        
        for dir in tempDirs {
            if let (size, count) = getDirectorySize(dir, olderThanDays: 7) {
                let cleanup = Process()
                cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/find")
                cleanup.arguments = [dir, "-type", "f", "-atime", "+7", "-delete"]
                try? cleanup.run()
                cleanup.waitUntilExit()
                
                totalCleaned += size
                filesDeleted += count
            }
        }
        
        // 2. Làm sạch các tập tin cũ trong bộ đệm của người dùng

        let userCaches = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        
        if let enumerator = FileManager.default.enumerator(at: userCaches, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) {
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            while let fileURL = enumerator.nextObject() as? URL {
                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate < oneWeekAgo,
                   let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                        totalCleaned += Int64(size)
                        filesDeleted += 1
                    }
                }
            }
        }
        
        // 3. Chạy thanh lọc để xóa bộ đệm đĩa

        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        try? purge.run()
        purge.waitUntilExit()
        
        let cleanedGB = Double(totalCleaned) / (1024 * 1024 * 1024)
        if cleanedGB > 0.1 {
            return (true, String(format: L("Đã giải phóng %.2f GB dung lượng"), cleanedGB), String(format: L("Đã xóa %d tệp cũ"), filesDeleted))
        } else {
            return (true, L("Dọn dẹp hoàn tất"), L("Hệ thống khá sạch, không có nhiều dữ liệu có thể dọn"))
        }
    }
    
    // Nhận kích thước thư mục (chỉ các tệp cũ hơn số ngày đã chỉ định mới được tính)

    private func getDirectorySize(_ path: String, olderThanDays days: Int) -> (size: Int64, count: Int)? {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        var totalSize: Int64 = 0
        var fileCount = 0
        
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return nil }
        
        while let file = enumerator.nextObject() as? String {
            let filePath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < cutoffDate,
               let size = attrs[.size] as? Int64 {
                totalSize += size
                fileCount += 1
            }
        }
        
        return (totalSize, fileCount)
    }
    
    // ĐÁNH DẤU: - Xóa bộ đệm DNS

    private func flushDNS() async -> (success: Bool, message: String, details: String?) {
        var success = true
        
        // Xóa bộ đệm DNS

        let dscacheutil = Process()
        dscacheutil.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        dscacheutil.arguments = ["-flushcache"]
        try? dscacheutil.run()
        dscacheutil.waitUntilExit()
        
        // Khởi động lại mDNSResponder

        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-HUP", "mDNSResponder"]
        try? killall.run()
        killall.waitUntilExit()
        
        if killall.terminationStatus != 0 {
            success = false
        }
        
        return (success, L("Đã làm mới bộ đệm DNS"), L("Các vấn đề kết nối mạng có thể đã được khắc phục"))
    }
    
    // MARK: - Tăng tốc mail (tối ưu cơ sở dữ liệu Mail)

    private func speedUpMail() async -> (success: Bool, message: String, details: String?) {
        let mailDataPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail")
        
        var dbOptimized = false
        var cacheCleaned: Int64 = 0
        
        // Tìm tệp cơ sở dữ liệu Envelope Index

        let possiblePaths = [
            mailDataPath.appendingPathComponent("V10/MailData/Envelope Index"),
            mailDataPath.appendingPathComponent("V9/MailData/Envelope Index"),
            mailDataPath.appendingPathComponent("V8/MailData/Envelope Index")
        ]
        
        for dbPath in possiblePaths {
            if FileManager.default.fileExists(atPath: dbPath.path) {
                // Sử dụng sqlite3 để thực hiện VACUUM nhằm tối ưu hóa cơ sở dữ liệu

                let sqlite = Process()
                sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
                sqlite.arguments = [dbPath.path, "VACUUM;"]
                try? sqlite.run()
                sqlite.waitUntilExit()
                
                // Thực hiện REINDEX

                let reindex = Process()
                reindex.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
                reindex.arguments = [dbPath.path, "REINDEX;"]
                try? reindex.run()
                reindex.waitUntilExit()
                
                dbOptimized = true
                break
            }
        }
        
        // Xóa bộ nhớ đệm tải xuống email

        let mailDownloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail Downloads")
        if FileManager.default.fileExists(atPath: mailDownloads.path) {
            if let contents = try? FileManager.default.contentsOfDirectory(at: mailDownloads, includingPropertiesForKeys: [.fileSizeKey]) {
                for item in contents {
                    if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        cacheCleaned += Int64(size)
                    }
                    try? FileManager.default.removeItem(at: item)
                }
            }
        }
        
        if dbOptimized {
            let cleanedMB = Double(cacheCleaned) / (1024 * 1024)
            if cleanedMB > 1 {
                return (true, L("Mail đã được tối ưu"), String(format: L("Cơ sở dữ liệu đã được xây dựng lại, đồng thời dọn %.1f MB bộ đệm"), cleanedMB))
            } else {
                return (true, L("Mail đã được tối ưu"), L("Cơ sở dữ liệu đã được lập chỉ mục lại"))
            }
        } else {
            return (false, L("Không tìm thấy cơ sở dữ liệu Mail"), L("Hãy chắc chắn ứng dụng Mail đã được cài đặt"))
        }
    }
    
    // MARK: - Xây dựng lại chỉ số Spotlight

    private func rebuildSpotlight() async -> (success: Bool, message: String, details: String?) {
        // Xây dựng lại chỉ mục Spotlight của thư mục chính của người dùng

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        
        let mdutil = Process()
        mdutil.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
        mdutil.arguments = ["-E", homePath]
        try? mdutil.run()
        mdutil.waitUntilExit()
        
        let success = mdutil.terminationStatus == 0
        
        // buộc lập chỉ mục lại

        let mdimport = Process()
        mdimport.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
        mdimport.arguments = [homePath]
        try? mdimport.run()
        // Đừng đợi hoàn thành vì việc lập chỉ mục mất nhiều thời gian

        
        if success {
            return (true, L("Đã bắt đầu xây dựng lại chỉ mục"), L("Spotlight sẽ lập chỉ mục lại các tệp của bạn ở chế độ nền"))
        } else {
            return (false, L("Không thể xây dựng lại chỉ mục"), L("Tác vụ này có thể cần quyền quản trị"))
        }
    }
    
    // MARK: - Sửa chữa quyền truy cập đĩa

    private func repairPermissions() async -> (success: Bool, message: String, details: String?) {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var fixedCount = 0
        
        // Sửa quyền thư mục chính

        let chmodHome = Process()
        chmodHome.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodHome.arguments = ["755", homePath]
        try? chmodHome.run()
        chmodHome.waitUntilExit()
        if chmodHome.terminationStatus == 0 { fixedCount += 1 }
        
        // REMOVED: Recursive permission repair on Library is dangerous and can break system settings
        // let chmodLib = Process() ...
        
        // Sửa các quyền thư mục phổ biến

        let userDirs = ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music"]
        for dir in userDirs {
            let dirPath = "\(homePath)/\(dir)"
            if FileManager.default.fileExists(atPath: dirPath) {
                let chmod = Process()
                chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmod.arguments = ["700", dirPath]
                try? chmod.run()
                chmod.waitUntilExit()
                if chmod.terminationStatus == 0 { fixedCount += 1 }
            }
        }
        
        // Sửa quyền truy cập thư mục .ssh (nếu có)

        let sshPath = "\(homePath)/.ssh"
        var sshFixed = false
        if FileManager.default.fileExists(atPath: sshPath) {
            let chmodSsh = Process()
            chmodSsh.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodSsh.arguments = ["700", sshPath]
            try? chmodSsh.run()
            chmodSsh.waitUntilExit()
            
            // Sửa quyền truy cập khóa SSH

            let chmodKeys = Process()
            chmodKeys.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodKeys.arguments = ["600", "\(sshPath)/id_rsa", "\(sshPath)/id_ed25519"]
            try? chmodKeys.run()
            chmodKeys.waitUntilExit()
            
            sshFixed = true
        }
        
        let details = sshFixed ? String(format: L("Đã sửa quyền cho %d thư mục, bao gồm cả cấu hình SSH"), fixedCount) : String(format: L("Đã sửa quyền cho %d thư mục"), fixedCount)
        return (true, L("Sửa quyền truy cập hoàn tất"), details)
    }
    
    // Đánh dấu: - Ảnh chụp nhanh cỗ máy thời gian sạch

    private func cleanTimeMachine() async -> (success: Bool, message: String, details: String?) {
        // Liệt kê tất cả các ảnh chụp nhanh cục bộ

        let listTask = Process()
        listTask.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        listTask.arguments = ["listlocalsnapshots", "/"]
        
        let pipe = Pipe()
        listTask.standardOutput = pipe
        
        try? listTask.run()
        listTask.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return (true, L("Không có snapshot để xóa"), L("Không tìm thấy snapshot Time Machine cục bộ"))
        }
        
        // Phân tích ngày chụp nhanh

        let lines = output.components(separatedBy: "\n")
        var snapshotDates: [String] = []
        
        for line in lines {
            // Định dạng: com.apple.TimeMachine.2024-12-14-123456

            if line.contains("com.apple.TimeMachine") {
                // Trích xuất phần ngày

                if let range = line.range(of: "\\d{4}-\\d{2}-\\d{2}-\\d{6}", options: .regularExpression) {
                    snapshotDates.append(String(line[range]))
                }
            }
        }
        
        if snapshotDates.count <= 1 {
            return (true, L("Không cần dọn dẹp"), L("Chỉ có một snapshot và đã được giữ lại"))
        }
        
        var deletedCount = 0
        
        // Xóa tất cả ảnh chụp nhanh cục bộ (giữ ảnh mới nhất)

        for date in snapshotDates.dropLast() {
            let deleteTask = Process()
            deleteTask.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            deleteTask.arguments = ["deletelocalsnapshots", date]
            try? deleteTask.run()
            deleteTask.waitUntilExit()
            
            if deleteTask.terminationStatus == 0 {
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            return (true, String(format: L("Đã xóa %d snapshot"), deletedCount), L("Đã giữ lại snapshot mới nhất"))
        } else {
            return (false, L("Xóa snapshot thất bại"), L("Tác vụ này có thể cần quyền quản trị"))
        }
    }
    
    // MARK: - Sửa chữa ứng dụng

    private func repairApps() async -> (success: Bool, message: String, details: String?) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileManager = FileManager.default
        var itemsFixed = 0
        var spaceFreed: Int64 = 0
        
        // 1. Làm sạch nhật ký sự cố ứng dụng

        let crashReportsPath = home.appendingPathComponent("Library/Logs/DiagnosticReports")
        if let contents = try? fileManager.contentsOfDirectory(at: crashReportsPath, includingPropertiesForKeys: [.fileSizeKey]) {
            for item in contents where item.pathExtension == "crash" || item.pathExtension == "ips" {
                if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    spaceFreed += Int64(size)
                }
                if (try? fileManager.removeItem(at: item)) != nil {
                    itemsFixed += 1
                }
            }
        }
        
        // 2. Dọn dẹp Trạng thái ứng dụng đã lưu bị hỏng

        let savedStatePath = home.appendingPathComponent("Library/Saved Application State")
        if let contents = try? fileManager.contentsOfDirectory(at: savedStatePath, includingPropertiesForKeys: [.fileSizeKey]) {
            for item in contents {
                if let size = try? item.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize {
                    spaceFreed += Int64(size)
                }
                if (try? fileManager.removeItem(at: item)) != nil {
                    itemsFixed += 1
                }
            }
        }
        
        // 3. Dọn dẹp các tập tin tạm thời trong Container ứng dụng

        let containersPath = home.appendingPathComponent("Library/Containers")
        if let apps = try? fileManager.contentsOfDirectory(at: containersPath, includingPropertiesForKeys: nil) {
            for app in apps {
                let tempPath = app.appendingPathComponent("Data/tmp")
                if let tempContents = try? fileManager.contentsOfDirectory(at: tempPath, includingPropertiesForKeys: [.fileSizeKey]) {
                    for item in tempContents {
                        if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            spaceFreed += Int64(size)
                        }
                        if (try? fileManager.removeItem(at: item)) != nil {
                            itemsFixed += 1
                        }
                    }
                }
            }
        }
        
        // 4. Đặt lại bộ đệm chuyển vị ứng dụng

        let translocatorReset = Process()
        translocatorReset.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        translocatorReset.arguments = ["/System/Library/Frameworks/Security.framework/Versions/A/XPCServices/SecTranslocate.xpc/Contents/MacOS/SecTranslocate", "--reset"]
        try? translocatorReset.run()
        
        // 5. Dọn dẹp các ứng dụng bị hỏng đã đăng ký bởi Launch Services

        let lsregister = Process()
        lsregister.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
        lsregister.arguments = ["-kill", "-r", "-domain", "local", "-domain", "user"]
        try? lsregister.run()
        lsregister.waitUntilExit()
        
        // 6. Xóa bộ nhớ đệm của Dịch vụ cốt lõi

        let cachesPaths = [
            home.appendingPathComponent("Library/Caches/com.apple.helpd"),
            home.appendingPathComponent("Library/Caches/com.apple.nsservicescache.plist"),
        ]
        for path in cachesPaths {
            if let size = try? path.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize {
                spaceFreed += Int64(size)
            }
            try? fileManager.removeItem(at: path)
        }
        
        let freedMB = Double(spaceFreed) / (1024 * 1024)
        let details = String(format: L("Đã xử lý %d mục lỗi và giải phóng %.1f MB dung lượng"), itemsFixed, freedMB)
        return (true, L("Sửa ứng dụng hoàn tất"), details)
    }
}

// MARK: - Maintenance View
struct MaintenanceView: View {
    @StateObject private var service = MaintenanceService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var viewState = 3 // 0: selection, 1: running, 2: finished, 3: landing
    
    var body: some View {
        Group {
            if viewState == 3 {
                landingView
            } else if viewState == 0 {
                selectionView
            } else if viewState == 1 {
                runningView
            } else {
                finishedView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Always start at landing page unless currently running a task
            if viewState != 1 {
                viewState = 3
            }
        }
        .sheet(isPresented: $service.showConfirmDialog) {
            MaintenanceConfirmDialog(service: service, loc: loc)
        }
    }
    
    // MARK: - Selection View
    var selectionView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                // Left Panel (Task List)
                VStack(alignment: .leading, spacing: 0) {
                    // Header: Intro Button
                    Button(action: { 
                        viewState = 3 // Go back to landing
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text(L("Giới thiệu"))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .padding(.leading, 16)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 2) {
                            ForEach(MaintenanceTask.allCases) { task in
                                taskRow(task)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    

                }
                .frame(width: geometry.size.width * 0.4)
                .background(Color.clear)
                
                // Right Panel (Details)
                VStack(alignment: .leading, spacing: 0) {
                    // Header: Maintenance Label & Assistant
                    HStack {
                        Text(L("Bảo trì"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 5, height: 5)
                                Text(L("Trợ lý"))
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // Title
                    Text(service.selectedTask.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 12)
                    
                    // Description
                    Text(service.selectedTask.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(3)
                        .padding(.bottom, 20)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Recommendations
                    Text(L("Được đề xuất cho:"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(service.selectedTask.recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.5))
                                Text(rec)
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Footer: Last Run Date only (button moved to left panel)
                    HStack {
                        Spacer()
                        Text(String(format: L("Lần chạy cuối cùng: %@"), service.getLastRunDate(for: service.selectedTask)))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 30)
                .frame(width: geometry.size.width * 0.6)
            }
            
            // Centered Run Button
            runButton
                .padding(.bottom, 40)
        }
        }
        .background(BackgroundStyles.privacy)
    }
    
    var runButton: some View {
        Button(action: {
            viewState = 1
            Task {
                await service.runSelectedTasks()
                await MainActor.run { viewState = 2 }
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 58, height: 58)
                
                Text(L("Chạy"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
    
    func taskRow(_ task: MaintenanceTask) -> some View {
        HStack(spacing: 8) {
            // Hộp kiểm - nút độc lập, xử lý chính xác trạng thái đã chọn

            Button(action: {
                if service.selectedTasks.contains(task) {
                    service.selectedTasks.remove(task)
                } else {
                    service.selectedTasks.insert(task)
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(service.selectedTasks.contains(task) ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if service.selectedTasks.contains(task) {
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
            
            // Biểu tượng + Tiêu đề có thể bấm vào để chọn nhiệm vụ

            Button(action: { service.selectedTask = task }) {
                HStack(spacing: 8) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(task.iconColor)
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: task.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    // Title
                    Text(task.title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(service.selectedTask == task ? Color.white.opacity(0.12) : Color.clear)
        )
    }
    
    // MARK: - Running View
    var runningView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // tiêu đề

            Text(L("Thực hiện các công việc bảo trì..."))
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

                        Text(task.title)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // tình trạng

                        if service.completedTasks.contains(task) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if service.currentRunningTask == task {
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
                    .background(service.currentRunningTask == task ? Color.white.opacity(0.1) : Color.clear)
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
    
    // MARK: - Finished View
    var finishedView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // biểu tượng thành công

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
            }
            .padding(.bottom, 20)
            
            Text(L("Bảo trì hoàn tất!"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 10)
            
            Text(L("Các tác vụ đã chọn đã được thực thi"))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(service.taskResults, id: \.task.rawValue) { result in
                        HStack(spacing: 16) {
                            // Status Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(result.task.iconColor.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(result.task.iconColor.opacity(0.5), lineWidth: 1)
                                    )
                                
                                Image(systemName: result.task.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(result.task.iconColor)
                            }
                            
                            // Task Info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.task.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Status Badge
                                    HStack(spacing: 4) {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                            .foregroundColor(result.success ? .green : .orange)
                                            .font(.system(size: 12))
                                        
                                        Text(result.message)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(result.success ? .green : .orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(result.success ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                    )
                                }
                                
                                if let details = result.details {
                                    Text(details)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: 600, maxHeight: 300)
            
            Spacer()
            
            // nút quay lại

            Button(action: { 
                service.taskResults.removeAll()
                viewState = 0 
            }) {
                Text(L("Xong"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }

        // Removed .background to avoid double background layer
    }
    // MARK: - Landing View
    var landingView: some View {
        MaintenanceLandingView(viewState: $viewState)
    }
}

struct MaintenanceLandingView: View {
    @Binding var viewState: Int
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        ZStack {
            HStack(spacing: 60) {
                // Left Content
                VStack(alignment: .leading, spacing: 30) {
                    // Branding Header
                    HStack(spacing: 8) {
                        Text(L("Bảo trì hệ thống"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Maintenance Icon
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                            Text(L("Sửa nhanh"))
                                .font(.system(size: 20, weight: .heavy))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Text(L("Chạy một tập lệnh để nhanh chóng tối ưu hóa hiệu suất hệ thống.\nLần bảo trì cuối cùng: Không bao giờ"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                    
                    // Feature Rows
                    VStack(alignment: .leading, spacing: 24) {
                        featureRow(
                            icon: "gauge",
                            title: L("Cải thiện hiệu suất ổ đĩa"),
                            desc: L("Bảo trì đĩa để đảm bảo hệ thống tập tin và tình trạng vật lý của nó tốt.")
                        )

                        featureRow(
                            icon: "exclamationmark.triangle",
                            title: L("Sửa lỗi ứng dụng"),
                            desc: L("Khắc phục hành vi ứng dụng không đúng bằng cách sửa chữa các quyền và chạy các tập lệnh bảo trì.")
                        )

                        featureRow(
                            icon: "magnifyingglass",
                            title: L("Cải thiện hiệu suất tìm kiếm"),
                            desc: L("Xây dựng lại cơ sở dữ liệu Spotlight để cải thiện tốc độ và độ chính xác khi tìm kiếm.")
                        )
                    }
                    
                    // View Tasks Button
                    Button(action: { viewState = 0 }) {
                        Text(L("Xem 7 nhiệm vụ..."))
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
                
                // Right Icon - Maintenance Visual
                ZStack {
                    if let path = Bundle.main.path(forResource: "weihu", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                    } else {
                        // Fallback: Pink Checklist
                        ZStack {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "C86FC9"), Color(hex: "9933CC")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                            
                            // Checklist Items (Visual)
                            VStack(spacing: 20) {
                                ForEach(0..<3) { i in
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 6) // Checkbox
                                            .fill(Color.white)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(Color(hex: "9933CC"))
                                            )
                                        
                                        RoundedRectangle(cornerRadius: 4) // Line
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 100, height: 10)
                                    }
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
                Button(action: { viewState = 0 }) {
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

// MARK: - Maintenance Confirmation Dialog
struct MaintenanceConfirmDialog: View {
    @ObservedObject var service: MaintenanceService
    @ObservedObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        // biểu tượng cảnh báo

                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                        
                            
                        Text(L("Xác nhận hành động"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let task = service.confirmDialogTask {
                        Text(task.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    service.cancelAction()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Warning Banner
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text(service.confirmDialogMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.15)) // Modern orange tint
            
            // Task Details
            VStack(alignment: .leading, spacing: 12) {
                if let task = service.confirmDialogTask {
                    Text(L("Các thao tác cần thực hiện:"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(getTaskOperations(task), id: \.self) { operation in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(operation)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Footer Actions
            HStack(spacing: 12) {
                Spacer()
                
                // Cancel Button
                Button(action: {
                    service.cancelAction()
                    dismiss()
                }) {
                    Text(L("Hủy bỏ"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Confirm Button
                Button(action: {
                    service.confirmAction()
                    dismiss()
                }) {
                    Text(L("Tiếp tục"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color(red: 0.8, green: 0.4, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.22)) // Darker modern background
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Lấy danh sách thao tác cụ thể của nhiệm vụ

    private func getTaskOperations(_ task: MaintenanceTask) -> [String] {
        switch task {
        case .repairApps:
            return [
                L("Dọn toàn bộ nhật ký sự cố của ứng dụng"),
                L("Xóa trạng thái đã lưu của ứng dụng, một số ứng dụng có thể cần đăng nhập lại"),
                L("Dọn tệp tạm của ứng dụng"),
                L("Đặt lại cơ sở dữ liệu Launch Services"),
                L("Dọn bộ đệm Core Services")
            ]
            
        case .timeMachine:
            return [
                L("Liệt kê toàn bộ snapshot Time Machine cục bộ"),
                L("Xóa snapshot cũ, giữ lại snapshot mới nhất"),
                L("Giải phóng dung lượng ổ đĩa")
            ]
            
        default:
            return []
        }
    }
}
