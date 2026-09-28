import Foundation
import AppKit

/// Chạy lệnh shell cần quyền quản trị qua osascript (hộp thoại nhập mật khẩu của macOS).
/// Dùng chung cho các tính năng ghi /etc/hosts, bẻ khóa LaunchAgents/Daemons cấp hệ thống.
enum PrivilegedShell {

    /// Chạy một lệnh với quyền root. Chỉ gọi từ luồng chính (osascript cần hiện hộp thoại).
    /// - Returns: true nếu lệnh thoát thành công (exit 0)
    @discardableResult
    static func run(_ command: String) -> Bool {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges with prompt \"\(L("MacOptimizer cần quyền quản trị để tiếp tục"))\""

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
