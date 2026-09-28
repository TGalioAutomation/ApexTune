import SwiftUI

struct LargeFileDetailsSplitView: View {
    @ObservedObject var scanner: LargeFileScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: String = "All"
    @State private var searchText = ""
    @State private var sortOption: SortOption = .size
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showDeleteSuccess = false
    @State private var successMessage = ""
    
    enum SortOption {
        case size, name, date
    }
    
    // Categories matching the design
    private let categories = [
        "All", 
        "Archives", "Documents", "Movies", "Music", "Pictures", "Others", // Type based
        "Huge", "Medium", "Small", // Size based
        "One Month Ago", "One Week Ago", "One Year Ago" // Date based
    ]
    
    // Filter logic helper
    private func filterFiles(for category: String) -> [FileItem] {
        let files = scanner.foundFiles
        switch category {
        case "All": return files
        case "Movies": return files.filter { ["mp4", "mov", "avi", "mkv", "m4v"].contains($0.type.lowercased()) }
        case "Archives": return files.filter { ["zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg"].contains($0.type.lowercased()) }
        case "Music": return files.filter { ["mp3", "wav", "aac", "flac", "m4a"].contains($0.type.lowercased()) }
        case "Pictures": return files.filter { ["jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "svg"].contains($0.type.lowercased()) }
        case "Documents": return files.filter { ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md"].contains($0.type.lowercased()) }
        case "Others":
            let knownTypes = ["mp4", "mov", "avi", "mkv", "m4v", "zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg", "mp3", "wav", "aac", "flac", "m4a", "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "svg", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md"]
            return files.filter { !knownTypes.contains($0.type.lowercased()) }
            
        case "Huge": return files.filter { $0.size > 1024 * 1024 * 1024 } // > 1GB
        case "Medium": return files.filter { $0.size >= 500 * 1024 * 1024 && $0.size <= 1024 * 1024 * 1024 } // 500MB - 1GB
        case "Small": return files.filter { $0.size >= 50 * 1024 * 1024 && $0.size < 500 * 1024 * 1024 } // 50MB - 500MB
            
        case "One Month Ago":
            let date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
        case "One Week Ago":
            let date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
        case "One Year Ago":
            let date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
            
        default: return files
        }
    }

    var filteredFiles: [FileItem] {
        let baseFiles = filterFiles(for: selectedCategory)
        
        let files = baseFiles.filter { file in
            if searchText.isEmpty { return true }
            return file.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sorting
        return files.sorted {
            switch sortOption {
            case .size: return $0.size > $1.size
            case .name: return $0.name < $1.name
            case .date: return $0.accessDate > $1.accessDate
            }
        }
    }
    
    // Calculate total size for a category
    private func sizeForCategory(_ category: String) -> String {
        let files = filterFiles(for: category)
        let total = files.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    

    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                // Return button area
                HStack {
                    Button(action: {
                        withAnimation {
                            scanner.reset()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(L("Quay lại"))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(16)
                
                // Sidebar List
                ScrollView {
                    VStack(spacing: 2) {
                        groupHeader("All Files")
                        categoryRow(title: "All", isSelected: selectedCategory == "All")
                            .onTapGesture { selectedCategory = "All" }
                        
                        groupHeader("Type")
                        ForEach(["Archives", "Others"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        // Only show non-empty categories or main ones? User screenshot has limited list.
                        // I will add the others but maybe conditionally hide empty ones later if requested.
                        // For now showing specific requested ones + standard ones ensuring coverage.
                        ForEach(["Documents", "Movies", "Music", "Pictures"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        
                        groupHeader("Size")
                        ForEach(["Huge", "Medium", "Small"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        
                        groupHeader("Date")
                        ForEach(["One Week Ago", "One Month Ago", "One Year Ago"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 200)
            .background(Color.white.opacity(0.05))
            
            // Content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(categoryTitle(selectedCategory))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        Button(L("Kích thước")) { sortOption = .size }
                        Button(L("Tên")) { sortOption = .name }
                        Button(L("Ngày")) { sortOption = .date }
                    } label: {
                        HStack(spacing: 4) {
                            Text(L("Sắp xếp theo"))
                            Text(sortOptionString)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondaryText)
                        TextField(L("Tìm kiếm"), text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .frame(width: 200)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                
                // File List
                List {
                    ForEach(filteredFiles) { file in
                        LargeFileItemRow(file: file, isSelected: scanner.selectedFiles.contains(file.id)) {
                            if scanner.selectedFiles.contains(file.id) {
                                scanner.selectedFiles.remove(file.id)
                            } else {
                                scanner.selectedFiles.insert(file.id)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                // Bottom Bar
                HStack(spacing: 20) {
                    Spacer()
                    
                    // Left side: Immediate Remove options
                    Menu {
                        Button(loc.L("selectAll")) {
                            scanner.selectedFiles = Set(filteredFiles.map { $0.id })
                        }
                        Button(L("Bỏ chọn tất cả")) {
                            scanner.selectedFiles.removeAll()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(L("Xóa ngay lập tức"))
                            Image(systemName: "chevron.up")
                        }
                        .foregroundColor(.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Center: Circular Action Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(scanner.selectedFiles.isEmpty ? Color.gray.opacity(0.3) : Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(spacing: 4) {
                                Text(L("Di dời"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text(ByteCountFormatter.string(fromByteCount: scanner.totalSelectedSize, countStyle: .file))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.selectedFiles.isEmpty)
                    .alert(L("Xác nhận xóa"), isPresented: $showDeleteConfirmation) {
                        Button(L("Hủy bỏ"), role: .cancel) { }
                        Button(L("Xóa bỏ"), role: .destructive) {
                            Task {
                                let result = await scanner.deleteItems(scanner.selectedFiles)
                                if result.isSuccessful {
                                    successMessage = String(format: L("Đã xóa tệp %d, giải phóng %@"), result.successCount, ByteCountFormatter.string(fromByteCount: result.recoveredSize, countStyle: .file))
                                    showDeleteSuccess = true
                                } else {
                                    let failedList = result.failedFiles.prefix(5).joined(separator: "\n")
                                    let moreCount = result.failedFiles.count > 5 ? "\n..." + String(format: L("và %d tệp khác bị lỗi"), result.failedFiles.count - 5) : ""
                                    deleteErrorMessage = String(format: L("Không xóa được tệp %d:\n%s%s"), result.failedCount, failedList, moreCount)
                                    showDeleteError = true
                                }
                            }
                        }
                    } message: {
                        Text(String(format: L("Bạn có chắc chắn muốn xóa các tập tin %d không?"), scanner.selectedFiles.count))
                    }
                    
                    // Right Side: Hidden balancer
                    Menu { } label: {
                        HStack(spacing: 4) {
                            Text(L("Xóa ngay lập tức"))
                            Image(systemName: "chevron.up") 
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .opacity(0)
                    .disabled(true)
                    
                    Spacer()
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .alert(L("Xóa không thành công"), isPresented: $showDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteErrorMessage)
        }
        .alert(L("Xóa thành công"), isPresented: $showDeleteSuccess) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
    }
    
    private var sortOptionString: String {
        switch sortOption {
        case .size: return L("Kích cỡ")
        case .name: return L("Tên")
        case .date: return L("Ngày")
        }
    }
    
    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(categoryLocalized(title))
                .font(.caption)
                .foregroundColor(.tertiaryText)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    private func categoryRow(title: String, isSelected: Bool) -> some View {
        HStack {
            // Circle Checkbox style indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 14, height: 14)
                if isSelected {
                    Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                }
            }
            
            Text(categoryLocalized(title))
                .foregroundColor(.white)
                .font(.system(size: 13))
            
            Spacer()
            
            // Show Size
            Text(sizeForCategory(title))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    private func categoryLocalized(_ title: String) -> String {
        switch title {
        case "All Files": return L("Tất cả tệp")
        case "Type": return L("Theo loại")
        case "Size": return L("Theo kích thước")
        case "Date": return L("Theo ngày truy cập")

        case "All": return L("Tất cả")
        case "Movies": return L("Video")
        case "Archives": return L("Lưu trữ")
        case "Music": return L("Nhạc")
        case "Pictures": return L("Hình ảnh")
        case "Documents": return L("Tài liệu")
        case "Others": return L("Khác")
        case "Huge": return L("Rất lớn")
        case "Small": return L("Nhỏ")
        case "Medium": return L("Trung bình")
        case "One Year Ago": return L("Một năm trước")
        case "One Month Ago": return L("Một tháng trước")
        case "One Week Ago": return L("Một tuần trước")
        default: return title
        }
    }
    
    private func categoryTitle(_ title: String) -> String {
        return categoryLocalized(title)
    }
}

struct LargeFileItemRow: View {
    let file: FileItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
            
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(file.url.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(file.formattedSize)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                onToggle()
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
