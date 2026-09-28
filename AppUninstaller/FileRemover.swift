import Foundation
import AppKit

// MARK: - Dịch vụ xóa file

class FileRemover {
    private let fileManager = FileManager.default
    
    /// Xóa ứng dụng và các file còn lại của nó

    func removeApp(_ app: InstalledApp, includeApp: Bool = true, moveToTrash: Bool = true) async -> RemovalResult {
        var successCount = 0
        var failedCount = 0
        var totalSizeRemoved: Int64 = 0
        var failedPaths: [URL] = []
        
        // Thu thập tất cả các đường dẫn cần xóa

        var pathsToDelete: [(URL, Int64)] = []
        
        for file in app.residualFiles where file.isSelected {
            pathsToDelete.append((file.path, file.size))
        }
        
        if includeApp {
            pathsToDelete.append((app.path, app.size))
        }
        
        // Trước tiên hãy thử xóa bình thường

        var failedForPrivileged: [(URL, Int64)] = []
        
        for (path, size) in pathsToDelete {
            let result = await removeItemNormal(at: path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += size
            } else {
                failedForPrivileged.append((path, size))
            }
        }
        
        // Nếu bất kỳ cách nào trong số đó không thành công, hãy thử nâng cao đặc quyền và xóa chúng.

        if !failedForPrivileged.isEmpty {
            print("Có \(failedForPrivileged.count) mục cần xóa bằng quyền quản trị")
            let privilegedResult = await removeItemsWithPrivilege(paths: failedForPrivileged.map { $0.0 })
            
            for (index, path) in failedForPrivileged.enumerated() {
                if privilegedResult[index] {
                    successCount += 1
                    totalSizeRemoved += path.1
                } else {
                    failedCount += 1
                    failedPaths.append(path.0)
                }
            }
        }
        
        return RemovalResult(
            successCount: successCount,
            failedCount: failedCount,
            totalSizeRemoved: totalSizeRemoved,
            failedPaths: failedPaths
        )
    }
    
    /// Chỉ xóa file dư (giữ lại chính ứng dụng)

    func removeResidualFiles(of app: InstalledApp, moveToTrash: Bool = true) async -> RemovalResult {
        var successCount = 0
        var failedCount = 0
        var totalSizeRemoved: Int64 = 0
        var failedPaths: [URL] = []
        
        var pathsToDelete: [(URL, Int64)] = []
        for file in app.residualFiles where file.isSelected {
            pathsToDelete.append((file.path, file.size))
        }
        
        var failedForPrivileged: [(URL, Int64)] = []
        
        for (path, size) in pathsToDelete {
            let result = await removeItemNormal(at: path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += size
            } else {
                failedForPrivileged.append((path, size))
            }
        }
        
        // Các dự án không thể nâng cấp đặc quyền và xóa chúng

        if !failedForPrivileged.isEmpty {
            let privilegedResult = await removeItemsWithPrivilege(paths: failedForPrivileged.map { $0.0 })
            
            for (index, path) in failedForPrivileged.enumerated() {
                if privilegedResult[index] {
                    successCount += 1
                    totalSizeRemoved += path.1
                } else {
                    failedCount += 1
                    failedPaths.append(path.0)
                }
            }
        }
        
        return RemovalResult(
            successCount: successCount,
            failedCount: failedCount,
            totalSizeRemoved: totalSizeRemoved,
            failedPaths: failedPaths
        )
    }
    
    /// Xóa thông thường (không nâng cao đặc quyền)

    private func removeItemNormal(at url: URL, moveToTrash: Bool) async -> Bool {
        if moveToTrash {
            // 🛡️ Sử dụng DeletionLogService để ghi lại nhật ký xóa và hỗ trợ khôi phục

            return DeletionLogService.shared.logAndDelete(at: url, category: "AppUninstall")
        } else {
            do {
                try fileManager.removeItem(at: url)
                return true
            } catch {
                print("Xóa thông thường thất bại: \(url.path), lỗi: \(error)")
                return false
            }
        }
    }
    
    ///Xóa các tệp có quyền quản trị viên (thông qua AppleScript)

    /// Một hộp nhập mật khẩu sẽ bật lên để yêu cầu ủy quyền người dùng.

    private func removeItemsWithPrivilege(paths: [URL]) async -> [Bool] {
        guard !paths.isEmpty else { return [] }

        // Xây dựng tập lệnh loại bỏ từng đường dẫn một, bỏ qua các lỗi đơn lẻ

        // Bằng cách này, việc không xóa một file sẽ không ảnh hưởng đến các file khác

        // Kiểm tra bảo mật: logic xác minh đường dẫn

        func isPathSafeToDelete(_ path: String) -> Bool {
            let standardPath = (path as NSString).standardizingPath
            
            // 1. Tuyệt đối cấm các thư mục gốc của hệ thống

            let dangerousPrefixes = [
                "/System",
                "/bin",
                "/sbin",
                "/usr",
                "/etc",
                "/var",
                "/Library", // Thư viện cấp hệ thống thường không được phép xóa trực tiếp, ngoại trừ trong các thư mục con cụ thể. Điều này được thực thi nghiêm ngặt.
                "/Applications/Safari.app", // Bảo vệ ứng dụng hệ thống
                "/Applications/System Preferences.app"
            ]
            
            if standardPath == "/" { return false }
            
            for prefix in dangerousPrefixes {
                if standardPath.hasPrefix(prefix) {
                    print("Chặn an toàn: đang cố xóa đường dẫn hệ thống được bảo vệ \(standardPath)")
                    return false
                }
            }
            
            // 2. Phải chứa thư mục chính của người dùng (suy nghĩ hộp cát bắt buộc)

            // Cho phép xóa /Ứng dụng, /Người dùng/xxx, /Thư viện/xxx (cụ thể)

            // Nhưng để đề phòng, chúng tôi yêu cầu đường dẫn phải nằm dưới /Users hoặc dưới /Applications

            let validPrefixes = [
                "/Users/",
                "/Applications/",
                "/private/var/folders/", // tập tin tạm thời
                "/Volumes/" // ổ đĩa ngoài
            ]
            
            var isValid = false
            for prefix in validPrefixes {
                if standardPath.hasPrefix(prefix) {
                    isValid = true
                    break
                }
            }
            
            if !isValid {
                print("Chặn an toàn: đường dẫn nằm ngoài phạm vi được phép \(standardPath)")
                return false
            }
            
            // 3. Kiểm tra các ký tự đặc biệt để ngăn chặn việc tiêm Shell (mặc dù với shellEscape, bảo vệ kép)

            // Chứa liên tiếp .. bị cấm.

            if standardPath.contains("..") { return false }
            
            return true
        }
        
        // Xây dựng tập lệnh loại bỏ từng đường dẫn một, bỏ qua các lỗi đơn lẻ

        // Bằng cách này, việc không xóa một file sẽ không ảnh hưởng đến các file khác

        var scriptLines: [String] = []
        var safePathsCount = 0
        
        for path in paths {
            let pathStr = path.path
            
            // Thực hiện kiểm tra an ninh

            if !isPathSafeToDelete(pathStr) {
                print("Bỏ qua đường dẫn không an toàn: \(pathStr)")
                continue
            }
            
            safePathsCount += 1
            let escapedPath = PrivilegedShell.shellEscape(pathStr)
            // Thêm || đúng sau mỗi lệnh xóa để tiếp tục ngay cả khi thất bại.

            scriptLines.append("rm -rf \(escapedPath) 2>/dev/null || true")
        }
        
        if safePathsCount == 0 {
            print("Không có đường dẫn hợp lệ vượt qua kiểm tra an toàn, bỏ qua thực thi")
            return Array(repeating: false, count: paths.count)
        }
        
        let shellCommands = scriptLines.joined(separator: "; ")

        let script = """
        do shell script "\(PrivilegedShell.appleScriptEscape(shellCommands))" with administrator privileges
        """        
        print("Thực thi script xóa bằng quyền quản trị cho \(paths.count) đường dẫn")
        
        return await MainActor.run {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                _ = appleScript.executeAndReturnError(&error)
                
                if let errorDict = error {
                    let errorNumber = errorDict["NSAppleScriptErrorNumber"] as? Int ?? -1
                    if errorNumber == -128 {
                        print("Người dùng đã hủy hộp thoại nhập mật khẩu")
                        return Array(repeating: false, count: paths.count)
                    }
                    // Các lỗi khác vẫn tiếp tục được xác minh

                    print("AppleScript trả về lỗi: \(errorDict), nhưng vẫn tiếp tục kiểm tra kết quả xóa")
                }
                
                // Bất kể lệnh có báo lỗi hay không, hãy xác minh xem mỗi đường dẫn đã bị xóa hay chưa.

                var results: [Bool] = []
                for path in paths {
                    let deleted = !fileManager.fileExists(atPath: path.path)
                    if !deleted {
                        print("Tệp vẫn còn tồn tại: \(path.path)")
                    }
                    results.append(deleted)
                }
                print("Xóa bằng quyền quản trị hoàn tất: \(results.filter { $0 }.count) thành công, \(results.filter { !$0 }.count) thất bại")
                return results
            } else {
                print("Không thể tạo đối tượng AppleScript")
            }
            return Array(repeating: false, count: paths.count)
        }
    }
    
    /// Xóa một tập tin với quyền quản trị viên

    func removeItemWithPrivilege(at url: URL) async -> Bool {
        let results = await removeItemsWithPrivilege(paths: [url])
        return results.first ?? false
    }
    
    /// Kiểm tra xem ứng dụng có đang chạy không

    func isAppRunning(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // So khớp theo ID gói

        if let bundleId = app.bundleIdentifier {
            if runningApps.contains(where: { $0.bundleIdentifier == bundleId }) {
                return true
            }
        }
        
        // khớp theo đường dẫn

        if runningApps.contains(where: { $0.bundleURL == app.path }) {
            return true
        }
        
        return false
    }
    
    ///Cố gắng chấm dứt ứng dụng

    func terminateApp(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == app.bundleIdentifier || runningApp.bundleURL == app.path {
                return runningApp.terminate()
            }
        }
        
        return false
    }
    
    /// buộc chấm dứt ứng dụng

    func forceTerminateApp(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == app.bundleIdentifier || runningApp.bundleURL == app.path {
                return runningApp.forceTerminate()
            }
        }
        
        return false
    }
    
    /// Sử dụng quyền quản trị viên để buộc chấm dứt ứng dụng (đối với các tiến trình cứng đầu)

    func forceTerminateAppWithPrivilege(_ app: InstalledApp) async -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }

        // bundleId do app bên thứ ba tự khai báo — coi như dữ liệu không tin cậy,
        // escape đủ 2 lớp (shell + AppleScript) trước khi đưa vào pkill.
        let command = "pkill -9 -f \(PrivilegedShell.shellEscape(bundleId))"
        let script = """
        do shell script "\(PrivilegedShell.appleScriptEscape(command))" with administrator privileges
        """
        
        return await MainActor.run {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                return error == nil
            }
            return false
        }
    }
}
