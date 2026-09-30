import Foundation
import AppKit

/// Chạy lệnh shell cần quyền quản trị qua osascript (hộp thoại nhập mật khẩu của macOS).
/// Dùng chung cho các tính năng ghi /etc/hosts, bẻ khóa LaunchAgents/Daemons cấp hệ thống.
///
/// Bảo mật: mọi lệnh có dữ liệu động (đường dẫn, bundle id...) phải escape qua
/// `shellEscape` cho lớp shell và toàn bộ lệnh phải đi qua `appleScriptEscape`
/// trước khi nhúng vào literal chuỗi AppleScript — xem 2 hàm escape dùng chung bên dưới.
enum PrivilegedShell {

    /// Escape một giá trị để nhúng an toàn vào lệnh shell POSIX: bọc trong nháy
    /// đơn, mọi nháy đơn bên trong được đóng–mở lại thành '\''.
    /// Dùng cho đường dẫn/tên file/bundle id... trước khi nối vào chuỗi lệnh.
    static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape một chuỗi lệnh shell để nhúng an toàn vào literal chuỗi AppleScript
    /// (`do shell script "..."`): thoát dấu gạch chéo TRƯỚC, rồi dấu nháy kép.
    /// Không qua bước này, một dấu `"` trong dữ liệu động có thể chèn mã
    /// AppleScript chạy với quyền quản trị.
    static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Chạy một lệnh với quyền root. Chỉ gọi từ luồng chính (osascript cần hiện hộp thoại).
    /// - Returns: true nếu lệnh thoát thành công (exit 0)
    @discardableResult
    static func run(_ command: String) -> Bool {
        let script = "do shell script \"\(appleScriptEscape(command))\" with administrator privileges with prompt \"\(L("ApexTune cần quyền quản trị để tiếp tục"))\""

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let output = String(data: data, encoding: .utf8) ?? ""
                print("[PrivilegedShell] Thất bại (\(task.terminationStatus)): \(output)")
            }
            return task.terminationStatus == 0
        } catch {
            print("[PrivilegedShell] Lỗi khởi chạy osascript: \(error)")
            return false
        }
    }
}
