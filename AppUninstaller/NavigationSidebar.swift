import SwiftUI

// MARK: - Định nghĩa nhóm thanh bên

enum SidebarSection: String, CaseIterable {
    case main = ""           // Quét thông minh (không có tiêu đề ở trên cùng)
    case cleanup = "Dọn dẹp"    // Rác hệ thống, tệp đính kèm email, thùng rác
    case protection = "Bảo vệ" // Loại bỏ phần mềm độc hại, quyền riêng tư
    case speed = "Tăng tốc"      // Tối ưu hóa và duy trì
    case apps = "Ứng dụng"   // Trình gỡ cài đặt, Trình cập nhật, Tiện ích mở rộng
    case files = "Tệp"      // Ống kính không gian, tài liệu lớn và cũ, máy hủy giấy
    
    var modules: [AppModule] {
        switch self {
        case .main:
            return [.monitor, .smartClean]
        case .cleanup:
            return [.cleaner, .deepClean, .trash]
        case .protection:
            return [.malware, .privacy]
        case .speed:
            return [.optimizer, .backgroundItems, .maintenance]
        case .apps:
            return [.uninstaller, .updater]
        case .files:
            return [.fileExplorer, .spaceLens, .aiModels, .docker, .largeFiles, .shredder]
        }
    }
}

struct NavigationSidebar: View {
    @Binding var selectedModule: AppModule
    @ObservedObject var localization = LocalizationManager.shared
    @State private var showSettings = false
    @State private var showUpdatePopup = false
    @StateObject private var updateService = UpdateCheckerService.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                // Khu vực Logo trên cùng (click để kiểm tra cập nhật)

                Button(action: {
                    if updateService.hasUpdate {
                        showUpdatePopup = true
                    }
                }) {
                    HStack(spacing: 12) {
                        AppBrandMark(size: 36)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ApexTune")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Hiển thị lời nhắc cập nhật phiên bản

                            if updateService.hasUpdate {
                                Text(L("Phiên bản mới"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(8)
                                    .padding(.top, 2)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showUpdatePopup) {
                    UpdatePopupView()
                }
                
                // Menu điều hướng được nhóm

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(SidebarSection.allCases, id: \.self) { section in
                            // Tiêu đề nhóm

                            if !section.rawValue.isEmpty {
                                Text(L(section.rawValue))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.leading, 14)
                                    .padding(.top, section == .cleanup ? 6 : 12)
                                    .padding(.bottom, 2)
                            }
                            
                            // các mục được nhóm

                            ForEach(section.modules) { module in
                                SidebarMenuItem(
                                    module: module,
                                    isSelected: selectedModule == module,
                                    action: { selectedModule = module },
                                    localization: localization
                                )
                                .id(module.rawValue)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                
                Spacer()
                
                // Thông tin và cài đặt phiên bản dưới cùng

                VStack(spacing: 8) {
                    HStack {
                        // nút cài đặt

                        Spacer()

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(L("Cài đặt"))
                    }
                    
                    HStack(spacing: 6) {
                        Text("v5.0.1")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        Text(L("Bản Pro"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Spacer()
                    }
                }
                .padding(.horizontal, 14)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .padding(.bottom, 12)
            }
            .frame(width: 220)
            .onAppear {
                scrollToSelectedModule(with: proxy, animated: false)
            }
            .onChange(of: selectedModule) { _ in
                scrollToSelectedModule(with: proxy, animated: true)
            }
        }
    }

    private func scrollToSelectedModule(with proxy: ScrollViewProxy, animated: Bool) {
        let scrollAction = {
            proxy.scrollTo(selectedModule.rawValue, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }
}

/// Brand mark used in sidebar and compact headers.
private struct AppBrandMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.70, blue: 1.00),
                            Color(red: 0.53, green: 0.24, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )

            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .frame(width: size, height: size)
    }
}

// ĐÁNH DẤU: - Mục menu thanh bên

struct SidebarMenuItem: View {
    let module: AppModule
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject var localization: LocalizationManager
    @State private var isHovering = false
    
    // Lấy tên mô-đun được bản địa hóa

    private var localizedName: String {
        switch module {
        case .monitor: return L("Giám sát")
        case .uninstaller: return L("Gỡ cài đặt")
        case .updater: return L("Trình cập nhật")
        case .deepClean: return L("Làm sạch sâu")
        case .cleaner: return L("Rác hệ thống")
        case .maintenance: return L("Bảo trì")
        case .optimizer: return L("Tối ưu hóa")
        case .shredder: return L("Hủy tệp")
        case .largeFiles: return L("Tệp lớn / cũ")
        case .fileExplorer: return L("Duyệt tệp")
        case .spaceLens: return L("Không gian đĩa")
        case .aiModels: return L("Mô hình AI")
        case .docker: return L("Image Docker")
        case .backgroundItems: return L("Dịch vụ nền")
        case .trash: return L("Thùng rác")
        case .privacy: return L("Quyền riêng tư")
        case .malware: return L("Quét mã độc")
        case .smartClean: return L("Quét thông minh")
        }
    }
    
    // Nhận biểu tượng mô-đun

    private var moduleIcon: String {
        module.icon
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // biểu tượng

                // Hiển thị biểu tượng màu khi được chọn hoặc di chuột

                if isSelected || isHovering {
                    Image(systemName: moduleIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(module.gradient) // Sử dụng màu chuyển màu do mô-đun xác định
                        .frame(width: 22)
                } else {
                    Image(systemName: moduleIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6)) // Màu xám chưa được chọn
                        .frame(width: 22)
                }
                
                // tên

                Text(localizedName)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        // Trạng thái đã chọn: Nền kết cấu kính rõ ràng hơn, bắt chước cảm giác thẻ về "kiến trúc ngoại vi"

                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.2)) // Đáy tối tăng cường độ tương phản
                                
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(LinearGradient(
                                            colors: [.white.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ), lineWidth: 0.5)
                                )
                        }
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
