import SwiftUI
import AppKit

// MARK: - Bảng màu toàn cục cho giao diện macOS hiện đại

extension Color {
    // màu nền

    static let mainBackground = Color(red: 0.12, green: 0.12, blue: 0.18) // Nền màu xanh và tím đậm hơn
    static let sidebarBackground = Color.black.opacity(0.15)
    static let cardBackground = Color.white.opacity(0.06) // tối giản mờ
    static let cardHover = Color.white.opacity(0.10)
    
    // màu văn bản

    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.4)
    
    // 4. Máy hủy giấy (màu xanh)

    static let shredderStart = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let shredderEnd = Color(red: 0.0, green: 0.3, blue: 0.8)
    
    // Màu nhấn của mô-đun chức năng

    // 1. Trình gỡ cài đặt (màu xanh - thông minh/bình tĩnh)

    static let uninstallerStart = Color(red: 0.0, green: 0.6, blue: 1.0)
    static let uninstallerEnd = Color(red: 0.0, green: 0.4, blue: 0.9)
    
    // 2. Dọn rác (Tím - Độ sâu/Làm sạch)

    static let cleanerStart = Color(red: 0.8, green: 0.2, blue: 0.8)
    static let cleanerEnd = Color(red: 0.6, green: 0.1, blue: 0.9)
    
    // 3. Tối ưu hóa hệ thống (màu cam - sức sống/tăng tốc)

    static let optimizerStart = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let optimizerEnd = Color(red: 1.0, green: 0.4, blue: 0.1)
    
    // màu trạng thái

    static let danger = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let success = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.2)
    
    // MARK: - Hex Extension
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// ĐÁNH DẤU: - Phong cách chuyển màu

struct GradientStyles {
    static let uninstaller = LinearGradient(
        colors: [.uninstallerStart, .uninstallerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cleaner = LinearGradient(
        colors: [.cleanerStart, .cleanerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let optimizer = LinearGradient(
        colors: [.optimizerStart, .optimizerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let shredder = LinearGradient(
        colors: [.shredderStart, .shredderEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let danger = LinearGradient(
        colors: [.danger, Color(red: 0.8, green: 0.1, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let largeFiles = LinearGradient(
        colors: [Color(red: 0.3, green: 0.0, blue: 0.8), Color(red: 0.2, green: 0.0, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let trash = LinearGradient(
        colors: [Color(red: 0.0, green: 0.8, blue: 0.7), Color(red: 0.0, green: 0.4, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 6. Bảng điều khiển (đỏ tươi/tím - tọa độ với nền)

    static let monitor = LinearGradient(
        colors: [Color(red: 0.9, green: 0.2, blue: 0.6), Color(red: 0.6, green: 0.1, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 7. Làm sạch sâu (Xanh ngọc lục bảo)

    static let deepClean = LinearGradient(
        colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.3, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 8. Trình quản lý tệp (Xanh thép)

    static let fileExplorer = LinearGradient(
        colors: [Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.1, green: 0.2, blue: 0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 9. Bảo vệ quyền riêng tư (gradient màu hồng và tím - bản vẽ thiết kế phù hợp)

    // 9. Bảo vệ quyền riêng tư (gradient màu hồng và tím - bản vẽ thiết kế phù hợp)

    static let privacy = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "D65D89"), // Deep Pink/Red
            Color(hex: "4A306D")  // Deep Purple
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 15. Thấu kính không gian (màu ngọc lam/màu xanh nước biển sâu)

    static let spaceLens = LinearGradient(
        stops: [
            .init(color: Color(hex: "00C9A7"), location: 0.0), // Bright Teal
            .init(color: Color(hex: "005E7C"), location: 1.0)  // Deep Sea Blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aiModels = LinearGradient(
        colors: [Color(hex: "57E8C5"), Color(hex: "5B7BFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // 13. Chương trình cập nhật (gradient xanh lam/lục lam - kiểu giao diện cập nhật hiện đại)

    static let updater = LinearGradient(
        colors: [Color(hex: "00B894"), Color(hex: "00A8E8")], // Teal to Light Blue
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 10. Làm sạch thông minh (màu ngọc lam)

    static let smartClean = LinearGradient(
        colors: [Color(red: 0.0, green: 0.6, blue: 0.8), Color(red: 0.0, green: 0.4, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Đánh dấu lựa chọn thanh bên

    static func sidebarSelected(for module: AppModule) -> LinearGradient {
        switch module {
        case .monitor: return monitor
        case .uninstaller: return uninstaller
        case .deepClean: return deepClean
        case .cleaner: return cleaner
        case .maintenance: return optimizer
        case .optimizer: return optimizer
        case .shredder: return shredder
        case .largeFiles: return largeFiles
        case .fileExplorer: return fileExplorer
        case .trash: return trash
        case .privacy: return privacy
        case .malware: return LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .smartClean: return smartClean
        case .updater: return updater
        case .spaceLens: return spaceLens
        case .aiModels: return aiModels
        case .docker: return LinearGradient(colors: [Color(hex: "4DB7FF"), Color(hex: "2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .backgroundItems: return optimizer
        }
    }

    // Design-specific gradients
    static let purple = LinearGradient(colors: [Color(hex: "B657FF"), Color(hex: "8A2BE2")], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Kiểu chuyển màu nền (toàn màn hình)

struct BackgroundStyles {
    // 1. Trình gỡ cài đặt (Xanh đậm - Công nghệ/Pure)

    static let uninstaller = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.5, blue: 1.0), location: 0.0), // màu xanh sáng
            .init(color: Color(red: 0.0, green: 0.1, blue: 0.4), location: 1.0)  // xanh đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 2. Dọn rác (gradient màu hồng và tím - kiểu công cụ dọn dẹp hiện đại)

    static let cleaner = LinearGradient(
        stops: [
            .init(color: Color(hex: "D15589"), location: 0.0), // hồng
            .init(color: Color(hex: "4A4385"), location: 1.0)  // màu tím đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 3. Tối ưu hóa hệ thống (Sức sống cam - Tăng tốc/Năng lượng)

    static let optimizer = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 0.5, blue: 0.0), location: 0.0), // màu cam
            .init(color: Color(red: 0.6, green: 0.2, blue: 0.0), location: 1.0)  // nâu sẫm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 4. Tìm kiếm tệp lớn (gradient đỏ tím - phù hợp với bản vẽ thiết kế)

    static let largeFiles = LinearGradient(
        stops: [
            .init(color: Color(red: 0.85, green: 0.35, blue: 0.35), location: 0.0), // màu đỏ mềm mại
            .init(color: Color(red: 0.25, green: 0.18, blue: 0.35), location: 1.0)  // màu tím đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 5. Thùng rác (màu ngọc lam - tươi/sắp xếp) - phù hợp với thiết kế

    static let trash = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.8, blue: 0.7), location: 0.0), // Màu xanh lá
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.5), location: 1.0)  // màu xanh đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let monitor = LinearGradient(
        stops: [
            .init(color: Color(red: 0.8, green: 0.0, blue: 0.5), location: 0.0), // Màu đỏ tươi (rác cùng hệ thống)
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.4), location: 1.0)  // màu tím đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 6. Làm sạch sâu (gradient xanh lục lam - quét sâu/chính xác)

    static let deepClean = LinearGradient(
        stops: [
            .init(color: Color(hex: "00B4D8"), location: 0.0), // màu lục lam sáng
            .init(color: Color(hex: "0077B6"), location: 0.5), // màu xanh vừa
            .init(color: Color(hex: "023E8A"), location: 1.0)  // xanh đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 7. Trình quản lý tệp (Xanh thép)

    static let fileExplorer = LinearGradient(
        stops: [
            .init(color: Color(red: 0.15, green: 0.3, blue: 0.5), location: 0.0), // màu xanh thép
            .init(color: Color(red: 0.08, green: 0.15, blue: 0.3), location: 1.0) // xanh đậm
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 8. Bảo vệ quyền riêng tư (thiết kế phù hợp với gradient màu hồng và tím)

    static let privacy = LinearGradient(
        stops: [
            .init(color: Color(hex: "D65D89"), location: 0.0), // Deep Pink
            .init(color: Color(hex: "4A306D"), location: 1.0)  // Deep Purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 15. Thấu kính không gian (nền màu lục lam đậm/xanh biển đậm phù hợp với thiết kế)

    static let spaceLens = LinearGradient(
        stops: [
            .init(color: Color(hex: "00A896"), location: 0.0), // Teal
            .init(color: Color(hex: "051937"), location: 1.0)  // Dark Blue Black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aiModels = LinearGradient(
        stops: [
            .init(color: Color(hex: "08243A"), location: 0.0),
            .init(color: Color(hex: "141B39"), location: 0.55),
            .init(color: Color(hex: "1B1748"), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    


    // 14. Cập nhật chương trình (nền gradient màu lục lam/xanh lam)

    static let updater = LinearGradient(
        stops: [
            .init(color: Color(hex: "00B09B"), location: 0.0), // Greeish Teal
            .init(color: Color(hex: "35495E"), location: 1.0)  // Dark Blue-Green
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 9. Làm sạch thông minh (Purple Indigo gradient - Match Design V2 Vibrant)

    static let smartClean = LinearGradient(
        stops: [
            .init(color: Color(red: 0.45, green: 0.35, blue: 0.65), location: 0.0),   // Top: Vibrant Purple
            .init(color: Color(red: 0.38, green: 0.28, blue: 0.58), location: 0.5),   // Mid: Transition
            .init(color: Color(red: 0.25, green: 0.20, blue: 0.50), location: 1.0)    // Bottom: Deep Indigo
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // 11. Quét gradient phân loại (Hình nền thẻ)

    static let cardCleaning = LinearGradient( // Cleaning - Green/Teal
        stops: [
            .init(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.3).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardProtection = LinearGradient( // Protection - Purple/Pink
        stops: [
            .init(color: Color(red: 0.6, green: 0.1, blue: 0.6).opacity(0.8), location: 0),
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.4).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardPerformance = LinearGradient( // Performance - Orange/Red
        stops: [
            .init(color: Color(red: 0.8, green: 0.3, blue: 0.1).opacity(0.8), location: 0),
            .init(color: Color(red: 0.6, green: 0.2, blue: 0.1).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardApps = LinearGradient( // Applications - Blue
        stops: [
            .init(color: Color(red: 0.0, green: 0.3, blue: 0.7).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.2, blue: 0.5).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardClutter = LinearGradient( // Clutter - Cyan/Blue
        stops: [
            .init(color: Color(red: 0.0, green: 0.5, blue: 0.6).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.3, blue: 0.5).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // 10. Máy hủy tài liệu (gradient màu xanh đậm/tím - thiết kế phù hợp)

    static let shredder = LinearGradient(
        stops: [
            .init(color: Color(red: 0.1, green: 0.3, blue: 0.6), location: 0.0), // xanh đậm
            .init(color: Color(red: 0.2, green: 0.2, blue: 0.5), location: 1.0)  // xanh tím
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 12. Nền trang chi tiết quét thông minh (gradient màu chàm tím mềm mại - thiết kế phù hợp)

    static let smartScanSheet = LinearGradient(
        stops: [
            .init(color: Color(red: 79/255, green: 65/255, blue: 89/255), location: 0.0),
            .init(color: Color(red: 105/255, green: 87/255, blue: 144/255), location: 0.5),
            .init(color: Color(red: 70/255, green: 71/255, blue: 124/255), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - liệt kê mô-đun

enum AppModule: String, CaseIterable, Identifiable {
    case monitor = "Điều khiển"
    case smartClean = "Quét thông minh"
    case cleaner = "Rác hệ thống"
    case deepClean = "Dọn dẹp sâu"
    case maintenance = "Bảo trì hệ thống"
    case optimizer = "Tối ưu hệ thống"
    case shredder = "Hủy tệp"
    case privacy = "Bảo vệ riêng tư"
    case largeFiles = "Tệp lớn"
    case fileExplorer = "Quản lý tệp"
    case spaceLens = "Bản đồ dung lượng"
    case aiModels = "Mô hình AI"
    case docker = "Image Docker"
    case backgroundItems = "Dịch vụ nền"
    case uninstaller = "Gỡ cài đặt ứng dụng"
    case updater = "Cập nhật ứng dụng"
    case trash = "Thùng rác"
    case malware = "Xóa phần mềm độc hại"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .monitor: return "chart.bar.xaxis"
        case .uninstaller: return "puzzlepiece.extension"
        case .updater: return "arrow.triangle.2.circlepath"
        case .deepClean: return "magnifyingglass.circle.fill"
        case .cleaner: return "square.stack.3d.up.fill"
        case .maintenance: return "wrench.and.screwdriver"
        case .optimizer: return "bolt.fill"
        case .shredder: return "doc.text.fill"
        case .largeFiles: return "doc"
        case .fileExplorer: return "folder" // Changed icon for File Management
        case .spaceLens: return "circle.hexagongrid" // Space Lens icon
        case .aiModels: return "brain.head.profile"
        case .docker: return "shippingbox.fill"
        case .backgroundItems: return "list.bullet.rectangle.fill"
        case .trash: return "trash"
        case .malware: return "exclamationmark.shield.fill"
        case .privacy: return "hand.raised.fill"
        case .smartClean: return "display"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .monitor: return GradientStyles.monitor
        case .uninstaller: return GradientStyles.uninstaller
        case .deepClean: return GradientStyles.deepClean
        case .cleaner: return GradientStyles.cleaner
        case .maintenance: return GradientStyles.optimizer
        case .optimizer: return GradientStyles.optimizer
        case .shredder: return GradientStyles.shredder
        case .largeFiles: return GradientStyles.largeFiles
        case .fileExplorer: return GradientStyles.fileExplorer
        case .spaceLens: return GradientStyles.spaceLens // New Gradient
        case .aiModels: return GradientStyles.aiModels
        case .docker: return LinearGradient(colors: [Color(hex: "4DB7FF"), Color(hex: "2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .backgroundItems: return GradientStyles.optimizer
        case .trash: return GradientStyles.trash
        case .malware: return LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .privacy:
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .smartClean: return GradientStyles.smartClean
        case .updater: return GradientStyles.updater
        }
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .monitor: return BackgroundStyles.monitor
        case .uninstaller: return BackgroundStyles.uninstaller
        case .deepClean: return BackgroundStyles.deepClean
        case .cleaner: return BackgroundStyles.cleaner
        case .maintenance: return BackgroundStyles.privacy
        case .optimizer: return BackgroundStyles.privacy
        case .shredder: return BackgroundStyles.shredder
        case .largeFiles: return BackgroundStyles.largeFiles
        case .fileExplorer: return BackgroundStyles.fileExplorer
        case .spaceLens: return BackgroundStyles.spaceLens // New Background
        case .aiModels: return BackgroundStyles.aiModels
        case .docker: return LinearGradient(stops: [
            .init(color: Color(hex: "12314F"), location: 0.0),
            .init(color: Color(hex: "2A123A"), location: 1.0)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .backgroundItems: return BackgroundStyles.privacy
        case .trash: return BackgroundStyles.trash
        case .malware: return LinearGradient(stops: [
            .init(color: Color(hex: "E05E5E"), location: 0.0),
            .init(color: Color(hex: "3F2E56"), location: 1.0)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .privacy: return BackgroundStyles.privacy
        case .smartClean: return BackgroundStyles.smartClean
        case .updater: return BackgroundStyles.updater
        }
    }
    
    var description: String {
        switch self {
        case .monitor: return L("Giám sát CPU, bộ nhớ và mạng theo thời gian thực")
        case .uninstaller: return L("Xóa sạch ứng dụng và toàn bộ tệp còn sót lại")
        case .deepClean: return L("Quét các tệp còn sót lại từ ứng dụng đã gỡ")
        case .cleaner: return L("Dọn bộ nhớ đệm và rác hệ thống")
        case .maintenance: return L("Chạy các tác vụ bảo trì hệ thống")
        case .optimizer: return L("Quản lý ứng dụng khởi động và giải phóng bộ nhớ")
        case .shredder: return L("Xóa an toàn các tệp nhạy cảm")
        case .largeFiles: return L("Tìm và dọn các tệp chiếm nhiều dung lượng")
        case .fileExplorer: return L("Duyệt và quản lý tệp trên ổ đĩa")
        case .spaceLens: return L("So sánh trực quan dung lượng thư mục và tệp để dọn nhanh hơn")
        case .aiModels: return L("Quản lý model Ollama và LM Studio, xem dung lượng và xóa nhanh")
        case .docker: return L("Xem image Docker đang chiếm dung lượng và xóa bớt")
        case .backgroundItems: return L("Liệt kê dịch vụ tự khởi động của bên thứ ba và tạm tắt khi cần")
        case .trash: return L("Xem và dọn sạch thùng rác")
        case .malware: return L("Quét và loại bỏ phần mềm độc hại")
        case .privacy: return L("Bảo vệ dữ liệu riêng tư của bạn")
        case .smartClean: return L("Quét nhanh và dọn rác hệ thống chỉ với một lần chạm")
        case .updater: return L("Giữ mọi ứng dụng luôn ở phiên bản mới và ổn định nhất")
        }
    }
}

// MARK: - Công cụ sửa đổi thành phần chung


struct ModernCardStyle: ViewModifier {
    var hoverEffect: Bool = true
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHovering && hoverEffect ? Color.cardHover : Color.cardBackground)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct GlassEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
    }
}

// MÃ: - Kiểu nút

struct CapsuleButtonStyle: ButtonStyle {
    var gradient: LinearGradient
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(gradient)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func modernCard() -> some View {
        modifier(ModernCardStyle())
    }
    
    func glassEffect() -> some View {
        modifier(GlassEffect())
    }
}

// ĐÁNH DẤU: - kiểu hộp kiểm

struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? GradientStyles.cleaner : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(configuration.isOn ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isOn.toggle()
                }
            }
            
            configuration.label
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isDestructive ? GradientStyles.danger : GradientStyles.uninstaller)
                    .shadow(color: (isDestructive ? Color.danger : Color.uninstallerStart).opacity(0.4), radius: 8, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
