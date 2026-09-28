import SwiftUI

struct MenuBarCustomizationView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject private var systemMonitor: SystemMonitorService
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var selectedSection: CustomizerSection = .display
    
    private let compactColumns = [GridItem(.adaptive(minimum: 108), spacing: 8)]
    private let sectionTitleFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    private let primaryBodyFont = Font.system(size: 12, weight: .regular)
    private let secondaryBodyFont = Font.system(size: 11, weight: .regular)
    private let itemTitleFont = Font.system(size: 13, weight: .semibold)
    private let badgeFont = Font.system(size: 12, weight: .semibold)
    
    init(manager: MenuBarManager) {
        self.manager = manager
        self._systemMonitor = ObservedObject(wrappedValue: manager.systemMonitor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            sectionPicker
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    sectionContent
                }
                .padding(16)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Tùy chỉnh thanh menu"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(L("Chọn thông tin bạn muốn luôn nhìn thấy trên thanh menu."))
                    .font(primaryBodyFont)
                    .lineSpacing(1)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: {
                manager.closeDetail()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(CustomizerSection.allCases) { section in
                Button(action: {
                    selectedSection = section
                }) {
                    Text(section.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(selectedSection == section ? .black.opacity(0.8) : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selectedSection == section ? Color.white.opacity(0.95) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .display:
            previewCard
            presetsCard
            bannerThemeCard
            selectedMetricsCard
            availableMetricsCard
        case .sampling:
            samplingProfilesCard
            samplingIntervalsCard
        case .options:
            customSamplingSummaryCard
            optionsCard
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Xem trước"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                if let previewImage = manager.statusItemPreviewImage() {
                    Image(nsImage: previewImage)
                        .interpolation(.high)
                } else if manager.statusMetricDisplays.isEmpty {
                    Text(L("Chỉ biểu tượng"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(manager.statusMetricDisplays) { display in
                                HStack(spacing: 4) {
                                    Image(systemName: display.metric.symbolName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(display.text)
                                        .font(.system(size: 12, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(.white)
                                }
                                .help("\(display.metric.title): \(display.text)\n\(display.metric.tooltipDescription)")
                            }
                        }
                    }
                    .frame(height: 20)
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Preset hiển thị"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            Text(L("Nhóm này chỉ quyết định thông tin nào hiện trên thanh menu, không đổi nhịp lấy mẫu."))
                .font(secondaryBodyFont)
                .lineSpacing(1)
                .foregroundColor(.white.opacity(0.55))
            
            LazyVGrid(columns: compactColumns, spacing: 10) {
                presetButton(title: L("Mặc định"), subtitle: "GPU + CPU + DISK + RAM") {
                    manager.setStatusMetrics([.gpu, .cpu, .storage, .memory])
                    manager.showsStatusIcon = true
                }
                
                presetButton(title: L("Làm việc"), subtitle: "GPU + CPU + RAM") {
                    manager.setStatusMetrics([.gpu, .cpu, .memory])
                    manager.showsStatusIcon = true
                }
                
                presetButton(title: L("Giám sát"), subtitle: L("Hiện tất cả")) {
                    manager.setStatusMetrics(MenuBarStatusMetric.allCases)
                    manager.showsStatusIcon = true
                }
                
                presetButton(title: L("Tối giản"), subtitle: L("Chỉ biểu tượng")) {
                    manager.setStatusMetrics([])
                    manager.showsStatusIcon = true
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var bannerThemeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Giao diện banner"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            Text(L("Đổi kiểu dáng dải số liệu ngay trên thanh menu."))
                .font(secondaryBodyFont)
                .lineSpacing(1)
                .foregroundColor(.white.opacity(0.55))

            LazyVGrid(columns: compactColumns, spacing: 10) {
                ForEach(MenuBarBannerTheme.allCases) { theme in
                    bannerThemeButton(theme)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func bannerThemeButton(_ theme: MenuBarBannerTheme) -> some View {
        let isActive = manager.bannerTheme == theme

        return Button(action: {
            manager.bannerTheme = theme
        }) {
            VStack(alignment: .leading, spacing: 8) {
                BannerThemeChipPreview(theme: theme)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(theme.title)
                            .font(itemTitleFont)
                            .foregroundColor(.white)
                        Spacer()
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    Text(theme.subtitle)
                        .font(secondaryBodyFont)
                        .lineSpacing(1)
                        .foregroundColor(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(Color.white.opacity(isActive ? 0.14 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.green.opacity(0.8) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .help(theme.subtitle)
        .accessibilityLabel("\(L("Giao diện banner")): \(theme.title)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var samplingProfilesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Nhịp lấy mẫu"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            Text(L("Mỗi profile đổi tốc độ thu thập CPU, RAM, Mạng, Pin, DISK và danh sách tiến trình."))
                .font(secondaryBodyFont)
                .lineSpacing(1)
                .foregroundColor(.white.opacity(0.55))
            
            LazyVGrid(columns: compactColumns, spacing: 10) {
                ForEach([SamplingProfile.economy, .balanced, .live]) { profile in
                    profileButton(profile)
                }
            }
            
            if systemMonitor.samplingProfile == .custom {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Bạn đang dùng nhịp lấy mẫu tùy chỉnh"))
                            .font(itemTitleFont)
                            .foregroundColor(.white)
                        Text(L("Các chỉnh sửa phía dưới sẽ được lưu lại cho lần mở sau."))
                            .font(secondaryBodyFont)
                            .lineSpacing(1)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var samplingIntervalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Tùy chỉnh theo từng loại"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            Text(L("Chu kỳ càng ngắn thì số liệu càng mới, nhưng tốn tài nguyên nền hơn."))
                .font(secondaryBodyFont)
                .lineSpacing(1)
                .foregroundColor(.white.opacity(0.55))
            Text(L("Chỉ những metric đang bật hoặc panel đang mở mới được lấy mẫu."))
                .font(secondaryBodyFont)
                .foregroundColor(.green.opacity(0.85))
            
            VStack(spacing: 10) {
                ForEach(SamplingMetricKind.allCases) { kind in
                    samplingIntervalRow(for: kind)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var customSamplingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Trạng thái hiện tại"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                Image(systemName: systemMonitor.samplingProfile == .custom ? "slider.horizontal.3" : "waveform.path.ecg")
                    .foregroundColor(.white.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(systemMonitor.samplingProfile.title)
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Text(systemMonitor.samplingProfile.subtitle)
                        .font(secondaryBodyFont)
                        .foregroundColor(.white.opacity(0.58))
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var selectedMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Thứ tự đang hiển thị"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            
            if manager.selectedStatusMetrics.isEmpty {
                Text(L("Hiện chưa có metric nào được bật. Bạn vẫn có thể giữ lại biểu tượng ứng dụng trên thanh menu."))
                    .font(primaryBodyFont)
                    .lineSpacing(1)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(manager.selectedStatusMetrics.enumerated()), id: \.element) { index, metric in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.title)
                                    .font(itemTitleFont)
                                    .foregroundColor(.white)
                                Text(exampleText(for: metric))
                                    .font(secondaryBodyFont)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Button(action: { manager.moveStatusMetric(metric, direction: -1) }) {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            
                            Button(action: { manager.moveStatusMetric(metric, direction: 1) }) {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == manager.selectedStatusMetrics.count - 1)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .help("\(metric.title)\n\(metric.tooltipDescription)")
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var availableMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Thông tin có thể hiển thị"))
                .font(sectionTitleFont)
                .foregroundColor(.white)
            
            ForEach(MenuBarStatusMetric.allCases) { metric in
                Button(action: { manager.toggleStatusMetric(metric) }) {
                    HStack(spacing: 12) {
                        Image(systemName: manager.isStatusMetricEnabled(metric) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(manager.isStatusMetricEnabled(metric) ? .green : .white.opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(itemTitleFont)
                                .foregroundColor(.white)
                            Text(exampleText(for: metric))
                                .font(secondaryBodyFont)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .help("\(metric.title)\n\(metric.tooltipDescription)")
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Tùy chọn khác"))
                .font(sectionTitleFont)
                .foregroundColor(.white)

            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Khởi động cùng macOS"))
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Text(L("Tự động chạy MacOptimizer và giám sát menu bar khi đăng nhập."))
                        .font(secondaryBodyFont)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .toggleStyle(.switch)
            .tint(.purple)

            Toggle(isOn: Binding(
                get: { manager.showsStatusIcon },
                set: { _ in manager.toggleStatusIcon() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Hiện biểu tượng ứng dụng"))
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Text(L("Giữ lại biểu tượng app ở đầu status item."))
                        .font(secondaryBodyFont)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .toggleStyle(.switch)
            .tint(.purple)

            Stepper(value: Binding(
                get: { systemMonitor.memoryAlertThresholdPercent },
                set: { systemMonitor.updateMemoryAlertThreshold($0) }
            ), in: 60...95, step: 5) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: L("Cảnh báo RAM từ %d%%"), Int(systemMonitor.memoryAlertThresholdPercent)))
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Text(L("Chỉ cảnh báo khi toàn bộ hệ thống dùng RAM vượt ngưỡng này."))
                        .font(secondaryBodyFont)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .tint(.green)

            Button(action: {
                manager.resetStatusBarPreferences()
                systemMonitor.applySamplingProfile(.balanced)
                systemMonitor.updateMemoryAlertThreshold(85)
            }) {
                Text(L("Khôi phục cấu hình mặc định"))
                    .font(itemTitleFont)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func presetButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(itemTitleFont)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(secondaryBodyFont)
                    .lineSpacing(1)
                    .foregroundColor(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func profileButton(_ profile: SamplingProfile) -> some View {
        let isActive = systemMonitor.samplingProfile == profile
        
        return Button(action: {
            systemMonitor.applySamplingProfile(profile)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(profile.title)
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                Text(profile.subtitle)
                    .font(secondaryBodyFont)
                    .lineSpacing(1)
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(isActive ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.green.opacity(0.8) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func samplingIntervalRow(for kind: SamplingMetricKind) -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(itemTitleFont)
                        .foregroundColor(.white)
                    Text(kind.subtitle)
                        .font(secondaryBodyFont)
                        .lineSpacing(1)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Text(systemMonitor.formattedSamplingInterval(for: kind))
                    .font(badgeFont)
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(999)
            }
            
            Stepper(
                value: Binding(
                    get: { systemMonitor.menuBarSamplingConfiguration.interval(for: kind) },
                    set: { systemMonitor.updateSamplingInterval(for: kind, to: $0) }
                ),
                in: kind.range,
                step: kind.step
            ) {
                Text(L("Điều chỉnh nhịp lấy mẫu"))
                    .font(secondaryBodyFont)
                    .foregroundColor(.white.opacity(0.55))
            }
            .tint(.green)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .help("\(kind.title)\n\(kind.subtitle)")
    }
    
    private func exampleText(for metric: MenuBarStatusMetric) -> String {
        switch metric {
        case .gpu:
            return L("Ví dụ: icon + 53%")
        case .storage:
            return L("Ví dụ: icon + F:36.6GB U:357.8GB")
        case .memory:
            return L("Ví dụ: icon + 61%")
        case .cpu:
            return L("Ví dụ: icon + 64%")
        case .network:
            return L("Ví dụ: icon + ↓2.4M ↑350K")
        case .battery:
            return L("Ví dụ: icon + 82%")
        }
    }
}

private enum CustomizerSection: String, CaseIterable, Identifiable {
    case display
    case sampling
    case options

    var id: String { rawValue }

    var title: String {
        switch self {
        case .display: return L("Hiển thị")
        case .sampling: return L("Lấy mẫu")
        case .options: return L("Khác")
        }
    }
}

/// Mô phỏng viên thuốc "RAM 64%" theo từng theme banner — nhãn màu mint như RAM thật.
private struct BannerThemeChipPreview: View {
    let theme: MenuBarBannerTheme

    /// Mint của chỉ số RAM trong banner thật.
    private let accent = Color(red: 0.63, green: 0.98, blue: 0.80)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.35))
            chip
                .padding(.horizontal, 6)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private var chip: some View {
        switch theme {
        case .dark:
            styled(
                fill: LinearGradient(
                    colors: [Color(red: 0.24, green: 0.29, blue: 0.43), Color(red: 0.17, green: 0.20, blue: 0.31)],
                    startPoint: .leading, endPoint: .trailing
                ),
                stroke: accent.opacity(0.26),
                label: accent,
                value: .white
            )
        case .light:
            styled(
                fill: LinearGradient(
                    colors: [Color.white.opacity(0.96), Color(white: 0.92).opacity(0.94)],
                    startPoint: .leading, endPoint: .trailing
                ),
                stroke: Color.black.opacity(0.10),
                label: Color(red: 0.32, green: 0.49, blue: 0.40),
                value: Color.black.opacity(0.82)
            )
        case .mono:
            styled(
                fill: LinearGradient(
                    colors: [Color.black.opacity(0.88), Color.black.opacity(0.76)],
                    startPoint: .leading, endPoint: .trailing
                ),
                stroke: Color.white.opacity(0.14),
                label: Color.white.opacity(0.62),
                value: .white
            )
        case .accentFill:
            styled(
                fill: LinearGradient(
                    colors: [accent, Color(red: 0.45, green: 0.71, blue: 0.58)],
                    startPoint: .leading, endPoint: .trailing
                ),
                stroke: Color.white.opacity(0.22),
                label: Color.white.opacity(0.95),
                value: .white
            )
        case .minimal:
            HStack(spacing: 4) {
                Text("RAM")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(accent)
                Text("64%")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.5), radius: 2, y: 1)
        }
    }

    private func styled(
        fill: LinearGradient,
        stroke: Color,
        label: Color,
        value: Color
    ) -> some View {
        HStack(spacing: 4) {
            Text("RAM")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(label)
            Text("64%")
                .font(.system(size: 10.5, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(value)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
    }
}
