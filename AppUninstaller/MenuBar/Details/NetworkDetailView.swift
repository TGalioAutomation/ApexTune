import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("Mạng"))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { 
                    withAnimation { manager.closeDetail() }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Status Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: "wifi")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(systemMonitor.wifiSSID)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text(L("Đã kết nối Wi-Fi"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Text(systemMonitor.connectionDuration)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        
                        Text(L("Theo dõi tốc độ và tổng lưu lượng truyền nhận theo thời gian thực của kết nối Wi-Fi đang dùng."))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                // Open Network Settings or similar
                            }) {
                                HStack(spacing: 4) {
                                    Text(L("Tìm hiểu thêm"))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "3A2E55")) // Card Purple
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // 2. Traffic Cards
                    HStack(spacing: 12) {
                        // Download Card
                        TrafficCard(
                            title: L("Tải xuống"),
                            total: systemMonitor.totalDownload,
                            speed: systemMonitor.formatSpeed(systemMonitor.downloadSpeed),
                            history: systemMonitor.downloadSpeedHistory,
                            color: Color(hex: "6A85FC") // Blueish
                        )
                        
                        // Upload Card
                        TrafficCard(
                            title: L("Tải lên"),
                            total: systemMonitor.totalUpload,
                            speed: systemMonitor.formatSpeed(systemMonitor.uploadSpeed),
                            history: systemMonitor.uploadSpeedHistory,
                            color: Color(hex: "FD6585") // Pinkish
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 3. Speed Test Section
                    VStack(spacing: 20) {
                        Text(L("Kiểm tra kết nối mạng"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 20) {
                            // Gauge
                            ZStack {
                                // Background Dashes
                                Circle()
                                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 10, lineCap: .butt, dash: [2, 4]))
                                    .frame(width: 140, height: 140)
                                
                                // Active Progress Dashes
                                if systemMonitor.isTestingSpeed || systemMonitor.speedTestResult > 0 {
                                    Circle()
                                        .trim(from: 0, to: systemMonitor.isTestingSpeed ? systemMonitor.speedTestProgress : 1.0)
                                        .stroke(
                                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            style: StrokeStyle(lineWidth: 10, lineCap: .butt, dash: [2, 4])
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 140, height: 140)
                                        .animation(.linear(duration: 0.5), value: systemMonitor.speedTestProgress)
                                }
                                
                                // Center Content
                                VStack {
                                    if systemMonitor.isTestingSpeed {
                                        Text(L("Đang kiểm tra"))
                                            .font(.headline)
                                            .foregroundColor(.cyan)
                                    } else if systemMonitor.speedTestResult > 0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                        Text(L("Hoàn tất"))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    } else {
                                        // Idle state
                                        Button(action: {
                                            systemMonitor.runSpeedTest()
                                        }) {
                                           Text(L("Bắt đầu"))
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding(20)
                                                .background(Circle().fill(Color.white.opacity(0.1)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Re-test overlay if done (Full overlay button)
                                if !systemMonitor.isTestingSpeed && systemMonitor.speedTestResult > 0 {
                                     Button(action: {
                                        systemMonitor.runSpeedTest()
                                    }) {
                                        VStack {
                                            Spacer()
                                            Text(L("Kiểm tra lại"))
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                                .padding(.bottom, 30)
                                        }
                                        .frame(width: 140, height: 140)
                                        .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Results List
                            if systemMonitor.speedTestResult > 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(String(format: L("%.1f Mbps"), systemMonitor.speedTestResult))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(L("Phù hợp cho:"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        SuitabilityRow(text: L("Chơi game trực tuyến"))
                                        SuitabilityRow(text: L("Xem video trực tuyến"))
                                        SuitabilityRow(text: L("Gọi video"))
                                        SuitabilityRow(text: L("Nghe nhạc trực tuyến"))
                                        SuitabilityRow(text: L("Gọi thoại"))
                                        SuitabilityRow(text: L("Nhắn tin"))
                                    }
                                }
                            } else {
                                // Placeholder when no test result yet
                                Text(systemMonitor.isTestingSpeed ? L("Đang đo tốc độ...") : L("Nhấn để bắt đầu kiểm tra"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
}

struct TrafficCard: View {
    let title: String
    let total: String
    let speed: String
    let history: [Double]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(alignment: .bottom) {
                Text(total)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(speed)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Mini Graph
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    for i in 0..<history.count {
                        let x = width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                        let val = CGFloat(history[i])
                        let y = height - (min(val / 1024 / 1024 / 2, 1.0) * height) // Normalize
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.5), color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                
                // Stroke Line
                Path { path in
                    // Re-calculate line without close
                    for i in 0..<history.count {
                        let x = width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                        let val = CGFloat(history[i])
                        let y = height - (min(val / 1024 / 1024 / 2, 1.0) * height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
            .frame(height: 40)
        }
        .padding(12)
        .background(Color(hex: "3A2E55"))
        .cornerRadius(12)
    }
}

struct SuitabilityRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }
}
