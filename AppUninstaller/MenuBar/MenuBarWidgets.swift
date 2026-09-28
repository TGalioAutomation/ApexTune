import SwiftUI

// MARK: - Bộ style chung của "Bảng điều khiển hệ thống"
// Ngôn ngữ thiết kế: nền graphite tối, thẻ phẳng viền hairline,
// phân cấp bằng nhãn section viết hoa và màu nhấn tiết chế.

/// Thẻ chính: mặt phẳng nổi nhẹ trên nền graphite, không gradient dày.
struct MenuBarPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isElevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isElevated
                                ? [Color.white.opacity(0.075), Color.white.opacity(0.045)]
                                : [Color.white.opacity(0.055), Color.white.opacity(0.032)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func menuBarPanel(cornerRadius: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(MenuBarPanelModifier(cornerRadius: cornerRadius, isElevated: elevated))
    }

    /// Mặt hàng con bên trong thẻ (hàng bấm, hàng toggle).
    func menuBarInsetRow(cornerRadius: CGFloat = 11, hovered: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(hovered ? 0.085 : 0.048))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(hovered ? 0.12 : 0.05), lineWidth: 1)
        )
    }
}

/// Nhãn section viết hoa kèm chấm màu nhấn — dùng để phân nhóm nội dung.
struct MenuBarSectionLabel: View {
    let title: String
    var tint: Color = Color(hex: "2CB7FF")

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.5))
        }
        .accessibilityHidden(true)
    }
}

/// Ô icon vuông bo góc dùng chung cho các hàng.
struct MenuBarIconChip: View {
    let icon: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(tint.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 1)
            )
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundColor(tint)
            )
            .frame(width: size, height: size)
    }
}

/// Track tiến trình mảnh dùng cho các hàng số liệu.
struct MenuBarTrack: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(max(progress, 0.02), 1)))
                    .animation(.easeOut(duration: 0.45), value: progress)
            }
        }
        .frame(height: height)
    }
}

/// Hiệu ứng nhấn chung cho hàng bấm được.
struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
