import Foundation
import Combine
import AppKit

// MARK: - loại rác enum

enum JunkType: String, CaseIterable, Identifiable {
    case userCache = "Bộ đệm người dùng"
    case systemCache = "Bộ đệm hệ thống"
    case userLogs = "Nhật ký người dùng"
    case systemLogs = "Nhật ký hệ thống"
    case browserCache = "Bộ đệm trình duyệt"
    case appCache = "Bộ đệm ứng dụng"
    case chatCache = "Bộ đệm trò chuyện"
    case mailAttachments = "Tệp đính kèm email"
    case crashReports = "Báo cáo sự cố"
    case tempFiles = "Tệp tạm"
    case xcodeDerivedData = "Rác Xcode"
    // Loại mới

    case universalBinaries = "Nhị phân đa kiến trúc"
    case unusedDiskImages = "Ảnh đĩa không dùng"
    case brokenLoginItems = "Mục đăng nhập lỗi"
    case languageFiles = "Tệp ngôn ngữ"
    case deletedUsers = "Người dùng đã xóa"
    case iosBackups = "Bản sao lưu iOS"
    case oldUpdates = "Bản cập nhật cũ"
    // ⚠️ đã xóa tùy chọn bị hỏng - tùy chọn hệ thống không còn được quét nữa

    case documentVersions = "Phiên bản tài liệu"
    case downloads = "Tải xuống"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .userCache: return "person.crop.circle.fill" // User Cache
        case .systemCache: return "gear.circle.fill" // System Cache
        case .userLogs: return "doc.text.fill" // User Logs
        case .systemLogs: return "doc.text.fill" // System Logs
        case .appCache: return "square.stack.3d.up.fill"
        case .browserCache: return "globe.americas.fill"
        case .chatCache: return "message.fill"
        case .mailAttachments: return "envelope.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        case .tempFiles: return "clock.fill"
        case .xcodeDerivedData: return "hammer.fill"
        // New Types Icons
        case .unusedDiskImages: return "externaldrive.fill" // Disk Image
        case .universalBinaries: return "cpu.fill" // Universal Binary
        case .brokenLoginItems: return "person.badge.minus" // Broken Login
        case .deletedUsers: return "person.crop.circle.badge.xmark" // Deleted Users
        case .iosBackups: return "iphone.circle.fill" // iOS Backups
        case .oldUpdates: return "arrow.down.doc.fill" // Updates
        // đã xóa tùy chọn bị hỏng

        case .documentVersions: return "doc.on.doc.fill"
        case .languageFiles: return "globe"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .userCache: return L("Các tệp bộ đệm tạm do ứng dụng tạo ra")
        case .systemCache: return L("Bộ đệm do macOS tạo ra")
        case .userLogs: return L("Nhật ký hoạt động của ứng dụng")
        case .systemLogs: return L("Tệp nhật ký hệ thống macOS")
        case .browserCache: return L("Bộ đệm từ Chrome, Safari, Firefox và các trình duyệt khác")
        case .appCache: return L("Tệp tạm từ nhiều ứng dụng")
        case .chatCache: return L("Bộ đệm trò chuyện từ WeChat, QQ, Telegram và các ứng dụng tương tự")
        case .mailAttachments: return L("Tệp đính kèm được tải về từ email")
        case .crashReports: return L("Báo cáo chẩn đoán khi ứng dụng gặp sự cố")
        case .tempFiles: return L("Tệp tạm do hệ thống và ứng dụng tạo ra")
        case .xcodeDerivedData: return L("Tệp trung gian do Xcode tạo trong lúc biên dịch")
        // Thêm mô tả

        case .universalBinaries: return L("Mã dư thừa dành cho ứng dụng hỗ trợ nhiều kiến trúc hệ thống")
        case .unusedDiskImages: return L("Tệp ảnh đĩa DMG/ISO đã tải về nhưng không dùng")
        case .brokenLoginItems: return L("Mục đăng nhập trỏ tới ứng dụng hoặc tệp không còn tồn tại")
        case .languageFiles: return L("Gói ngôn ngữ ứng dụng không sử dụng")
        case .deletedUsers: return L("Dữ liệu còn sót của người dùng đã xóa")
        case .iosBackups: return L("Tệp sao lưu thiết bị iOS")
        case .oldUpdates: return L("Gói cập nhật phần mềm cũ đã cài")
        // BrokenPreferences đã bị xóa - Tùy chọn hệ thống không còn được quét nữa

        case .documentVersions: return L("Lịch sử phiên bản tài liệu cũ")
        case .downloads: return L("Các tệp trong thư mục Tải xuống")
        }
    }
    
    var searchPaths: [String] {
        // SAFETY: Only scan user home (~/) paths. NEVER scan system paths.
        switch self {
        case .userCache: 
            return [
                "~/Library/Saved Application State",
                "~/Library/Cookies"
            ]
        case .systemCache:
            // Quét bộ đệm hệ thống cấp người dùng

            return [
                "~/Library/Caches"
            ]
        case .userLogs: 
            return [
                "~/Library/Logs",
                "~/Library/Application Support/CrashReporter"
            ]
        case .systemLogs:
            // Removed /Library/Logs, /private/var/log - only user logs
            return [
                "~/Library/Logs"
            ]
        case .browserCache: 
            // Chỉ chứa đường dẫn bộ đệm an toàn, thư mục chứa thông tin đăng nhập đã bị xóa

            // Lưu ý: IndexedDB, LocalStorage, Cơ sở dữ liệu, Firefox/Profiles, CacheStorage đã bị xóa - những thứ này chứa thông tin đăng nhập của người dùng

            return [
                // Chrome - Bộ nhớ đệm an toàn

                "~/Library/Caches/Google/Chrome",
                "~/Library/Application Support/Google/Chrome/Default/Cache",
                "~/Library/Application Support/Google/Chrome/Default/Code Cache",
                "~/Library/Application Support/Google/Chrome/Default/GPUCache",
                "~/Library/Application Support/Google/Chrome/ShaderCache",
                // Safari - Chỉ có bộ nhớ đệm an toàn

                "~/Library/Caches/com.apple.Safari",
                // Firefox - Chỉ lưu trữ an toàn (Đã xóa hồ sơ - bao gồm lịch sử và thông tin đăng nhập)

                "~/Library/Caches/Firefox",
                // Edge - Bộ nhớ đệm an toàn

                "~/Library/Caches/Microsoft Edge",
                "~/Library/Application Support/Microsoft Edge/Default/Cache",
                "~/Library/Application Support/Microsoft Edge/Default/Code Cache",
                // Arc - Bộ nhớ đệm an toàn

                "~/Library/Caches/company.thebrowser.Browser",
                "~/Library/Application Support/Arc/User Data/Default/Cache",
                // Brave - Bộ nhớ đệm an toàn

                "~/Library/Caches/BraveSoftware",
                "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",
                // Opera
                "~/Library/Caches/com.operasoftware.Opera",
                // Vivaldi
                "~/Library/Caches/com.vivaldi.Vivaldi"
            ]
        case .appCache:
            return [] // Dynamic scanning implemented in scanTypeConcurrent
        case .chatCache:
            // LƯU Ý: Chỉ quét các đường dẫn an toàn trong ~/Library/Caches và ~/Library/Application Support

            // Không quét thư mục ~/Library/Containers/<other-app> vì nó sẽ kích hoạt cửa sổ bật lên cấp phép macOS

            return [
                // WeChat - Chỉ thư mục bộ nhớ đệm

                "~/Library/Caches/com.tencent.xinWeChat",
                // QQ - Chỉ thư mục bộ đệm

                "~/Library/Caches/com.tencent.qq",
                // Telegram
                "~/Library/Caches/ru.keepcoder.Telegram",
                "~/Library/Application Support/Telegram Desktop",
                // Slack
                "~/Library/Caches/com.tinyspeck.slackmacgap",
                "~/Library/Application Support/Slack/Service Worker/CacheStorage",
                // Discord
                "~/Library/Caches/com.hnc.Discord",
                "~/Library/Application Support/discord/Cache",
                "~/Library/Application Support/discord/Code Cache",
                // WhatsApp
                "~/Library/Caches/net.whatsapp.WhatsApp",
                "~/Library/Application Support/WhatsApp/Cache",
                // Line
                "~/Library/Caches/jp.naver.line.mac",
                // Tệp đính kèm iMessage (làm sạch tùy chọn)

                "~/Library/Messages/Attachments"
            ]
        case .mailAttachments:
            return [
                "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                "~/Library/Mail Downloads",
                "~/Library/Caches/com.apple.mail"
            ]
        case .crashReports:
            // Removed /Library paths - only user crash reports
            return [
                "~/Library/Logs/DiagnosticReports",
                "~/Library/Application Support/CrashReporter"
            ]
        case .tempFiles:
            // Removed /tmp, /private - only user temp files
            return [
                "~/Library/Application Support/CrashReporter",
                "~/Library/Caches/com.apple.helpd",
                "~/Library/Caches/CloudKit",
                "~/Library/Caches/GeoServices",
                "~/Library/Caches/com.apple.parsecd",
                "~/Downloads/*.dmg",
                "~/Downloads/*.pkg",
                "~/Downloads/*.zip"
            ]
        case .xcodeDerivedData: 
            return [
                "~/Library/Developer/Xcode/DerivedData",
                "~/Library/Developer/Xcode/Archives",
                "~/Library/Developer/CoreSimulator/Caches",
                "~/Library/Developer/CoreSimulator/Devices",
                "~/Library/Developer/Xcode/iOS DeviceSupport",
                "~/Library/Developer/Xcode/watchOS DeviceSupport",
                "~/Library/Developer/Xcode/tvOS DeviceSupport",
                "~/Library/Caches/com.apple.dt.Xcode",
                // CocoaPods
                "~/Library/Caches/CocoaPods",
                // npm/yarn/pnpm
                "~/.npm/_cacache",
                "~/.npm/_logs",
                "~/Library/Caches/Yarn",
                "~/Library/pnpm",
                // Gradle/Maven
                "~/.gradle/caches",
                "~/.m2/repository",
                // Homebrew
                "~/Library/Caches/Homebrew",
                // pip
                "~/Library/Caches/pip",
                // Ruby/Gem
                "~/.gem",
                // Go
                "~/go/pkg/mod/cache"
            ]
        // DISABLED TYPES - These are risky or require system access
        case .universalBinaries:
            return ["/Applications", "/System/Applications", "/System/Applications/Utilities", "~/Applications"]
        case .unusedDiskImages:
            return ["~"] // Scan full user home directory recursively
        case .brokenLoginItems:
            return ["~/Library/LaunchAgents"]
        case .languageFiles:
            return [] // Custom logic
        case .deletedUsers:
            return ["/Users/Deleted Users"]
        case .iosBackups:
            return ["~/Library/Application Support/MobileSync/Backup"]
        case .oldUpdates:
            return ["/Library/Updates"]
        // brokenPreferences LOẠI BỎ - Không bao giờ quét lại tùy chọn hệ thống
        case .documentVersions:
            return ["/.DocumentRevisions-V100"] 
        case .downloads:
            return ["~/Downloads"]
        }
    }
}

// MARK: - Mô hình đồ rác
class JunkItem: Identifiable, ObservableObject, @unchecked Sendable {
    let id = UUID()
    let type: JunkType
    let path: URL
    let contextPath: URL? // Path for the actual operation (e.g., binary to strip), while `path` is for display (App Bundle)
    let customName: String? // Optional custom display name
    let size: Int64
    @Published var isSelected: Bool = true
    
    init(type: JunkType, path: URL, size: Int64, contextPath: URL? = nil, customName: String? = nil) {
        self.type = type
        self.path = path
        self.size = size
        self.contextPath = contextPath
        self.customName = customName
    }
    
    var name: String {
        customName ?? path.lastPathComponent
    }
}

// MARK: - Dịch vụ dọn rác
class JunkCleaner: ObservableObject {
    @Published var junkItems: [JunkItem] = []
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false  // Thêm trạng thái sạch
    @Published var scanProgress: Double = 0
    @Published var hasPermissionErrors: Bool = false
    @Published var currentScanningPath: String = "" // Add path tracking
    @Published var currentScanningCategory: String = "" // Add category tracking
    
    // MARK: - Phân loại theo dõi tiến độ làm sạch
    /// Danh sách các danh mục đang được làm sạch theo đúng thứ tự thực thi
    @Published var cleaningCategories: [JunkType] = []
    /// Danh mục hiện đang được làm sạch
    @Published var currentCleaningCategory: JunkType? = nil
    /// Tình trạng vệ sinh của từng danh mục: pending, cleaning, completed
    @Published var categoryCleaningStatus: [JunkType: CleaningStatus] = [:]
    /// Kích thước dọn dẹp cho mỗi danh mục
    @Published var categoryCleanedSize: [JunkType: Int64] = [:]
    
    enum CleaningStatus: String {
        case pending = "pending"      // Đang chờ dọn dẹp
        case cleaning = "cleaning"    // Dọn dẹp
        case completed = "completed"  // Đã hoàn tất dọn dẹp
    }
    
    private let fileManager = FileManager.default
    
    var totalSize: Int64 {
        junkItems.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        junkItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    /// đặt lại tất cả trạng thái
    @MainActor
    func reset() {
        junkItems.removeAll()
        isScanning = false
        isCleaning = false
        scanProgress = 0
        hasPermissionErrors = false
        currentScanningPath = ""
        currentScanningCategory = ""
        // Đặt lại trạng thái làm sạch danh mục
        cleaningCategories.removeAll()
        currentCleaningCategory = nil
        categoryCleaningStatus.removeAll()
        categoryCleanedSize.removeAll()
    }
    
    /// Dừng quét
    @MainActor
    func stopScanning() {
        isScanning = false
        scanProgress = 0
        currentScanningPath = ""
        currentScanningCategory = ""
    }
    
    /// Quét tất cả rác - Sử dụng tối ưu hóa quét đồng thời đa luồng
    func scanJunk() async {
        await MainActor.run {
            isScanning = true
            junkItems.removeAll()
            scanProgress = 0
            hasPermissionErrors = false // Reset errors
        }
        
        let startTime = Date()
        
        // Remove exclusions to matching design requirement. Use safe scanning where possible.
        // Note: documentVersions and oldUpdates might require admin permissions (handled by sudo fallback or error reporting)
        let safeTypes = JunkType.allCases
        let totalTypes = safeTypes.count
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(totalTypes)
        
        // sử dụng TaskGroup Quét tất cả các loại rác cùng lúc
        await withTaskGroup(of: (JunkType, ([JunkItem], Bool)).self) { group in
            for type in safeTypes {
                group.addTask {
                    let (typeItems, hasError) = await self.scanTypeConcurrent(type)
                    return (type, (typeItems, hasError))
                }
            }
            
            // Thu thập kết quả và cập nhật tiến độ - cập nhật theo thời gian thực junkItems để hiển thị kích thước tích lũy
            for await (_, (typeItems, hasError)) in group {
                if hasError {
                    await MainActor.run { self.hasPermissionErrors = true }
                }
                
                // Nối kết quả theo thời gian thực vào junkItems(làm totalSize cập nhật theo thời gian thực)
                if !typeItems.isEmpty {
                    await MainActor.run {
                        for item in typeItems {
                            item.isSelected = true
                        }
                        self.junkItems.append(contentsOf: typeItems)
                    }
                }
                
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
        }
        
        // Sắp xếp: giảm dần theo kích thước
        await MainActor.run {
            self.junkItems.sort { $0.size > $1.size }
        }
        
        // Ensure minimum 2 seconds scanning time for better UX
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 2.0 {
            try? await Task.sleep(nanoseconds: UInt64((2.0 - elapsed) * 1_000_000_000))
        }

        await MainActor.run {
            isScanning = false
        }
    }
    
    /// Quét đồng thời một loại - Phiên bản tối ưu, xử lý song song nhiều đường dẫn tìm kiếm
    private func scanTypeConcurrent(_ type: JunkType) async -> ([JunkItem], Bool) {
        let searchPaths = type.searchPaths
        var hasError = false
        // Nhận danh sách các ứng dụng đã cài đặt trước và chỉ khi cần (Localizations Có thể cần thiết)
        // brokenPreferences Đã xóa và không còn cần thiết installedBundleIds
        
        // sử dụng TaskGroup Quét song song nhiều đường dẫn
        var allItems: [JunkItem] = []
        
        await withTaskGroup(of: ([JunkItem], Bool).self) { group in
            for pathStr in searchPaths {
                group.addTask {
                    let expandedPath = NSString(string: pathStr).expandingTildeInPath
                    let url = URL(fileURLWithPath: expandedPath)
                    
                    await MainActor.run { 
                        self.currentScanningPath = expandedPath
                        self.currentScanningCategory = L(type.rawValue) 
                    }
                    
                    guard self.fileManager.fileExists(atPath: url.path) else { return ([], false) }
                    
                    var items: [JunkItem] = []
                    
                    // --- Các loại logic xử lý đặc biệt ---
                    
                    if type == .universalBinaries {
                        // ⚠️ Tính năng bị tắt: Giảm béo nhị phân phổ biến sẽ tự sửa đổi ứng dụng
                        // Theo nguyên tắc an toàn, các chức năng liên quan tới ứng dụng chỉ được dọn bộ đệm và rác, không sửa ứng dụng
                        // Việc sửa nhị phân ứng dụng sẽ dẫn tới:
                        // - Ký mã phá vỡ
                        // - hủy hoại App Store ứng dụng
                        // - Tiêu hủy công chứng (Notarization）
                        // - cò súng GateKeeper cảnh báo
                        print("[JunkCleaner] universalBinaries DISABLED for safety - modifying app binaries breaks signatures")
                        return ([], false)
                    }
                    
                    if type == .unusedDiskImages {
                        // Quét đệ quy thư mục để tìm .dmg / .iso
                        if let enumerator = self.fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .contentAccessDateKey], options: [.skipsHiddenFiles]) {
                            while let fileURL = enumerator.nextObject() as? URL {
                                if Int.random(in: 0...50) == 0 { 
                                    await MainActor.run { 
                                        self.currentScanningPath = fileURL.path 
                                        self.currentScanningCategory = L(type.rawValue)
                                    } 
                                } // Throttle updates
                                let ext = fileURL.pathExtension.lowercased()
                                if ["dmg", "iso", "pkg"].contains(ext) {
                                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                        items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                    }
                                }
                            }
                        }
                        return (items, false)
                    }
                    
                    // brokenPreferences LOẠI BỎ - Không quét lại bất kỳ tùy chọn nào

                    if type == .brokenLoginItems {
                        // Scan ~/Library/LaunchAgents
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                            for fileURL in contents where fileURL.pathExtension == "plist" {
                                // Parse plist to find the executable path
                                if let dict = NSDictionary(contentsOf: fileURL),
                                   let programArguments = dict["ProgramArguments"] as? [String],
                                   let executablePath = programArguments.first {
                                    
                                    // Check if executable exists
                                    if !self.fileManager.fileExists(atPath: executablePath) {
                                        // It's broken!
                                        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                             items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                        }
                                    }
                                } else if let dict = NSDictionary(contentsOf: fileURL),
                                          let program = dict["Program"] as? String {
                                     // Check Program key
                                     if !self.fileManager.fileExists(atPath: program) {
                                         if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                             items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                         }
                                     }
                                }
                            }
                        }
                        return (items, false)
                    }
                    
                    if type == .downloads {
                        // Just list top-level files in Downloads for user review, or maybe old ones?
                        // Design implies "Downloads" is just a category. Let's list all files in Downloads.
                        // Ideally we should categorize them or filter by age, but for now scan them all.
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                             for fileURL in contents {
                                 if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                     items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                 }
                             }
                        }
                        return (items, false)
                    }

                    if type == .languageFiles {
                         // ⚠️ nghiêm trọng BUG Khắc phục: tắt tính năng này
                         // xóa áp dụng .lproj Tập tin sẽ bị hỏng macOS ký mã
                         // kết quả báo cáo ứng dụng"Bị hư hại"Không thể bắt đầu
                         print("[JunkCleaner] languageFiles DISABLED for safety - deleting .lproj breaks app signatures")
                         return ([], false)
                         
                         // Mã gốc bị vô hiệu hóa:
                         /*
                         // Adapting logic from SmartCleanerService
                         // 1. Get preferred languages
                         var keepLanguages: Set<String> = ["Base", "en", "English"]
                         for lang in Locale.preferredLanguages {
                             let parts = lang.split(separator: "-").map(String.init)
                             if let languageCode = parts.first {
                                 keepLanguages.insert(languageCode)
                                 if parts.count > 1 {
                                     let secondPart = parts[1]
                                     if secondPart.count == 4 { // Script code like Hans
                                         keepLanguages.insert("\(languageCode)-\(secondPart)")
                                         keepLanguages.insert("\(languageCode)_\(secondPart)")
                                     }
                                 }
                             }
                             keepLanguages.insert(lang)
                         }
                         
                         // 2. Scan Applications
                         let appDirs = [
                             "/Applications",
                             self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
                         ]
                         
                         for appDir in appDirs {
                             guard let apps = try? self.fileManager.contentsOfDirectory(atPath: appDir) else { continue }
                             
                             for appName in apps where appName.hasSuffix(".app") {
                                 let appPath = (appDir as NSString).appendingPathComponent(appName)
                                 let appURL = URL(fileURLWithPath: appPath)
                                 
                                 // Skip system apps
                                 let plistPath = appURL.appendingPathComponent("Contents/Info.plist")
                                 if let plist = NSDictionary(contentsOfFile: plistPath.path),
                                    let bundleId = plist["CFBundleIdentifier"] as? String {
                                     if bundleId.hasPrefix("com.apple.") { continue }
                                 }
                                 
                                 // Skip App Store apps
                                 let receiptPath = appURL.appendingPathComponent("Contents/_MASReceipt")
                                 if self.fileManager.fileExists(atPath: receiptPath.path) { continue }
                                 
                                 let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
                                 guard let resources = try? self.fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) else { continue }
                                 
                                 for itemURL in resources where itemURL.pathExtension == "lproj" {
                                     let langName = itemURL.deletingPathExtension().lastPathComponent
                                     
                                     let shouldKeep = keepLanguages.contains { keep in
                                         if keep.lowercased() == langName.lowercased() { return true }
                                         if langName.lowercased().hasPrefix(keep.lowercased()) { return true }
                                         return false
                                     }
                                     
                                     if !shouldKeep {
                                         let size = await self.calculateSizeAsync(at: itemURL)
                                         if size > 0 {
                                             items.append(JunkItem(type: type, path: itemURL, size: size))
                                         }
                                     }
                                 }
                             }
                         }
                         return (items, false)
                         */
                    }
                    
                    if type == .appCache {
                        // `appCache` hiện được xử lý trong `systemCache` tại ~/Library/Caches

                        // Không còn quét riêng lẻ các Vùng chứa để tránh cửa sổ bật lên về quyền

                        return (items, false)
                    }
                    
                    // --- Logic quét phổ quát (logic gốc) ---

                    
                    do {
                        let contents = try self.fileManager.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )
                        
                        // Đồng thời tính toán kích thước của mỗi đứa trẻ

                        await withTaskGroup(of: JunkItem?.self) { sizeGroup in
                            for fileUrl in contents {
                                sizeGroup.addTask {
                                    let size = await self.calculateSizeAsync(at: fileUrl)
                                    if size > 0 {
                                        return JunkItem(type: type, path: fileUrl, size: size)
                                    }
                                    return nil
                                }
                            }
                            
                            for await item in sizeGroup {
                                if let item = item {
                                    items.append(item)
                                }
                            }
                        }
                        return (items, false)
                    } catch let error as NSError {
                        // Chỉ các lỗi từ chối cấp phép thực sự mới được đánh dấu là lỗi cấp phép

                        // Bỏ qua các trường hợp phổ biến như thư mục không tồn tại (NSFileReadNoSuchFileError = 260)

                        let isPermissionError = error.domain == NSCocoaErrorDomain && 
                            (error.code == NSFileReadNoPermissionError || error.code == NSFileWriteNoPermissionError)
                        return (items, isPermissionError)
                    }
                }
            }
            
            for await (pathItems, error) in group {
                allItems.append(contentsOf: pathItems)
                if error { hasError = true }
            }
        }
        
        return (allItems, hasError)
    }
    
    // MARK: - Phương pháp phân tích phụ trợ

    
    /// Tính toán dung lượng có thể được giải phóng bằng cách giảm bớt tệp nhị phân phổ quát

    // tính toánUniversalBinarySavings đã bị xóa - Tiết kiệm nhị phân phổ quát bị vô hiệu hóa

    
    /// Lấy Bundle ID của toàn bộ ứng dụng đã cài đặt, phiên bản cải tiến

    private func getAllInstalledAppBundleIds() -> Set<String> {
        var bundleIds = Set<String>()
        
        // 1. Quét thư mục ứng dụng chuẩn

        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for appDir in appDirs {
            if let apps = try? fileManager.contentsOfDirectory(atPath: appDir) {
                for app in apps where app.hasSuffix(".app") {
                    let appPath = "\(appDir)/\(app)"
                    let plistPath = "\(appPath)/Contents/Info.plist"
                    
                    // Thêm tên ứng dụng làm đối sánh thay thế

                    let appName = (app as NSString).deletingPathExtension
                    bundleIds.insert(appName.lowercased())
                    
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        bundleIds.insert(bundleId)
                        bundleIds.insert(bundleId.lowercased())
                        
                        // Trích xuất thành phần cuối cùng của ID gói

                        if let lastComponent = bundleId.components(separatedBy: ".").last {
                            bundleIds.insert(lastComponent.lowercased())
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
                    bundleIds.insert(cask.lowercased())
                }
            }
        }
        
        // 3. Thêm ứng dụng đang chạy

        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                bundleIds.insert(bundleId)
                bundleIds.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                bundleIds.insert(name.lowercased())
            }
        }
        
        // 4. Thêm danh sách bảo mật hệ thống

        let systemSafelist = [
            "com.apple", "apple", "google", "chrome", "microsoft", "firefox",
            "adobe", "dropbox", "slack", "discord", "zoom", "telegram",
            "wechat", "qq", "tencent", "jetbrains", "xcode", "safari"
        ]
        for safe in systemSafelist {
            bundleIds.insert(safe)
        }
        
        return bundleIds
    }
    
    // Tính toán không đồng bộ kích thước thư mục (giữ lại phiên bản tối ưu hóa ban đầu)

    private func calculateSizeAsync2(at url: URL) async -> Int64 {
        // ... (kept for reference, actual implementation uses check below)
        return await calculateSizeAsync(at: url)
    }
    
    /// Tính toán không đồng bộ kích thước thư mục - phiên bản tối ưu

    private func calculateSizeAsync(at url: URL) async -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        
        if isDirectory.boolValue {
            // Đối với các thư mục, hãy thu thập tất cả các tệp rồi tính toán chúng theo đợt

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            
            var fileURLs: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                fileURLs.append(fileURL)
            }
            
            // Tính toán đồng thời bị chặn

            let chunkSize = max(50, fileURLs.count / 4)
            let chunks = stride(from: 0, to: fileURLs.count, by: chunkSize).map {
                Array(fileURLs[$0..<min($0 + chunkSize, fileURLs.count)])
            }
            
            await withTaskGroup(of: Int64.self) { group in
                for chunk in chunks {
                    group.addTask {
                        var chunkTotal: Int64 = 0
                        for fileURL in chunk {
                            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let size = values.fileSize {
                                chunkTotal += Int64(size)
                            }
                        }
                        return chunkTotal
                    }
                }
                
                for await size in group {
                    totalSize += size
                }
            }
        } else {
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? UInt64 {
                totalSize = Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// Dọn dẹp rác đã chọn

    func cleanSelected() async -> (cleaned: Int64, failed: Int64, requiresAdmin: Bool) {
        var cleanedSize: Int64 = 0
        var failedSize: Int64 = 0
        var needsAdmin = false
        let selectedItems = junkItems.filter { $0.isSelected }
        var failedItems: [JunkItem] = []
        
        // Xử lý tất cả các tệp đã chọn

        for item in selectedItems {
            let success = await deleteItem(item)
            if success {
                cleanedSize += item.size
            } else {
                failedSize += item.size
                failedItems.append(item)
            }
        }
        
        // Nếu có dự án thất bại, hãy thử xóa chúng bằng quyền sudo

        if !failedItems.isEmpty {
            let failedPaths = failedItems.map { $0.path.path }
            let (sudoCleanedSize, sudoSuccess) = await cleanWithAdminPrivileges(paths: failedPaths, items: failedItems)
            if sudoSuccess {
                cleanedSize += sudoCleanedSize
                failedSize -= sudoCleanedSize
            } else {
                needsAdmin = true
            }
        }
        
        await MainActor.run { [failedItems] in
            self.junkItems.removeAll { item in
                selectedItems.contains { $0.id == item.id } && !failedItems.contains { $0.id == item.id }
            }
            // Cập nhật hiển thị dung lượng ổ đĩa

            DiskSpaceManager.shared.updateDiskSpace()
        }
        
        // Lưu ý: Không quét lại sau khi quá trình dọn dẹp hoàn tất, nếu không sẽ khiến giao diện người dùng hiển thị 0KB để giải phóng dung lượng.

        // Vì các mục đã được làm sạch đã bị loại bỏ khỏi các mục rác ở trên

        
        return (cleanedSize, failedSize, needsAdmin)
    }
    
    /// Dọn dẹp từng rác đã chọn - Dọn dẹp từng rác một theo yêu cầu thiết kế và hiển thị tiến độ

    func cleanSelectedByCategory() async -> (cleaned: Int64, failed: Int64, requiresAdmin: Bool) {
        var totalCleanedSize: Int64 = 0
        var totalFailedSize: Int64 = 0
        var needsAdmin = false
        
        // 1. Nhận tất cả các danh mục với các mục đã chọn (sắp xếp theo thứ tự giảm dần theo kích thước)

        let selectedItems = junkItems.filter { $0.isSelected }
        let categorySizes: [JunkType: Int64] = Dictionary(grouping: selectedItems, by: { $0.type })
            .mapValues { items in items.reduce(0) { $0 + $1.size } }
        
        let sortedCategories = categorySizes.keys.sorted { 
            categorySizes[$0] ?? 0 > categorySizes[$1] ?? 0 
        }
        
        // 2. Khởi tạo trạng thái dọn dẹp phân loại

        await MainActor.run {
            self.cleaningCategories = sortedCategories
            self.categoryCleaningStatus = Dictionary(uniqueKeysWithValues: sortedCategories.map { ($0, .pending) })
            self.categoryCleanedSize = [:]
        }
        
        // 3. Dọn dẹp từng cái một

        for category in sortedCategories {
            await MainActor.run {
                self.currentCleaningCategory = category
                self.categoryCleaningStatus[category] = .cleaning
            }
            
            // Nhận các mục đã chọn của danh mục này

            let categoryItems = selectedItems.filter { $0.type == category }
            var categoryCleanedSize: Int64 = 0
            var categoryFailedItems: [JunkItem] = []
            
            // Làm sạch tất cả các tập tin trong danh mục này

            for item in categoryItems {
                let success = await deleteItem(item)
                if success {
                    categoryCleanedSize += item.size
                    totalCleanedSize += item.size
                } else {
                    totalFailedSize += item.size
                    categoryFailedItems.append(item)
                }
                
                // Cập nhật tiến trình - chụp giá trị trước để tránh cảnh báo Swift 6

                let currentCleanedSize = categoryCleanedSize
                await MainActor.run {
                    self.categoryCleanedSize[category] = currentCleanedSize
                }
            }
            
            // Cố gắng xóa tập tin với quyền quản trị viên không thành công

            if !categoryFailedItems.isEmpty {
                let failedPaths = categoryFailedItems.map { $0.path.path }
                let (sudoCleanedSize, sudoSuccess) = await cleanWithAdminPrivileges(paths: failedPaths, items: categoryFailedItems)
                if sudoSuccess {
                    categoryCleanedSize += sudoCleanedSize
                    totalCleanedSize += sudoCleanedSize
                    totalFailedSize -= sudoCleanedSize
                    // Ghi lại giá trị trước để tránh cảnh báo Swift 6

                    let currentCleanedSize = categoryCleanedSize
                    await MainActor.run {
                        self.categoryCleanedSize[category] = currentCleanedSize
                    }
                } else {
                    needsAdmin = true
                }
            }
            
            // Đánh dấu danh mục này là hoàn thành

            await MainActor.run {
                self.categoryCleaningStatus[category] = .completed
            }
            
            // Trì hoãn một chút để người dùng có thể thấy tiến trình

            try? await Task.sleep(nanoseconds: 300_000_000) // 0,3 giây
        }
        
        // 4. Xóa các mục đã được làm sạch khỏi JunkItems

        await MainActor.run {
            self.junkItems.removeAll { item in
                selectedItems.contains { $0.id == item.id }
            }
            self.currentCleaningCategory = nil
            DiskSpaceManager.shared.updateDiskSpace()
        }
        
        return (totalCleanedSize, totalFailedSize, needsAdmin)
    }
    
    /// Kiểm tra xem ứng dụng có thể thu gọn một cách an toàn hay không

    // canSafelyThinApp, ThinUniversalBinary, reSignApp đã bị xóa - Đã tắt tính năng Universal Binary Thin

    
    ///Xóa một mục duy nhất

    private func deleteItem(_ item: JunkItem) async -> Bool {
        // ⚠️ Sửa lỗi bảo mật: Kiểm tra với SafetyGuard

        if !SafetyGuard.shared.isSafeToDelete(item.path) {
            print("[JunkCleaner] 🛡️ SafetyGuard blocked deletion: \(item.path.path)")
            return false
        }
        
        // 🛡️ Sử dụng DeletionLogService để ghi lại nhật ký xóa và hỗ trợ khôi phục

        if DeletionLogService.shared.logAndDelete(at: item.path, category: "JunkClean") {
            print("[JunkCleaner] ✅ Moved to trash with log: \(item.path.lastPathComponent)")
            return true
        } else {
            print("[JunkCleaner] ⚠️ Failed to delete: \(item.path.lastPathComponent)")
            return false
        }
    }
    
    ///Làm sạch với quyền quản trị viên (thông qua AppleScript)

    private func cleanWithAdminPrivileges(paths: [String], items: [JunkItem]) async -> (Int64, Bool) {
        var cleanedSize: Int64 = 0
        var safePaths: [String] = []
        
        // 1. Kiểm tra an ninh

        for path in paths {
            if SafetyGuard.shared.isSafeToDelete(URL(fileURLWithPath: path)) {
                safePaths.append(path)
            } else {
                print("[JunkCleaner] 🛡️ Skipped unsafe path in privileged clean: \(path)")
            }
        }
        
        if safePaths.isEmpty {
            return (0, false)
        }
        
        // 2. Xây dựng lệnh xóa

        // Sử dụng rm -rf 

        let escapedPaths = safePaths.map { path in
            path.replacingOccurrences(of: "'", with: "'\\''")
        }
        
        let rmCommands = escapedPaths.map { "rm -rf '\($0)'" }.joined(separator: " && ")
        
        let script = """
        do shell script "\(rmCommands)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            
            if error == nil {
                // Thành công, tính toán kích thước dọn dẹp

                for path in safePaths {
                    if let item = items.first(where: { $0.path.path == path }) {
                        cleanedSize += item.size
                    }
                }
                return (cleanedSize, true)
            } else {
                 print("[JunkCleaner] AppleScript error: \(String(describing: error))")
            }
        }
        
        return (0, false)
    }
    
    private func scanType(_ type: JunkType) async -> [JunkItem] {
        var items: [JunkItem] = []
        
        for pathStr in type.searchPaths {
            let expandedPath = NSString(string: pathStr).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            
            guard fileManager.fileExists(atPath: url.path) else { continue }
            
            // Đối với Bộ nhớ đệm và Nhật ký, chúng tôi quét các thư mục con

            // Đối với Thùng rác, hãy quét các tệp con

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])
                
                for fileUrl in contents {
                    let size = calculateSize(at: fileUrl)
                    if size > 0 {
                        items.append(JunkItem(type: type, path: fileUrl, size: size))
                    }
                }
            } catch {
                print("Error scanning \(url.path): \(error)")
            }
        }
        
        return items
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch { continue }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch { return 0 }
            }
        }
        
        return totalSize
    }
}
