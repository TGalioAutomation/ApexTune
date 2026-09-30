import SwiftUI

// Quét trạng thái enum

enum ScanState {
    case initial    // Trang đầu tiên
    case scanning   // Đang quét
    case cleaning   // Dọn dẹp
    case completed  // Quét hoàn tất (trang kết quả)
    case finished   // Việc dọn dẹp đã hoàn tất (trang cuối cùng)
}

struct SmartCleanerView: View {
    // Liên kết điều hướng - được sử dụng để chuyển sang các trang khác

    @Binding var selectedModule: AppModule
    
    // Sử dụng trình quản lý dịch vụ dùng chung

    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedCategory: CleanerCategory = .systemJunk
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showResult = false
    @State private var showCleaningFinished = false
    @State private var showRunningAppsSafetyAlert = false
    
    // Thử lại với quyền quản trị viên

    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    
    // Running Apps Dialog
    @State private var showRunningAppsDialog = false
    @State private var detectedRunningApps: [(name: String, icon: NSImage?, bundleId: String)] = []
    
    @State private var viewingLog = false
    @State private var showScanningTips = false
    @State private var showFailedFilesPopover = false
    @State private var failedFilesClipboardContent: String = ""
    @EnvironmentObject private var aiModelManager: AIModelManager
    
    // Detail Sheet State
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // Trạng thái quét

    private var scanState: ScanState {
        if service.isScanning {
            return .scanning
        } else if service.isCleaning {
            // cleaningPage UI is simpler, we can reuse simplified scanning layout or keeping it
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
    
    // Thuộc tính được tính toán: Kiểm tra xem dịch vụ đã có kết quả quét chưa

    private var hasScanResults: Bool {
        return service.systemJunkTotalSize > 0 ||
               !service.duplicateGroups.isEmpty ||
               !service.similarPhotoGroups.isEmpty ||
               !service.largeFiles.isEmpty ||
               !service.userCacheFiles.isEmpty ||
               !service.systemCacheFiles.isEmpty ||
               !service.virusThreats.isEmpty ||
               service.hasAppUpdates ||
               !service.startupItems.isEmpty //||
               // ⚠️ Tạm thời bị vô hiệu hóa: !service.performanceApps.isEmpty

    }

    // Tính tổng kích thước được quét

    private var totalScannedSize: Int64 {
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .largeFiles, .virus
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
            // Nền - Màu chàm gradient để phù hợp với thiết kế

            BackgroundStyles.smartClean
                .ignoresSafeArea()
            
            // Main Content Area (With top padding for header)
            VStack {
                 // Spacer to account for fixed header + padding
                 Spacer().frame(height: 60)
                 
                 // Dynamic Content
                 if viewingLog {
                     cleaningLogPage
                         .transition(.opacity)
                 } else {
                     switch scanState {
                     case .initial:
                         initialPage
                     case .scanning:
                         scanningPage
                     case .completed:
                         resultsPage
                     case .cleaning:
                         cleaningPage
                     case .finished:
                         cleaningFinishedPage
                     }
                 }
            }
            .padding(.bottom, 100) // Increase padding to avoid button overlap

            // Fixed Header Overlay
            VStack {
                headerView
                Spacer()
            }
            .allowsHitTesting(true) // Ensure buttons in header are clickable

            // Floating Main Action Button
            VStack {
                Spacer()
                mainActionButton
                    .padding(.bottom, 40) // Standardized padding
            }
            
            if showRunningAppsDialog {
                runningAppsOverlay
            }
        }
        // Sheet for details
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
        // Alerts & Confirmations ... (Keeping existing logic)
        .confirmationDialog(
            L("Xác nhận Xóa"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(L("Bắt đầu làm sạch"), role: .destructive) {
                Task {
                    let result = await service.cleanAll()
                    deleteResult = (result.success, result.failed, result.size)
                    failedFiles = result.failedFiles
                    if result.failed > 0 && !failedFiles.isEmpty {
                        showRetryWithAdmin = true
                    } else {
                        showCleaningFinished = true
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(L("Làm sạch tất cả các tệp đã chọn để giải phóng dung lượng."))
        }
        .alert(L("Một số tệp yêu cầu đặc quyền quản trị viên"), isPresented: $showRetryWithAdmin) {
             Button(L("Xóa với quản trị viên"), role: .destructive) {
                 Task {
                     let adminResult = await service.cleanWithPrivileges(files: failedFiles)
                     if let currentResult = deleteResult {
                         deleteResult = (
                             currentResult.success + adminResult.success,
                             adminResult.failed,
                             currentResult.size + adminResult.size
                         )
                     }
                     failedFiles = []
                     showCleaningFinished = true
                 }
             }
             Button(loc.L("cancel"), role: .cancel) { showCleaningFinished = true }
        } message: {

            Text(L("Không thể xóa một số tệp do thiếu quyền truy cập."))
        }
        }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
            // Center Title
            Text(L("Quét thông minh"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            // Left Action
            HStack {
                if viewingLog || scanState == .completed || scanState == .finished {
                    Button(action: { 
                        if viewingLog {
                            withAnimation { viewingLog = false }
                        }
                        Task { service.resetAll() } 
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("Bắt đầu lại"))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
    
    // MARK: - Initial Page (Ready State)
    private var initialPage: some View {
        GeometryReader { geometry in
            let compactHeight = geometry.size.height < 640
            let compactWidth = geometry.size.width < 920
            let heroSize = min(
                compactHeight ? 220 : 320,
                max(180, geometry.size.width * (compactWidth ? 0.22 : 0.28))
            )

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: compactHeight ? 16 : 22) {
                    Spacer(minLength: compactHeight ? 4 : 12)

                    ZStack {
                        if let imagePath = Bundle.main.path(forResource: "welcome", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: heroSize, height: heroSize)
                                .shadow(color: Color.pink.opacity(0.2), radius: 20, x: 0, y: 8)
                        } else {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: heroSize * 0.78, height: heroSize * 0.78)
                                .shadow(color: Color.pink.opacity(0.2), radius: 20, x: 0, y: 8)
                        }
                    }

                    VStack(spacing: compactHeight ? 8 : 12) {
                        Text(L("Chào mừng đến với ApexTune"))
                            .font(.system(size: compactHeight ? 31 : 40, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(L("Bắt đầu quét toàn diện để kiểm tra và dọn máy Mac của bạn."))
                            .font(.system(size: compactHeight ? 14 : 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    quickStorageEntryPoints(compactLayout: compactHeight || compactWidth)
                        .padding(.top, compactHeight ? 8 : 16)

                    Spacer(minLength: compactHeight ? 0 : 8)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                .padding(.horizontal, compactWidth ? 24 : 36)
                .padding(.bottom, compactHeight ? 128 : 150)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func quickStorageEntryPoints(compactLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Text(L("Mục chiếm dung lượng lớn"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(L("Đi thẳng vào nơi thường làm đầy ổ đĩa nhanh nhất."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.58))
            }

            Group {
                if compactLayout {
                    VStack(spacing: 12) {
                        storageEntryCard(
                            icon: "brain.head.profile",
                            title: L("Mô hình AI"),
                            value: aiModelsSummaryValue,
                            subtitle: aiModelsSummarySubtitle,
                            gradient: GradientStyles.aiModels,
                            actionTitle: L("Quản lý model"),
                            compactLayout: true
                        ) {
                            selectedModule = .aiModels
                        }

                        storageEntryCard(
                            icon: "circle.hexagongrid.fill",
                            title: L("Bản đồ dung lượng"),
                            value: L("Quét trực quan"),
                            subtitle: L("Xem thư mục và tệp nào đang chiếm ổ đĩa nhiều nhất."),
                            gradient: GradientStyles.spaceLens,
                            actionTitle: L("Mở bản đồ"),
                            compactLayout: true
                        ) {
                            selectedModule = .spaceLens
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        storageEntryCard(
                            icon: "brain.head.profile",
                            title: L("Mô hình AI"),
                            value: aiModelsSummaryValue,
                            subtitle: aiModelsSummarySubtitle,
                            gradient: GradientStyles.aiModels,
                            actionTitle: L("Quản lý model"),
                            compactLayout: false
                        ) {
                            selectedModule = .aiModels
                        }

                        storageEntryCard(
                            icon: "circle.hexagongrid.fill",
                            title: L("Bản đồ dung lượng"),
                            value: L("Quét trực quan"),
                            subtitle: L("Xem thư mục và tệp nào đang chiếm ổ đĩa nhiều nhất."),
                            gradient: GradientStyles.spaceLens,
                            actionTitle: L("Mở bản đồ"),
                            compactLayout: false
                        ) {
                            selectedModule = .spaceLens
                        }
                    }
                }
            }
        }
        .frame(maxWidth: compactLayout ? 560 : 760)
    }

    private var aiModelsSummaryValue: String {
        let total = aiModelManager.totalManagedSize
        if total > 0 {
            return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
        return L("Chưa phát hiện")
    }

    private var aiModelsSummarySubtitle: String {
        let detectedProviders = aiModelManager.providerStates.values.filter(\.isDetected)
        if detectedProviders.isEmpty {
            return L("Tự kiểm tra Ollama và LM Studio để biết có model local nào đang chiếm chỗ không.")
        }

        let providerNames = detectedProviders.map(\.provider.rawValue).joined(separator: " + ")
        return String(format: L("Đã phát hiện %@. Mở để xem model nào nặng nhất và xóa nhanh."), providerNames)
    }

    private func storageEntryCard(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
        gradient: LinearGradient,
        actionTitle: String,
        compactLayout: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: compactLayout ? 48 : 56, height: compactLayout ? 48 : 56)

                Image(systemName: icon)
                    .font(.system(size: compactLayout ? 20 : 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: compactLayout ? 16 : 18, weight: .bold))
                    .foregroundColor(.white)

                Text(value)
                    .font(.system(size: compactLayout ? 20 : 24, weight: .bold))
                    .foregroundStyle(gradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.system(size: compactLayout ? 11 : 12))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compactLayout ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Scanning Page (3-Column Layout)
    private var scanningPage: some View {
        VStack {
            // Title & Subtitle for Scanning - Added per user request
            VStack(spacing: 12) {
                Text(L("Đang quét hệ thống..."))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                
                Text(L("Quá trình này chỉ mất ít phút. Vui lòng chờ trong giây lát."))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            threeColumnLayout(state: .scanning)
            
            Spacer()
        }
        .frame(height: 500) // Fixed height to prevent shifting during authorization alerts
    }
    
    // MARK: - Results Page (3-Column Layout)
    private var resultsPage: some View {
        VStack {
            // Title & Subtitle for Results
            VStack(spacing: 12) {
                Text(L("Đây là những gì tôi tìm thấy."))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                
                Text(L("Các tác vụ cần thiết để dọn dẹp, bảo vệ và tăng tốc máy Mac đã sẵn sàng."))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            threeColumnLayout(state: .completed)
            
            Spacer()
        }
    }
    
    // MARK: - Cleaning/Finished Pages
    // MARK: - Cleaning Page (3-Column Layout, similar to Scanning)
    private var cleaningPage: some View {
        VStack {
            Spacer().frame(height: 60)
            
            HStack(spacing: 80) {
                Group {
                    if let category = service.cleaningCurrentCategory {
                        let iconName = getIconFor(category: category)
                        if let imagePath = Bundle.main.path(forResource: iconName, ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
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
                .animation(.easeInOut(duration: 0.6), value: service.cleaningCurrentCategory)
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
                        // Dynamically show tasks based on what's cleaning
                        // Danh sách tác vụ được làm mới: Rác hệ thống, Thùng rác, Chương trình độc hại, DNS, RAM

                        let categories: [CleanerCategory] = [.systemJunk, .largeFiles, .virus, .startupItems, .performanceApps]
                        ForEach(categories, id: \.self) { cat in
                            let isActive = service.cleaningCurrentCategory == cat
                            let isDone = service.cleanedCategories.contains(cat)
                            
                            HStack(spacing: 12) {
                                // Icon Circle
                                ZStack {
                                    Circle()
                                        .fill(getCategoryColor(cat).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: getCategoryIcon(cat))
                                        .font(.system(size: 14))
                                        .foregroundColor(getCategoryColor(cat))
                                }
                                
                                Text(cat == .largeFiles ? L("Rác") : getCategoryTitle(cat))
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if isActive {
                                    Text(service.cleaningDescription)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 20, height: 20)
                                } else if isDone {
                                    Text(ByteCountFormatter.string(fromByteCount: service.sizeFor(category: cat), countStyle: .file))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text(L("..."))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                            .frame(width: 340)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 500) // Fixed height to prevent shifting during alerts
            
            Spacer()
        }
    }
    
    // MARK: - Cleaning Log Page
    private var cleaningLogPage: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 60) {
                // Left: Hero Image (iMac with wiper)
                if let imagePath = Bundle.main.path(forResource: "welcome.png", ofType: "png"),
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
                
                // Right: Detailed Task List (Log)
                VStack(alignment: .leading, spacing: 24) {
                    Text(L("Nhật ký làm sạch"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        // 1. System Junk
                        let sysJunkSize = service.sizeFor(category: .systemJunk) + service.sizeFor(category: .userCache)
                        let sysJunkState: CleaningTaskState = sysJunkSize > 0 ? .warning : .completed
                        
                        cleaningTaskRow(
                            icon: "trash.circle.fill",
                            color: .pink,
                            title: L("Rác hệ thống"),
                            size: sysJunkSize > 0 ? sysJunkSize : service.totalCleanedSize, 
                            state: sysJunkState
                        )
                        
                        // 2. Trash
                        cleaningTaskRow(
                            icon: "trash.fill",
                            color: .green,
                            title: L("Rác"),
                            size: 0,
                            state: .completed
                        )
                        
                        // 3. Malware
                        cleaningTaskRow(
                            icon: "exclamationmark.shield.fill",
                            color: .gray,
                            title: L("Ứng dụng có thể gây hại"),
                            size: 0,
                            state: .completed
                        )
                        
                        // 4. Optimization
                        cleaningTaskRow(
                            icon: "network",
                            color: .blue,
                            title: L("Làm mới bộ đệm DNS"),
                            size: 0,
                            state: .completed
                        )
                         
                         cleaningTaskRow(
                             icon: "memorychip",
                             color: .blue,
                             title: L("RAM miễn phí"),
                             size: 0,
                             state: .completed
                         )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Left: Hide Log Button
            Button(action: { withAnimation { viewingLog = false } }) {
                Text(L("Ẩn nhật ký"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 60)
            .padding(.bottom, 40)
        }
    }
    private var cleaningFinishedPage: some View {
        VStack {
            Spacer().frame(height: 50)
            
            // Headline
            VStack(spacing: 8) {
                Text(L("Làm tốt lắm, đây là những gì tôi tìm thấy."))
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                
                Text(L("Tất cả các nhiệm vụ để giữ cho máy Mac của bạn sạch sẽ, an toàn và tối ưu hóa đều sẵn sàng. Chạy ngay bây giờ!"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer().frame(height: 50)
            
            // Horizontal Cards
            HStack(spacing: 60) {
                // 1. Cleanup (Blue)
                VStack(spacing: 30) {
                    ScanResultCard(
                        icon: "trash.circle.fill", // Using standard SF Symbol or custom
                        title: L("Dọn dẹp"),
                        subtitle: L("Loại bỏ rác không mong muốn"),
                        gradient: BackgroundStyles.cardApps, // Blue
                        isCompleted: true
                    )
                    
                    ScanResultStat(
                        value: ByteCountFormatter.string(fromByteCount: service.totalCleanedSize, countStyle: .file).replacingOccurrences(of: " GB", with: "").replacingOccurrences(of: " MB", with: "").replacingOccurrences(of: " KB", with: ""),
                        unit: ByteCountFormatter.string(fromByteCount: service.totalCleanedSize, countStyle: .file).suffix(2).trimmingCharacters(in: .whitespaces),
                        detailsAction: {
                            withAnimation { viewingLog = true }
                        },
                        color: Color(red: 0.2, green: 0.6, blue: 1.0), // Blue Text
                        loc: loc
                    )
                }
                
                // 2. Protection (Green)
                VStack(spacing: 30) {
                    ScanResultCard(
                        icon: "lock.shield.fill",
                        title: L("Bảo vệ"),
                        subtitle: L("Loại bỏ các mối đe dọa tiềm ẩn"),
                        gradient: BackgroundStyles.cardCleaning, // Green (naming mismatch in Styles)
                        isCompleted: true
                    )
                    
                    ScanResultStat(
                        value: service.totalResolvedThreats > 0 ? "\(service.totalResolvedThreats)" : L("Tốt"),
                        unit: service.totalResolvedThreats > 0 ? L("Mối đe dọa") : "",
                        detailsAction: nil, // No details for Good
                        color: Color.green, // Green Text
                        loc: loc
                    )
                }
                
                // 3. Speed (Pink/Red)
                VStack(spacing: 30) {
                    ScanResultCard(
                        icon: "gauge.with.needle",
                        title: L("Tốc độ"),
                        subtitle: L("Cải thiện hiệu suất hệ thống"),
                        gradient: BackgroundStyles.cardProtection, // Pink/Purple (naming mismatch)
                        isCompleted: service.totalOptimizedItems > 0
                    )
                    
                    ScanResultStat(
                        value: "\(service.totalOptimizedItems)",
                        unit: L("Nhiệm vụ"),
                        detailsAction: nil,
                        color: Color(red: 1.0, green: 0.4, blue: 0.6), // Pink Text
                        loc: loc
                    )
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Run Button (Bottom Center)
            Button(action: {
                // Perform clean logic or dismiss
                // Usually this button triggers "Clean Now" if separated scan/clean
                // But scanClean() usually runs automatically or manually.
                // Assuming this is the "Done" state, user might want to re-run or just finish.
                // For now, matching the design "Run" button style.
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 80)
                        .shadow(color: .blue.opacity(0.5), radius: 10)
                        
                    Text(L("Chạy"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.2)
                            .opacity(0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }
    }


    // MARK: - UI Helpers
    
    enum CleaningTaskState {
        case pending, cleaning, completed, warning
    }
    
    @ViewBuilder
    private func cleaningTaskRow(icon: String, color: Color, title: String, size: Int64, state: CleaningTaskState) -> some View {
        HStack(spacing: 16) {
            // Icon in Solid Circle
            ZStack {
                Circle()
                    .fill(color) // Solid background color
                    .frame(width: 32, height: 32)
                
                // Extract base icon name if it contains .circle.fill to avoid double circle
                let baseIcon = icon.replacingOccurrences(of: ".circle.fill", with: "")
                                  .replacingOccurrences(of: ".fill", with: "")
                
                Image(systemName: baseIcon == "trash" ? "trash.fill" : (baseIcon == "exclamationmark.shield" ? "exclamationmark.shield.fill" : baseIcon))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white)
            
            Spacer()
            
            // Check if warning state, move size to title side or keep? 
            // Design shows: 3.37 GB [Warning Icon]
            if state == .warning {
                 Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                  
                  Button(action: { showFailedFilesPopover = true }) {
                      Image(systemName: "exclamationmark.triangle.fill")
                         .foregroundColor(.yellow)
                         .font(.system(size: 14))
                  }
                  .buttonStyle(.plain)
                  .popover(isPresented: $showFailedFilesPopover, arrowEdge: .top) {
                      VStack(alignment: .leading, spacing: 12) {
                          Text(L("Mặt hàng này đã được làm sạch một phần."))
                              .font(.system(size: 13, weight: .bold))
                          
                          VStack(alignment: .leading, spacing: 4) {
                              Text(L("Lỗi:"))
                                  .font(.system(size: 12, weight: .semibold))
                                  .foregroundColor(.gray)
                              
                              ScrollView {
                                  VStack(alignment: .leading, spacing: 4) {
                                      ForEach(failedFiles, id: \.id) { item in
                                          Text(String(format: L("Không thể xóa \"%@\" vì ứng dụng liên quan vẫn đang chạy."), item.url.lastPathComponent))
                                              .font(.system(size: 11))
                                              .foregroundColor(.white.opacity(0.8))
                                      }
                                  }
                              }
                              .frame(maxHeight: 150)
                          }
                          
                          Button(action: {
                              let errorText = failedFiles.map { item in
                                  String(format: L("Không thể xóa \"%@\" vì ứng dụng liên quan vẫn đang chạy."), item.url.lastPathComponent)
                              }.joined(separator: "\n")
                              let pasteboard = NSPasteboard.general
                              pasteboard.clearContents()
                              pasteboard.setString(errorText, forType: .string)
                          }) {
                              Text(L("Sao chép vào Clipboard"))
                                  .font(.system(size: 12))
                                  .foregroundColor(.white.opacity(0.9))
                                  .padding(.horizontal, 12)
                                  .padding(.vertical, 4)
                                  .background(Color.white.opacity(0.1))
                                  .cornerRadius(6)
                          }
                          .buttonStyle(.plain)
                      }
                      .padding()
                      .frame(width: 300)
                      .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                  }
            } else {
                // Normal Size (if > 0 and not cleaning?)
                if size > 0 && state != .cleaning {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Status Indicator
                if state == .cleaning {
                   ProgressView()
                       .scaleEffect(0.5)
                       .frame(width: 16, height: 16)
                       .colorScheme(.dark)
                } else if state == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                } else if state == .pending {
                    // Pending dot (empty circle or similar)
                     Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .frame(height: 44) // Increased height for better touch target
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func resultRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            // Large Icon
             ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.8), color.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            // Checkmark
            ZStack {
                Circle().fill(Color.white).frame(width: 18, height: 18)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
            
            // Texts
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - 3-Column Layout Implementation
    // MARK: - 3-Column Layout Implementation
    private func threeColumnLayout(state: ScanState) -> some View {
        HStack(spacing: 40) {
            // 1. Cleanup Group
            // State Logic:
            // - Active if cleaning any junk category
            // - Done if systemJunk (primary) is cleaned OR if we moved past junk
            // - Pending if not started
            let cleanupActive = state == .cleaning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles, .appUpdates].contains(service.cleaningCurrentCategory)
            let cleanupDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.systemJunk) && !cleanupActive)
            
            itemColumn(
                title: L("Dọn dẹp"),
                iconName: "yinpan_2026",
                description: state == .scanning ? L("Đang tìm kiếm các tập tin không mong muốn...") : L("Loại bỏ rác không mong muốn"),
                categories: [.systemJunk, .duplicates, .similarPhotos, .largeFiles],
                state: state,
                isActive: (state == .scanning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) || cleanupActive,
                isDone: cleanupDone,
                color: Color(red: 0.1, green: 0.6, blue: 0.9), // Blue
                currentPath: (state == .scanning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) ? service.currentScanPath : (cleanupActive ? service.currentScanPath : nil)
            )
            
            // 2. Protection Group
            let protectionActive = state == .cleaning && service.cleaningCurrentCategory == .virus
            let protectionDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.virus))
            
            itemColumn(
                title: L("Bảo vệ"),
                iconName: "zhiwendunpai_2026",
                description: state == .scanning ? L("Xác định các mối đe dọa tiềm ẩn...") : L("Loại bỏ các mối đe dọa tiềm ẩn"),
                categories: [.virus],
                state: state,
                isActive: (state == .scanning && service.currentCategory == .virus) || protectionActive,
                isDone: protectionDone,
                color: Color(red: 0.2, green: 0.8, blue: 0.5), // Green
                currentPath: (state == .scanning && service.currentCategory == .virus) ? service.currentScanPath : (protectionActive ? service.currentScanPath : nil)
            )
            
            // 3. Speed Group
            let speedActive = state == .cleaning && [.startupItems, .performanceApps].contains(service.cleaningCurrentCategory)
            let speedDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.startupItems))
            
            // ⚠️ Tạm thời vô hiệu hóa hiệu suất Ứng dụng: Người dùng báo cáo rằng việc quét và dọn dẹp thông minh sẽ phá hủy ứng dụng

            itemColumn(
                title: L("Tốc độ"),
                iconName: "yibiaopan_2026", // Speedometer
                description: state == .scanning ? L("Đang xác định các tác vụ phù hợp...") : L("Cải thiện hiệu suất hệ thống"),
                categories: [.startupItems, .performanceApps, .appUpdates],
                state: state,
                isActive: (state == .scanning && [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory)) || speedActive,
                isDone: speedDone,
                color: Color(red: 0.9, green: 0.3, blue: 0.5), // Pink
                currentPath: (state == .scanning && [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory)) ? service.currentScanPath : (speedActive ? service.currentScanPath : nil)
            )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Column Item View
    @ViewBuilder
    private func itemColumn(
        title: String,
        iconName: String,
        description: String,
        categories: [CleanerCategory],
        state: ScanState,
        isActive: Bool,
        isDone: Bool,
        color: Color,
        currentPath: String? = nil
    ) -> some View {
        VStack(spacing: 16) {
            // Icon Area
            ZStack {
                // Background Glow/Shape - Enlarged
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: color.opacity(0.4), radius: 10, y: 5)
                
                // Image Icon - Direct path to resource subdirectory
                let resourcePath = Bundle.main.path(forResource: iconName, ofType: "png", inDirectory: "resource") ?? ""
                if let nsImage = NSImage(contentsOfFile: resourcePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .modifier(SmartIconAnimationModifier(
                            type: getAnimationType(for: title),
                            isScanning: isActive,
                            isCleaning: state == .cleaning && isActive
                        ))
                } else if let imagePath = Bundle.main.path(forResource: iconName, ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .modifier(SmartIconAnimationModifier(
                            type: getAnimationType(for: title),
                            isScanning: isActive,
                            isCleaning: state == .cleaning && isActive
                        ))
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 160)
            
            // Status Check + Title
            HStack(spacing: 6) {
                if isActive {
                   if currentPath != nil {
                       ProgressView()
                           .scaleEffect(0.6)
                           .frame(width: 16, height: 16)
                   } else {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                   }
                } else if isDone || state == .completed { // Scan Completed also shows Checkmark if finished
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                } else {
                     Circle()
                         .fill(Color.white.opacity(0.2))
                         .frame(width: 8, height: 8)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Description
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(minHeight: 36)
            
            Spacer().frame(height: 8)
            
            // MARK: - Dynamic Content Area (Scanning Path or Results)
            VStack(spacing: 8) {
                if isActive {
                    // Scanning: Show real-time path
                    if let path = currentScanPathInColumn(title) {
                        Text(path)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                            )
                            .frame(maxWidth: 280)
                    } else {
                        Text("")
                            .frame(height: 28)
                    }
                } else if state == .completed {
                    // Completed: Show result size
                    VStack(spacing: 6) {
                        if title == L("Dọn dẹp") {
                            let size = categories.reduce(0) { $0 + service.sizeFor(category: $1) }
                            if size > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(color)
                                
                                // View Details Button (Only if count > 0)
                                Button(action: {
                                    initialDetailCategory = .systemJunk
                                    showDetailSheet = true
                                }) {
                                    Text(L("Xem chi tiết..."))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(L("Tốt"))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        } else if title == L("Bảo vệ") {
                            let threats = service.virusThreats.count
                            if threats > 0 {
                                Text("\(threats)")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.red)
                                
                                // View Details Button (Only if threats > 0)
                                Button(action: {
                                    initialDetailCategory = .virus
                                    showDetailSheet = true
                                }) {
                                    Text(L("Xem chi tiết..."))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(L("Tốt"))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        } else if title == L("Tốc độ") {
                            let count = service.startupItems.count
                            if count > 0 {
                                VStack(spacing: 0) {
                                    Text("\(count)")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundColor(.white)
                                    
                                    // Text Description instead of Button (matched reference)
                                    Text(L("nhiệm vụ cần chạy"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.top, 2)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    initialDetailCategory = .startupItems
                                    showDetailSheet = true
                                }
                                
                            } else {
                                Text(L("Tốt"))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        }
                    }
                } else {
                    // Pending: Empty space
                    Text("")
                        .frame(height: 60)
                }
            }
            // Removed fixed minHeight to reduce whitespace gap

            
        }
        .frame(maxWidth: 320)
    }

    // MARK: - Smart Icon Animation Modifier
    enum SmartIconType {
        case cleanup
        case protection
        case speed
        case unknown
    }
    
    private func getAnimationType(for title: String) -> SmartIconType {
        // Simple mapping based on title text
        // Note: Localization aware check
        let lower = title.lowercased()
        if lower.contains("clean") || lower.contains("dọn") { return .cleanup }
        if lower.contains("protect") || lower.contains("bảo vệ") { return .protection }
        if lower.contains("speed") || lower.contains("tăng tốc") { return .speed }
        return .unknown
    }

    struct SmartIconAnimationModifier: ViewModifier {
        let type: SmartIconType
        let isScanning: Bool
        let isCleaning: Bool
        
        @State private var phase: Double = 0
        @State private var isAnimating: Bool = false
        
        func body(content: Content) -> some View {
            Group {
                switch type {
                case .cleanup:
                    // Disk/Radar Animation
                    if isScanning {
                        content
                            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                            .animation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
                    } else if isCleaning {
                        // Fast vibration
                         content
                            .offset(x: isAnimating ? -2 : 2, y: isAnimating ? 2 : -2)
                            .animation(Animation.linear(duration: 0.1).repeatForever(autoreverses: true), value: isAnimating)
                    } else {
                        content
                    }
                    
                case .protection:
                    // Shield Pulse/Shimmer
                    if isScanning || isCleaning {
                        content
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                            .opacity(isAnimating ? 1.0 : 0.8)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    } else {
                        content
                    }
                    
                case .speed:
                    // Speedometer Needle Wobble
                    if isScanning {
                         content
                            .rotationEffect(Angle(degrees: isAnimating ? 15 : -15))
                            .animation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: isAnimating)
                    } else if isCleaning {
                         // Max Speed Shake
                         content
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(Animation.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: isAnimating)
                    } else {
                        content
                    }
                    
                case .unknown:
                    content
                        .scaleEffect(isScanning && isAnimating ? 1.1 : 1.0)
                        .animation(isScanning ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isAnimating)
                }
            }
            .onAppear {
                if isScanning || isCleaning {
                    isAnimating = true
                }
            }
            .onChange(of: isScanning) { newVal in isAnimating = newVal }
            .onChange(of: isCleaning) { newVal in 
                 if newVal { isAnimating = true }
            }
        }
    }
    
    // MARK: - Animation Modifier (Deprecated, but kept for safe fallback if needed)
    struct ScanningAnimationModifier: ViewModifier {
        let isScanning: Bool
        @State private var isAnimating = false
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isScanning && isAnimating ? 1.1 : 1.0)
                .animation(isScanning ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isAnimating)
                .onAppear {
                    if isScanning { isAnimating = true }
                }
                .onChange(of: isScanning) { newValue in
                    isAnimating = newValue
                }
        }
    }
    
    // MARK: - Spinning Animation Modifier
    struct SpinningAnimationModifier: ViewModifier {
        @State private var isSpinning = false
        
        func body(content: Content) -> some View {
            content
                .rotationEffect(Angle(degrees: isSpinning ? 360 : 0))
                .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: isSpinning)
                .onAppear {
                    isSpinning = true
                }
        }
    }

    // MARK: - Main Action Button (Scan Orb)
    @ViewBuilder
    private var mainActionButton: some View {
        if viewingLog {
            EmptyView()
        } else {
            switch scanState {
        case .initial:
            // Start Orb
            Button(action: {
                Task { await service.scanAll() }
            }) {
                ZStack {
                    // Bottom Floor Glow (The "Under" Effect)
                    // Elliptical glow to simulate reflection/light on the surface below
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.6), // Bright Purple core
                                    Color(red: 0.4, green: 0.1, blue: 0.6).opacity(0.2), // Fading out
                                    .clear
                                ],
                                startPoint: .center,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 180, height: 40) // Flattened disk
                        .blur(radius: 15)
                        .offset(y: 65) // Positioned well below the button
                    
                    // Outer Ring (Pulsing or static faint ring)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 74, height: 74) // Outer ring for 60x60 button
                    
                    // Main Orb Body
                    ZStack {
                        // Background Gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(red: 0.85, green: 0.3, blue: 0.7), location: 0), // Lighter Pink/Purple Top
                                        .init(color: Color(red: 0.6, green: 0.1, blue: 0.6), location: 0.5), // Mid Purple
                                        .init(color: Color(red: 0.4, green: 0.1, blue: 0.5), location: 1.0)  // Darker Bottom
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        // Inner "Concave" Shadow (simulated with overlay gradient)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(2)
                            .blur(radius: 2)
                        
                        // Text
                        Text(L("Quét"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: 60, height: 60)
                    .overlay(
                        // Sharp Glassy Rim
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .contentShape(Rectangle()) // Expand hit area slightly if needed, or keep generic
            }
            .buttonStyle(.plain)
            
        case .scanning:
            // New Stop Button with Rotating Ring and Real-time Size
            // New Stop Button with Rotating Ring and Real-time Size
            // New Stop Button with Real Progress Ring and Side Text
            HStack(spacing: 20) {
                // Stop Button Group
                Button(action: { service.stopScanning() }) {
                    ZStack {
                        // 1. Outer Track (Background Ring)
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 60, height: 60)
                        
                        // 2. Progress Indicator (Determinate Ring)
                        // Use service.scanProgress (0.0 to 1.0)
                        Circle()
                            .trim(from: 0, to: max(0.01, service.scanProgress)) // Ensure at least a tiny dot is visible
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(Angle(degrees: -90)) // Start from top
                            .animation(.linear(duration: 0.2), value: service.scanProgress) // Smooth progress updates
                        
                        // 3. Inner Button Background (Glassy)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.8, green: 0.2, blue: 0.5), // Pinkish Red
                                        Color(red: 0.6, green: 0.1, blue: 0.4)  // Darker Purple/Red
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        // 4. "Stop" Icon/Text
                        // Design shows a simple Stop square or text. Let's use text as before for clarity, or icon.
                        // Người dùng đã đề cập đến "Nút dừng" nhưng ảnh chụp màn hình thiết kế 3 hiển thị văn bản "Dừng" bên trong.

                        // 4. "Stop" Icon/Text
                        Text(L("Dừng lại"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // Real-time Size Display (displayed to the right)
                Text(ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file))
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            .padding(.bottom, 20)
                         
        case .cleaning:
            // Stop Button for Cleaning Page
            Button(action: { service.stopCleaning() }) {
                ZStack {
                     Circle()
                         .fill(Color.white.opacity(0.1))
                         .frame(width: 80, height: 80)
                         .overlay(
                             Circle()
                                 .trim(from: 0, to: 0.7) // Mock progress Ring
                                 .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                 .rotationEffect(Angle(degrees: -90))
                         )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(L("Dừng lại"))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
        case .completed:
            // Run Orb (Updated to match design: Cyan Ring + Purple Fill)
            Button(action: {
                // Check for running apps
                let selectedFiles = service.getAllSelectedFiles()
                let runningApps = service.checkRunningApps(for: selectedFiles)
                
                if !runningApps.isEmpty {
                    detectedRunningApps = runningApps
                    showRunningAppsDialog = true
                } else {
                    showDeleteConfirmation = true
                }
            }) {
                ZStack {
                    // 1. Outer Diffused Glow (Purple/Blue aura)
                    Circle()
                        .fill(Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.3)) // Purple aura
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    
                    // 2. Main Glow Ring (Cyan/Blue - Behind border to create glow effect)
                    Circle()
                        .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.5), lineWidth: 4)
                        .frame(width: 112, height: 112)
                        .blur(radius: 8) // Soft glow
                    
                    // 3. Button Body (Translucent Purple/Blue Gradient)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.35, blue: 0.65).opacity(0.8), // Top: Muted Purple
                                    Color(red: 0.35, green: 0.25, blue: 0.55).opacity(0.9)  // Bottom: Darker
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    // 4. Cyan Border Ring (Sharp)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.9, blue: 1.0), // Bright Cyan
                                    Color(red: 0.0, green: 0.6, blue: 0.9)  // Strong Blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3.5
                        )
                        .frame(width: 60, height: 60)
                    
                    // 5. Inner Highlight (Glassy top reflection)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 56, height: 56)
                        .blur(radius: 0.5)

                    // 6. Text
                    Text(L("Chạy"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            
        case .finished:
             // Back/Done Orb
             // Back/Done Button (Simple Green Button)
             Button(action: {
                 Task { service.resetAll(); showCleaningFinished = false }
             }) {
                 ZStack {
                     Circle()
                         .fill(LinearGradient(
                             colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)],
                             startPoint: .top,
                             endPoint: .bottom
                         ))
                         .frame(width: 80, height: 80)
                         .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 5)
                         .overlay(
                             Circle()
                                 .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                         )
                     
                     Text(L("Quay lại"))
                         .font(.system(size: 16, weight: .semibold))
                         .foregroundColor(.white)
                 }
             }
             .buttonStyle(.plain)
             
        }
    }
}

}

extension SmartCleanerView {
    private func getFinishedResultText(for category: CleanerCategory) -> String {
        if category == .systemJunk && deleteResult != nil {
            return String(format: L("Đã dọn sạch %@"), ByteCountFormatter.string(fromByteCount: deleteResult!.size, countStyle: .file))
        }
        return getCleaningSubText(for: category)
    }
}

// MARK: - Result Compact Row (For Finished Page)
struct ResultCompactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let stat: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Square Icon
            let resourcePath = Bundle.main.path(forResource: icon, ofType: "png", inDirectory: "resource") ?? ""
            if let nsImage = NSImage(contentsOfFile: resourcePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
            } else if let imagePath = Bundle.main.path(forResource: icon, ofType: "png"),
               let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
            } else {
                 Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.blue)
            }
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
            
            // Texts
            VStack(alignment: .leading, spacing: 2) {
                Text(stat)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cleaning Large Icon Animation
struct CleaningLargeIconAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Helper Functions Extension
extension SmartCleanerView {
    
    // MARK: - Custom Running Apps Dialog (Pro Max)
    private var runningAppsOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close dialog if tapped outside
                    withAnimation { showRunningAppsDialog = false }
                }
            
            // Dark "Pro Max" Dialog
            VStack(spacing: 0) {
                runningAppsHeader
                
                // Content Divider
                Divider()
                    .background(Color.white.opacity(0.1))
                
                runningAppsList
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                runningAppsFooter
            }
            .frame(width: 440) // Slightly wider
            .background(Color(red: 0.12, green: 0.12, blue: 0.13)) // Dark background
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1) // Thin border
            )
        }
        .transition(.opacity)
    }
    
    private var runningAppsHeader: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }
            .padding(.top, 8)
            
            VStack(spacing: 6) {
                Text(L("Một số ứng dụng nên thoát"))
                    .font(.system(size: 18, weight: .bold)) // Slightly larger
                    .foregroundColor(.white) // White text
                
                Text(L("Vui lòng thoát khỏi các ứng dụng sau để xóa tất cả các mục liên quan:"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7)) // Secondary text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(2)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var runningAppsList: some View {
        ScrollView {
            VStack(spacing: 1) { // 1px spacing for list feel
                ForEach(detectedRunningApps, id: \.bundleId) { app in
                    HStack(spacing: 12) {
                        // App Icon
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                        }
                        
                        // App Name
                        Text(app.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white) // White
                        
                        Spacer()
                        
                        // Close Button
                        Button(action: {
                            // 1. Close the app
                            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleId }) {
                                runningApp.terminate()
                            }
                            
                            // 2. Remove from list
                            withAnimation {
                                detectedRunningApps.removeAll(where: { $0.bundleId == app.bundleId })
                                // If list becomes empty, close dialog and show confirmation
                                if detectedRunningApps.isEmpty {
                                    showRunningAppsDialog = false
                                    showDeleteConfirmation = true
                                }
                            }
                        }) {
                            Text(L("Đóng"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)) // Dark pill
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02)) // Slight highlight on row
                    
                    // Separator
                    if app.bundleId != detectedRunningApps.last?.bundleId {
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .frame(maxHeight: 220) // Slightly taller
        .background(Color.black.opacity(0.2)) // Darker inner background
    }
    
    private var runningAppsFooter: some View {
        HStack(spacing: 16) {
            // Ignore Button
            Button(action: {
                withAnimation {
                    showRunningAppsDialog = false
                    showDeleteConfirmation = true
                }
            }) {
                Text(L("Bỏ qua"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Force Quit All Button
            Button(action: {
                // Close all apps in the list
                for app in detectedRunningApps {
                    if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleId }) {
                        runningApp.terminate()
                    }
                }
                
                // Proceed to cleaning
                withAnimation {
                    detectedRunningApps.removeAll()
                    showRunningAppsDialog = false
                    showDeleteConfirmation = true
                }
            }) {
                Text(L("Thoát khỏi tất cả"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(8)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

private func currentScanPathInColumn(_ title: String) -> String? {
    if title == L("Dọn dẹp") {
        if [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory) {
            return service.currentScanPath
        }
    } else if title == L("Bảo vệ") {
        if service.currentCategory == .virus {
            return service.currentScanPath
        }
    } else if title == L("Tốc độ") {
        if [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory) {
            return service.currentScanPath
        }
    }
    return nil
}


    private func getDisplayTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return L("Rác hệ thống")
        case .duplicates: return L("trùng lặp")
        case .similarPhotos: return L("Ảnh tương tự")
        case .largeFiles: return L("Tệp lớn")
        case .virus: return L("Phòng ngừa vi-rút")
        case .startupItems: return L("Mục khởi động")
        case .performanceApps: return L("Hiệu suất")
        case .appUpdates: return L("Cập nhật ứng dụng")
        default: return ""
        }
    }
    
    private func getResultText(for category: CleanerCategory) -> String {
        let size = service.sizeFor(category: category)
        if size > 0 || [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(category) {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        switch category {
        case .virus: return service.virusThreats.isEmpty ? L("0 mối đe dọa") : String(format: L("%d Mối đe dọa"), service.virusThreats.count)
        case .startupItems: return String(format: L("%d Mặt hàng"), service.startupItems.count)
        case .performanceApps: return String(format: L("%d Ứng dụng"), service.performanceApps.count)
        case .appUpdates: return service.hasAppUpdates ? L("Đã cập nhật") : L("Không có cập nhật")
        default: return L("0 KB")
        }
    }
    
    private func getSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return L("Có thể làm sạch")
        case .virus: return service.virusThreats.isEmpty ? L("An toàn") : L("Có thể tháo rời")
        case .startupItems: return L("Có thể tối ưu hóa")
        case .performanceApps: return L("Để xem lại")
        case .appUpdates: return L("Để cài đặt")
        default: return ""
        }
    }
    
    private func getScanningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return L("Đang tìm kiếm rác...")
        case .duplicates: return L("Đang tìm bản sao...")
        case .similarPhotos: return L("Đang tìm thấy những bức ảnh tương tự...")
        case .largeFiles: return L("Đang quét các tệp lớn...")
        case .virus: return L("Đang quét các mối đe dọa...")
        case .startupItems: return L("Đang phân tích các mục khởi động...")
        case .performanceApps: return L("Đang kiểm tra ứng dụng nền...")
        case .appUpdates: return L("Đang kiểm tra cập nhật...")
        default: return ""
        }
    }
    
    private func getGradient(for category: CleanerCategory) -> LinearGradient {
        switch category {
        case .systemJunk:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.6, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .duplicates:
            return LinearGradient(colors: [Color(red: 0.3, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .similarPhotos:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .largeFiles:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .virus:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.3, blue: 0.4), Color(red: 0.7, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .startupItems:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.4, blue: 0.9), Color(red: 0.2, green: 0.2, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .performanceApps:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 0.8, green: 0.2, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appUpdates:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.gray, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func getCleaningSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return L("Đã dọn sạch")
        case .virus: return L("An toàn")
        case .performanceApps, .startupItems: return L("Tối ưu hóa")
        case .appUpdates: return L("Đã rà soát")
        default: return ""
        }
    }
    
    private func getCleaningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return L("Dọn dẹp rác...")
        case .duplicates, .similarPhotos, .largeFiles: return L("Sắp xếp tập tin...")
        case .virus: return L("Loại bỏ các mối đe dọa...")
        case .startupItems: return L("Tối ưu mục khởi động...")
        case .performanceApps: return L("Tối ưu hóa hiệu suất...")
        case .appUpdates: return L("Đang kiểm tra trạng thái cập nhật...")
        default: return ""
        }
    }

    private func getIconFor(category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .userCache, .systemCache, .userLogs, .systemLogs:
            return "system_clean"
        case .duplicates, .similarPhotos:
            return "kongjianshentou"
        case .virus:
            return "yinsi"
        case .startupItems, .performanceApps:
            return "youhua"
        default:
            return "system_clean"
        }
    }
    
    private func getCategoryIcon(_ category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return "trash.circle.fill"
        case .largeFiles: return "trash.fill"
        case .virus: return "exclamationmark.shield.fill"
        case .startupItems: return "network"
        case .performanceApps: return "memorychip"
        default: return "circle.fill"
        }
    }
    
    private func getCategoryColor(_ category: CleanerCategory) -> Color {
        switch category {
        case .systemJunk: return .pink
        case .largeFiles: return .green
        case .virus: return .gray
        case .startupItems, .performanceApps: return .blue
        default: return .gray
        }
    }
    
    private func getCategoryTitle(_ category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return L("Rác hệ thống")
        case .largeFiles: return L("Rác")
        case .virus: return L("Ứng dụng có thể gây hại")
        case .startupItems: return L("Làm mới bộ đệm DNS")
        case .performanceApps: return L("RAM miễn phí")
        default: return L("Task")
        }
    }
}
struct DashboardCard: View {
    let title: String
    let mainText: String
    let subText: String
    let icon: String // SF Symbol
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Checkbox visually represented by Icon for now per design)
                HStack {
                     Image(systemName: "checkmark.square.fill") // Fake checkbox for aesthetic
                        .foregroundColor(.white.opacity(0.6))
                     Text(title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Text(mainText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Right Side Graphic (Glassmorphism Icon)
            VStack {
                ZStack {
                    // Glassy background for icon
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                    
                    Image(systemName: icon)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 40, height: 40)
                         .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(L("Xem")) { action() } // View Button
                .buttonStyle(SmallGlassButtonStyle())
            }
        }
        .padding(20)
        .frame(height: 180)
        .background(
            ZStack {
                gradient.opacity(0.3) // Tint
                Color.black.opacity(0.3) // Darken
                Rectangle().fill(.thinMaterial) // Blur
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Status Pill for Scanning
struct StatusPill: View {
    let label: String
    let active: Bool
    
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(active ? Color.purple : Color.white.opacity(0.1))
            .cornerRadius(20)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut, value: active)
    }
}

// MARK: - Small Glass Button
struct SmallGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Block state for consistent rendering
enum ScanBlockState {
    case idle       // Not yet scanned
    case active     // Currently scanning/cleaning
    case completed  // Finished
}

// MARK: - Scan Block View (Fixed Size, No Flashing)
struct ScanBlockView: View {
    let category: CleanerCategory
    let isActive: Bool
    let isCompleted: Bool
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let scanningTitle: String
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    private var state: ScanBlockState {
        if isActive { return .active }
        if isCompleted { return .completed }
        return .idle
    }
    
    var body: some View {
        // Fixed size container - prevents layout shifts
        ZStack {
            // Background based on state
            backgroundView
            
            // Content based on state
            contentView
        }
        .frame(height: 180) // Fixed height to prevent jumping
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var borderColor: Color {
        switch state {
        case .active: return Color.white.opacity(0.3)
        case .completed: return Color.white.opacity(0.1)
        case .idle: return Color.white.opacity(0.05)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch state {
        case .active:
            // Quét: nền mờ + nhấp nháy đột quỵ

            ZStack {
                Color.black.opacity(0.3)
                gradient.opacity(0.15)
                
                // Trang trí nền động

                RoundedRectangle(cornerRadius: 20)
                    .fill(gradient)
                    .opacity(0.15)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        case .completed:
            // Đã hoàn thành: hình thái thủy tinh cổ điển

            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.12)
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .idle:
            // Được quét: tinh khiết và tối giản

            ZStack {
                Color.black.opacity(0.15)
                Color.white.opacity(0.02)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .active:
            activeContent
        case .completed:
            completedContent
        case .idle:
            idleContent
        }
    }
    
    // Active state content
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scanningTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            // Icon with glow
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 60))
                        .frame(width: 100, height: 100)
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(gradient)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .rotationEffect(.degrees(45))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            
            Spacer()
            
            Text(currentPath)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
    }
    
    // Completed state content
    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                // Cổng vào "Xem chi tiết"

                if let action = viewDetailsAction {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(L("Chi tiết"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient.opacity(0.5))
                        .frame(width: 45, height: 45)
                        .rotationEffect(.degrees(45))
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
        }
        .padding(14)
    }
    
    // Idle state content
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            // Faded icon
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.25))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }
            
            Spacer()
        }
        .padding(14)
    }
}

// MARK: - Cleaning Block View
struct CleaningBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let cleaningTitle: String
    let isActive: Bool
    let isCompleted: Bool
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    // Action for "View Details" button
    
    var body: some View {
        ZStack {
            // Background
            ZStack {
                if isActive {
                    gradient.opacity(0.8)
                } else if isCompleted {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.1)
                } else {
                    Color.black.opacity(0.15)
                    Color.white.opacity(0.02)
                }
                
                // kính nổi bật

                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Content
            if isActive {
                // Active cleaning
                VStack(alignment: .leading, spacing: 8) {
                    Text(cleaningTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 50))
                                .frame(width: 80, height: 80)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(14)
            } else if isCompleted {
                // Completed
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if let action = viewDetailsAction {
                            Button(action: action) {
                                HStack(spacing: 2) {
                                    Text(L("Chi tiết"))
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resultText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            Text(subText)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(gradient.opacity(0.5))
                                .frame(width: 45, height: 45)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    Spacer()
                }
                .padding(12)
            } else {
                // Idle
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(gradient.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

// MARK: - Result Block View (for completed scan results)
struct ResultBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // nền thủy tinh

                ZStack {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.08)
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(gradient.opacity(0.6))
                                .frame(width: 55, height: 55)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(resultText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(subText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(14)
            }
            .frame(height: 180)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Finished Block View (all blocks completed)
struct FinishedBlockView: View {
    let title: String
    let resultText: String
    let icon: String
    let gradient: LinearGradient
    var viewDetailsAction: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // nền thủy tinh

            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.05)
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    // Cổng thông tin "Xem chi tiết" (tùy chọn)

                    if let action = viewDetailsAction {
                        Button(action: action) {
                            HStack(spacing: 2) {
                                Text(L("Xem chi tiết"))
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    Text(resultText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gradient.opacity(0.5))
                            .frame(width: 45, height: 45)
                            .rotationEffect(.degrees(45))
                        
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// Hoạt hình hiệu ứng ánh sáng quét

struct WipingAnimation: ViewModifier {
    @State private var offset: CGFloat = -300
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    offset = 400
                }
            }
    }
}
