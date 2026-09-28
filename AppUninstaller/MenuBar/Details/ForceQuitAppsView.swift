import SwiftUI
import AppKit

struct ForceQuitAppsView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    @State private var searchText = ""
    @State private var runningApps: [NSRunningApplication] = []
    @State private var activePid: pid_t?
    
    private var filteredApps: [NSRunningApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return runningApps }
        return runningApps.filter { app in
            let name = app.localizedName?.lowercased() ?? ""
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains(query) || bundleId.contains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.45))
                    TextField(L("Tìm ứng dụng đang chạy"), text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                
                Text(L("Chọn ứng dụng regular đang chạy để buộc thoát nhanh từ menu bar."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if filteredApps.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green.opacity(0.9))
                                Text(L("Không có ứng dụng phù hợp"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(L("Thử đổi từ khóa hoặc làm mới danh sách."))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            ForEach(filteredApps, id: \.processIdentifier) { app in
                                ForceQuitAppRow(
                                    app: app,
                                    isProcessing: activePid == app.processIdentifier,
                                    onForceQuit: {
                                        forceQuit(app)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(hex: "1C0C24"))
        .onAppear(perform: refreshRunningApps)
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Buộc thoát ứng dụng"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(String(format: L("%d ứng dụng đang mở"), runningApps.count))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: refreshRunningApps) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation { manager.closeDetail() }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func refreshRunningApps() {
        let currentPid = ProcessInfo.processInfo.processIdentifier
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != currentPid }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    
    private func forceQuit(_ app: NSRunningApplication) {
        activePid = app.processIdentifier
        systemMonitor.forceQuitProcess(app.processIdentifier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            refreshRunningApps()
            if activePid == app.processIdentifier {
                activePid = nil
            }
        }
    }
}

private struct ForceQuitAppRow: View {
    let app: NSRunningApplication
    let isProcessing: Bool
    let onForceQuit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.localizedName ?? L("Ứng dụng không rõ"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(app.bundleIdentifier ?? "PID \(app.processIdentifier)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onForceQuit) {
                Text(isProcessing ? L("Đang thoát...") : L("Buộc thoát"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isProcessing ? Color.white.opacity(0.14) : Color.red.opacity(0.82))
                    .cornerRadius(999)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}
