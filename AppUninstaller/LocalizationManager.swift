import SwiftUI

// MARK: - Language Model

/// Một ngôn ngữ được nạp từ file `Languages/<code>.json` trong bundle.
struct AppLanguage: Identifiable, Hashable {
    /// Mã ngôn ngữ, trùng với tên file, ví dụ "vi", "en", "ja".
    let code: String
    /// Tên hiển thị gốc, lấy từ khóa đặc biệt "_name".
    let name: String
    /// Emoji cờ, lấy từ khóa đặc biệt "_flag".
    let flag: String

    var id: String { code }
}

// MARK: - Localization Manager
//
// Mỗi ngôn ngữ là một file JSON phẳng trong thư mục `Languages/` của bundle:
//
//     {
//       "_name": "English",
//       "_flag": "🇬🇧",
//       "Điều khiển": "Dashboard",
//       "Đã dọn %d mục": "Cleaned %d items"
//     }
//
// Toàn bộ chuỗi UI trong mã nguồn được viết bằng tiếng Việt và được dùng
// trực tiếp làm khóa qua hàm toàn cục L(...). Khi ngôn ngữ hiện tại là tiếng
// Việt, L(...) trả nguyên chuỗi gốc; với ngôn ngữ khác, hệ tra bảng của ngôn
// ngữ đó, thiếu thì fallback về bảng tiếng Việt, cuối cùng trả về chính khóa.
// Thêm một ngôn ngữ mới chỉ cần thả file JSON vào Languages/ — không cần sửa
// mã, ngôn ngữ sẽ tự xuất hiện trong phần Cài đặt.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// Ngôn ngữ nguồn: mọi chuỗi UI trong mã nguồn viết bằng tiếng Việt.
    static let sourceLanguageCode = "vi"

    @Published private(set) var currentLanguage: AppLanguage
    @Published private(set) var availableLanguages: [AppLanguage] = []

    /// code ngôn ngữ -> [khóa -> bản dịch]. Khóa đặc biệt "_name"/"_flag" bị loại.
    private var tables: [String: [String: String]] = [:]

    private let defaultsKey = "app_language"

    private init() {
        currentLanguage = AppLanguage(code: Self.sourceLanguageCode, name: "Tiếng Việt", flag: "🇻🇳")
        loadLanguages()

        // Chưa từng chọn ngôn ngữ -> dùng ngôn ngữ hệ thống nếu app có bản
        // dịch cho nó, ngược lại giữ tiếng Việt (ngôn ngữ nguồn). Giá trị đoán
        // này KHÔNG được lưu lại; nó chỉ được ghi khi người dùng chủ động chọn.
        let saved: String
        if let stored = UserDefaults.standard.string(forKey: defaultsKey) {
            saved = stored
        } else if let detected = preferredSystemLanguageCode() {
            saved = detected
        } else {
            saved = Self.sourceLanguageCode
        }
        currentLanguage = language(for: saved)
    }

    /// Trả về mã của ngôn ngữ hệ thống đầu tiên (theo thứ tự ưu tiên của
    /// người dùng) mà app có file bản dịch, ví dụ "en" từ "en-US".
    private func preferredSystemLanguageCode() -> String? {
        for preference in Locale.preferredLanguages {
            guard let base = preference.split(separator: "-").first.map(String.init),
                  !base.isEmpty else { continue }
            if tables[base] != nil { return base }
        }
        return nil
    }

    // MARK: - Public API

    /// Chuyển ngôn ngữ theo mã ("vi", "en", ...). Lựa chọn được lưu lại.
    func setLanguage(_ code: String) {
        guard tables[code] != nil, currentLanguage.code != code else { return }
        UserDefaults.standard.set(code, forKey: defaultsKey)
        currentLanguage = language(for: code)
        objectWillChange.send()
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    /// Dịch một khóa (thường là chính chuỗi tiếng Việt trong mã nguồn) kèm
    /// tham số format tùy chọn. Chỉ format khi có tham số.
    func t(_ key: String, _ args: CVarArg...) -> String {
        var text = tables[currentLanguage.code]?[key]
            ?? tables[Self.sourceLanguageCode]?[key]
            ?? key
        if !args.isEmpty {
            text = String(format: text, arguments: args)
        }
        return text
    }

    /// Tên gọi khác của t(...) — giữ tương thích với các view cũ dùng loc.L(...).
    func L(_ key: String, _ args: CVarArg...) -> String {
        t(key, args)
    }

    func language(for code: String) -> AppLanguage {
        if let language = availableLanguages.first(where: { $0.code == code }) {
            return language
        }
        return AppLanguage(code: Self.sourceLanguageCode,
                           name: tables[Self.sourceLanguageCode]?["_name"] ?? "Tiếng Việt",
                           flag: tables[Self.sourceLanguageCode]?["_flag"] ?? "🇻🇳")
    }

    // MARK: - Loading

    /// Quét toàn bộ file JSON trong thư mục `Languages/` của resource bundle.
    /// Tên file (không gồm phần mở rộng) trở thành mã ngôn ngữ.
    private func loadLanguages() {
        let bundle = Bundle.module
        var urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Languages") ?? []
        if urls.isEmpty {
            urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        }

        var languages: [AppLanguage] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let table = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                continue
            }
            let code = url.deletingPathExtension().lastPathComponent
            var translations: [String: String] = [:]
            for (key, value) in table where !key.hasPrefix("_") {
                translations[key] = value
            }
            tables[code] = translations
            languages.append(AppLanguage(
                code: code,
                name: table["_name"] ?? code.uppercased(),
                flag: table["_flag"] ?? "🌐"
            ))
        }

        // Tiếng Việt (ngôn ngữ nguồn) luôn đứng đầu, các ngôn ngữ còn lại theo tên.
        availableLanguages = languages.sorted {
            let vi0 = $0.code == Self.sourceLanguageCode
            let vi1 = $1.code == Self.sourceLanguageCode
            if vi0 != vi1 { return vi0 }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

// MARK: - Global Localization Function

func L(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.t(key, args)
}

// MARK: - Notifications

extension Notification.Name {
    /// Đăng ký để dựng lại UI chứa văn bản dựng bằng lệnh (NSMenu, NSStatusItem...)
    /// khi người dùng đổi ngôn ngữ.
    static let appLanguageDidChange = Notification.Name("AppLanguageDidChange")
}

// MARK: - Environment Keys

struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}
