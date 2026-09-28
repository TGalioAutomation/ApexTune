import SwiftUI
import AppKit

// MARK: - Legacy Components Support
// These components are used by MonitorView and potentially other parts of the app, 
// originally defined in SmartCleanerView.swift but moved here during redesign.

struct ResultCategoryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    var valueSecondary: String? = nil
    let hasDetails: Bool
    let onDetailTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // biểu tượng bên trái

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }
            
            // văn bản ở giữa

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Giá trị bên phải

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if let secondary = valueSecondary {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // Nút xem chi tiết

            if hasDetails {
                Button(action: onDetailTap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isHovering ? .white : .secondaryText)
                        .padding(8)
                        .background(isHovering ? Color.white.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            } else {
                // Định vị, giữ thẳng hàng

                Color.clear.frame(width: 30, height: 30)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

struct CleaningTaskRow: View {
    let icon: String
    let color: Color
    let title: String
    enum Status { case waiting, processing, completed }
    let status: Status
    let fileSize: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            if let size = fileSize {
                Text(size)
                    .foregroundColor(.secondaryText)
                    .font(.body)
                    .frame(width: 90, alignment: .trailing)
            }
            
            ZStack {
                switch status {
                case .waiting:
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondaryText)
                case .processing:
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                case .completed:
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }
}

// MARK: - All Categories Detail Sheet (Original Three-Column Design)

struct AllCategoriesDetailSheet: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var isPresented: Bool
    var initialCategory: CleanerCategory?
    
    @State private var selectedMainCategory: MainCategory? = nil
    @State private var selectedSubcategory: CleanerCategory? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // thanh trên cùng

            HStack {
                Button(action: {
                    // Kích hoạt cập nhật thủ công trước khi đóng để đảm bảo giao diện chính hiển thị kích thước tệp được chọn mới nhất

                    service.objectWillChange.send()
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text(L("Quay lại"))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(L("Chi tiết dọn dẹp"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for balance
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Back") }
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // bố cục ba cột

            threeColumnLayout
        }
        .frame(width: 1024, height: 680)
        .background(BackgroundStyles.smartScanSheet)
        .onAppear {
            // Lựa chọn mặc định thông minh

            if selectedMainCategory == nil {
                selectedMainCategory = .systemJunk
                if let firstSubcat = MainCategory.systemJunk.subcategories.first {
                    selectedSubcategory = firstSubcat
                }
            }
            
            // Xử lý phân loại ban đầu

            if let initial = initialCategory {
                if initial == .systemJunk {
                    selectedMainCategory = .systemJunk
                } else if MainCategory.systemJunk.subcategories.contains(initial) {
                    selectedMainCategory = .systemJunk
                    selectedSubcategory = initial
                } else {
                    // Tìm danh mục chính mà nó thuộc về

                    for mainCat in MainCategory.allCases {
                        if mainCat.subcategories.contains(initial) {
                            selectedMainCategory = mainCat
                            selectedSubcategory = initial
                            break
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Giao diện chính của bố cục ba cột

    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            // Cột bên trái: Danh sách danh mục chính

            MainCategoryListView(
                service: service,
                loc: loc,
                selectedMainCategory: $selectedMainCategory
            )
            .onChange(of: selectedMainCategory) { newValue in
                // Khi chọn danh mục chính mới, tự động chọn danh mục phụ đầu tiên

                if let mainCat = newValue {
                    selectedSubcategory = mainCat.subcategories.first
                }
            }
            
            Divider()
                .frame(width: 1)
                .background(Color.white.opacity(0.1))
            
            // Cột giữa: danh sách danh mục con

            if let mainCat = selectedMainCategory {
                SubCategoryListView(
                    mainCategory: mainCat,
                    service: service,
                    loc: loc,
                    selectedSubcategory: $selectedSubcategory
                )
                
                Divider()
                    .frame(width: 1)
                    .background(Color.white.opacity(0.1))
                
                // Cột bên phải: Danh sách chi tiết file

                if let subcat = selectedSubcategory {
                    if subcat == .startupItems {
                        startupItemsRightPane
                    } else if subcat == .virus {
                        virusRightPane
                    } else if subcat == .performanceApps {
                        performanceAppsRightPane
                    } else if subcat == .appUpdates {
                        appUpdatesRightPane
                    } else {
                        fileDetailPane(for: subcat)
                    }
                } else {
                    emptyStateView
                }
            } else {
                emptyStateView
            }
        }
    }
    
    // Chế độ xem trạng thái trống

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.left")
                .font(.system(size: 48))
                .foregroundColor(.secondaryText.opacity(0.5))
            Text(L("Chọn một danh mục"))
                .font(.title3)
                .foregroundColor(.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    //Bảng chi tiết tập tin

    private func fileDetailPane(for category: CleanerCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // khu vực tiêu đề

            HStack {
                Text(L(category.rawValue))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Chọn tất cả, bỏ chọn tất cả và sắp xếp

                HStack(spacing: 12) {
                    Button(action: {
                        service.toggleCategorySelection(category, forceTo: true)
                    }) {
                        Text(L("Chọn tất cả"))
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        service.toggleCategorySelection(category, forceTo: false)
                    }) {
                        Text(L("Bỏ chọn tất cả"))
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    
                    Text(L("Sắp xếp theo kích thước ▼"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // danh sách tập tin

            ScrollView {
                LazyVStack(spacing: 0) {
                    if category == .userCache {
                        // Xử lý đặc biệt: hiển thị theo nhóm ứng dụng

                        ForEach(service.appCacheGroups) { group in
                            AppCacheGroupRow(group: group, service: service, onToggleFile: { file in
                                service.toggleFileSelection(file: file, in: .userCache)
                            })
                            Divider().background(Color.white.opacity(0.05))
                        }
                        
                        // Các thư mục khác

                        let orphanFiles = filesFor(category: .userCache).filter { file in
                            !service.appCacheGroups.flatMap { $0.files }.contains { $0.url == file.url }
                        }
                        
                        if !orphanFiles.isEmpty {
                            ForEach(orphanFiles.sorted { $0.size > $1.size }, id: \.url) { file in
                                FileItemRow(file: file, showPath: true, service: service, category: .userCache) {
                                    service.toggleFileSelection(file: file, in: .userCache)
                                }
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    } else {
                        // Hiển thị danh sách chung

                        ForEach(filesFor(category: category).sorted { $0.size > $1.size }, id: \.url) { file in
                            FileItemRow(file: file, showPath: true, service: service, category: category) {
                                service.toggleFileSelection(file: file, in: category)
                            }
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // Bảng danh sách tập tin ở bên phải

    private func rightPaneFileList(for category: CleanerCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // tiêu đề

            VStack(alignment: .leading, spacing: 4) {
                Text(L(category.rawValue))
                    .font(.system(size: 18, weight: .bold)) // Reduced from Title
                    .foregroundColor(.white)
                
                let files = filesFor(category: category)
                Text(String(format: L("%d mục, %@"), files.count, ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file)))
                    .font(.system(size: 12)) // Reduced from subheadline
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            // danh sách tập tin

            ScrollView {
                LazyVStack(spacing: 0) { // Removed spacing
                    ForEach(filesFor(category: category).sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: true, service: service, category: category) {
                            service.toggleFileSelection(file: file, in: category)
                        }
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // Lấy danh sách file tương ứng với danh mục

    private func filesFor(category: CleanerCategory) -> [CleanerFileItem] {
        switch category {
        case .userCache: return service.userCacheFiles
        case .systemCache: return service.systemCacheFiles
        case .oldUpdates: return service.oldUpdateFiles
        case .systemLogs: return service.systemLogFiles
        case .userLogs: return service.userLogFiles
        case .duplicates: return service.duplicateGroups.flatMap { $0.files }
        case .similarPhotos: return service.similarPhotoGroups.flatMap { $0.files }
        case .largeFiles: return service.largeFiles
        case .localizations: return service.localizationFiles
        default: return []
        }
    }
    
    // MARK: - Virus đe dọa bảng bên phải

    private var virusRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Mối đe dọa vi-rút"))
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(service.virusThreats.isEmpty ? 
                     L("Không phát hiện thấy mối đe dọa nào") :
                     String(format: L("%d mối đe dọa được tìm thấy"), service.virusThreats.count))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(service.virusThreats.isEmpty ? .green : .red)
            }
            .padding()
            
            if service.virusThreats.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text(L("Hệ thống của bạn an toàn"))
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.virusThreats, id: \.id) { threat in
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(threat.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(threat.path.path)
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(L(threat.type.rawValue))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Bên phải mục khởi động

    private var startupItemsRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Mục khởi động"))
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(String(format: L("%d các mục bắt đầu tự động"), service.startupItems.count))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.startupItems, id: \.id) { item in
                        HStack(spacing: 12) {
                            // hộp đánh dấu

                            // hộp đánh dấu

                            TriStateCheckbox(state: item.isSelected ? .all : .none) {
                                item.isSelected.toggle()
                                service.objectWillChange.send()
                            }
                            .frame(width: 20, height: 20)
                            
                            Image(systemName: "power")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text(item.url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(item.isEnabled ? L("Đã bật") : L("Tàn tật"))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(item.isEnabled ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                                .foregroundColor(item.isEnabled ? .orange : .gray)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tối ưu hóa hiệu suất bảng bên phải

    private var performanceAppsRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Hiệu suất"))
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(String(format: L("%d ứng dụng tiêu tốn tài nguyên"), service.performanceApps.count))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.performanceApps) { app in
                        HStack(spacing: 12) {
                            // hộp đánh dấu

                            // hộp đánh dấu

                            TriStateCheckbox(state: app.isSelected ? .all : .none) {
                                app.isSelected.toggle()
                                service.objectWillChange.send()
                            }
                            .frame(width: 20, height: 20)
                            
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text(app.app.bundleIdentifier ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.orange)
                                Text(app.formattedMemory)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Áp dụng cập nhật bảng bên phải

    private var appUpdatesRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Cập nhật ứng dụng"))
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(service.hasAppUpdates ? 
                     L("Cập nhật có sẵn") :
                     L("Tất cả các ứng dụng được cập nhật"))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(service.hasAppUpdates ? .blue : .green)
            }
            .padding()
            
            VStack {
                Spacer()
                Image(systemName: service.hasAppUpdates ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(service.hasAppUpdates ? .blue : .green)
                Text(service.hasAppUpdates ? 
                     L("Bấm vào nút cập nhật để kiểm tra") :
                     L("Không cần cập nhật"))
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.top)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hàng tệp tin, hỗ trợ đi sâu vào thư mục

struct FileItemRow: View {
    let file: CleanerFileItem
    let showPath: Bool
    @ObservedObject var service: SmartCleanerService
    var category: CleanerCategory = .userCache
    var onToggle: (() -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    @State private var subItems: [CleanerFileItem] = []
    @State private var isLoading: Bool = false
    @State private var isHovering: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // Thuộc tính tính toán xác định khi nào hàng hiện trạng thái chọn một phần

    private var selectionState: SmartCleanerService.SelectionState {
        // Nếu đó là một thư mục và đã tải khóa con

        if file.isDirectory && !subItems.isEmpty {
            let selectedCount = subItems.filter { $0.isSelected }.count
            if selectedCount == 0 { return .none }
            if selectedCount == subItems.count { return .all }
            return .partial
        }
        // Mặc định quay trở lại trạng thái đã chọn của một tệp

        return file.isSelected ? .all : .none
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Hộp kiểm (ba trạng thái)

                TriStateCheckbox(state: selectionState) {
                    toggleSelection()
                }
                .frame(width: 18, height: 18)
                .padding(.trailing, 4)
                
                Image(nsImage: file.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(file.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if file.isDirectory {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    if showPath {
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.system(size: 10))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(file.formattedSize)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                // (Đã loại bỏ các nút hành động di chuột: Xem & Xóa)

                /*
                if isHovering {
                    HStack(spacing: 6) { ... }
                }
                */
                
                if file.isDirectory {
                    Button(action: {
                        toggleExpand()
                    }) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle()) // Full area clickable
            .onHover { isHovering = $0 }
            // Tap on row content (except arrow) toggles selection
            .onTapGesture {
                toggleSelection()
            }
            .confirmationDialog(
                L("Xác nhận Xóa"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(
                    L("Xóa bỏ"),
                    role: .destructive
                ) {
                    deleteSingleFile()
                }
                Button(
                    L("Hủy bỏ"),
                    role: .cancel
                ) {}
            } message: {
                let fileName = file.name
                Text(String(format: L("Bạn có chắc muốn xóa \"%@\" không? Thao tác này không thể hoàn tác."), fileName))
            }
            .contextMenu {
                // Chỉ hiển thị "Bỏ chọn" khi được chọn

                if file.isSelected {
                    Button {
                        onToggle?()
                    } label: {
                        let fileName = file.name
                        Label(
                            String(format: L("Bỏ chọn \"%@\""), fileName),
                            systemImage: "checkmark.circle"
                        )
                    }
                    
                    Divider()
                }
                
                // Hiển thị trong Trình tìm kiếm

                Button {
                    openInFinder()
                } label: {
                    Label(
                        L("Hiện trong Finder"),
                        systemImage: "folder"
                    )
                }
                
                // xem nhanh

                Button {
                    quickLookFile()
                } label: {
                    let fileName = file.name
                    Label(
                        String(format: L("Xem nhanh \"%@\""), fileName),
                        systemImage: "eye"
                    )
                }
                
                Divider()
                
                // sao nhãng

                Button {
                    // TODO: Thực hiện chức năng bỏ qua

                    print("Bỏ qua: \(file.name)")
                } label: {
                    Label(
                        L("Bỏ qua"),
                        systemImage: "eye.slash"
                    )
                }
            }
            
            // Mở rộng trẻ em

            if isExpanded && !subItems.isEmpty {
                VStack(spacing: 2) {
                    ForEach(subItems, id: \.url) { subFile in
                        FileItemRow(file: subFile, showPath: false, service: service, category: category) {
                            service.toggleFileSelection(file: subFile, in: category)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // Logic lựa chọn chuyển đổi: cập nhật đệ quy các Mục con và Dịch vụ cục bộ

    private func toggleSelection() {
        let newState = selectionState == .all ? false : true
        
        if file.isDirectory && !subItems.isEmpty {
             for i in subItems.indices {
                 if subItems[i].isSelected != newState {
                     // Update Service for Child
                     service.toggleFileSelection(file: subItems[i], in: category)
                     // Update Local
                     subItems[i].isSelected = newState
                 }
             }
        } else {
             onToggle?()
        }
    }
    
    private func toggleExpand() {
        if isExpanded {
            isExpanded = false
        } else {
            if subItems.isEmpty {
                isLoading = true
                Task {
                    let items = await service.loadSubItems(for: file)
                    await MainActor.run {
                        subItems = items
                        isLoading = false
                        withAnimation { isExpanded = true }
                    }
                }
            } else {
                withAnimation { isExpanded = true }
            }
        }
    }
    
    private func openInFinder() {
        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
    }
    
    private func deleteSingleFile() {
        Task {
            let success = await service.deleteSingleFile(file, from: category)
            if !success {
                print("Xóa tệp thất bại: \(file.url.path)")
            }
        }
    }
    
    private func quickLookFile() {
        // Dùng NSWorkspace để mở Quick Look

        NSWorkspace.shared.open([file.url], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), configuration: NSWorkspace.OpenConfiguration())
    }
}

// MARK: - Áp dụng các dòng nhóm bộ đệm

struct AppCacheGroupRow: View {
    @ObservedObject var group: AppCacheGroup
    @ObservedObject var service: SmartCleanerService
    let onToggleFile: (CleanerFileItem) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Hàng chính: thông tin ứng dụng

            HStack(spacing: 8) { // Compact spacing 12->8
                // Hộp kiểm (tương tác độc lập)

                TriStateCheckbox(state: selectionState) {
                    service.toggleAppGroupSelection(group)
                }
                .frame(width: 18, height: 18) // Smaller 20->18
                
                // khu vực nội dung

                HStack(spacing: 8) { // Compact spacing 12->8
                    Image(nsImage: group.icon)
                        .resizable()
                        .frame(width: 24, height: 24) // Smaller 32->24
                    
                    VStack(alignment: .leading, spacing: 1) { // Compact spacing
                        Text(group.appName)
                            .font(.system(size: 13, weight: .semibold)) // Smaller 14->13
                            .foregroundColor(.white)
                        
                        Text("\(group.files.count) " + (group.files.count == 1 ? "location" : "locations"))
                            .font(.caption2) // Smaller
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Số lượng đã chọn

                    Text("\(selectedCount)/\(group.files.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                    
                    // Chọn kích thước

                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .font(.system(size: 12, weight: .medium)) // Smaller 13->12
                        .foregroundColor(.white)
                    
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11)) // Smaller 12->11
                            .foregroundColor(.secondaryText)
                            .frame(width: 16, height: 16) // Smaller 24->16
                            .contentShape(Rectangle())
                    }
                }
                // Tap on content area toggles group selection
                .contentShape(Rectangle())
                .onTapGesture {
                    service.toggleAppGroupSelection(group)
                }
            }
            .padding(.vertical, 4) // Compact vertical padding
            
            // Mở rộng nội dung: các thư mục con cụ thể

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(group.files.sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: false, service: service, category: .userCache) {
                            service.toggleFileSelection(file: file, in: .userCache)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var selectionState: SmartCleanerService.SelectionState {
        let selectedCount = group.files.filter { $0.isSelected }.count
        if selectedCount == 0 { return .none }
        if selectedCount == group.files.count { return .all }
        return .partial
    }
    
    private var selectedSize: Int64 {
        group.files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    private var selectedCount: Int {
        group.files.filter { $0.isSelected }.count
    }
}

// ĐÁNH DẤU: - Các hàng danh mục có thể nhấp vào (có chi tiết)

struct DrillDownCategoryRow: View {
    let icon: String
    let title: String
    let size: Int64
    let count: Int
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    if count > 0 {
                        Text("\(count) " + (count == 1 ? "file" : "files"))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
                    .font(.system(size: 14))
                
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 12) // Slightly more padding for main rows
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

struct DetailSidebarRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(isSelected ? .white : .secondaryText)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.8) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
//
//  ThreeColumnUIComponents.swift
//  Thành phần giao diện người dùng bố cục ba cột mới

//
//  Created for Smart Scan Detail View Redesign
//

import SwiftUI

// MARK: - Hàng danh mục chính (cột bên trái)
