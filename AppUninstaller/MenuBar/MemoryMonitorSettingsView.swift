import SwiftUI

///Chế độ xem cài đặt giám sát bộ nhớ

/// Người dùng có thể quản lý danh sách bỏ qua và tùy chọn giám sát

struct MemoryMonitorSettingsView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    @State private var ignoredApps: [String] = []
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // tiêu đề

            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text(L("Cài đặt giám sát bộ nhớ"))
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
            }
            
            Divider()
            
            // minh họa

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Tự động giám sát"))
                    .font(.system(size: 14, weight: .semibold))
                
                Text(L("Hệ thống sẽ tự phát hiện ứng dụng dùng hơn 1 GB bộ nhớ và hiện cảnh báo ở thanh menu."))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // bỏ qua danh sách

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("Ứng dụng đã bỏ qua"))
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                    
                    if !ignoredApps.isEmpty {
                        Button(L("Xóa tất cả")) {
                            showingClearConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    }
                }
                
                if ignoredApps.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.green.opacity(0.6))
                            
                            Text(L("Chưa có ứng dụng nào bị bỏ qua"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(ignoredApps, id: \.self) { appName in
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(.gray)
                                    
                                    Text(appName)
                                        .font(.system(size: 13))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeApp(appName)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
            
            // Tin nhắn nhắc nhở

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text(L("Sau khi chọn \"Bỏ qua ứng dụng này\", ứng dụng đó sẽ không kích hoạt cảnh báo bộ nhớ nữa."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(20)
        .frame(width: 400, height: 500)
        .onAppear {
            loadIgnoredApps()
        }
        .alert(L("Xác nhận xóa"), isPresented: $showingClearConfirmation) {
            Button(L("Hủy"), role: .cancel) { }
            Button(L("Xóa tất cả"), role: .destructive) {
                clearAllApps()
            }
        } message: {
            Text(L("Bạn có chắc muốn xóa toàn bộ ứng dụng đã bỏ qua không? Sau khi xóa, các ứng dụng này sẽ lại kích hoạt cảnh báo nếu dùng nhiều bộ nhớ."))
        }
    }
    
    private func loadIgnoredApps() {
        ignoredApps = systemMonitor.getIgnoredApps()
    }
    
    private func removeApp(_ appName: String) {
        systemMonitor.removeFromIgnoredApps(appName)
        loadIgnoredApps()
    }
    
    private func clearAllApps() {
        systemMonitor.clearAllIgnoredApps()
        loadIgnoredApps()
    }
}

#if DEBUG
struct MemoryMonitorSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryMonitorSettingsView(systemMonitor: SystemMonitorService())
    }
}
#endif
