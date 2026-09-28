import SwiftUI
import Combine

// MARK: - Models

struct DeepCleanItem: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let category: DeepCleanCategory
    var isSelected: Bool = true
    
    // New metadata for Apps
    var appIcon: NSImage? = nil
    var bundleId: String? = nil
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - App Info Helper Structure
struct InstalledAppInfo {
    let name: String
    let bundleId: String
    let url: URL
    let icon: NSImage
}

enum DeepCleanCategory: String, CaseIterable, Sendable {
    case largeFiles = "Large Files"
    case junkFiles = "System Junk"
    case systemLogs = "Log Files"
    case systemCaches = "Cache Files"
    case appResiduals = "App Residue"
    
    var localizedName: String {
        switch self {
        case .largeFiles: return L("Tệp lớn")
        case .junkFiles: return L("Rác hệ thống")
        case .systemLogs: return L("Tệp nhật ký")
        case .systemCaches: return L("Tệp bộ nhớ đệm")
        case .appResiduals: return L("Dư lượng ứng dụng")
        }
    }
    
    var icon: String {
        switch self {
        case .largeFiles: return "arrow.down.doc.fill"
        case .junkFiles: return "trash.fill"
        case .systemLogs: return "doc.text.fill"
        case .systemCaches: return "externaldrive.fill"
        case .appResiduals: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .largeFiles: return .purple
        case .junkFiles: return .red
        case .systemLogs: return .gray
        case .systemCaches: return .blue
        case .appResiduals: return .orange
        }
    }
}

// MARK: - Scanner

class DeepCleanScanner: ObservableObject {
    @Published var items: [DeepCleanItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatus: String = ""
    @Published var currentScanningUrl: String = ""
    @Published var completedCategories: Set<DeepCleanCategory> = []
    
    // Thống kê

    @Published var totalSize: Int64 = 0
    @Published var cleanedSize: Int64 = 0
    @Published var cleaningProgress: Double = 0.0
    @Published var currentCleaningItem: String = ""
    
    // Theo dõi trạng thái dọn dẹp

    @Published var cleaningCurrentCategory: DeepCleanCategory? = nil
    @Published var cleanedCategories: Set<DeepCleanCategory> = []
    @Published var cleaningDescription: String = ""
    
    // kích thước đã chọn

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    // Progress smoothing
    private var currentTaskProgressRange: (start: Double, end: Double) = (0, 0)
    private var scannedItemsCount: Int = 0
    private let progressSmoothingFactor: Double = 1000.0 // Items to reach 50% of range
    
    private let fileManager = FileManager.default
    private var scanTask: Task<Void, Never>?
    
    // Bảo vệ hệ thống - không bao giờ xóa

    private let protectedPaths: Set<String> = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/var/root"
    ]
    
    // MARK: - API
    
    @Published var currentCategory: DeepCleanCategory = .largeFiles // Default, updates during scan
    
    // MARK: - API
    
    func startScan() async {
        await MainActor.run {
            self.reset()
            self.isScanning = true
            self.scanStatus = L("Chuẩn bị...")
            self.scanProgress = 0.0
        }
        
        let categoriesToScan: [DeepCleanCategory] = [.junkFiles, .systemLogs, .systemCaches, .appResiduals, .largeFiles]
        let totalCategories = Double(categoriesToScan.count)
        
        for (index, category) in categoriesToScan.enumerated() {
            // Update Current Category
            await MainActor.run {
                self.currentCategory = category
                self.scanStatus = self.statusText(for: category)
                
                // Define range for this task
                let start = Double(index) / totalCategories
                let end = Double(index + 1) / totalCategories
                self.currentTaskProgressRange = (start, end)
                self.scannedItemsCount = 0
                self.scanProgress = start
            }
            
            // Perform Scan
            let newItems: [DeepCleanItem]
            switch category {
            case .largeFiles: newItems = await scanLargeFiles()
            case .junkFiles: newItems = await scanJunk()
            case .systemLogs: newItems = await scanLogs()
            case .systemCaches: newItems = await scanCaches()
            case .appResiduals: newItems = await scanResiduals()
            }
            
            // Update Results
             await MainActor.run {
                self.items.append(contentsOf: newItems)
                self.totalSize += newItems.reduce(0) { $0 + $1.size }
                self.completedCategories.insert(category)
                self.items.sort { $0.size > $1.size } // Keep sorted
                
                // Animate Progress (Complete this step)
                withAnimation(.linear(duration: 0.3)) {
                    self.scanProgress = Double(index + 1) / totalCategories
                }
            }
            
            // Small delay for visual pacing (optional, feels more "pro")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        }
        
        await MainActor.run {
            self.isScanning = false
            self.scanStatus = L("Quét hoàn tất")
            self.scanProgress = 1.0
        }
    }
    
    private func statusText(for category: DeepCleanCategory) -> String {
        switch category {
        case .largeFiles: return L("Đang quét tệp lớn...")
        case .junkFiles: return L("Đang quét rác hệ thống...")
        case .systemLogs: return L("Đang quét nhật ký...")
        case .systemCaches: return L("Đang quét bộ đệm...")
        case .appResiduals: return L("Đang quét tệp còn sót của ứng dụng...")
        }
    }
    
    // Throttled UI Update Helper
    private var lastUpdateTime: Date = Date()
    
    func updateScanningUrl(_ url: String) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 0.05 else { return } // Update every 50ms max
        lastUpdateTime = now
        
        Task { @MainActor in
            self.currentScanningUrl = url
            
            // Asymptotic Progress Update
            self.scannedItemsCount += 1
            let progressWithinRange = 1.0 - (1.0 / (1.0 + Double(self.scannedItemsCount) / self.progressSmoothingFactor))
            let (start, end) = self.currentTaskProgressRange
            let newProgress = start + (end - start) * progressWithinRange
            
            // Only update if greater (monotonically increasing)
            if newProgress > self.scanProgress {
                self.scanProgress = newProgress
            }
        }
    }
    
    func sizeFor(category: DeepCleanCategory) -> Int64 {
        return items.filter { $0.category == category && $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }
    
    func cleanSelected() async -> (count: Int, size: Int64) {
        print("[DeepClean] 🧹 Bắt đầu dọn dẹp...")
        
        await MainActor.run {
            self.isCleaning = true
            self.scanStatus = L("Đang chuẩn bị dọn dẹp...")
            self.cleaningProgress = 0
            self.cleanedCategories = []
        }
        
        let categoriesToClean: [DeepCleanCategory] = [.junkFiles, .systemLogs, .systemCaches, .appResiduals, .largeFiles]
        var totalDeletedCount = 0
        var totalDeletedSize: Int64 = 0
        var allFailures: [URL] = []
        
        let categoriesWithSelection = categoriesToClean.filter { cat in
            items.contains { $0.category == cat && $0.isSelected }
        }
        
        print("[DeepClean] 📋 Tìm thấy \(categoriesWithSelection.count) danh mục cần dọn")
        
        // Nếu không có mục nào được chọn, hãy quay lại trực tiếp

        guard !categoriesWithSelection.isEmpty else {
            print("[DeepClean] ⚠️ Không có mục nào được chọn, kết thúc sớm")
            await MainActor.run {
                self.isCleaning = false
            }
            return (0, 0)
        }
        
        let totalCategories = Double(categoriesWithSelection.count)
        
        for (index, category) in categoriesWithSelection.enumerated() {
            print("[DeepClean] 🔄 Bắt đầu dọn danh mục: \(category.localizedName)")
            
             await MainActor.run {
                self.cleaningCurrentCategory = category
                self.currentCategory = category
                self.scanStatus = String(format: L("Đang dọn %@..."), category.localizedName)
                self.cleaningDescription = L("Làm sạch...")
            }
            
            let categoryItems = items.filter { $0.category == category && $0.isSelected }
            print("[DeepClean] 📦 Danh mục này có \(categoryItems.count) mục cần dọn")
            var categoryFailures: [URL] = []
            
            for item in categoryItems {
                // ⚠️ Sửa lỗi bảo mật: Kiểm tra với SafetyGuard

                if !SafetyGuard.shared.isSafeToDelete(item.url) {
                    print("[DeepClean] 🛡️ SafetyGuard blocked deletion: \(item.url.path)")
                    categoryFailures.append(item.url)
                    allFailures.append(item.url)
                    continue
                }
                
                do {
                    try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                    totalDeletedCount += 1
                    totalDeletedSize += item.size
                } catch {
                    print("Delete failed for \(item.url): \(error.localizedDescription)")
                    categoryFailures.append(item.url)
                    allFailures.append(item.url)
                }
            }
            
            // Update items for this category immediately
            let capturedFailures = categoryFailures
            await MainActor.run {
                self.items.removeAll { item in
                    categoryItems.contains(where: { $0.id == item.id }) && !capturedFailures.contains(item.url)
                }
                
                // Mark category as cleaned
                self.cleanedCategories.insert(category)
                
                // Animate Progress
                withAnimation(.linear(duration: 0.3)) {
                    self.cleaningProgress = Double(index + 1) / totalCategories
                }
            }
            
            // Small delay for visual pacing (reduced from 300ms to 100ms)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        let finalDeletedSize = totalDeletedSize
        let finalDeletedCount = totalDeletedCount
        
        print("[DeepClean] ✅ Dọn dẹp hoàn tất. Đã xử lý \(finalDeletedCount) tệp và giải phóng \(ByteCountFormatter.string(fromByteCount: finalDeletedSize, countStyle: .file))")
        
        await MainActor.run { [finalDeletedSize] in
            self.cleanedSize = finalDeletedSize
            self.totalSize -= finalDeletedSize
            self.isCleaning = false
            self.cleaningProgress = 1.0
            self.cleaningCurrentCategory = nil
            self.currentCleaningItem = ""
            self.scanStatus = L("Dọn dẹp hoàn tất")
            print("[DeepClean] 📢 Đã đặt isCleaning = false, giao diện nên chuyển màn hình")
        }
        
        return (finalDeletedCount, finalDeletedSize)
    }
    
    func reset() {
        items = []
        totalSize = 0
        cleanedSize = 0
        scanProgress = 0
        scanStatus = ""
        currentScanningUrl = ""
        completedCategories = []
        cleaningCurrentCategory = nil
        cleanedCategories = []
        cleaningDescription = ""
    }
    
    // MARK: - Helper Methods
    
    private func updateStatus(_ status: String, category: DeepCleanCategory? = nil) async {
        await MainActor.run {
            self.scanStatus = status
        }
    }
    
    // MARK: - Scanning Implementations
    
    private func scanLargeFiles() async -> [DeepCleanItem] {
        // Scan User's Home Directory (~/) recursively
        let home = fileManager.homeDirectoryForCurrentUser
        let scanRoots = [home]
        
        // Exclude specific system/sensitive/app directories to prevent damage
        let config = ScanConfiguration(
            minFileSize: 50 * 1024 * 1024, // 50MB
            skipHiddenFiles: true,
            excludedPaths: [
                "Library",          // Contains App Data/Databases - Unsafe to delete single files
                "Applications",     // Apps themselves
                ".Trash",           // Already in Trash
                ".vol", ".Db",      // System mounts
                "Music/Music Library", // Protect Music Library DB
                "Pictures/Photos Library.photoslibrary" // Protect Photos DB
            ]
        )
        
        let results = await scanDirectoryConcurrently(directories: scanRoots, configuration: config) { url, values -> DeepCleanItem? in
            // SAFETY: Skip .app bundles and application-related files
            self.updateScanningUrl(url.path) // Trigger progress update
            
            if url.path.contains(".app") || 
               url.path.contains("/Applications/") ||
               url.path.contains("/Library/") { // Double check for Library in path
                return nil
            }
            
            return DeepCleanItem(
                url: url,
                name: url.lastPathComponent,
                size: Int64(values.fileSize ?? 0),
                category: .largeFiles
            )
        }
        
        return results
    }
    
    private func scanLogs() async -> [DeepCleanItem] {
        var logPaths = [String]()
        
        // 1. Standard Log Paths
        logPaths.append(contentsOf: [
            "~/Library/Logs",
            "~/Library/Application Support/CrashReporter",
            "~/Library/Logs/DiagnosticReports"
        ])
        
        // 2. Expand tilde
        let expandedPaths = logPaths.map { NSString(string: $0).expandingTildeInPath }
        
        let config = ScanConfiguration(
            minFileSize: 0,
            skipHiddenFiles: false
        )
        
        return await scanDirectoryConcurrently(directories: expandedPaths.map { URL(fileURLWithPath: $0) }, configuration: config) { url, values in
            self.updateScanningUrl(url.path)
            
            // Filter logic
            let isLog = url.pathExtension == "log" || 
                       url.pathExtension == "crash" ||
                       url.path.contains("/Logs/") || 
                       url.path.contains("/CrashReporter/")
            
            if isLog {
                return DeepCleanItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: Int64(values.fileSize ?? 0),
                    category: .systemLogs
                )
            }
            return nil
        }
    }
    
    // MARK: - Dynamic App Scanning Helpers
    
    private func getInstalledApps() -> [InstalledAppInfo] {
        var apps: [InstalledAppInfo] = []
        let appDirs = [
            "/Applications",
            "/System/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                if item.hasSuffix(".app") {
                    let appUrl = URL(fileURLWithPath: dir).appendingPathComponent(item)
                    // Get Bundle ID
                    if let bundle = Bundle(url: appUrl),
                       let bundleId = bundle.bundleIdentifier {
                        let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
                        let name = (item as NSString).deletingPathExtension
                        apps.append(InstalledAppInfo(name: name, bundleId: bundleId, url: appUrl, icon: icon))
                    }
                }
            }
        }
        return apps
    }
    
    private func scanCaches() async -> [DeepCleanItem] {
        var items: [DeepCleanItem] = []
        
        // 1. Dynamic App Scanning
        let apps = getInstalledApps()
        let home = fileManager.homeDirectoryForCurrentUser
        
        // Optimization: Use concurrent scanning for apps
        await withTaskGroup(of: DeepCleanItem?.self) { group in
            for app in apps {
                group.addTask {
                    // Predict Cache Path: ~/Library/Caches/[BundleID]
                    let cacheUrl = home.appendingPathComponent("Library/Caches").appendingPathComponent(app.bundleId)
                    
                    if self.fileManager.fileExists(atPath: cacheUrl.path) {
                        // Update UI occasionally
                        if Int.random(in: 0...50) == 0 { await MainActor.run { self.updateScanningUrl(cacheUrl.path) } }
                        
                        let size = await calculateSizeAsync(at: cacheUrl)
                        if size > 1024 * 1024 { // > 1MB
                             return DeepCleanItem(
                                url: cacheUrl,
                                name: app.name + " " + (L("Bộ nhớ đệm")),
                                size: size,
                                category: .systemCaches,
                                appIcon: app.icon,
                                bundleId: app.bundleId
                            )
                        }
                    }
                    return nil
                }
            }
            
            for await item in group {
                if let item = item { items.append(item) }
            }
        }
        
        // 2. Scan Log Paths (using predicted Bundle IDs)
         // (This could be integrated here or in scanLogs, but let's stick to Caches for now as requested)
         
        // 3. Scan Generic Caches (browsers etc. matching specifically if not found by bundle ID)
        // Note: Chrome/Safari/etc usually have specific bundle IDs so getInstalledApps should catch them.
        // We can keep the manual list as a fallback or removal it?
        // Let's keep a small manual list for non-standard apps that might not be in /Applications or have weird cache paths (like Chrome's "Default/Cache")
        
        // Browsers specific paths not covered by Bundle ID Caches standard
        let manualItems = await scanManualCaches()
        items.append(contentsOf: manualItems)
        
        // Deduplicate
        return Array(Set(items.map { $0.url })).compactMap { url in
            items.first(where: { $0.url == url })
        }
    }
    
    private func scanManualCaches() async -> [DeepCleanItem] {
         var cachePaths = Set<String>()
        
        // Specific complex paths not just ~/Library/Caches/BundleID
        cachePaths.insert("~/Library/Caches/Google/Chrome") // Sometimes this is a container
        cachePaths.insert("~/Library/Application Support/Google/Chrome/Default/Cache")
        cachePaths.insert("~/Library/Caches/com.apple.Safari") // Safari uses standard ID but complex structure sometimes
        cachePaths.insert("~/Library/Caches/Firefox")
        
         // 3. Expand all paths
        let validPaths = cachePaths
            .map { NSString(string: $0).expandingTildeInPath }
            .map { URL(fileURLWithPath: $0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
            
        var items: [DeepCleanItem] = []
        for dir in validPaths {
             let size = await calculateSizeAsync(at: dir)
             if size > 1024 {
                var displayName = dir.lastPathComponent
                if dir.path.contains("Chrome") { displayName = "Chrome Cache" }
                else if dir.path.contains("Firefox") { displayName = "Firefox Cache" }
                
                 items.append(DeepCleanItem(
                    url: dir,
                    name: displayName,
                    size: size,
                    category: .systemCaches
                ))
             }
        }
        return items
    }
    
    private func scanResiduals() async -> [DeepCleanItem] {
        print("[DeepClean] 🔍 Bắt đầu quét phần còn sót của ứng dụng...")
        
        let home = fileManager.homeDirectoryForCurrentUser
        var items: [DeepCleanItem] = []
        
        // 1. Nhận thông tin về tất cả các ứng dụng đã cài đặt

        let installedApps = await getInstalledAppParams()
        print("[DeepClean] 📱 Tìm thấy \(installedApps.count) ứng dụng đã cài đặt")
        
        // 2. Hỗ trợ quét ứng dụng (dữ liệu ứng dụng)

        let appSupport = home.appendingPathComponent("Library/Application Support")
        if fileManager.fileExists(atPath: appSupport.path) {
            updateScanningUrl(appSupport.path)
            if let contents = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for folder in contents {
                    // Update UI occasionally
                    if Int.random(in: 0...10) == 0 { await MainActor.run { self.updateScanningUrl(folder.path) } }
                    
                    let folderName = folder.lastPathComponent
                    
                    // ⚠️ Key: Sử dụng isOrphanedFolder để xác định xem nó có phải là phần dư không

                    if isOrphanedFolder(name: folderName, installedApps: installedApps) {
                        // ⚠️ Xác minh lại bằng SafetyGuard

                        if SafetyGuard.shared.isSafeToDelete(folder) {
                            let size = await calculateSizeAsync(at: folder)
                            if size > 100_000 { // Chỉ thêm phần còn lại lớn hơn 100KB
                                items.append(DeepCleanItem(
                                    url: folder,
                                    name: folderName,
                                    size: size,
                                    category: .appResiduals
                                ))
                                print("[DeepClean] 🗑️ Phát hiện phần còn sót: \(folderName)")
                            }
                        }
                    }
                }
            }
        }
        
        // 3. Tùy chọn quét

        // ⚠️ Lưu ý: Tùy chọn chứa một số lượng lớn cấu hình dịch vụ hệ thống và cần hết sức thận trọng

        // Vì lý do an toàn, chúng tôi tạm thời tắt chức năng quét Tùy chọn để tránh vô tình xóa cấu hình hệ thống.

        // let prefs = home.appendingPathComponent("Library/Preferences")
        // print("[DeepClean] ⚠️ Chức năng quét tùy chọn đã bị tắt để ngăn việc vô tình xóa cấu hình hệ thống")

        
        // Nếu nó được kích hoạt trong tương lai, sẽ cần có một danh sách trắng chặt chẽ hơn

        /*
        if fileManager.fileExists(atPath: prefs.path) {
            updateScanningUrl(prefs.path)
            if let contents = try? fileManager.contentsOfDirectory(at: prefs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for file in contents {
                    guard file.pathExtension == "plist" else { continue }
                    
                    let bundleId = file.deletingPathExtension().lastPathComponent
                    
                    // Kiểm tra bảo mật bổ sung
                    if isOrphanedFile(bundleId: bundleId, installedApps: installedApps) {
                        if SafetyGuard.shared.isSafeToDelete(file) {
                            // Chỉ thêm những ứng dụng chắc chắn là ứng dụng của bên thứ ba plist
                            if bundleId.contains(".") && 
                               !bundleId.hasPrefix("com.apple.") &&
                               !bundleId.hasPrefix("apple") {
                                if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                                   let size = attrs[.size] as? Int64, size > 100_000 { // Chỉ thêm >100KB của
                                    items.append(DeepCleanItem(
                                        url: file,
                                        name: file.lastPathComponent,
                                        size: size,
                                        category: .appResiduals
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        */
        
        // 4. Scan Container (thùng chứa sandbox)

        let containers = home.appendingPathComponent("Library/Containers")
        if fileManager.fileExists(atPath: containers.path) {
            updateScanningUrl(containers.path)
            if let contents = try? fileManager.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for folder in contents {
                    // Update UI occasionally
                    if Int.random(in: 0...10) == 0 { await MainActor.run { self.updateScanningUrl(folder.path) } }
                    
                    let bundleId = folder.lastPathComponent
                    
                    if isOrphanedFile(bundleId: bundleId, installedApps: installedApps) {
                        if SafetyGuard.shared.isSafeToDelete(folder) {
                            let size = await calculateSizeAsync(at: folder)
                            if size > 100_000 { // Chỉ thêm phần còn lại lớn hơn 100KB
                                items.append(DeepCleanItem(
                                    url: folder,
                                    name: bundleId,
                                    size: size,
                                    category: .appResiduals
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        print("[DeepClean] ✅ Quét xong, tìm thấy \(items.count) mục còn sót của ứng dụng")
        return items
    }
    
    // MARK: - Phương pháp phụ trợ phát hiện dư lượng

    
    /// Xác định xem tên tệp/thư mục có phải là phần còn lại của ứng dụng đã gỡ cài đặt hay không

    private func isOrphanedFolder(name: String, installedApps: Set<String>) -> Bool {
        let lowerName = name.lowercased()
        
        // 1. Bỏ qua các thư mục hệ thống và dịch vụ của Apple

        let systemDirs = [
            // Thư mục hệ thống cốt lõi

            "cloudkit", "geoservices", "familycircle", "knowledge", "metadata",
            "tmp", "t", "caches", "cache", "logs", "preferences", "temp",
            "cookies", "webkit", "httpstorages", "containers", "group containers",
            "databases", "keychains", "accounts", "mail", "calendars", "contacts",
            
            // Ứng dụng và dịch vụ của Apple

            "safari", "finder", "dock", "spotlight", "siri",
            "passkit", "wallet",  // ⚠️ Dịch vụ ví và tiền điện tử
            "appstore", "facetime", "messages", "photos", "music", "tv",
            "icloud", "cloudphotosd", "cloudpaird",
            
            // Trình nền hệ thống và tác nhân

            "accountsd", "appleaccount", "identityservicesd",
            "itunesstored", "commerce", "storekit",
            "softwareupdate", "diagnostics"
        ]
        if systemDirs.contains(lowerName) { return false }
        
        // 2. Bỏ qua các thư mục ẩn bắt đầu bằng .

        if name.hasPrefix(".") { return false }
        
        // 3. Bỏ qua thư mục hệ thống Apple

        if lowerName.hasPrefix("com.apple.") { return false }
        if lowerName.hasPrefix("apple") { return false }
        
        // 4. Kiểm tra xem nó có khớp với ứng dụng đã cài đặt không

        // khớp chính xác

        if installedApps.contains(lowerName) { return false }
        
        // Khớp mờ: Kiểm tra xem nó có chứa tên của ứng dụng đã cài đặt không

        for appId in installedApps {
            // Kết hợp hai chiều

            if lowerName.contains(appId) || appId.contains(lowerName) {
                // Kiểm tra bổ sung: tránh các chuỗi không khớp và quá ngắn

                if min(lowerName.count, appId.count) >= 5 {
                    return false
                }
            }
        }
        
        // 5. Kiểm tra thành phần ở định dạng Bundle ID

        if lowerName.contains(".") {
            let components = lowerName.components(separatedBy: ".")
            for component in components where component.count >= 4 {
                for appId in installedApps {
                    if appId.contains(component) {
                        return false
                    }
                }
            }
        }
        
        // Đã vượt qua tất cả các cuộc kiểm tra và được xác nhận là còn sót lại

        return true
    }
    
    /// Kiểm tra xem Bundle ID có phải phần còn sót của ứng dụng đã gỡ cài đặt hay không.

    private func isOrphanedFile(bundleId: String, installedApps: Set<String>) -> Bool {
        let lowerBundleId = bundleId.lowercased()
        
        // 1. Bỏ qua các tệp hệ thống bắt đầu bằng . (chẳng hạn như .GlobalPreferences.plist)

        if bundleId.hasPrefix(".") { return false }
        
        // 2. Bỏ qua tất cả các dịch vụ hệ thống của Apple

        if lowerBundleId.hasPrefix("com.apple.") { return false }
        if lowerBundleId.hasPrefix("apple") { return false }
        
        // 3. 🛡️ Danh sách trắng dịch vụ hệ thống mở rộng (các thành phần hệ thống chính)

        let systemBundleIds = [
            // Dịch vụ hệ thống cốt lõi

            "loginwindow", "finder", "dock", "systemuiserver", "controlcenter",
            "notificationcenter", "launchservicesd", "cfprefsd",
            
            // Trình nền hệ thống

            "contextstoreagent", "contextstore",  // lưu trữ ngữ cảnh
            "pbs", "pasteboard",                   // dịch vụ clipboard
            "familycircled", "familycircle",       // chia sẻ nhà
            "sharedfilelistd", "sharedfilelist",   // Danh sách tập tin được chia sẻ
            "diagnostics_agent", "diagnostics",    // Chẩn đoán hệ thống
            
            // Tài khoản Apple và xác thực

            "passkit", "wallet", "passd",          // Dịch vụ ví và tiền điện tử ⚠️ QUAN TRỌNG
            "accountsd", "accounts",               // Quản lý tài khoản
            "identityservicesd", "appleaccount",   // Xác thực
            
            // Dịch vụ iCloud và đồng bộ hóa

            "cloudd", "icloud", "bird", "syncdefaultsd",
            "cloudphotosd", "cloudpaird", "cloudkitd",
            
            // Cửa hàng ứng dụng và nội dung tải xuống

            "itunesstored", "commerce", "storekit", "appstoreupdates",
            "softwareupdate", "softwareupdate_notify_agent",
            
            // Dịch vụ truyền thông và đa phương tiện

            "mediaremoted", "coremedia", "avfoundation",
            "applemediaservices", "applemedialibrary",
            
            // Mạng và bảo mật

            "networkd", "securityd", "trustd", "keybagd",
            
            // Các dịch vụ chính khác

            "coreduetd", "dasd", "rapportd", "askpermissiond"
        ]
        if systemBundleIds.contains(lowerBundleId) { return false }
        
        // 4. So khớp chính xác theo Bundle ID

        if installedApps.contains(bundleId) || installedApps.contains(lowerBundleId) {
            return false
        }
        
        // 5. Fuzzymatch: Kiểm tra từng thành phần của Bundle ID

        let components = bundleId.components(separatedBy: ".")
        for component in components where component.count > 3 {
            for appId in installedApps {
                if appId.contains(component) || component.contains(appId) {
                    return false
                }
            }
        }
        
        // Đã vượt qua tất cả các cuộc kiểm tra và được xác nhận là còn sót lại

        return true
    }
    
    private func scanJunk() async -> [DeepCleanItem] {
        // Trash, Downloads (Older than X?), Xcode DerivedData
        let home = fileManager.homeDirectoryForCurrentUser
        let trash = home.appendingPathComponent(".Trash")
        
        var items: [DeepCleanItem] = []
        
        // 1. Scan Trash
        updateScanningUrl(trash.path)
        let trashSize = await calculateSizeAsync(at: trash)
        if trashSize > 0 {
            items.append(DeepCleanItem(
                url: trash,
                name: L("Rác"),
                size: trashSize,
                category: .junkFiles
            ))
        }
        
        // 2. Xcode DerivedData
        let developer = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if fileManager.fileExists(atPath: developer.path) {
            updateScanningUrl(developer.path)
            let size = await calculateSizeAsync(at: developer)
             if size > 0 {
                items.append(DeepCleanItem(
                    url: developer,
                    name: "Xcode DerivedData",
                    size: size,
                    category: .junkFiles
                ))
            }
        }
        
        // 3. iOS Device Backups
        let iosBackups = home.appendingPathComponent("Library/Application Support/MobileSync/Backup")
        if fileManager.fileExists(atPath: iosBackups.path) {
            updateScanningUrl(iosBackups.path)
            let size = await calculateSizeAsync(at: iosBackups)
            if size > 0 {
                items.append(DeepCleanItem(
                    url: iosBackups,
                    name: L("Sao lưu iOS"),
                    size: size,
                    category: .junkFiles
                ))
            }
        }
        
        // 4. Mail Downloads
        let mailDownloads = home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
        if fileManager.fileExists(atPath: mailDownloads.path) {
            updateScanningUrl(mailDownloads.path)
            let size = await calculateSizeAsync(at: mailDownloads)
            if size > 0 {
                items.append(DeepCleanItem(
                    url: mailDownloads,
                    name: L("Tệp đính kèm thư"),
                    size: size,
                    category: .junkFiles
                ))
            }
        }
        
        // 5. Bộ nhớ đệm ứng dụng - Quét bộ nhớ đệm ứng dụng trong ~/Library/Caches

        // ⚠️ LƯU Ý: Thư mục Caches chứa một số lượng lớn bộ đệm của hệ thống và ứng dụng

        // Vì lý do bảo mật, chỉ quét các bộ nhớ đệm được xác định rõ ràng là ứng dụng của bên thứ ba.

        let cachesDir = home.appendingPathComponent("Library/Caches")
        if fileManager.fileExists(atPath: cachesDir.path) {
            updateScanningUrl(cachesDir.path)
            if let cacheContents = try? fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for cacheFolder in cacheContents {
                    // Update UI occasionally
                    if Int.random(in: 0...5) == 0 { await MainActor.run { self.updateScanningUrl(cacheFolder.path) } }
                    
                    let folderName = cacheFolder.lastPathComponent.lowercased()
                    
                    // 🛡️ Cấp độ đầu tiên: Bỏ qua tất cả bộ đệm hệ thống của Apple một cách rõ ràng

                    if folderName.hasPrefix("com.apple.") {
                        continue  // Không bao giờ quét bộ nhớ đệm hệ thống của Apple
                    }
                    
                    // 🛡️ Lớp thứ hai: Bỏ qua ứng dụng đang chạy (ứng dụng của chúng tôi)

                    if folderName == "com.tool.appuninstaller" {
                        continue  // Không xóa bộ nhớ đệm riêng
                    }
                    
                    // 🛡️Lớp thứ ba: Bỏ qua bộ đệm dịch vụ hệ thống Apple đã biết

                    let appleSystemServices = [
                        "passkit",  // Dịch vụ Apple Wallet/Mật khẩu
                        "cloudkit", "clouddocs", "cloudphotosd",
                        "familycircle", "familycircled",
                        "sqlite", "metadata", "applemedialibrary",
                        "applemediaservices", "itunesstored",
                        "commerce", "storekit", "appleaccount",
                        "accountsd", "identityservicesd",
                        "com.crashlytics", "diagnostics",
                        "appstoreupdates", "softwareupdate"
                    ]
                    if appleSystemServices.contains(folderName) {
                        continue  // Bỏ qua các dịch vụ hệ thống của Apple
                    }
                    
                    // 🛡️Cấp 4: Bỏ qua bộ nhớ cache cho tất cả các ứng dụng đang chạy

                    let runningBundleIds = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() }
                    if runningBundleIds.contains(folderName) {
                        continue  // Không xóa bộ nhớ đệm của ứng dụng đang chạy
                    }
                    
                    // 🛡️Cấp độ 5: Kiểm tra lần cuối SafetyGuard

                    if SafetyGuard.shared.isSafeToDelete(cacheFolder) {
                        let size = await calculateSizeAsync(at: cacheFolder)
                        if size > 100_000 { // Chỉ thêm bộ đệm lớn hơn 100KB
                            items.append(DeepCleanItem(
                                url: cacheFolder,
                                name: cacheFolder.lastPathComponent,
                                size: size,
                                category: .junkFiles
                            ))
                        }
                    }
                }
            }
        }
        
        // 6. Bộ nhớ đệm của trình duyệt

        let browserCaches: [(name: String, path: String)] = [
            (L("Bộ đệm Safari"), "Library/Caches/com.apple.Safari"),
            (L("Bộ đệm Chrome"), "Library/Caches/Google/Chrome"),
            (L("Bộ đệm Firefox"), "Library/Caches/Firefox"),
            (L("Bộ đệm Edge"), "Library/Caches/com.microsoft.Edge")
        ]
        
        for (name, relativePath) in browserCaches {
            let cachePath = home.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: cachePath.path) {
                updateScanningUrl(cachePath.path)
                let size = await calculateSizeAsync(at: cachePath)
                if size > 0 {
                    items.append(DeepCleanItem(
                        url: cachePath,
                        name: name,
                        size: size,
                        category: .junkFiles
                    ))
                }
            }
        }
        
        return items
    }
    
    // MARK: - App Helpers
    
    /// Lấy bộ định danh các ứng dụng đã cài đặt (Bundle ID + Name) - phiên bản cải tiến

    private func getInstalledAppParams() async -> Set<String> {
        var params = Set<String>()
        
        // 1. Quét thư mục ứng dụng chuẩn

        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                if item.hasSuffix(".app") {
                    // Thêm tên ứng dụng (bỏ hậu tố)

                    let name = (item as NSString).deletingPathExtension
                    params.insert(name.lowercased())
                    
                    // Đọc Info.plist để lấy ID gói

                    let appPath = (dir as NSString).appendingPathComponent(item)
                    let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                    
                    if let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        params.insert(bundleId.lowercased())
                        
                        // Trích xuất các thành phần ID gói

                        for component in bundleId.components(separatedBy: ".") where component.count > 3 {
                            params.insert(component.lowercased())
                        }
                    }
                }
            }
        }
        
        // 2. Thêm ứng dụng Homebrew Cask

        let homebrewPaths = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
        for caskPath in homebrewPaths {
            if let casks = try? fileManager.contentsOfDirectory(atPath: caskPath) {
                for cask in casks {
                    params.insert(cask.lowercased())
                }
            }
        }
        
        // 3. Thêm ứng dụng đang chạy (kiểm tra bảo mật quan trọng nhất)

        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                params.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                params.insert(name.lowercased())
            }
        }
        
        // 4. Danh sách bảo mật hệ thống mở rộng

        let systemSafelist = [
            // Dịch vụ hệ thống của Apple

            "com.apple", "cloudkit", "safari", "mail", "messages", "photos",
            "finder", "dock", "spotlight", "siri", "xcode", "instruments",
            "passkit", "wallet", "appstore", "facetime", "imessage",
            "familycircle", "familysharing", "icloud", "appleaccount",
            "findmy", "fmip", "healthkit", "homekit", "newsstand",
            "itunesstored", "commerce", "storekit", "applemediaservices",
            // Các ứng dụng bên thứ ba thường được sử dụng

            "google", "chrome", "microsoft", "firefox", "adobe", "dropbox",
            "slack", "discord", "zoom", "telegram", "wechat", "qq", "tencent",
            "jetbrains", "vscode", "homebrew", "npm", "python", "ruby", "java",
            "todesk", "teamviewer", "anydesk"  // Công cụ máy tính từ xa
        ]
        for safe in systemSafelist {
            params.insert(safe)
        }
        
        return params
    }
    
    private func isAppInstalled(_ name: String, params: Set<String>) -> Bool {
        let lowerName = name.lowercased()
        
        // 1. Trận đấu trực tiếp

        if params.contains(lowerName) { return true }
        
        // 2. Kiểm tra xem nó có được dành riêng cho hệ thống không

        if lowerName.starts(with: "com.apple.") { return true }
        if lowerName.starts(with: "apple") { return true }
        
        // 3. Khớp mờ: Kiểm tra xem có bao gồm tên ứng dụng đã cài đặt hay không

        for param in params {
            // Kiểm tra ngăn chặn hai chiều

            if lowerName.contains(param) || param.contains(lowerName) {
                return true
            }
        }
        
        // 4. Bảo vệ khung và plug-in

        let safePatterns = ["framework", "plugin", "extension", "helper", "service", "daemon", "agent"]
        for pattern in safePatterns {
            if lowerName.contains(pattern) { return true }
        }
        
        return false
    }

    
    // Toggle Logic
    func toggleSelection(for item: DeepCleanItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isSelected.toggle()
        }
        objectWillChange.send()
    }
    
    func toggleCategorySelection(_ category: DeepCleanCategory, to newState: Bool) {
        let categoryItems = items.filter { $0.category == category }
        for item in categoryItems {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isSelected = newState
            }
        }
        objectWillChange.send()
    }
    
    func selectItems(in category: DeepCleanCategory) {
        for i in items.indices where items[i].category == category {
            items[i].isSelected = true
        }
    }
    
    func deselectItems(in category: DeepCleanCategory) {
        for i in items.indices where items[i].category == category {
            items[i].isSelected = false
        }
    }
    
    ///Xóa một mục duy nhất

    @MainActor
    func deleteSingleItem(_ item: DeepCleanItem) async -> Bool {
        // ⚠️ KHẮC PHỤC LỖI: Thêm kiểm tra SafetyGuard

        if !SafetyGuard.shared.isSafeToDelete(item.url) {
            print("[DeepClean] 🛡️ SafetyGuard blocked deletion: \(item.url.path)")
            return false
        }
        
        do {
            // ⚠️ Cải thiện bảo mật: sử dụng thùng rác thay vì xóaItem, hỗ trợ khôi phục từ thùng rác

            try fileManager.trashItem(at: item.url, resultingItemURL: nil)
            items.removeAll { $0.id == item.id }
            totalSize -= item.size
            return true
        } catch {
            print("Xóa thất bại: \(item.url.path) - \(error)")
            return false
        }
    }
}
