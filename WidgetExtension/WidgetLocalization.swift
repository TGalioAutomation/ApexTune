import Foundation

/// Bản dịch mini cho widget: đọc file `Languages/<mã>.json` từ resource bundle
/// của app chứa widget (widget chạy trong tiến trình riêng, không dùng được
/// LocalizationManager của app chính). Ưu tiên ngôn ngữ hệ thống nếu app có
/// bản dịch cho nó, ngược lại giữ tiếng Việt — đồng bộ hành vi lần-đầu-chạy
/// của app chính. Khóa chính là chuỗi tiếng Việt gốc, giống hệt en.json.
enum WidgetL {
    static let table: [String: String] = loadTable()

    static func t(_ key: String) -> String {
        table[key] ?? key
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: table[key] ?? key, arguments: args)
    }

    // MARK: - Nạp bảng dịch

    private static func loadTable() -> [String: String] {
        let code = preferredCode()
        guard let url = languageFileURL(code: code),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return raw.filter { !$0.key.hasPrefix("_") }
    }

    /// Mã ngôn ngữ hệ thống đầu tiên (theo thứ tự ưu tiên) mà app có file dịch.
    private static func preferredCode() -> String {
        for preference in Locale.preferredLanguages {
            let base = String(preference.split(separator: "-").first ?? Substring(preference))
            if !base.isEmpty, languageFileURL(code: base) != nil {
                return base
            }
        }
        return "vi"
    }

    /// Tìm `Languages/<code>.json` trong app chứa widget. Widget appex nằm ở
    /// `MacOptimizer.app/Contents/PlugIns/`, resource bundle SPM nằm ở
    /// `MacOptimizer.app/Contents/Resources/MacOptimizer_AppUninstaller.bundle`
    /// (JSON nằm ở `<bundle>/Contents/Resources/Languages/`). Quét mọi
    /// *.bundle cho chắc, kèm đường dự phòng không qua bundle.
    private static func languageFileURL(code: String) -> URL? {
        let fileManager = FileManager.default
        let plugIns = Bundle.main.bundleURL.deletingLastPathComponent()   // .../Contents/PlugIns
        let resources = plugIns.deletingLastPathComponent()
            .appendingPathComponent("Resources")

        if let bundles = try? fileManager.contentsOfDirectory(
            at: resources, includingPropertiesForKeys: nil) {
            for bundleURL in bundles where bundleURL.pathExtension == "bundle" {
                for candidate in [
                    bundleURL.appendingPathComponent("Contents/Resources/Languages/\(code).json"),
                    bundleURL.appendingPathComponent("Languages/\(code).json"),
                    bundleURL.appendingPathComponent("\(code).json"),
                ] where fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        let direct = resources.appendingPathComponent("Languages/\(code).json")
        return fileManager.fileExists(atPath: direct.path) ? direct : nil
    }
}
