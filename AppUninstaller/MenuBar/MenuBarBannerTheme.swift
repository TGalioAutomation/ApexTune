import AppKit

// MARK: - Theme cho dải số liệu trên thanh menu (banner status item)
// Mỗi theme quyết định: nền viên thuốc, viền, màu nhãn/giá trị, ô icon và bóng đổ.

enum MenuBarBannerTheme: String, CaseIterable, Identifiable {
    /// Nền xanh đêm, nhãn màu nhấn — mặc định.
    case dark
    /// Nền sáng, chữ đậm — hợp thanh menu trắng.
    case light
    /// Đen trắng, bỏ màu nhấn.
    case mono
    /// Viên thuốc tô gradient theo màu của từng chỉ số.
    case accentFill
    /// Không nền, chỉ chữ màu nhấn kèm bóng đổ.
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return L("Tối")
        case .light: return L("Sáng")
        case .mono: return L("Đơn sắc")
        case .accentFill: return L("Màu nhấn")
        case .minimal: return L("Tối giản")
        }
    }

    var subtitle: String {
        switch self {
        case .dark: return L("Viên thuốc xanh đêm, nhãn màu nhấn (mặc định).")
        case .light: return L("Nền sáng, chữ đậm — hợp thanh menu trắng.")
        case .mono: return L("Đen trắng tinh giản, bỏ màu nhấn.")
        case .accentFill: return L("Tô đậm màu riêng của từng chỉ số.")
        case .minimal: return L("Chỉ chữ màu nhấn kèm bóng đổ, không nền.")
        }
    }

    /// Gradient hồng→tím của ô icon thương hiệu.
    static let brandIconGradient: [NSColor] = [
        NSColor(calibratedRed: 0.87, green: 0.46, blue: 0.80, alpha: 1),
        NSColor(calibratedRed: 0.55, green: 0.20, blue: 1.0, alpha: 1)
    ]

    var palette: MenuBarBannerPalette {
        switch self {
        case .dark:
            let fills = [
                NSColor(calibratedRed: 0.24, green: 0.29, blue: 0.43, alpha: 0.94),
                NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.31, alpha: 0.94)
            ]
            return MenuBarBannerPalette(
                hasChipBackground: true,
                chipFills: { _ in fills },
                chipStroke: { $0.withAlphaComponent(0.26) },
                innerHighlight: NSColor.white.withAlphaComponent(0.06),
                labelColor: { $0.withAlphaComponent(0.96) },
                valueColor: .white,
                iconFills: fills,
                iconStroke: Self.brandIconGradient[0].withAlphaComponent(0.26),
                iconTintOverride: nil,
                textShadow: nil
            )

        case .light:
            let fills = [
                NSColor.white.withAlphaComponent(0.96),
                NSColor(calibratedWhite: 0.92, alpha: 0.94)
            ]
            return MenuBarBannerPalette(
                hasChipBackground: true,
                chipFills: { _ in fills },
                chipStroke: { _ in NSColor.black.withAlphaComponent(0.10) },
                innerHighlight: nil,
                labelColor: { menuBarBlend($0, .black, 0.5) },
                valueColor: NSColor.black.withAlphaComponent(0.82),
                iconFills: fills,
                iconStroke: NSColor.black.withAlphaComponent(0.10),
                iconTintOverride: NSColor.black.withAlphaComponent(0.85),
                textShadow: nil
            )

        case .mono:
            let fills = [
                NSColor.black.withAlphaComponent(0.88),
                NSColor.black.withAlphaComponent(0.76)
            ]
            return MenuBarBannerPalette(
                hasChipBackground: true,
                chipFills: { _ in fills },
                chipStroke: { _ in NSColor.white.withAlphaComponent(0.14) },
                innerHighlight: NSColor.white.withAlphaComponent(0.08),
                labelColor: { _ in NSColor.white.withAlphaComponent(0.62) },
                valueColor: .white,
                iconFills: fills,
                iconStroke: NSColor.white.withAlphaComponent(0.14),
                iconTintOverride: nil,
                textShadow: nil
            )

        case .accentFill:
            return MenuBarBannerPalette(
                hasChipBackground: true,
                chipFills: { accent in [accent, menuBarBlend(accent, .black, 0.28)] },
                chipStroke: { _ in NSColor.white.withAlphaComponent(0.22) },
                innerHighlight: NSColor.white.withAlphaComponent(0.12),
                labelColor: { _ in NSColor.white.withAlphaComponent(0.95) },
                valueColor: .white,
                iconFills: Self.brandIconGradient,
                iconStroke: NSColor.white.withAlphaComponent(0.22),
                iconTintOverride: nil,
                textShadow: nil
            )

        case .minimal:
            return MenuBarBannerPalette(
                hasChipBackground: false,
                chipFills: { _ in [] },
                chipStroke: { _ in .clear },
                innerHighlight: nil,
                labelColor: { $0.withAlphaComponent(1) },
                valueColor: .white,
                iconFills: nil,
                iconStroke: nil,
                iconTintOverride: nil,
                textShadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
                    shadow.shadowBlurRadius = 3
                    shadow.shadowOffset = NSSize(width: 0, height: 1)
                    return shadow
                }()
            )
        }
    }
}

// MARK: - Bộ tham số vẽ của một theme

struct MenuBarBannerPalette {
    /// Có vẽ nền viên thuốc cho từng chỉ số hay không.
    let hasChipBackground: Bool
    /// Màu nhấn của chỉ số → gradient nền viên thuốc.
    let chipFills: (NSColor) -> [NSColor]
    /// Màu nhấn → màu viền viên thuốc.
    let chipStroke: (NSColor) -> NSColor
    /// Đường viền sáng phía trong tạo độ nổi.
    let innerHighlight: NSColor?
    /// Màu nhấn → màu chữ nhãn (RAM/CPU/DISK…).
    let labelColor: (NSColor) -> NSColor
    let valueColor: NSColor
    /// Gradient nền ô icon; nil = icon nổi không nền (theme tối giản).
    let iconFills: [NSColor]?
    let iconStroke: NSColor?
    /// Ép màu icon (vd icon đen trên nền sáng); nil = vẽ template như cũ.
    let iconTintOverride: NSColor?
    /// Bóng đổ sau chữ/icon để đọc được trên thanh menu sáng.
    let textShadow: NSShadow?
}

/// Trộn hai màu theo tỉ lệ t (0 = a, 1 = b).
func menuBarBlend(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
    guard let c1 = a.usingColorSpace(.sRGB), let c2 = b.usingColorSpace(.sRGB) else { return a }
    return NSColor(
        srgbRed: c1.redComponent + (c2.redComponent - c1.redComponent) * t,
        green: c1.greenComponent + (c2.greenComponent - c1.greenComponent) * t,
        blue: c1.blueComponent + (c2.blueComponent - c1.blueComponent) * t,
        alpha: c1.alphaComponent + (c2.alphaComponent - c1.alphaComponent) * t
    )
}
