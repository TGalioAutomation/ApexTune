import Foundation
import AppKit

/// Dịch vụ bảo vệ an ninh - ngăn chặn việc vô tình xóa các tập tin hệ thống quan trọng và cấu hình ứng dụng

class SafetyGuard {
    static let shared = SafetyGuard()
    
    private let fileManager = FileManager.default
    
    // MARK: - Danh sách trắng tệp khóa hệ thống

    
    /// Tệp tùy chọn khóa hệ thống macOS (không được xóa)

    private let systemPreferencesWhitelist: Set<String> = [
        // Cài đặt hệ thống cốt lõi

        "com.apple.finder.plist",
        "com.apple.dock.plist",
        "com.apple.LaunchServices.plist",
        "com.apple.loginwindow.plist",
        "com.apple.menuextra.plist",
        "com.apple.systempreferences.plist",
        ".GlobalPreferences.plist",
        
        // Giao diện người dùng và tương tác hệ thống

        "com.apple.spaces.plist",
        "com.apple.notificationcenterui.plist",
        "com.apple.notificationcenterui-donotdisturb.plist",
        "com.apple.controlcenter.plist",
        "com.apple.Spotlight.plist",
        "com.apple.SpotlightServer.plist",
        
        // thiết bị đầu vào

        "com.apple.driver.AppleBluetoothMultitouch.mouse.plist",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad.plist",
        "com.apple.AppleMultitouchTrackpad.plist",
        "com.apple.keyboard.plist",
        
        // Khả năng tiếp cận

        "com.apple.universalaccess.plist",
        "com.apple.accessibility.plist",
        
        // Các ứng dụng tích hợp trên hệ thống

        "com.apple.Safari.plist",
        "com.apple.mail.plist",
        "com.apple.iCal.plist",
        "com.apple.Notes.plist",
        "com.apple.Contacts.plist",
        "com.apple.Maps.plist",
        "com.apple.Photos.plist",
        "com.apple.Music.plist",
        "com.apple.TV.plist",
        "com.apple.Podcasts.plist",
        "com.apple.Books.plist",
        "com.apple.FaceTime.plist",
        "com.apple.iChat.plist",
        "com.apple.TextEdit.plist",
        "com.apple.Preview.plist",
        "com.apple.QuickTimePlayerX.plist",
        
        // Dịch vụ hệ thống

        "com.apple.screensaver.plist",
        "com.apple.screencaptureui.plist",
        "com.apple.Siri.plist",
        "com.apple.speech.synthesis.general.prefs.plist",
        "com.apple.TimeMachine.plist",
        "com.apple.security.plist",
        "com.apple.networkextension.plist",
        
        // iCloud và đồng bộ hóa

        "com.apple.iCloud.plist",
        "com.apple.bird.plist",
        "com.apple.cloudd.plist",
        
        // Công cụ dành cho nhà phát triển

        "com.apple.dt.Xcode.plist",
        "com.apple.dt.instruments.plist",
        
        // Các tập tin hệ thống quan trọng khác

        "com.apple.HIToolbox.plist",
        "com.apple.LaunchServices.QuarantineEventsV2",
        "com.apple.recentitems.plist",
        "com.apple.sidebarlists.plist",
        
        // Tài khoản và xác thực (Sửa chữa quan trọng)

        "MobileMeAccounts.plist",           // Thông tin tài khoản iCloud (trước đây là MobileMe)
        "com.apple.accountsd.plist",        // Trình nền tài khoản
        "com.apple.Passbook.plist",         // Ví/Apple Pay
        "com.apple.commerce.plist",         // Lịch sử mua hàng trên App Store
        "com.apple.tourist.plist"           // Trạng thái khởi động hệ thống
    ]
    
    /// Thư mục quan trọng của hệ thống (không được quét/xóa)

    private let protectedDirectories: Set<String> = [
        // Thư mục lõi hệ thống

        "/System",
        "/Library/Apple",
        "/Library/Security",
        "/usr",
        "/bin",
        "/sbin",
        "/private/etc",
        "/private/var/db",
        "/private/var/root",
        
        // ⚠️Sửa LỖI nghiêm trọng: Bảo vệ thư mục phương tiện của người dùng để ngăn chặn việc vô tình xóa video/nhạc/hình ảnh, v.v.

        "~/Movies",
        "~/Music",
        "~/Pictures",
        "~/Documents",
        "~/Desktop",
        "~/Downloads",
        
        // ⚠️Sửa BUG nghiêm trọng: Bảo vệ thư mục ứng dụng để tránh làm hỏng ứng dụng

        "/Applications",
        "~/Applications",
        
        // Dữ liệu khóa người dùng

        "~/Library/Keychains",
        "~/Library/KeyboardServices",
        "~/Library/Cookies",
        "~/Library/Safari/Bookmarks.plist",
        "~/Library/Safari/History.db",
        "~/Library/Mail",
        "~/Library/Messages",
        "~/Library/Photos",
        
        // Trình quản lý mật khẩu và xác thực

        "~/Library/Application Support/1Password",
        "~/Library/Application Support/Bitwarden",
        "~/Library/Application Support/LastPass",
        "~/Library/Application Support/KeePassXC",
        
        // Dữ liệu khóa trình duyệt

        "~/Library/Application Support/Google/Chrome/Default/Cookies",
        "~/Library/Application Support/Google/Chrome/Default/Login Data",
        "~/Library/Application Support/Firefox/Profiles",
        "~/Library/Safari/CloudTabs.db",
        
        // môi trường phát triển

        "~/Library/Developer/Xcode/UserData",
        "~/.ssh",
        "~/.gnupg",
        
        // Lưu trữ và đồng bộ hóa đám mây

        "~/Library/Application Support/iCloud",
        "~/Library/Mobile Documents"
    ]
    
    /// Cấu hình khóa ứng dụng phổ biến (yêu cầu chăm sóc đặc biệt)

    private let criticalAppPatterns: [String] = [
        "com.google.Chrome",
        "com.microsoft.VSCode",
        "com.microsoft.edgemac",
        "com.jetbrains.",  // Tất cả các IDE JetBrains
        "com.tencent.xinWeChat",
        "com.tencent.qq",
        "com.tencent.meeting",
        "org.mozilla.firefox",
        "com.apple.dt.Xcode",
        "com.docker.docker",
        "com.spotify.client",
        "com.adobe.",  // Dòng Adobe
        "com.figma.Desktop",
        "com.notion.id",
        "com.slack.Slack",
        "us.zoom.xos",
        "com.skype.skype",
        "org.telegram.desktop",
        "com.facebook.archon.developerID",  // WhatsApp
        "com.readdle.PDFExpert-Mac",
        "com.tapbots.TweetbotMac"
    ]
    
    // MARK: - Bộ đệm phát hiện ứng dụng

    
    private var installedAppCache: Set<String>?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 phút
    
    // ĐÁNH DẤU: - API công khai

    
    /// Kiểm tra xem tập tin/thư mục có an toàn để xóa không

    /// - Parameters:
    /// - url: URL file/thư mục cần kiểm tra

    /// - ignProtection: có bỏ qua bảo vệ thư mục hay không (để dọn dẹp tệp lớn được người dùng chọn rõ ràng)

    /// - Trả về: true nghĩa là an toàn, false nghĩa là không thể xóa được

    func isSafeToDelete(_ url: URL, ignoreProtection: Bool = false) -> Bool {
        let path = url.path
        
        // 1. Kiểm tra xem đó có phải là thư mục được bảo vệ không

        // Nếu ignProtection là đúng (để dọn dẹp tệp lớn), hãy bỏ kiểm tra protectedDirectories

        // Tuy nhiên, vẫn bị cấm xóa thư mục lõi hệ thống

        if isProtectedPath(path) {
            if ignoreProtection {
                // Xác định các thư mục hệ thống cốt lõi không được xóa

                let coreSystemPaths = ["/System", "/usr", "/bin", "/sbin", "/private/var/db", "/private/var/root", "/Library/Apple", "/Library/Security"]
                let isCore = coreSystemPaths.contains { path.hasPrefix($0) }
                
                if isCore {
                    print("[SafetyGuard] 🛡️ Core system path, cannot delete even with bypass: \(path)")
                    return false
                } else {
                    print("[SafetyGuard] ⚠️ Bypassing directory protection for: \(path)")
                    // Cho phép tiếp tục kiểm tra tiếp theo

                }
            } else {
                print("[SafetyGuard] 🛡️ Protected path, cannot delete: \(path)")
                return false
            }
        }
        
        // 2. Kiểm tra xem đó có phải là file hệ thống không

        if isSystemFile(url) {
            print("[SafetyGuard] 🛡️ System file, cannot delete: \(path)")
            return false
        }
        
        // 3. Kiểm tra xem đó có phải là key hệ thống không

        if isSystemPreference(url) {
            print("[SafetyGuard] 🛡️ System preference, cannot delete: \(path)")
            return false
        }
        
        // 4. Kiểm tra xem đó có phải là cấu hình ứng dụng quan trọng không

        if isCriticalAppConfig(url) {
            print("[SafetyGuard] ⚠️ Critical app config, risky to delete: \(path)")
            // Lưu ý: Điều này trả về true, nhưng người gọi nên xử lý nó một cách thận trọng

        }
        
        // 5. 🛡️ Mới: Bảo vệ các thư mục chính của ứng dụng đã cài đặt

        if let protection = isInstalledAppProtectedPath(url) {
            if !protection.isSafeSubdir {
                print("[SafetyGuard] 🛡️ Installed app data protected: \(path) (app: \(protection.bundleId))")
                return false
            }
            // Nếu đó là thư mục con an toàn (Caches, tmp, Logs) thì được phép xóa

            print("[SafetyGuard] ✅ Safe cache subdir for installed app: \(path)")
        }
        
        return true
    }
    
    /// Kiểm tra xem ứng dụng đã được cài đặt chưa (phiên bản nâng cao, xác thực đa yếu tố)

    /// - Tham số BundleId: ID gói hoặc tên ứng dụng

    /// - Trả về: true nghĩa là đã cài đặt, false nghĩa là chưa cài đặt

    func isApplicationInstalled(_ identifier: String) -> Bool {
        let lowerId = identifier.lowercased()
        
        // 1. Kiểm tra các ứng dụng đang chạy

        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier?.lowercased(), bundleId == lowerId {
                return true
            }
            if let name = app.localizedName?.lowercased(), name == lowerId {
                return true
            }
        }
        
        // 2. Kiểm tra bộ đệm ứng dụng đã cài đặt

        let installedApps = getInstalledApplications()
        if installedApps.contains(lowerId) {
            return true
        }
        
        // 3. Kết hợp mờ - kiểm tra xem nó có được bao gồm trong các ứng dụng đã cài đặt không

        for installedId in installedApps {
            if installedId.contains(lowerId) || lowerId.contains(installedId) {
                // Kiểm tra bổ sung: Tránh các chuỗi không khớp quá ngắn

                if min(installedId.count, lowerId.count) >= 5 {
                    return true
                }
            }
        }
        
        // 4. Kiểm tra xem nó có được hệ thống bảo lưu hay không

        if lowerId.hasPrefix("com.apple.") || lowerId.hasPrefix("apple") {
            return true
        }
        
        return false
    }
    
    /// Kiểm tra xem ứng dụng tương ứng với file Preference đã được cài đặt chưa

    /// - Tham số preferencesURL: URL file ưu tiên

    /// - Trả về: true nghĩa là ứng dụng đã được cài đặt, false nghĩa là nó có thể là một file mồ côi

    func isPreferenceOrphaned(_ preferenceURL: URL) -> Bool {
        let filename = preferenceURL.deletingPathExtension().lastPathComponent
        
        // 1. Các tập tin hệ thống không bao giờ bị cô lập

        if systemPreferencesWhitelist.contains(preferenceURL.lastPathComponent) {
            return false
        }
        
        // 2. Các tập tin com.apple.* không bị cô lập

        if filename.hasPrefix("com.apple.") {
            return false
        }
        
        // 3. Kiểm tra xem tập tin có được sửa đổi gần đây không (sửa đổi trong vòng 7 ngày vẫn có thể được sử dụng)

        if let modDate = try? preferenceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            let daysSinceModification = Date().timeIntervalSince(modDate) / 86400
            if daysSinceModification < 7 {
                print("[SafetyGuard] ℹ️ \(filename) modified recently, keeping")
                return false
            }
        }
        
        // 4. Kiểm tra xem ứng dụng tương ứng đã được cài đặt chưa

        return !isApplicationInstalled(filename)
    }
    
    /// Nhận gợi ý xóa an toàn

    /// - Url tham số: URL của file cần xóa

    /// - Returns: Xóa khuyến nghị và mức độ rủi ro

    func getDeletionAdvice(for url: URL) -> (riskLevel: DeletionRiskLevel, advice: String) {
        if !isSafeToDelete(url) {
            return (.critical, L("Đây là tệp hệ thống quan trọng. Xóa nó có thể làm hệ thống hoặc ứng dụng hoạt động lỗi."))
        }

        if isSystemPreference(url) {
            return (.critical, L("Đây là tệp cấu hình hệ thống. Xóa nó sẽ làm mất các thiết lập hiện tại."))
        }

        if isCriticalAppConfig(url) {
            return (.high, L("Đây là cấu hình ứng dụng quan trọng. Xóa nó có thể làm mất thiết lập và trạng thái đăng nhập."))
        }

        if url.path.contains("/Library/Preferences") {
            if isPreferenceOrphaned(url) {
                return (.low, L("Tệp này có thể là cấu hình còn sót lại của ứng dụng đã gỡ cài đặt."))
            } else {
                return (.medium, L("Ứng dụng liên quan vẫn đang được dùng. Bạn nên giữ lại tệp này."))
            }
        }

        if url.path.contains("/Library/Caches") {
            return (.low, L("Đây là tệp bộ đệm, có thể xóa an toàn và ứng dụng sẽ tự tạo lại khi cần."))
        }

        if url.path.contains("/Library/Logs") {
            return (.low, L("Đây là tệp nhật ký, có thể xóa an toàn."))
        }

        return (.medium, L("Nên chuyển vào Thùng rác thay vì xóa ngay lập tức."))
    }
    
    // MARK: - phương pháp riêng tư

    
    private func isProtectedPath(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        for protectedDir in protectedDirectories {
            let expandedProtected = NSString(string: protectedDir).expandingTildeInPath
            if expandedPath.hasPrefix(expandedProtected) {
                return true
            }
        }
        
        return false
    }
    
    private func isSystemFile(_ url: URL) -> Bool {
        // Kiểm tra xem tập tin có trong thư mục hệ thống không

        let path = url.path
        if path.hasPrefix("/System/") || 
           path.hasPrefix("/usr/") || 
           path.hasPrefix("/bin/") || 
           path.hasPrefix("/sbin/") {
            return true
        }
        
        // Kiểm tra xem tập tin có thuộc tính bảo vệ hệ thống hay không

        if let values = try? url.resourceValues(forKeys: [.isSystemImmutableKey, .isUserImmutableKey]) {
            if values.isSystemImmutable == true || values.isUserImmutable == true {
                return true
            }
        }
        
        return false
    }
    
    private func isSystemPreference(_ url: URL) -> Bool {
        // Phải có trong thư mục Tùy chọn

        guard url.path.contains("/Library/Preferences") else {
            return false
        }
        
        let filename = url.lastPathComponent
        return systemPreferencesWhitelist.contains(filename)
    }
    
    private func isCriticalAppConfig(_ url: URL) -> Bool {
        let filename = url.deletingPathExtension().lastPathComponent
        
        for pattern in criticalAppPatterns {
            if filename.hasPrefix(pattern) || filename.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    /// 🛡️ Kiểm tra xem đường dẫn có phải là thư mục được bảo vệ của ứng dụng đã cài đặt không

    /// - Url tham số: đường dẫn cần kiểm tra

    /// - Trả về: Nếu là thư mục đã cài đặt ứng dụng thì return (bundleId, có phải là thư mục con an toàn); nếu không, trả về con số không

    private func isInstalledAppProtectedPath(_ url: URL) -> (bundleId: String, isSafeSubdir: Bool)? {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Tên thư mục con an toàn - chúng có thể được xóa một cách an toàn

        let safeSubdirNames: Set<String> = [
            "Cache", "Caches", "cache", "caches",
            "tmp", "Tmp", "temp", "Temp",
            "Logs", "logs", "Log", "log",
            "GPUCache", "ShaderCache", "Code Cache",
            "CachedData", "CachedExtensions"
        ]
        
        // 1. Kiểm tra ~/Library/Containers/<bundle-id>

        let containersPath = home + "/Library/Containers/"
        if path.hasPrefix(containersPath) {
            let relativePath = String(path.dropFirst(containersPath.count))
            let components = relativePath.components(separatedBy: "/")
            guard let bundleId = components.first, !bundleId.isEmpty else { return nil }
            
            // Kiểm tra xem ứng dụng đã được cài đặt chưa

            if isApplicationInstalled(bundleId) {
                // Kiểm tra xem đó có phải là thư mục con an toàn không

                // Ví dụ: ~/Library/Containers/com.xxx/Data/Library/Caches

                let isSafe = components.count > 1 && components.contains { safeSubdirNames.contains($0) }
                return (bundleId, isSafe)
            }
        }
        
        // 2. Kiểm tra ~/Thư viện/Hỗ trợ ứng dụng/<tên ứng dụng>

        let appSupportPath = home + "/Library/Application Support/"
        if path.hasPrefix(appSupportPath) {
            let relativePath = String(path.dropFirst(appSupportPath.count))
            let components = relativePath.components(separatedBy: "/")
            guard let appName = components.first, !appName.isEmpty else { return nil }
            
            // Bỏ qua các thư mục phổ biến (không thuộc về một ứng dụng cụ thể)

            let genericDirs: Set<String> = [
                "AddressBook", "CallHistoryDB", "CallHistoryTransactions",
                "CloudDocs", "CrashReporter", "FileProvider", "Knowledge",
                "MobileSync", "SyncServices", "Ubiquity"
            ]
            if genericDirs.contains(appName) { return nil }
            
            // Kiểm tra xem ứng dụng đã được cài đặt chưa

            if isApplicationInstalled(appName) {
                // Kiểm tra xem đó có phải là thư mục con an toàn không

                let isSafe = components.count > 1 && components.contains { safeSubdirNames.contains($0) }
                return (appName, isSafe)
            }
        }
        
        // 3. Kiểm tra ~/Library/Caches/<bundle-id> - điều này luôn an toàn

        let cachesPath = home + "/Library/Caches/"
        if path.hasPrefix(cachesPath) {
            let relativePath = String(path.dropFirst(cachesPath.count))
            let components = relativePath.components(separatedBy: "/")
            guard let bundleId = components.first, !bundleId.isEmpty else { return nil }
            
            if isApplicationInstalled(bundleId) {
                // Nội dung trong ~/Library/Caches luôn an toàn

                return (bundleId, true)
            }
        }
        
        return nil
    }
    
    /// Lấy số nhận dạng của tất cả các ứng dụng đã cài đặt (có bộ đệm)

    private func getInstalledApplications() -> Set<String> {
        // Kiểm tra xem bộ đệm có hợp lệ không

        if let cache = installedAppCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cache
        }
        
        // Quét lại

        var apps = Set<String>()
        
        // 1. Quét thư mục ứng dụng

        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(item)
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                
                // Thêm tên ứng dụng

                let appName = (item as NSString).deletingPathExtension.lowercased()
                apps.insert(appName)
                
                // Đọc ID gói

                if let plist = NSDictionary(contentsOfFile: plistPath),
                   let bundleId = plist["CFBundleIdentifier"] as? String {
                    apps.insert(bundleId.lowercased())
                    
                    // Thêm từng thành phần của ID gói

                    for component in bundleId.components(separatedBy: ".") where component.count > 3 {
                        apps.insert(component.lowercased())
                    }
                }
            }
        }
        
        // 2. Thêm ứng dụng Homebrew Cask

        let homebrewPaths = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
        for caskPath in homebrewPaths {
            if let casks = try? fileManager.contentsOfDirectory(atPath: caskPath) {
                for cask in casks {
                    apps.insert(cask.lowercased())
                }
            }
        }
        
        // 3. Thêm ứng dụng đang chạy

        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                apps.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                apps.insert(name.lowercased())
            }
        }
        
        // 4. Thêm danh sách bảo mật hệ thống

        let safelist = [
            "finder", "dock", "spotlight", "safari", "mail", "messages", "photos",
            "music", "tv", "podcasts", "books", "notes", "calendar", "contacts",
            "facetime", "preview", "textedit", "quicktime", "appstore",
            "systempreferences", "activitymonitor", "terminal", "console",
            "chrome", "firefox", "edge", "opera", "brave",
            "vscode", "xcode", "jetbrains", "intellij", "pycharm", "webstorm",
            "docker", "postman", "figma", "sketch", "notion", "obsidian",
            "slack", "discord", "zoom", "skype", "telegram", "wechat", "qq",
            "1password", "bitwarden", "lastpass", "dropbox", "onedrive", "googledrive"
        ]
        for safe in safelist {
            apps.insert(safe)
        }
        
        // Cập nhật bộ đệm

        installedAppCache = apps
        cacheTimestamp = Date()
        
        return apps
    }
    
    /// Bộ đệm không hợp lệ (được gọi khi cài đặt/gỡ cài đặt ứng dụng)

    func invalidateCache() {
        installedAppCache = nil
        cacheTimestamp = nil
    }
}

// MARK: - Loại bỏ mức độ rủi ro


enum DeletionRiskLevel: String {
    case low = "Rủi ro thấp"
    case medium = "Rủi ro trung bình"
    case high = "Rủi ro cao"
    case critical = "Rủi ro nghiêm trọng"
    
    var color: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        }
    }
}
