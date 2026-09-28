import SwiftUI

struct StorageDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var diskManager = DiskSpaceManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("Dung lượng lưu trữ"))
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
                VStack(spacing: 24) {
                    // Main Chart
                    ZStack {
                        // Background Ring
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 20)
                            .frame(width: 160, height: 160)
                        
                        // Data Ring (Free Space for contrast or Used Space?)
                        // Show Used Space in Color for better visualization.
                        let usedPercent = 1.0 - (Double(diskManager.freeSize) / Double(diskManager.totalSize))
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(usedPercent))
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 160, height: 160)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 0)
                        
                        VStack(spacing: 4) {
                            Text(diskManager.formattedFree)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text(L("Dung lượng trống"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            Text(String(format: L("Tổng %@"), diskManager.formattedTotal))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 10)
                    
                    // Breakdown Grid
                    VStack(spacing: 12) {
                        // Mock Categories for Visuals (since we don't scan full file types instantly in menu bar)
                        // In a real app we'd fetch these from a background service
                        StorageCategoryRow(color: .blue, name: L("Ứng dụng"), size: "35.09 GB")
                        StorageCategoryRow(color: .cyan, name: L("Tài liệu"), size: "12.4 GB")
                        StorageCategoryRow(color: .purple, name: L("Dữ liệu hệ thống"), size: "89.2 GB")
                        StorageCategoryRow(color: .pink, name: L("Ảnh"), size: "5.1 GB")
                        StorageCategoryRow(color: .gray, name: L("Khác"), size: "10.2 GB")
                    }
                    .padding(.horizontal, 20)
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            manager.openMainApp()
                        }) {
                            Text(L("Dọn rác"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            manager.openMainApp()
                        }) {
                            Text(L("Quản lý tệp lớn"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
}

struct StorageCategoryRow: View {
    let color: Color
    let name: String
    let size: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text(size)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
