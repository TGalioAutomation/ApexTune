import SwiftUI
import AppKit

// MARK: - Xem chi tiết ứng dụng

struct AppDetailView: View {
    @ObservedObject var app: InstalledApp
    @ObservedObject private var loc = LocalizationManager.shared
    let onDelete: (Bool, Bool) -> Void
    
    @State private var includeApp = true
    @State private var moveToTrash = true
    @State private var selectAll = true
    
    var selectedFilesCount: Int {
        app.residualFiles.filter { $0.isSelected }.count
    }
    
    var selectedFilesSize: Int64 {
        app.residualFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var totalDeleteSize: Int64 {
        selectedFilesSize + (includeApp ? app.size : 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tiêu đề thông tin ứng dụng

            headerView
            
            // Danh sách các tập tin còn sót lại

            if app.isScanning {
                scanningView
            } else if app.residualFiles.isEmpty {
                noResidualView
            } else {
                residualFilesView
            }
            
            // Thanh hành động dưới cùng

            bottomBar
        }
        .onChange(of: selectAll) { newValue in
            for file in app.residualFiles {
                file.isSelected = newValue
            }
        }
    }
    
    // DẤU HIỆU: - Nhìn từ đầu

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                // Biểu tượng ứng dụng - với hiệu ứng phát sáng

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.uninstallerStart.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)
                    
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                
                // Thông tin ứng dụng

                VStack(alignment: .leading, spacing: 10) {
                    Text(app.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    if let bundleId = app.bundleIdentifier {
                        Text(bundleId)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }
                    
                    // Thống kê

                    HStack(spacing: 12) {
                        StatBadge(
                            icon: "internaldrive.fill",
                            label: loc.L("Kích thước ứng dụng"),
                            value: app.formattedSize,
                            color: .uninstallerStart
                        )
                        
                        if !app.residualFiles.isEmpty {
                            StatBadge(
                                icon: "doc.on.doc.fill",
                                label: loc.L("residual_files"),
                                value: "\(app.residualFiles.count)",
                                color: .warning
                            )
                            
                            StatBadge(
                                icon: "trash.fill",
                                label: loc.L("Có thể làm sạch"),
                                value: app.formattedResidualSize,
                                color: .danger
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(28)
            
            // dải phân cách

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .background(Color.cardBackground.opacity(0.5))
    }
    
    // MARK: - Chế độ xem quét

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.uninstallerStart.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .uninstallerStart))
                    .scaleEffect(1.4)
            }
            
            Text(loc.L("Đang quét các tập tin còn sót lại..."))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Không xem được file dư

    private var noResidualView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.success)
            }
            
            VStack(spacing: 8) {
                Text(loc.L("Xuất sắc!"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(loc.L("Không phát hiện thấy tệp dư nào cho ứng dụng này"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Danh sách file dư

    private var residualFilesView: some View {
        VStack(spacing: 0) {
            // Người đứng đầu danh sách

            HStack {
                Toggle(isOn: $selectAll) {
                    Text(loc.L("selectAll"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                .toggleStyle(CheckboxStyle())
                
                Spacer()
                
                // Thống kê đã chọn

                HStack(spacing: 6) {
                    Text("\(selectedFilesCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GradientStyles.uninstaller)
                    Text(loc.L("mục đã chọn"))
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.02))
            
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
            
            // danh sách tập tin

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(FileType.allCases) { type in
                        let filesOfType = app.residualFiles.filter { $0.type == type }
                        if !filesOfType.isEmpty {
                            FileTypeSection(type: type, files: filesOfType, loc: loc)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Thanh hành động phía dưới

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
            
            HStack(spacing: 24) {
                // tùy chọn xóa

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $includeApp) {
                        HStack(spacing: 6) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 11))
                            Text(loc.L("Bao gồm ứng dụng"))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.primaryText.opacity(0.85))
                    }
                    .toggleStyle(CheckboxStyle())
                    
                    Toggle(isOn: $moveToTrash) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text(loc.L("Chuyển vào Thùng rác (Có thể phục hồi)"))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.primaryText.opacity(0.85))
                    }
                    .toggleStyle(CheckboxStyle())
                }
                
                Spacer()
                
                // Xóa số liệu thống kê

                VStack(alignment: .trailing, spacing: 4) {
                    Text(loc.L("để làm sạch"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.tertiaryText)
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalDeleteSize, countStyle: .file))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(GradientStyles.uninstaller)
                }
                .padding(.trailing, 20)
                
                // nút xóa

                Button(action: {
                    onDelete(includeApp, moveToTrash)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: includeApp ? "trash.fill" : "paintbrush.fill")
                            .font(.system(size: 14))
                        Text(includeApp ? loc.L("Gỡ ứng dụng") : loc.L("Dọn tệp còn sót"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDestructive: includeApp))
                .disabled(selectedFilesCount == 0 && !includeApp)
            }
            .padding(24)
            .background(Color.cardBackground)
        }
    }
}



// MARK: - Huy hiệu thống kê

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .uninstallerStart
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.tertiaryText)
                
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Nhóm loại tập tin

struct FileTypeSection: View {
    let type: FileType
    let files: [ResidualFile]
    @ObservedObject var loc: LocalizationManager
    @State private var isExpanded = true
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    // Lấy tên loại bản địa hóa

    private var localizedTypeName: String {
        switch type {
        case .preferences:
            return loc.L("preferences")
        case .applicationSupport:
            return loc.L("app_support")
        case .caches:
            return loc.L("cache")
        case .containers:
            return loc.L("containers")
        case .savedState:
            return loc.L("saved_state")
        case .logs:
            return loc.L("logs")
        case .groupContainers:
            return loc.L("group_containers")
        case .cookies:
            return loc.L("cookies")
        case .launchAgents:
            return loc.L("launch_agents")
        case .crashReports:
            return loc.L("crash_reports")
        case .developer:
            return loc.L("Dữ liệu của nhà phát triển")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // tiêu đề gói

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // biểu tượng

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: type.color).opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: type.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: type.color))
                    }
                    
                    Text(localizedTypeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text("(\(files.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                        .frame(width: 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.015))
            
            // danh sách tập tin

            if isExpanded {
                ForEach(files) { file in
                    ResidualFileRow(file: file)
                }
            }
        }
    }
}

// MARK: - dòng tập tin còn lại

struct ResidualFileRow: View {
    @ObservedObject var file: ResidualFile
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $file.isSelected) {
                EmptyView()
            }
            .toggleStyle(CheckboxStyle())
            .labelsHidden()
            
            Image(systemName: "doc.fill")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(file.path.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
            
            // Hiển thị trong Trình tìm kiếm

            Button(action: {
                NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: file.path.deletingLastPathComponent().path)
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(IconButtonStyle(size: 26))
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(isHovering ? Color.white.opacity(0.025) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
