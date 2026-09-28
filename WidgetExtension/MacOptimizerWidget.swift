import WidgetKit
import SwiftUI

// MARK: - Entry & Provider

struct HealthEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
}

struct HealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: Date(), metrics: SystemMetrics.sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        completion(HealthEntry(date: Date(), metrics: SystemMetrics.sample()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        let entry = HealthEntry(date: Date(), metrics: SystemMetrics.sample())
        // Widget tự đo lại mỗi 15 phút; app chính cũng chủ động reload khi mở bảng điều khiển.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Widget

// LƯU Ý (2026-09-28, macOS 27.0/26A428): widget appex này trap
// EXC_BREAKPOINT trong ExtensionFoundation (MainActor.assumeIsolated lúc
// EXExtension.bootstrap) trước khi code bên dưới kịp chạy — xảy ra cả khi
// hosted lẫn standalone, bất kể Swift 5/6, minos 13/27 hay các mẫu khởi
// tạo runtime concurrency. Widget hệ thống build bằng Xcode (Reminders)
// chạy bình thường. Hướng đi: chờ Apple sửa hoặc rebuild appex bằng
// Xcode project thật.
@main
struct MacOptimizerWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacHealthWidget()
    }
}
struct MacHealthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MacOptimizerHealth", provider: HealthProvider()) { entry in
            MacHealthWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL.t("Điểm sức khỏe hệ thống"))
        .description(WidgetL.t("Theo dõi CPU, RAM, ổ đĩa và điểm sức khỏe của Mac theo thiết kế MacOptimizer."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Giao diện

struct MacHealthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HealthEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumHealthView(metrics: entry.metrics)
            default:
                SmallHealthView(metrics: entry.metrics)
            }
        }
        .padding(12)
        .macWidgetBackground()
    }
}

// MARK: - Widget Small: vòng điểm sức khỏe

private struct SmallHealthView: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(spacing: 8) {
            HealthRingView(score: metrics.healthScore, accent: Color(hex: metrics.accentHex))
            Text(metrics.statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(metrics.uptimeText)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Widget Medium: vòng điểm + CPU/RAM/Ổ đĩa

private struct MediumHealthView: View {
    let metrics: SystemMetrics

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 5) {
                HealthRingView(score: metrics.healthScore, accent: Color(hex: metrics.accentHex), ringSize: 74)
                Text(metrics.statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 10) {
                GaugeRow(label: "CPU", value: Int(metrics.cpuUsage * 100), progress: metrics.cpuUsage, tint: Color(hex: "FFB46B"))
                GaugeRow(label: "RAM", value: Int(metrics.memoryUsage * 100), progress: metrics.memoryUsage, tint: Color(hex: "7DEBCE"))
                GaugeRow(label: WidgetL.t("Đĩa"), value: Int(metrics.diskUsage * 100), progress: metrics.diskUsage, tint: Color(hex: "2CB7FF"), caption: WidgetL.t("Trống %@", metrics.diskFreeText))
            }
        }
    }
}

private struct GaugeRow: View {
    let label: String
    let value: Int
    let progress: Double
    let tint: Color
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(value)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(3, proxy.size.width * min(max(progress, 0.02), 1)))
                }
            }
            .frame(height: 4)
            if let caption {
                Text(caption)
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Vòng điểm dùng chung

struct HealthRingView: View {
    let score: Int
    let accent: Color
    var ringSize: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.03, Double(score) / 100))
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.55), accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: ringSize * 0.28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text(WidgetL.t("điểm"))
                    .font(.system(size: ringSize * 0.10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: ringSize, height: ringSize)
    }
}

// MARK: - Nền widget (graphite đồng bộ bảng điều khiển)

private struct GraphiteBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "161A22"), Color(hex: "0C0E13")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension View {
    /// macOS 14 yêu cầu containerBackground; bản cũ dùng nền trực tiếp.
    @ViewBuilder
    func macWidgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(for: .widget) { GraphiteBackground() }
        } else {
            background(GraphiteBackground())
        }
    }
}

// MARK: - Hex color (bản gọn của Color(hex:) trong Styles.swift)

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        Scanner(string: hexString).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
