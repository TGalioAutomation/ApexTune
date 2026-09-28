import SwiftUI

struct ConsoleSidebar: View {
    @Binding var selection: MonitorView.DashboardState
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Trung tâm hệ thống"))
                .font(.title3)
                .bold()
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 10)
                .foregroundColor(.white)
            
            Group {
                SidebarButton(title: L("Tổng quan"), icon: "square.grid.2x2", isSelected: selection == .dashboard) {
                    selection = .dashboard
                }
                
                SidebarButton(title: L("Quản lý ứng dụng"), icon: "app.badge", isSelected: selection == .appManager) {
                    selection = .appManager
                }
                
                SidebarButton(title: L("Quản lý tiến trình"), icon: "waveform.path.ecg", isSelected: selection == .processManager) {
                    selection = .processManager
                }
                
                SidebarButton(title: L("Mạng"), icon: "wifi", isSelected: selection == .networkOptimize) {
                    selection = .networkOptimize
                }
                
                SidebarButton(title: L("Quản lý cổng mạng"), icon: "network", isSelected: selection == .portManager) {
                    selection = .portManager
                }
                
                SidebarButton(title: L("Bảo vệ hệ thống"), icon: "shield.checkerboard", isSelected: selection == .protection) {
                    selection = .protection
                }
            }
            
            Spacer()
        }
        .frame(width: 200)
        .background(Color.white.opacity(0.03))
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Spacer()
                
                if isSelected {
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: 3, height: 16)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}
