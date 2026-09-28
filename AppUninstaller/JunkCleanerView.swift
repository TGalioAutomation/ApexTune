import SwiftUI
import AVFoundation
import Quartz

struct JunkCleanerView: View {
    // Quét trạng thái enum

    enum ScanState {
        case initial    // Trang đầu tiên
        case scanning   // Đang quét
        case cleaning   // Dọn dẹp
        case completed  // Quét hoàn tất (trang kết quả)
        case finished   // Việc dọn dẹp đã hoàn tất (trang cuối cùng)
    }

    // Sử dụng trình quản lý dịch vụ dùng chung

    @ObservedObject private var cleaner = ScanServiceManager.shared.junkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    // View State
    @State private var showingDetails = false // Kiểm soát hiển thị trang chi tiết
    @State private var selectedCategory: JunkType? // danh mục đã chọn
    @State private var searchText = ""
    @State private var showingCleanAlert = false
    @State private var cleanedAmount: Int64 = 0
    @State private var failedFiles: [String] = []
    @State private var showRetryWithAdmin = false
    @State private var cleanResult: (cleaned: Int64, failed: Int64, requiresAdmin: Bool)?
    @State private var showCleaningFinished = false
    @State private var wasScanning = false // Theo dõi thay đổi trạng thái quét
    
    // Animation State
    @State private var pulse = false
    @State private var animateScan = false
    @State private var isAnimating = false
    
    // Trạng thái quét - được tính toán động dựa trên trạng thái sạch hơn bằng cách sử dụng các thuộc tính được tính toán

    private var scanState: ScanState {
        if cleaner.isScanning {
            return .scanning
        } else if cleaner.isCleaning {
            return .cleaning
        } else if showRetryWithAdmin {
            return .cleaning
        } else if showCleaningFinished {
            return .finished
        } else if hasScanResults {
            return .completed
        }
        return .initial
    }
    
    // Thuộc tính được tính toán: Kiểm tra xem kết quả quét đã tồn tại chưa

    private var hasScanResults: Bool {
        return cleaner.totalSize > 0 || !cleaner.junkItems.isEmpty
    }
    
    // Tham chiếu trình phát âm thanh tĩnh để ngăn phát hành sớm

    private static var soundPlayer: NSSound?
    
    // Phát âm thanh hoàn tất quá trình quét

    private func playScanCompleteSound() {
        if let soundURL = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") {
            // Dừng phát lại trước đó

            JunkCleanerView.soundPlayer?.stop()
            // Tạo trình phát mới và giữ lại tham chiếu

            JunkCleanerView.soundPlayer = NSSound(contentsOf: soundURL, byReference: false)
            JunkCleanerView.soundPlayer?.play()
        }
    }
    
    var body: some View {
        ZStack {
            switch scanState {
            case .initial:
                initialPage
            case .scanning:
                scanningPage
            case .completed:
                if showingDetails {
                    detailPage
                } else {
                    summaryPage
                }
            case .cleaning:
                cleaningPage.padding(.bottom, 100)
            case .finished:
                finishedPage
            }
        }
        .overlay(
            // Fixed Bottom Action Button Overlay
            VStack {
                Spacer()
                if scanState != .cleaning {
                    mainActionButton
                        .padding(.bottom, 40)
                }
            }
        )
        .alert(L("Một số tệp yêu cầu đặc quyền quản trị viên"), isPresented: $showRetryWithAdmin) {
            Button(L("Xóa với quản trị viên"), role: .destructive) {
                 showCleaningFinished = true
            }
            Button(loc.L("cancel"), role: .cancel) {
                showCleaningFinished = true
            }
        } message: {
            Text(L("Không thể xóa một số tệp do không đủ quyền."))
        }
        // Giám sát quá trình quét hoàn tất và phát âm thanh nhắc nhở

        .onReceive(cleaner.$isScanning) { isScanning in
            if wasScanning && !isScanning && hasScanResults {
                // Quá trình quét thay đổi từ đang tiến hành sang hoàn tất và một âm báo sẽ phát ra

                playScanCompleteSound()
            }
            wasScanning = isScanning
        }
    }
    
    // MARK: - Main Action Button (Unified)
    @ViewBuilder
    private var mainActionButton: some View {
        switch scanState {
        case .initial:
            Button(action: { startScan() }) {
                ZStack {
                    // 1. Soft Glow
                    Circle()
                        .fill(Color(hex: "5E5CE6").opacity(0.4))
                        .frame(width: 50, height: 50)
                        .blur(radius: 10)
                    
                    // 2. Main Button
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "7D7AFF"), Color(hex: "5E5CE6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                    
                    // 3. Border
                    Circle()
                        .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        .frame(width: 50, height: 50)
                    
                    Text(L("Quét"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: 60, height: 60)
                .background(
                     Circle()
                        .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                )
            }
            .buttonStyle(.plain)
            
        case .scanning:
            HStack(spacing: 20) {
                 Button(action: { cleaner.stopScanning() }) {
                    ZStack {
                        // Progress/Ring Background
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        // Progress Ring (Determinate)
                        Circle()
                            .trim(from: 0, to: max(0.01, cleaner.scanProgress))
                            .stroke(
                                AngularGradient(gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.1)]), center: .center),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(Angle(degrees: -90))
                            .animation(.linear(duration: 0.2), value: cleaner.scanProgress)
                        
                        // Inner Button
                        Circle()
                            .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 48, height: 48)
                        
                        Text(L("Dừng lại"))
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // Real-time Size
                Text(ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file))
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            
        case .completed:
            // Summary or Detail or Finished
            if showCleaningFinished {
                // Finished State - "Review Remaining"
                 Button(action: { 
                    showCleaningFinished = false
                    showingDetails = true
                }) {
                    Text(L("Ôn tập")) // Shortened
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                // Summary or Detail - Clean Button
                HStack(spacing: 16) {
                     Button(action: { startCleaning() }) {
                         ZStack {
                             // Glow
                             Circle()
                                 .fill(Color(hex: "7D7AFF").opacity(0.4))
                                 .frame(width: 50, height: 50)
                                 .blur(radius: 10)
                             
                             // Fill
                             Circle()
                                 .fill(LinearGradient(colors: [Color(hex: "7D7AFF"), Color(hex: "5E5CE6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                 .frame(width: 50, height: 50)
                                 .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                             
                             // Border
                             Circle()
                                 .stroke(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                                 .frame(width: 50, height: 50)
                             
                             Text(L("Lau dọn"))
                                 .font(.system(size: 12, weight: .semibold, design: .rounded))
                                 .foregroundColor(.white)
                         }
                         .frame(width: 60, height: 60)
                     }
                     .buttonStyle(.plain)
                     
                     // Size Text (Only if details shown or needed)
                     if showingDetails {
                          Text(ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file))
                              .font(.system(size: 18, weight: .medium))
                              .foregroundColor(.white)
                     }
                }
            }
            
        case .finished:
             Button(action: { 
                showCleaningFinished = false
                showingDetails = true
            }) {
                Text(L("Ôn tập"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.white.opacity(0.2)))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            
        default:
            EmptyView()
        }
    }
    
    // ĐÁNH DẤU: - 1. Trang đầu tiên

    private var initialPage: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 60) {
                // Left Side: Text and Features
                VStack(alignment: .leading, spacing: 20) {
                    Text(L("Rác hệ thống"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(L("Dọn dẹp hệ thống của bạn để tối đa hóa hiệu suất và giải phóng không gian."))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    
                    Spacer().frame(height: 10)
                    
                    // Feature 1: Optimize System
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "chart.bar") // Icon resembling the waveform/chart
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Tối ưu hóa hệ thống"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(L("Xóa các tập tin tạm thời để giải phóng dung lượng, cải thiện hiệu suất máy Mac."))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Feature 2: Fix Errors
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "pill") // Icon resembling the pill
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Sửa tất cả các loại lỗi"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(L("Xóa các mục bị hỏng khác nhau có thể gây ra sự bất thường của ứng dụng."))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(width: 300)
                
                // Right Side: Large Pink Mouse Icon
                if let imagePath = Bundle.main.path(forResource: "system_clean_menu", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 380, height: 380)
                        .shadow(color: .pink.opacity(0.3), radius: 20, x: 0, y: 10)
                } else {
                    // Fallback
                    GlassyPurpleDisc(scale: 1.5)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
             .padding(.bottom, 60)
        }
    }

    // MARK: - 2. Quét trang

    private var scanningPage: some View {
        VStack {
            HStack {
                 Spacer()
                 Text(L("Rác hệ thống"))
                     .foregroundColor(.white.opacity(0.7))
                 Spacer()
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Center Image with Animation
            ZStack {
                if let imagePath = Bundle.main.path(forResource: "system_clean_menu", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 320)
                }
            }
            .padding(.bottom, 40)
            
            // Status Text
            Text(L("Hệ thống phân tích..."))
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(cleaner.currentScanningPath)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4)) // Grey path
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 60)
                .frame(height: 20)
            
            Text(cleaner.currentScanningCategory)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
            
            Spacer()
            
            Spacer()

        }
        .onAppear { isAnimating = true }
    }
    
    // MARK: - 3. Summary Page (Results)
    private var summaryPage: some View {
        VStack(spacing: 0) {
            // Navbar
            HStack {
                Button(action: { cleaner.reset(); showCleaningFinished = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("Bắt đầu lại"))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("Rác hệ thống"))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                // Assistant Pill
                Button(action: { /* Help */ }) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "40C4FF")).frame(width: 6, height: 6)
                        Text(L("Trợ lý"))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            HStack(spacing: 80) {
                // Left: Image
                if let imagePath = Bundle.main.path(forResource: "system_clean_menu", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 380, height: 380)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                }
                
                // Bên phải: Văn bản kết quả - Hiển thị động các danh mục đã chọn

                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Quét hoàn tất"))
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file))
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(Color(hex: "40C4FF"))
                        
                        Text(L("Đã chọn"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Hiển thị động danh sách danh mục đã chọn

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Bao gồm"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Nhận danh mục đã chọn

                        ForEach(selectedCategories, id: \.self) { category in
                            HStack(spacing: 6) {
                                Text("•")
                                Text(L(category.rawValue))
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    HStack(spacing: 30) {
                        Button(action: { withAnimation { showingDetails = true } }) {
                            Text(L("Xem chi tiết"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Text(String(format: L("Đã tìm thấy %@"), ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file)))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
        }
    }
    
    /// Lấy danh sách danh mục đã chọn (thứ tự giảm dần theo kích thước)

    private var selectedCategories: [JunkType] {
        let selectedItems = cleaner.junkItems.filter { $0.isSelected }
        let categorySizes: [JunkType: Int64] = Dictionary(grouping: selectedItems, by: { $0.type })
            .mapValues { items in items.reduce(0) { $0 + $1.size } }
        return categorySizes.keys.sorted { categorySizes[$0] ?? 0 > categorySizes[$1] ?? 0 }
    }
    
    // ... Detail/Cleaning/Finished Pages (Unchanged for now) ...
    
    // MARK: - 4. Detail Page
    private var detailPage: some View {
        VStack(spacing: 0) {
            // Navbar
            HStack {
                Button(action: {
                    withAnimation {
                        showingDetails = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("Quay lại"))
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(L("Rác hệ thống"))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack {
                     Image(systemName: "magnifyingglass").foregroundColor(.secondaryText)
                     TextField(L("Tìm kiếm"), text: $searchText)
                         .textFieldStyle(.plain)
                         .frame(width: 100)
                }
                .padding(6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider().background(Color.white.opacity(0.1))
            
            HSplitView {
                JunkSidebarView(selectedCategory: $selectedCategory, cleaner: cleaner)
                JunkDetailContentView(selectedCategory: selectedCategory, cleaner: cleaner)
            }
            
            // Bottom Clean Button Overlay (Removed)
        }
        .onAppear {
            if selectedCategory == nil, let first = cleaner.junkItems.first {
                selectedCategory = first.type
            }
        }
    }
    
    private var cleaningPage: some View {
        ZStack {
            // nội dung chính

            VStack(spacing: 0) {
                // Thanh điều hướng trên cùng - giữ chỗ, duy trì chiều cao của thanh điều hướng

                HStack {
                    Spacer()
                    Text(L("Rác hệ thống"))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // khu vực nội dung chính

                HStack(alignment: .top, spacing: 60) {
                    // Bên trái: biểu tượng lớn

                    VStack {
                        if let imagePath = Bundle.main.path(forResource: "system_clean_menu", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 300, height: 300) // Bật nó lên một chút
                                .shadow(color: .black.opacity(0.3), radius: 25, y: 15)
                                .rotationEffect(.degrees(cleaningRotation))
                                .onAppear {
                                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                                        cleaningRotation = 360
                                    }
                                }
                                .onDisappear {
                                    cleaningRotation = 0
                                }
                        }
                    }
                    .frame(width: 360, height: 360) // Kích thước thùng cố định
                    
                    // Bên phải: tiêu đề + danh sách danh mục

                    VStack(alignment: .leading, spacing: 0) {
                        // Tiêu đề - Thêm phần đệm trên cùng để làm cho nó chìm xuống, căn chỉnh gần bằng hoặc hơi thấp hơn phần trên cùng của hình ảnh bên trái

                        Text(L("Đang dọn hệ thống..."))
                            .font(.system(size: 26, weight: .semibold)) // Làm cho phông chữ lớn hơn và đậm hơn
                            .foregroundColor(.white)
                            .padding(.bottom, 32) // Tăng tiêu đề lên khoảng cách dưới cùng
                            .padding(.top, 40) // Điều chỉnh cốt lõi: chìm văn bản
                        
                        // Danh sách danh mục - Thêm khoảng cách

                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(cleaner.cleaningCategories, id: \.self) { category in
                                CleaningCategoryRow(
                                    category: category,
                                    status: cleaner.categoryCleaningStatus[category] ?? .pending,
                                    cleanedSize: cleaner.categoryCleanedSize[category] ?? 0,
                                    totalSize: getCategorySelectedSize(category)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: 450, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                // Di chuyển toàn bộ lên một chút để giữ trung tâm thị giác

                .offset(y: -40)
                
                Spacer()
            }
            
            // nút dừng phía dưới

            VStack {
                Spacer()
                Button(action: { 
                    // Dừng chức năng làm sạch

                }) {
                    ZStack {
                        // Độ dốc vòng ngoài - màu xanh lá cây

                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.green.opacity(0.8), .teal.opacity(0.8), .green.opacity(0.8)]),
                                    center: .center
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .green.opacity(0.3), radius: 10)
                        
                        // nền vòng tròn bên trong

                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 72, height: 72)
                        
                        Text(L("Dừng lại"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 50)
            }
        }
    }
    
    // Làm sạch góc xoay hoạt ảnh

    @State private var cleaningRotation: Double = 0
    
    /// Lấy tổng kích thước của các mục đã chọn trong một danh mục

    private func getCategorySelectedSize(_ category: JunkType) -> Int64 {
        cleaner.junkItems
            .filter { $0.type == category && $0.isSelected }
            .reduce(0) { $0 + $1.size }
    }
    
    private var finishedPage: some View {
        ZStack {
            // nội dung chính

            VStack(spacing: 0) {
                // thanh điều hướng trên cùng

                HStack {
                    Button(action: { cleaner.reset(); showCleaningFinished = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(L("Bắt đầu lại"))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(L("Rác hệ thống"))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    // Phần giữ chỗ cho nút Trợ lý

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "40C4FF")).frame(width: 6, height: 6)
                            Text(L("Trợ lý"))
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Khu vực nội dung chính - hình ảnh bên trái và văn bản bên phải

                HStack(spacing: 80) {
                    // Bên trái: biểu tượng lớn

                    if let imagePath = Bundle.main.path(forResource: "system_clean_menu", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 380, height: 380)
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    }
                    
                    // Phải: Thông tin kết quả làm sạch

                    VStack(alignment: .leading, spacing: 16) {
                        Text(L("Dọn dẹp hoàn tất"))
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Kích thước sạch + biểu tượng kiểm tra

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            
                            Text(ByteCountFormatter.string(fromByteCount: cleanResult?.cleaned ?? cleanedAmount, countStyle: .file))
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(Color(hex: "40C4FF"))
                            
                            Text(L("Đã dọn sạch"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Thông tin dung lượng còn lại của đĩa

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: L("Bạn đã lấy lại %@ trên ổ khởi động."), ByteCountFormatter.string(fromByteCount: cleanedAmount, countStyle: .file)))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(L("Kiểm tra các mục còn lại để phục hồi thêm dung lượng."))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 8)
                        
                        }
                    }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            
            // Dưới cùng bên trái - xem nhật ký

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        // Mở nhật ký xóa

                        let logPath = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Library/Application Support/MacOptimizer/deletion_log.json")
                        NSWorkspace.shared.activateFileViewerSelecting([logPath])
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                            Text(L("Xem nhật ký"))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.yellow.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 24)
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            // Cập nhật dung lượng ổ đĩa sau khi dọn dẹp xong

            DiskSpaceManager.shared.updateDiskSpace()
        }
    }

    func startScan() {
        // scanState sẽ tự động trở thành .scanning thông qua clean.isScanning

        Task {
            await cleaner.scanJunk()
        }
    }
    
    func startCleaning() {
        // scanState sẽ tự động trở thành .cleaning thông qua Cleaner.isCleaning

        Task {
            cleaner.isCleaning = true
            // Sử dụng phương pháp làm sạch theo từng loại để làm sạch từng cái một theo yêu cầu của bản vẽ thiết kế.

            let result = await cleaner.cleanSelectedByCategory()
            cleanResult = (result.cleaned, result.failed, result.requiresAdmin)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0,5 giây
            cleaner.isCleaning = false
            showCleaningFinished = true
        }
    }
}

// MARK: - Extracted Subviews for Detail Page

struct JunkSidebarView: View {
    @Binding var selectedCategory: JunkType?
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    let allSelected = cleaner.junkItems.allSatisfy { $0.isSelected }
                    cleaner.junkItems.forEach { $0.isSelected = !allSelected }
                    cleaner.objectWillChange.send()
                }) {
                    Text(cleaner.junkItems.allSatisfy { $0.isSelected } ? (L("Bỏ chọn tất cả")) : (L("Chọn tất cả")))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(L("Sắp xếp theo kích thước"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    Image(systemName: "chevron.down")
                         .font(.system(size: 10))
                         .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cleaner.junkItems.map { $0.type }.removingDuplicates(), id: \.self) { type in
                        JunkCategoryRow(type: type, 
                                    // Vượt qua trạng thái đã chọn để có thể đánh dấu yếu hoặc không có gì cả

                                    // isSelected được giữ lại ở đây để có thể thêm các chỉ báo tối giản trong tương lai, nhưng hiện tại, nền mạnh đã bị xóa bên trong Hàng

                                    isSelected: selectedCategory == type,
                                    cleaner: cleaner)
                            .background(
                                // Thêm nền rất sáng cho danh mục hiện được chọn, tương tự như hiệu ứng Di chuột ở bên phải, để đảm bảo người dùng biết họ đang xem danh mục nào

                                // Nếu người dùng không muốn xem nền chút nào thì có thể đổi sang Color.clear nhưng mình khuyên bạn nên để lại một chút gợi ý

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedCategory == type ? Color.white.opacity(0.1) : Color.clear)
                                    .padding(.horizontal, 4)
                            )
                            .onTapGesture {
                                selectedCategory = type
                            }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minWidth: 280)
        }
        .background(Color.black.opacity(0.1)) // More transparent dark sidebar
    }
}

struct JunkDetailContentView: View {
    let selectedCategory: JunkType?
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let type = selectedCategory {
                let items = cleaner.junkItems.filter { $0.type == type }
                
                // Content Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L(type.rawValue))
                        .font(.system(size: 24, weight: .bold)) // Larger Title
                        .foregroundColor(.white)
                    
                    Text(type.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8)) // Brighter description
                        .lineSpacing(4)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 24)
                
                // Sort by Size (Right Aligned)
                 HStack {
                     Spacer()
                     Text(L("Sắp xếp theo kích thước"))
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.6))
                     Image(systemName: "triangle.fill")
                         .font(.system(size: 6))
                         .rotationEffect(.degrees(180))
                         .foregroundColor(.white.opacity(0.6))
                 }
                 .padding(.horizontal, 30)
                 .padding(.bottom, 10)
                
                // Items List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            JunkItemRow(item: item)
                        }
                    }
                    .padding(.bottom, 100) // Space for floating button
                }
            } else {
                // Empty State
                Spacer()
                Text(L("Chọn danh mục để xem chi tiết"))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        }
        .frame(minWidth: 460)
         // Ensure standard background is transparent so global background shows through
        .background(Color.clear) 
    }
}


// Helper for Array duplicate removal
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

// Category Row View
struct JunkCategoryRow: View {
    let type: JunkType
    let isSelected: Bool
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isHovering: Bool = false
    
    // Nhận các mục từ trình dọn dẹp trong thời gian thực (thay vì sử dụng ảnh chụp nhanh)

    private var items: [JunkItem] {
        cleaner.junkItems.filter { $0.type == type }
    }
    
    // Chỉ tính tổng dung lượng của các tệp đang được chọn

    var totalSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    // Kiểm tra trạng thái: chưa được chọn, được chọn một phần, đã chọn tất cả

    enum CheckState {
        case none      // Không được chọn
        case partial   // Đã chọn một phần
        case all       // Chọn tất cả
    }
    
    var checkState: CheckState {
        guard !items.isEmpty else { return .none }
        let selectedCount = items.filter { $0.isSelected }.count
        if selectedCount == 0 {
            return .none
        } else if selectedCount == items.count {
            return .all
        } else {
            return .partial
        }
    }
    
    var isChecked: Bool {
        !items.isEmpty && items.allSatisfy { $0.isSelected }
    }
    
    var categoryColor: Color {
        // Match specific colors from design if possible, otherwise use specific gradients
        switch type {
        case .unusedDiskImages: return Color(hex: "A0A0A0") // Grey/Silver
        case .universalBinaries: return Color(hex: "FF9F0A") // Orange
        case .userCache: return Color(hex: "FFB340") // Light Orange
        case .systemCache: return Color(hex: "5AC8FA") // Blue
        case .userLogs: return Color(hex: "8E8E93") // Grey
        case .systemLogs: return Color(hex: "8E8E93") // Grey
        case .brokenLoginItems: return .red
        case .oldUpdates: return .green
        case .iosBackups: return .cyan
        case .downloads: return Color(hex: "0A84FF") // Blue
        default: return .purple
        }
    }
    
    var body: some View {
        HStack {
            // Selection Pill Background
            HStack {
                 // Hộp đánh dấu - Sử dụng .onTapGesture để đảm bảo số nhấp chuột đáng tin cậy

                 ZStack {
                     Circle()
                         .stroke(checkState != .none ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                         .frame(width: 20, height: 20)
                     
                     if checkState == .all {
                         // Tất cả trạng thái đã chọn: hình tròn đã điền + dấu kiểm

                         Circle()
                            .fill(Color(hex: "40C4FF"))
                            .frame(width: 20, height: 20)
                         Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                     } else if checkState == .partial {
                         // Trạng thái đánh dấu một nửa: hình tròn đầy + dấu trừ

                         Circle()
                            .fill(Color(hex: "40C4FF"))
                            .frame(width: 20, height: 20)
                         Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                     }
                 }
                 .frame(width: 20, height: 20)
                 .contentShape(Rectangle())
                 .onTapGesture {
                     // Thực thi đồng bộ trên luồng chính để tránh các vấn đề về thời gian

                     Task { @MainActor in
                         let newState: Bool
                         if checkState == .all {
                             // Chọn tất cả -> Bỏ chọn tất cả

                             newState = false
                         } else {
                             // Không được chọn hoặc được chọn một phần -> Chọn tất cả

                             newState = true
                         }
                         items.forEach { $0.isSelected = newState }
                         cleaner.objectWillChange.send()
                     }
                 }
                 .padding(.leading, 12)
                
                // Icon
                ZStack {
                     // Colored Background Circle
                    Circle()
                        .fill(
                            LinearGradient(colors: [categoryColor, categoryColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(.leading, 8)
                
                Text(L(type.rawValue))
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .padding(.leading, 4)
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 13))
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        // Xóa màu nền đã chọn và chỉ giữ lại hiệu ứng di chuột

                        isHovering ? Color.white.opacity(0.08) : Color.clear
                    )
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            // Chọn tất cả

            Button {
                items.forEach { $0.isSelected = true }
                cleaner.objectWillChange.send()
            } label: {
                Label(
                    String(format: L("Chọn tất cả \"%@\""), type.rawValue),
                    systemImage: "checkmark.circle.fill"
                )
            }
            .disabled(checkState == .all)
            
            // Bỏ chọn tất cả

            Button {
                items.forEach { $0.isSelected = false }
                cleaner.objectWillChange.send()
            } label: {
                Label(
                    String(format: L("Bỏ chọn tất cả \"%@\""), type.rawValue),
                    systemImage: "circle"
                )
            }
            .disabled(checkState == .none)
        }
    }
}


// MARK: - Subviews
struct JunkItemRow: View {
    @ObservedObject var item: JunkItem
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Hộp kiểm - sử dụng các vùng nhấp chuột riêng biệt để tránh xung đột trạng thái

            ZStack {
                Circle()
                    .stroke(item.isSelected ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                
                if item.isSelected {
                    Circle()
                        .fill(Color(hex: "40C4FF"))
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .onTapGesture {
                // Thực thi đồng bộ trên luồng chính để tránh các vấn đề về thời gian

                Task { @MainActor in
                    item.isSelected.toggle()
                    ScanServiceManager.shared.junkCleaner.objectWillChange.send()
                }
            }
            
            // File Icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            
            // Name
            Text(item.name)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Size
            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            // Bỏ chọn/Chọn

            Button {
                item.isSelected.toggle()
                ScanServiceManager.shared.junkCleaner.objectWillChange.send()
            } label: {
                Label(
                    item.isSelected ? 
                        (String(format: L("Bỏ chọn \"%@\""), item.name)) :
                        (String(format: L("Chọn \"%@\""), item.name)),
                    systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                )
            }
            
            Divider()
            
            // Hiển thị trong Trình tìm kiếm

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            } label: {
                Label(
                    L("Hiển thị trong Finder"),
                    systemImage: "folder"
                )
            }
            
            // xem nhanh

            Button {
                quickLookFile()
            } label: {
                Label(
                    String(format: L("Xem nhanh \"%@\""), item.name),
                    systemImage: "eye"
                )
            }
        }
    }
    
    // Xem nhanh tập tin

    private func quickLookFile() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Helpers

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// Removed duplicate GradientStyles struct here. Using global one in Styles.swift

// MARK: - Glassy Purple Disc (Icon)
struct GlassyPurpleDisc: View {
    var scale: CGFloat = 1.0
    var rotation: Double = 0
    var isSpinning: Bool = false
    
    var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "BF5AF2").opacity(0.2), Color(hex: "5E5CE6").opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 260 * scale, height: 260 * scale)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            // Middle Glass Purple
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "AC44CF").opacity(0.8), Color(hex: "5E5CE6").opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 200 * scale, height: 200 * scale)
                .shadow(color: Color(hex: "BF5AF2").opacity(0.5), radius: 25, y: 10)
                .overlay(    
                    Circle().stroke(
                        LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), 
                        lineWidth: 1
                    )
                )
            
            // Inner Core
            Circle()
                .fill(LinearGradient(colors: [.white, Color(hex: "E0B0FF")], startPoint: .top, endPoint: .bottom))
                .frame(width: 80 * scale, height: 80 * scale)
                .shadow(color: .black.opacity(0.2), radius: 5)
            
            // Spinner Detail
            if isSpinning {
                 Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 140 * scale, height: 140 * scale)
                    .rotationEffect(.degrees(rotation))
            } else {
                 // Static Center (Broom or Trash Icon)
                 Image(systemName: "trash.fill")
                    .font(.system(size: 30 * scale))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "BF5AF2"), Color(hex: "5E5CE6")], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

// MARK: - Custom Checkbox Style
struct CircleCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            ZStack {
                Circle()
                    .stroke(configuration.isOn ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                
                if configuration.isOn {
                    Circle()
                        .fill(Color(hex: "40C4FF"))
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Universal Binary Warning Dialog
// UniversalBinaryWarningDialog đã bị xóa - Tính năng giảm béo nhị phân phổ quát bị vô hiệu hóa


// MARK: - Dọn dẹp các thành phần hàng danh mục

struct CleaningCategoryRow: View {
    let category: JunkType
    let status: JunkCleaner.CleaningStatus
    let cleanedSize: Int64
    let totalSize: Int64
    
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Biểu tượng danh mục - sử dụng nền hình chữ nhật bo tròn

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            // Tên danh mục

            Text(L(category.rawValue))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // chỉ báo trạng thái

            switch status {
            case .pending:
                // Đang chờ - Hiển thị nút dấu chấm lửng

                Button(action: {}) {
                    Text("•••")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
            case .cleaning:
                // Dọn dẹp - kích thước hiển thị và tải hình ảnh động

                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // đang tải hình ảnh động

                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
                
            case .completed:
                // Xong - Hiển thị biểu tượng kiểm tra

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var categoryColor: Color {
        switch category {
        case .downloads: return Color(hex: "5AC8FA")        // màu xanh da trời
        case .systemCache: return Color(hex: "5AC8FA")      // màu xanh da trời
        case .userLogs: return Color(hex: "8E8E93")         // xám
        case .systemLogs: return Color(hex: "8E8E93")       // xám
        case .userCache: return Color(hex: "FF9F0A")        // màu cam
        case .unusedDiskImages: return Color(hex: "A0A0A0") // bạc
        case .xcodeDerivedData: return Color(hex: "BF5AF2") // Màu tím
        case .browserCache: return Color(hex: "30D158")     // màu xanh lá
        case .chatCache: return Color(hex: "FF375F")        // màu đỏ
        case .crashReports: return Color(hex: "FF9F0A")     // màu cam
        default: return Color(hex: "8E8E93")                // Màu xám mặc định
        }
    }
}
