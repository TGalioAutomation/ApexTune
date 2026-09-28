import SwiftUI

/// "Bảng điều khiển hệ thống" — bản thiết kế graphite:
/// nền than sạch thay cho các khối màu nhòe, một vòng "Điểm sức khỏe"
/// làm tâm điểm, các số liệu còn lại dạng hàng mảnh phân nhóm bằng nhãn section.
struct MenuBarView: View {
    @EnvironmentObject var manager: MenuBarManager
    @EnvironmentObject var systemMonitor: SystemMonitorService
    @ObservedObject private var hosts = HostsProtectionManager.shared
    @ObservedObject private var backgroundItems = BackgroundItemsManager.shared
    @ObservedObject private var insights = DashboardInsights.shared
    @ObservedObject private var diskManager = DiskSpaceManager.shared

    @State private var selectedFooterShortcut: FooterShortcut = .home
    @State private var showQuitConfirm = false

    var body: some View {
        ZStack {
            menuBarBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    heroCard
                    diskCard
                    networkCard
                    protectionCard
                    utilitiesCard
                    footerBar
                }
                .padding(14)
                .padding(.bottom, 8)
            }

            if systemMonitor.showHighMemoryAlert {
                VStack {
                    MemoryAlertView(systemMonitor: systemMonitor, openAppAction: {
                        manager.openMainApp()
                    })
                    Spacer()
                }
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .frame(width: MenuBarManager.popupSize.width, height: MenuBarManager.popupSize.height)
        .background(Color(hex: "0C0E13"))
        .confirmationDialog(L("Thoát MacOptimizer?"), isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button(L("Thoát"), role: .destructive) {
                NSApp.terminate(nil)
            }
            Button(L("Hủy"), role: .cancel) {}
        } message: {
            Text(L("Giám sát menu bar và cảnh báo RAM sẽ dừng cho đến khi bạn mở lại ứng dụng."))
        }
    }

    // MARK: - Nền graphite (một vầng sáng duy nhất thay cho bốn khối màu)

    private var menuBarBackground: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: "161A22"), Color(hex: "0C0E13")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "2CB7FF").opacity(0.13))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: -30, y: -170)
        }
    }

    // MARK: - Điểm sức khỏe tổng hợp (CPU 45% · RAM 40% · Ổ đĩa 15%)

    private var healthScore: Int {
        let load = systemMonitor.cpuUsage * 0.45
            + systemMonitor.memoryUsage * 0.40
            + diskManager.usagePercentage * 0.15
        return max(0, min(100, Int((100 - load * 100).rounded())))
    }

    private var healthTint: Color {
        switch healthScore {
        case 75...: return Color(hex: "7DEBCE")
        case 50..<75: return Color(hex: "FBBF24")
        default: return Color(hex: "F87171")
        }
    }

    private var healthStatusText: String {
        switch healthScore {
        case 75...: return L("Ổn định")
        case 50..<75: return L("Cần chú ý")
        default: return L("Quá tải")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            DashboardBrandMark()

            VStack(alignment: .leading, spacing: 2) {
                Text("MacOptimizer")
                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(L("Bảng điều khiển hệ thống"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(healthTint)
                    .frame(width: 6, height: 6)
                Text(healthStatusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .accessibilityLabel(String(format: L("Tình trạng hệ thống: %@"), healthStatusText))

            headerIconButton(icon: "gearshape", tint: .white.opacity(0.75)) {
                manager.showDetail(route: .customization)
            } help: {
                L("Tùy chỉnh menu bar")
            }

            headerIconButton(icon: "power", tint: Color(hex: "FF6B6B")) {
                showQuitConfirm = true
            } help: {
                L("Thoát MacOptimizer")
            }
        }
    }

    private func headerIconButton(
        icon: String,
        tint: Color,
        action: @escaping () -> Void,
        help: @escaping () -> String
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 27, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help())
        .accessibilityLabel(help())
    }

    // MARK: - Thẻ tâm điểm: vòng điểm sức khỏe + CPU/RAM

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MenuBarSectionLabel(title: L("TÌNH TRẠNG HỆ THỐNG"), tint: healthTint)
                Spacer()
                Text(String(format: L("Hoạt động %@"), formatUptime(systemMonitor.systemUptime)))
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            HStack(spacing: 18) {
                HealthRing(score: healthScore, tint: healthTint)

                VStack(spacing: 9) {
                    MiniGaugeRow(
                        icon: "cpu",
                        tint: Color(hex: "FFB46B"),
                        label: "CPU",
                        value: "\(Int(systemMonitor.cpuUsage * 100))%",
                        progress: systemMonitor.cpuUsage
                    ) {
                        manager.showDetail(route: .cpu)
                    }

                    MiniGaugeRow(
                        icon: "memorychip",
                        tint: Color(hex: "7DEBCE"),
                        label: "RAM",
                        value: "\(Int(systemMonitor.memoryUsage * 100))%",
                        progress: systemMonitor.memoryUsage
                    ) {
                        manager.showDetail(route: .memory)
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .menuBarPanel(cornerRadius: 18, elevated: true)
    }

    // MARK: - Hàng ổ đĩa

    private var diskCard: some View {
        Button {
            manager.showDetail(route: .storage)
        } label: {
            HStack(spacing: 12) {
                MenuBarIconChip(icon: "internaldrive", tint: Color(hex: "2CB7FF"))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L("Ổ đĩa"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: L("Trống %@"), compact(diskManager.freeSize)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }

                    MenuBarTrack(progress: diskManager.usagePercentage, tint: Color(hex: "2CB7FF"))

                    HStack {
                        Text(String(format: L("Đã dùng %@ / %@"), compact(diskManager.usedSize), compact(diskManager.totalSize)))
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarButtonStyle())
        .menuBarPanel(cornerRadius: 16)
    }

    // MARK: - Hàng mạng

    private var networkCard: some View {
        Button {
            manager.showDetail(route: .network)
        } label: {
            HStack(spacing: 12) {
                MenuBarIconChip(icon: "wifi", tint: Color(hex: "B48DFF"))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L("Mạng"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(systemMonitor.wifiSSID)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        speedChip(icon: "arrow.down", text: shortSpeed(systemMonitor.downloadSpeed))
                        speedChip(icon: "arrow.up", text: shortSpeed(systemMonitor.uploadSpeed))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarButtonStyle())
        .menuBarPanel(cornerRadius: 16)
    }

    private func speedChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Bảo vệ thời gian thực (chặn quảng cáo + theo dõi thật qua /etc/hosts)

    private var protectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MenuBarSectionLabel(title: L("BẢO VỆ THỜI GIAN THỰC"), tint: Color(hex: "7DEBCE"))
                Spacer()
                let anyOn = hosts.adBlockEnabled || hosts.antiTrackEnabled
                HStack(spacing: 5) {
                    Circle()
                        .fill(anyOn ? Color(hex: "22C55E") : Color.white.opacity(0.35))
                        .frame(width: 6, height: 6)
                    Text(anyOn ? L("Đang hoạt động") : L("Chưa bật"))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }

            HostsToggleRow(
                icon: "hand.raised.fill",
                accent: Color(hex: "2CB7FF"),
                title: L("Chặn quảng cáo"),
                subtitle: hosts.adBlockEnabled
                    ? String(format: L("Đang chặn %d máy chủ quảng cáo"), hosts.adBlockDomainCount)
                    : L("Chặn banner và quảng cáo trong trình duyệt"),
                isOn: hosts.adBlockEnabled
            ) { value in
                hosts.setAdBlock(value)
            }

            HostsToggleRow(
                icon: "eye.slash.fill",
                accent: Color(hex: "8D34FF"),
                title: L("Ngăn chặn theo dõi"),
                subtitle: hosts.antiTrackEnabled
                    ? String(format: L("Đang chặn %d trình theo dõi"), hosts.antiTrackDomainCount)
                    : L("Chặn Google Analytics, pixel mạng xã hội…"),
                isOn: hosts.antiTrackEnabled
            ) { value in
                hosts.setAntiTrack(value)
            }

            HStack {
                if let message = hosts.lastMessage {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                Button(action: {
                    manager.openMainApp(module: .malware)
                }) {
                    HStack(spacing: 4) {
                        Text(L("Trung tâm bảo vệ"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "7DEBCE"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .menuBarPanel(cornerRadius: 16)
    }

    // MARK: - Tiện ích trên máy

    private var utilitiesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            MenuBarSectionLabel(title: L("TIỆN ÍCH TRÊN MÁY"), tint: Color(hex: "FFB46B"))

            InsightRow(
                icon: "list.bullet.rectangle.fill",
                accent: Color(hex: "FFB46B"),
                title: L("Dịch vụ nền"),
                value: backgroundItems.thirdPartyCount == 0
                    ? L("Chỉ có dịch vụ của hệ thống")
                    : String(format: L("%d mục của bên thứ ba"), backgroundItems.thirdPartyCount)
            ) {
                manager.openMainApp(module: .backgroundItems)
            }

            InsightRow(
                icon: "brain.head.profile",
                accent: Color(hex: "7DEBCE"),
                title: L("Mô hình AI"),
                value: insights.aiModelsText
            ) {
                manager.openMainApp(module: .aiModels)
            }

            InsightRow(
                icon: "shippingbox.fill",
                accent: Color(hex: "2CB7FF"),
                title: "Image Docker",
                value: insights.dockerText
            ) {
                manager.openMainApp(module: .docker)
            }
        }
        .padding(12)
        .menuBarPanel(cornerRadius: 16)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 4) {
            FooterNavItem(icon: "house.fill", title: L("Trang chủ"), isActive: selectedFooterShortcut == .home) {
                selectedFooterShortcut = .home
                manager.openMainApp(module: .smartClean)
            }
            FooterNavItem(icon: "xmark.app.fill", title: L("Buộc thoát"), isActive: selectedFooterShortcut == .clean) {
                selectedFooterShortcut = .clean
                manager.showDetail(route: .forceQuitApps)
            }
            FooterNavItem(icon: "bolt.fill", title: L("Tăng tốc"), isActive: selectedFooterShortcut == .boost) {
                selectedFooterShortcut = .boost
                manager.openMainApp(module: .optimizer)
            }
            FooterNavItem(icon: "checkmark.shield.fill", title: L("Bảo vệ"), isActive: selectedFooterShortcut == .protect) {
                selectedFooterShortcut = .protect
                manager.openMainApp(module: .malware)
            }
            FooterNavItem(icon: "gearshape.fill", title: L("Cài đặt"), isActive: selectedFooterShortcut == .settings) {
                selectedFooterShortcut = .settings
                manager.showDetail(route: .customization)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .menuBarPanel(cornerRadius: 16)
    }

    // MARK: - Helper

    private func formatUptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: L("%d giờ %d phút"), hours, minutes)
    }

    private func compact(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes).replacingOccurrences(of: " ", with: "")
    }

    private func shortSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0fK", bytesPerSecond / 1_000)
        }
        return String(format: "%.0fB", bytesPerSecond)
    }
}

// MARK: - Brand mark nhỏ cho dashboard

private struct DashboardBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "2CB7FF"), Color(hex: "8D34FF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Vòng điểm sức khỏe

private struct HealthRing: View {
    let score: Int
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 9)

            Circle()
                .trim(from: 0, to: max(0.03, Double(score) / 100))
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.55), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text(L("điểm"))
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: 92, height: 92)
        .animation(.easeOut(duration: 0.5), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: L("Điểm sức khỏe hệ thống: %d trên 100"), score))
    }
}

// MARK: - Hàng gauge mảnh cho CPU / RAM bên phải vòng điểm

private struct MiniGaugeRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    let progress: Double
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tint)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(value)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }

                MenuBarTrack(progress: progress, tint: tint, height: 3.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 148)
            .menuBarInsetRow(hovered: hovering)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }
        .buttonStyle(MenuBarButtonStyle())
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Hàng toggle cho chặn quảng cáo / theo dõi

private struct HostsToggleRow: View {
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 11) {
            MenuBarIconChip(icon: icon, tint: accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isOn }, set: { onChange($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(hex: "22C55E"))
                .scaleEffect(0.8, anchor: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .menuBarInsetRow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle). \(isOn ? L("Đang bật") : L("Đang tắt"))")
    }
}

// MARK: - Hàng tiện ích (dịch vụ nền / AI / Docker)

private struct InsightRow: View {
    let icon: String
    let accent: Color
    let title: String
    let value: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                MenuBarIconChip(icon: icon, tint: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    Text(value)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .menuBarInsetRow(hovered: hovering)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }
        .buttonStyle(MenuBarButtonStyle())
    }
}

private enum FooterShortcut {
    case home
    case clean
    case boost
    case protect
    case settings
}

private struct FooterNavItem: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? Color(hex: "5CC8FF") : .white.opacity(0.42))
                Text(title)
                    .font(.system(size: 9.5, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .white : .white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isActive ? Color(hex: "2CB7FF").opacity(0.16) : Color.clear)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
