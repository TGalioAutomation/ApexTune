import SwiftUI

// MARK: - Deep Clean States
enum DeepCleanState {
    case initial
    case scanning
    case results
    case cleaning
    case finished
}

struct DeepCleanView: View {
    @Binding var selectedModule: AppModule
    @ObservedObject private var scanner = ScanServiceManager.shared.deepCleanScanner
    @State private var viewState: DeepCleanState = .initial
    @State private var showingDetails = false
    @State private var selectedCategoryForDetails: DeepCleanCategory?
    @ObservedObject private var loc = LocalizationManager.shared
    
    // Alert States
    @State private var showCleanConfirmation = false
    @State private var cleanResult: (count: Int, size: Int64)?
    
    var body: some View {
        ZStack {
            VStack {
                 switch viewState {
                 case .initial:
                     initialView.padding(.bottom, 100)
                 case .scanning:
                     scanningView.padding(.bottom, 100)
                 case .results:
                     resultsView.padding(.bottom, 100)
                 case .cleaning:
                     cleaningView.padding(.bottom, 100)
                 case .finished:
                     finishedView.padding(.bottom, 100)
                 }
            }
            
            // Fixed Bottom Action Button Overlay
            VStack {
                Spacer()
                mainActionButton
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Sync state if already scanning
            if scanner.isScanning {
                viewState = .scanning
            } else if scanner.isCleaning {
                viewState = .cleaning
            } else if scanner.totalSize > 0 && viewState == .initial {
                 viewState = .results // Resume results if available
            }
        }
        .onChange(of: scanner.isScanning) { isScanning in
             if isScanning { viewState = .scanning }
             else if scanner.totalSize > 0 { viewState = .results }
        }
        .onChange(of: scanner.isCleaning) { newValue in
             if newValue {
                 viewState = .cleaning
             } else if viewState == .cleaning {
                 // Dọn dẹp xong, chuyển sang trang hoàn thành

                 viewState = .finished
             }
        }
        .sheet(isPresented: $showingDetails) {
            DeepCleanDetailView(scanner: scanner, category: selectedCategoryForDetails, isPresented: $showingDetails)
        }
        .confirmationDialog(loc.L("confirm_clean"), isPresented: $showCleanConfirmation) {
            Button(L("Bắt đầu làm sạch"), role: .destructive) {
                Task { @MainActor in
                    let result = await scanner.cleanSelected()
                    cleanResult = result
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(String(format: L("Bạn có chắc chắn muốn xóa các mục đã chọn không? Tổng dung lượng: %@"), ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file)))
        }
    }
    
    // MARK: - Main Action Button (Unified)
    @ViewBuilder
    private var mainActionButton: some View {
        switch viewState {
        case .initial:
            Button(action: {
                Task { await scanner.startScan() }
            }) {
                ZStack {
                    // 1. Soft Glow
                    Circle()
                        .fill(Color(hex: "0A84FF").opacity(0.4))
                        .frame(width: 50, height: 50)
                        .blur(radius: 10)
                    
                    // 2. Main Button
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "007AFF"), Color(hex: "0055D4")], startPoint: .top, endPoint: .bottom))
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
            .transition(.scale.combined(with: .opacity))
            
        case .scanning:
            HStack(spacing: 20) {
                Button(action: {
                    scanner.stopScan()
                    viewState = .initial
                }) {
                    ZStack {
                         // Outer
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        // Ring
                        Circle()
                            .trim(from: 0, to: max(0.01, scanner.scanProgress))
                            .stroke(
                                LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(Angle(degrees: -90))
                            .animation(.linear(duration: 0.2), value: scanner.scanProgress)
                        
                        // Inner
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Text(L("Dừng lại"))
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // Real-time Size
                Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            
        case .results:
            HStack(spacing: 20) {
                Button(action: {
                    if scanner.selectedCount > 0 {
                        showCleanConfirmation = true
                    }
                }) {
                    ZStack {
                        // Glow
                        Circle()
                           .fill(Color.green.opacity(0.4))
                           .frame(width: 50, height: 50)
                           .blur(radius: 10)
                        
                        // Button Body
                        Circle()
                           .fill(LinearGradient(colors: [Color(hex: "34C759"), Color(hex: "248A3D")], startPoint: .top, endPoint: .bottom))
                           .frame(width: 50, height: 50)
                           .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                        
                        // Border
                        Circle()
                           .stroke(Color.white.opacity(0.3), lineWidth: 1)
                           .frame(width: 50, height: 50)
                           
                        Text(L("Lau dọn"))
                           .font(.system(size: 12, weight: .semibold, design: .rounded))
                           .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                
                // Hiển thị kích thước (chỉ hiển thị số kích thước)

                if scanner.selectedCount > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "40C4FF"))
                }
            }
            
        case .finished:
            Button(action: {
                withAnimation {
                    viewState = .initial
                    scanner.reset()
                    cleanResult = nil
                }
            }) {
                Text(L("Xong"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 160, height: 50)
                    .background(Color.green)
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - 1. Xem lần đầu (trang khởi tạo)

    var initialView: some View {
        HStack(spacing: 60) {
            // Left Content
            VStack(alignment: .leading, spacing: 30) {
                // Branding Header
                HStack(spacing: 8) {
                    Text(L("Làm sạch hệ thống sâu"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Magnifying Glass Icon
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            Text(L("Quét toàn bộ"))
                            .font(.system(size: 20, weight: .heavy))
                    }
                    .foregroundColor(.white)
                }
                
                Text(L("Quét toàn bộ máy Mac của bạn để tìm các tệp lớn, rác, bộ nhớ đệm, nhật ký và phần còn sót lại.\nLần quét cuối cùng: Không bao giờ"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
                
                // Feature Rows
                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "doc.text.magnifyingglass",
                        title: L("Tìm tệp lớn"),
                        desc: L("Nhanh chóng xác định vị trí các tệp lớn và cũ đang chiếm dung lượng.")
                    )
                    
                    featureRow(
                        icon: "trash.circle",
                        title: L("Dọn dẹp hệ thống rác"),
                        desc: L("Xóa bộ nhớ đệm, nhật ký và tệp tạm thời để giải phóng dung lượng.")
                    )
                    
                    featureRow(
                        icon: "app.badge",
                        title: L("Phát hiện dư lượng ứng dụng"),
                        desc: L("Tìm các tập tin và dữ liệu bị bỏ lại bởi các ứng dụng đã gỡ cài đặt.")
                    )
                }
                
                // Configure Button (Cyan)
                Button(action: {}) {
                    Text(L("Định cấu hình tùy chọn quét..."))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4DDEE8")) // Cyan
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .frame(maxWidth: 400)
            
            // Right Icon - Using shenduqingli.png
            ZStack {
                if let path = Bundle.main.path(forResource: "shenduqingli", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 320)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                } else {
                    // Fallback
                    RoundedRectangle(cornerRadius: 40)
                        .fill(LinearGradient(
                            colors: [Color(hex: "00B4D8"), Color(hex: "0077B6")],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 280, height: 280)
                        .overlay(
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - 2. Chế độ xem quét (Quét trang - bố cục đầy đủ)

    var scanningView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Bố cục lưới thích ứng

            VStack(spacing: 20) {
                // Hàng 1: Tệp lớn, Rác hệ thống, Tệp nhật ký (đầy đủ)

                HStack(spacing: 20) {
                    scanningCategoryCard(for: .largeFiles)
                    scanningCategoryCard(for: .junkFiles)
                    scanningCategoryCard(for: .systemLogs)
                }
                
                // Hàng 2: Bộ nhớ đệm, phần dư (được che ở bên trái và bên phải)

                HStack(spacing: 20) {
                    scanningCategoryCard(for: .systemCaches)
                    scanningCategoryCard(for: .appResiduals)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
            
            // Current scanning path
            Text(scanner.currentScanningUrl)
                .font(.caption)
                .foregroundColor(.secondaryText.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .frame(height: 20)
        }
    }
    
    // MARK: - Thẻ quét (thẻ nền hình ảnh - chiều rộng thích ứng)

    func scanningCategoryCard(for category: DeepCleanCategory) -> some View {
        let isCompleted = scanner.completedCategories.contains(category)
        let isCurrent = scanner.currentCategory == category && scanner.isScanning && !isCompleted
        
        return ZStack(alignment: .topLeading) {
            // Hình ảnh làm nền cho toàn bộ thẻ

            GeometryReader { geometry in
                if let imageName = getCategoryImageName(category),
                   let nsImage = NSImage(named: imageName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 240)
                        .clipped()
                        .scaleEffect(isCurrent ? 1.05 : 1.0)
                        .animation(isCurrent ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isCurrent)
                } else {
                    // Dự phòng: Nền gradient

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCategoryGradientTop(category),
                                    getCategoryGradientBottom(category)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 240)
                        .overlay(
                            Image(systemName: getCategoryCustomIcon(category))
                                .font(.system(size: 80, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            
            // Mặt nạ chuyển màu dưới cùng (làm cho văn bản rõ ràng hơn)

            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 100)
            }
            
            // Dấu góc trên cùng bên trái (bản thiết kế tham khảo - hiển thị trên tất cả các thẻ)

            HStack(spacing: 8) {
                // Hiển thị dấu kiểm khi hoàn thành

                if isCompleted {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Tên danh mục (hiển thị trên tất cả các thẻ)

                Text(category.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            
            // Đường viền rung động khi quét

            if isCurrent {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(getCategoryGradientTop(category), lineWidth: 3)
                    .scaleEffect(1.05)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isCurrent)
            }
            
            // Thông tin văn bản dưới cùng (kiểu thống nhất)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    // Văn bản chính (kích thước tệp hoặc trạng thái)

                    if isCompleted {
                        // Chỉ đếm các mục đã chọn

                        let categoryItems = scanner.items.filter { $0.category == category && $0.isSelected }
                        let size = categoryItems.reduce(0) { $0 + $1.size }
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        let itemCount = categoryItems.count
                        Text(String(format: L("%d mục"), itemCount))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    } else if isCurrent {
                        Text(L("Đang quét..."))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // Hiển thị đường dẫn quét hiện tại

                        if !scanner.currentScanningUrl.isEmpty {
                            Text(scanner.currentScanningUrl)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    } else {
                        Text(L("Chờ..."))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - 3. Xem kết quả (quét trang kết quả - bố cục giống hệt như trang đang được quét)

    var resultsView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Lưới thẻ lớn (bố cục chính xác của trang đang được quét)

            VStack(spacing: 20) {
                // Hàng 1: Trải ba lá bài

                HStack(spacing: 20) {
                    resultCategoryCard(for: .largeFiles)
                    resultCategoryCard(for: .junkFiles)
                    resultCategoryCard(for: .systemLogs)
                }
                
                // Hàng 2: Hai lá bài trải xung quanh

                HStack(spacing: 20) {
                    resultCategoryCard(for: .systemCaches)
                    resultCategoryCard(for: .appResiduals)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
        }
    }
    
    // MARK: - Thẻ kết quả (giống hệt trang được scan)

    func resultCategoryCard(for category: DeepCleanCategory) -> some View {
        // Chỉ những mục đã chọn mới được tính, do đó số thẻ sẽ thay đổi khi người dùng bỏ chọn.

        let items = scanner.items.filter { $0.category == category && $0.isSelected }
        let totalSize = items.reduce(0) { $0 + $1.size }
        let isCompleted = !scanner.items.filter { $0.category == category }.isEmpty // Miễn là có các mục trong danh mục (dù được chọn hay không), trạng thái hoàn thành sẽ được hiển thị.
        
        return ZStack(alignment: .topLeading) {
                // Hình ảnh làm nền cho toàn bộ thẻ

                GeometryReader { geometry in
                    if let imageName = getCategoryImageName(category),
                       let nsImage = NSImage(named: imageName) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 240)
                            .clipped()
                    } else {
                        // Dự phòng: Nền gradient

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        getCategoryGradientTop(category),
                                        getCategoryGradientBottom(category)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: geometry.size.width, height: 240)
                            .overlay(
                                Image(systemName: getCategoryCustomIcon(category))
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                .allowsHitTesting(false) // Hãy để các nhấp chuột thâm nhập vào nút bên dưới
                
                // Mặt nạ gradient phía dưới (giống như khi quét)

                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 100)
                }
                .allowsHitTesting(false) // Hãy để các nhấp chuột thâm nhập vào nút bên dưới
                
                // Dấu góc trên bên trái (giống hệt như trong bản quét)

                HStack(spacing: 8) {
                    // Dấu kiểm (hiển thị trên tất cả các thẻ)

                    if isCompleted {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Tên danh mục

                    Text(category.localizedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .padding(.leading, 16)
                .padding(.top, 16)
                
                // Thông tin văn bản ở phía dưới (giống hệt như trong bản quét)

                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Text(String(format: L("%d mục"), items.count))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        // Nút "Xem chi tiết" ở góc dưới bên phải

                        Button(action: {
                            selectedCategoryForDetails = category
                            showingDetails = true
                        }) {
                            Text(L("Xem chi tiết"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 240)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    
    // MARK: - 4. Cleaning View (trang dọn dẹp tương tự như quét thông minh)

    var cleaningView: some View {
        VStack {
            Spacer().frame(height: 60)
            
            HStack(spacing: 80) {
                // Left: Current Category Image
                Group {
                    if let category = scanner.cleaningCurrentCategory {
                        let imageName = getCategoryImageName(category)
                        if let imageName = imageName,
                           let nsImage = NSImage(named: imageName) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 240, height: 240)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .id(category) // unique ID triggers transition
                                .modifier(CleaningLargeIconAnimation())
                        } else {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 120))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Fallback
                        ProgressView()
                            .scaleEffect(2.0)
                            .frame(width: 240, height: 240)
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: scanner.cleaningCurrentCategory)
                .frame(width: 300)
                
                // Right: Text & Task List
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Đang dọn hệ thống..."))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(L("Xóa các tệp không mong muốn và tối ưu hóa máy Mac của bạn."))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 16) {
                        // Chỉ hiển thị danh mục với các mục đã chọn (Chỉ hiển thị danh mục với các mục đã chọn)

                        let allCategories: [DeepCleanCategory] = [.junkFiles, .systemLogs, .systemCaches, .appResiduals, .largeFiles]
                        let categoriesToShow = allCategories.filter { cat in
                            scanner.items.contains { $0.category == cat && $0.isSelected }
                        }
                        
                        ForEach(categoriesToShow, id: \.self) { cat in
                            let isActive = scanner.cleaningCurrentCategory == cat
                            let isDone = scanner.cleanedCategories.contains(cat)
                            
                            HStack(spacing: 12) {
                                // Icon Circle
                                ZStack {
                                    Circle()
                                        .fill(getCategoryGradientTop(cat).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(getCategoryGradientTop(cat))
                                }
                                
                                Text(cat.localizedName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if isActive {
                                    Text(scanner.cleaningDescription)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 20, height: 20)
                                } else if isDone {
                                    Text(ByteCountFormatter.string(fromByteCount: scanner.sizeFor(category: cat), countStyle: .file))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("...")
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                            .frame(width: 340)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 500)
            
            Spacer()
        }
    }
    
    // MARK: - 5. Đã xem xong (tương tự như trang hoàn thành của quét thông minh)

    var finishedView: some View {
        VStack {
            Spacer().frame(height: 100)
            
            HStack(spacing: 60) {
                // Left: Hero Image
                if let imagePath = Bundle.main.path(forResource: "welcome", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500, height: 500)
                } else {
                    Image(systemName: "desktopcomputer")
                        .resizable()
                        .frame(width: 300, height: 300)
                        .foregroundColor(.pink)
                }
                
                // Right: Results
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Làm tốt!"))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text(L("Máy Mac của bạn đang ở trạng thái tốt."))
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 12) {
                        // 1. Deep Cleanup Result
                        DeepCleanResultRow(
                            icon: getCategoryImageName(.junkFiles) ?? "system_clean",
                            title: L("Làm sạch sâu"),
                            subtitle: L("Đã xóa tệp"),
                            stat: ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)
                        )
                        
                        // 2. Items Cleaned
                        if let result = cleanResult {
                            DeepCleanResultRow(
                                icon: "trash.fill",
                                title: L("Số mục đã dọn"),
                                subtitle: L("Đã dọn thành công"),
                                stat: String(format: L("%d mục"), result.count)
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 550)
            
            Spacer()

            Spacer()
        } // End VStack
        // Overlay removed (Moved to main ZStack)

    }
    
    // ĐÁNH DẤU: - chức năng trợ giúp

    private func getCategoryGradientTop(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "FF6B9D") // hồng
        case .junkFiles: return Color(hex: "FF5757") // màu đỏ
        case .systemLogs: return Color(hex: "5B9BD5") // màu xanh da trời
        case .systemCaches: return Color(hex: "70C1B3") // màu xanh da trời
        case .appResiduals: return Color(hex: "FFD93D") // màu vàng
        }
    }
    
    private func getCategoryGradientBottom(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "C23B8C") // Hồng đậm
        case .junkFiles: return Color(hex: "B80F0A") // màu đỏ đậm
        case .systemLogs: return Color(hex: "2E5C8A") // xanh đậm
        case .systemCaches: return Color(hex: "29A39B") // màu xanh đậm
        case .appResiduals: return Color(hex: "F77F00") // màu cam
        }
    }
    
    private func getCategoryCustomIcon(_ category: DeepCleanCategory) -> String {
        switch category {
        case .largeFiles: return "doc.fill"
        case .junkFiles: return "trash.fill"
        case .systemLogs: return "doc.text.fill"
        case .systemCaches: return "server.rack"
        case .appResiduals: return "app.badge"
        }
    }
    
    private func getCategoryImageName(_ category: DeepCleanCategory) -> String? {
        switch category {
        case .largeFiles: return "deepclean_large_files"
        case .junkFiles: return "deepclean_system_junk"
        case .systemLogs: return "deepclean_log_files"
        case .systemCaches: return "deepclean_cache_files"
        case .appResiduals: return "deepclean_app_residue"
        }
    }
}

// MARK: - Xem chi tiết (trang chi tiết - giữ nguyên phần thực hiện trước đó)

struct DeepCleanDetailView: View {
    @ObservedObject var scanner: DeepCleanScanner
    var category: DeepCleanCategory?
    @Binding var isPresented: Bool
    @State private var selectedCategory: DeepCleanCategory?
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            leftSidebar
                .frame(width: 280)
            
            // Right Content
            if let category = selectedCategory {
                rightPane(for: category)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondaryText.opacity(0.5))
                    Text(L("Chọn danh mục để xem chi tiết"))
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 900, height: 650)
        .background(BackgroundStyles.deepClean)
        .onAppear {
            if let initial = category {
                selectedCategory = initial
            } else if selectedCategory == nil {
                selectedCategory = DeepCleanCategory.allCases.first
            }
        }
    }
    
    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L("Quay lại Tổng quan"))
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: selectAllItems) {
                        Text(L("Chọn tất cả"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "40C4FF"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.05))
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(DeepCleanCategory.allCases, id: \.self) { cat in
                        categorySidebarRow(cat)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 280)
        .background(Color.black.opacity(0.2))
    }
    
    private func categorySidebarRow(_ category: DeepCleanCategory) -> some View {
        let items = scanner.items.filter { $0.category == category }
        // Sửa đổi: Chỉ đếm kích thước của các mục đã chọn

        let totalSize = items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let isSelected = selectedCategory == category
        
        // Tính toán trạng thái kiểm tra

        let selectedCount = items.filter { $0.isSelected }.count
        let checkState: SelectionState = {
            if items.isEmpty || selectedCount == 0 { return .none }
            if selectedCount == items.count { return .all }
            return .partial
        }()
        
        return Button(action: {
            selectedCategory = category
        }) {
            HStack(spacing: 10) {
                // Hộp kiểm ba trạng thái (Nhỏ gọn)

                ZStack {
                    Circle()
                        .stroke(checkState != .none ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if checkState == .all {
                        Circle()
                            .fill(Color(hex: "40C4FF"))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else if checkState == .partial {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 18, height: 18)
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { @MainActor in
                        scanner.toggleCategorySelection(category, to: checkState != .all)
                    }
                }
                
                // Biểu tượng nhỏ (gọn nhẹ)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCategoryGradientTop(category).opacity(0.3),
                                    getCategoryGradientBottom(category).opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(getCategoryGradientTop(category))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.localizedName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 3) {
                        // Sửa đổi: Hiển thị số lượng mục đã chọn

                        Text("\(selectedCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                        
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText.opacity(0.5))
                        
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "40C4FF"))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Kiểm tra liệt kê trạng thái

    private enum SelectionState {
        case none, partial, all
    }
    
    // MARK: - Right Pane
    private func rightPane(for category: DeepCleanCategory) -> some View {
        let items = scanner.items.filter { $0.category == category }
        
        return VStack(spacing: 0) {
            // Tiêu đề (nhỏ gọn)

            VStack(alignment: .leading, spacing: 6) {
                Text(category.localizedName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // Sửa đổi: Chỉ đếm kích thước và số lượng của các mục đã chọn

                let selectedItems = items.filter { $0.isSelected }
                let totalSize = selectedItems.reduce(0) { $0 + $1.size }
                Text(String(format: L("%d mục đã chọn, %@"), selectedItems.count, ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            
            // Items List
            if items.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text(L("Không có mục nào trong danh mục này"))
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            DeepCleanItemRow(item: item, scanner: scanner)
                            
                            if item.id != items.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func selectAllItems() {
        guard let category = selectedCategory else { return }
        scanner.toggleCategorySelection(category, to: true)
    }
    
    // Chức năng trợ giúp

    private func getCategoryGradientTop(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "FF6B9D")
        case .junkFiles: return Color(hex: "FF5757")
        case .systemLogs: return Color(hex: "5B9BD5")
        case .systemCaches: return Color(hex: "70C1B3")
        case .appResiduals: return Color(hex: "FFD93D")
        }
    }
    
    private func getCategoryGradientBottom(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "C23B8C")
        case .junkFiles: return Color(hex: "B80F0A")
        case .systemLogs: return Color(hex: "2E5C8A")
        case .systemCaches: return Color(hex: "29A39B")
        case .appResiduals: return Color(hex: "F77F00")
        }
    }
}

// MARK: - Hàng Mục (rút gọn)

struct DeepCleanItemRow: View {
    let item: DeepCleanItem
    @ObservedObject var scanner: DeepCleanScanner
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Hộp kiểm (nhỏ gọn)

            ZStack {
                Circle()
                    .stroke(item.isSelected ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                
                if item.isSelected {
                    Circle()
                        .fill(Color(hex: "40C4FF"))
                        .frame(width: 16, height: 16)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task { @MainActor in
                    scanner.toggleSelection(for: item)
                }
            }
            
            // Biểu tượng (nhỏ hơn)

            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue.opacity(0.8))
                .frame(width: 20)
            
            // Tên & Đường dẫn (phông chữ nhỏ gọn)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.url.path)
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Kích thước (nhỏ hơn)

            Text(item.formattedSize)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "40C4FF"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Deep Clean Result Row (làm sạch hàng kết quả)

struct DeepCleanResultRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let stat: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            if let nsImage = NSImage(named: icon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                // Fallback SF Symbol
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
            
            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Stat
            Text(stat)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "40C4FF"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .frame(width: 400)
    }
}
