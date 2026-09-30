import SwiftUI

struct ConsoleOverviewView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var systemMonitor: SystemMonitorService
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text(L("Tổng quan về hệ thống"))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Memory Chart Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundColor(.blue)
                        Text(L("10 mức sử dụng bộ nhớ hàng đầu"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        
                        Text(L("Nhấn vào đây để xem tất cả"))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    if systemMonitor.topMemoryProcesses.isEmpty {
                        Text(L("Đang tải..."))
                            .foregroundColor(.secondaryText)
                            .padding()
                    } else {
                        // Custom Chart
                        VStack(spacing: 12) {
                            ForEach(systemMonitor.topMemoryProcesses) { process in
                                HStack {
                                    // Icon and Name
                                    HStack(spacing: 8) {
                                        if let icon = process.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Image(systemName: "gearshape")
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.secondaryText)
                                        }
                                        
                                        Text(process.name)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 150, alignment: .leading)
                                    
                                    // Bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: max(0, min(geometry.size.width * CGFloat(process.memory / (systemMonitor.topMemoryProcesses.first?.memory ?? 1.0)), geometry.size.width)), height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                    
                                    // Value
                                    Text(String(format: "%.1f GB", process.memory))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondaryText)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation {
                        viewState = .processManager
                    }
                }
                .padding(.horizontal)
                
                // CPU Usage Chart (Top 10)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        Text(L("10 mức sử dụng CPU hàng đầu"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    if systemMonitor.topCPUProcesses.isEmpty {
                        Text(L("Đang tải..."))
                            .foregroundColor(.secondaryText)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(systemMonitor.topCPUProcesses) { process in
                                HStack {
                                    HStack(spacing: 8) {
                                        if let icon = process.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Image(systemName: "gearshape")
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.secondaryText)
                                        }
                                        Text(process.name)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 150, alignment: .leading)
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple, .pink],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: max(0, min(geometry.size.width * CGFloat(process.cpu / (systemMonitor.topCPUProcesses.first?.cpu ?? 100.0)), geometry.size.width)), height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                    
                                    Text(String(format: "%.1f%%", process.cpu))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondaryText)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation {
                        viewState = .processManager
                    }
                }
                .padding(.horizontal)
                
                // Network Speed History
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.green)
                        Text(L("Xu hướng mạng"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text(systemMonitor.formatSpeed(systemMonitor.downloadSpeed))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    // Simple Line Chart
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let data = systemMonitor.downloadSpeedHistory
                            
                            guard data.count > 1 else { return }
                            let maxValue = data.max() ?? 1.0
                            let stepX = width / CGFloat(data.count - 1)
                            
                            for (index, value) in data.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height - (CGFloat(value) / CGFloat(maxValue == 0 ? 1 : maxValue)) * height
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.green, lineWidth: 2)
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    
                    HStack {
                        Text(L("Tổng số lượt tải xuống:")) +
                        Text(systemMonitor.totalDownload).foregroundColor(.white)
                        Spacer()
                        Text(L("Tổng tải lên:")) +
                        Text(systemMonitor.totalUpload).foregroundColor(.white)
                    }
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation {
                        viewState = .networkOptimize
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        // Lifecycle start/stop do MonitorView sở hữu (dùng chung 1 SystemMonitorService)
    }
}

struct StatsDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(value)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
