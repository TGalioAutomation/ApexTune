import SwiftUI

struct TrashDetailsSplitView: View {
    @ObservedObject var scanner: TrashScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: String = "trash_on_mac" // Default selection
    @State private var searchText = ""
    @State private var showCleanConfirmation = false
    
    // Dữ liệu được phân loại mô phỏng, theo thiết kế chỉ có "thùng rác trên mac"

    private let categories = ["trash_on_mac"]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // khu vực nội dung chính

            HStack(spacing: 0) {
                // thanh bên trái

                VStack(spacing: 0) {
                    // khu vực nút quay lại trên cùng

                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
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
                    
                    // Chọn/bỏ chọn tất cả tiêu đề

                    HStack {
                        Button(action: {
                            let allSelected = scanner.items.allSatisfy { $0.isSelected }
                            scanner.toggleAllSelection(!allSelected)
                        }) {
                            Text(scanner.items.allSatisfy { $0.isSelected } ?
                                 (L("Bỏ chọn tất cả")) :
                                 (L("Chọn tất cả")))
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Text(L("Sắp xếp theo kích thước"))
                            Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    
                    // Danh sách danh mục

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(categories, id: \.self) { category in
                                categoryRow(title: L("Thùng rác trên máy Mac"), size: scanner.formattedSelectedSize, isSelected: selectedCategory == category)
                                    .onTapGesture {
                                        selectedCategory = category
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .frame(width: 340) // mở rộng sang trái
                .background(Color.clear)
                
                // Danh sách tập tin ở bên phải

                VStack(spacing: 0) {
                    // Thanh công cụ trên cùng (tìm kiếm, v.v.)

                    HStack {
                        Spacer()
                        
                        Text(L("Thùng rác"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading, 40) // Balance
                        
                        Spacer()
                        
                        // hộp tìm kiếm

                        HStack {
                            Image(systemName: "magnifyingglass")
                            // ...
                            .foregroundColor(.white.opacity(0.6))
                            TextField(L("Tìm kiếm"), text: $searchText)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(6)
                        .frame(width: 200)
                        
                        // Nút trợ lý

                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.white).frame(width: 6, height: 6)
                                Text(L("Trợ lý"))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    
                    // Khu vực tiêu đề danh sách

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Thùng rác trên máy Mac"))
                            .font(.system(size: 28, weight: .bold)) // Large Title
                            .foregroundColor(.white)
                        
                        Text(L("Thùng rác hệ thống vẫn giữ các mục đã xóa và tiếp tục chiếm dung lượng."))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // cột sắp xếp

                    HStack {
                        Spacer()
                        Text(L("Sắp xếp theo kích thước"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 6))
                            .rotationEffect(.degrees(180))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    // danh sách tập tin

                    List {
                        ForEach(scanner.items) { item in
                             TrashDetailRow(item: item, scanner: scanner)
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    // Để trống phần dưới cùng cho các nút nổi

                    Spacer().frame(height: 100)
                }
            }
            
            // Nút làm sạch đáy (trung tâm toàn cầu)

            HStack(spacing: 16) {
                ZStack {
                     // Glow
                     Circle()
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    
                    Button(action: {
                        if scanner.selectedSize > 0 {
                            showCleanConfirmation = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(scanner.selectedSize > 0 ? Color.white.opacity(0.25) : Color.white.opacity(0.1)) // Tàn tật
                                .frame(width: 70, height: 70)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                            
                            VStack(spacing: 2) {
                                Text(L("Dọn sạch"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(scanner.selectedSize > 0 ? .white : .white.opacity(0.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.selectedSize == 0)
                }
                
                // Size next to it
                Text(scanner.formattedSelectedSize)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 30)
        }
        .confirmationDialog(loc.L("empty_trash"), isPresented: $showCleanConfirmation) {
            Button(loc.L("empty_trash"), role: .destructive) {
                Task {
                   _ = await scanner.emptyTrash()
                   presentationMode.wrappedValue.dismiss()
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(L("Điều này không thể hoàn tác được."))
        }
    }
    
    private func categoryRow(title: String, size: String, isSelected: Bool) -> some View {
        HStack {
            // Custom Checkbox
            ZStack {
                Circle()
                    .fill(Color(hex: "007AFF")) // Blue fill
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Icon Background
            ZStack {
                // Trash icon looks like a folder with items or just trash can
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"), // Use trash icon for category
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                     Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)
            
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            Text(size)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.15) : Color.clear) // Rounded pill selection
        .cornerRadius(6)
    }
}

struct TrashDetailRow: View {
    let item: TrashItem
    @ObservedObject var scanner: TrashScanner
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox (Interactive)
            Button(action: {
                scanner.toggleSelection(item)
            }) {
                ZStack {
                    Circle()
                        .stroke(item.isSelected ? Color(hex: "007AFF") : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if item.isSelected {
                        Circle()
                            .fill(Color(hex: "007AFF"))
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Folder Icon (Blue)
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "5AC8FA")) 
            
            Text(item.name)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            scanner.toggleSelection(item)
        }
    }
}
