import SwiftUI

struct PrivacyView: View {
    @Binding var selectedModule: AppModule
    @StateObject private var service = PrivacyScannerService()
    @ObservedObject private var loc = LocalizationManager.shared
    
    // UI State
    @State private var scanState: PrivacyScanState = .initial
    @State private var pulse = false
    @State private var cleaningProgress: Double = 0
    @State private var cleanedSize: Int64 = 0
    @State private var showPermissionAlert = false
    @State private var showingCloseBrowserAlert = false
    
    // Selection State
    @State private var selectedSidebarItem: SidebarCategory = .permissions
    
    enum SidebarCategory: Hashable, Equatable {
        case permissions
        case recentItems
        case wifi
        case chat
        case development
        case browser(BrowserType)
        
        static func == (lhs: SidebarCategory, rhs: SidebarCategory) -> Bool {
            switch (lhs, rhs) {
            case (.permissions, .permissions): return true
            case (.recentItems, .recentItems): return true
            case (.wifi, .wifi): return true
            case (.chat, .chat): return true
            case (.development, .development): return true
            case (.browser(let b1), .browser(let b2)): return b1 == b2
            default: return false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .permissions: hasher.combine(0)
            case .recentItems: hasher.combine(1)
            case .wifi: hasher.combine(2)
            case .chat: hasher.combine(3)
            case .development: hasher.combine(5)
            case .browser(let b): 
                hasher.combine(4)
                hasher.combine(b)
            }
        }
        
        var title: String {
            switch self {
            case .permissions: return L("Quyền ứng dụng")
            case .recentItems: return L("Danh sách các mục gần đây")
            case .wifi: return L("Mạng Wi-Fi")
            case .chat: return L("Dữ liệu trò chuyện")
            case .development: return L("Dấu vết phát triển")
            case .browser(let b): return b.rawValue
            }
        }
        
        var icon: String {
            switch self {
            case .permissions: return "lock.shield"
            case .recentItems: return "clock"
            case .wifi: return "wifi"
            case .chat: return "message"
            case .development: return "terminal"
            case .browser(let b): return b.icon
            }
        }
    }
    
    var body: some View {
        ZStack {
            // độ dốc nền

            AppModule.privacy.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Khu vực nội dung chính (mỗi chế độ xem có tiêu đề riêng)

                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // If the service has already scanned and has items, go to completed state
            if !service.privacyItems.isEmpty && scanState == .initial {
                scanState = .completed
                selectFirstAvailableCategory()
            }
        }
        .alert(L("Đóng trình duyệt"), isPresented: $showingCloseBrowserAlert) {
            Button(L("Đóng và làm sạch"), role: .destructive) {
                Task {
                    await performClean(closeBrowsers: true)
                }
            }
            Button(loc.L("cancel"), role: .cancel) { }
        } message: {
            Text(L("Các trình duyệt đang chạy. Chúng cần phải được đóng lại để đảm bảo dữ liệu được xóa hoàn toàn."))
        }
    }
    
    // DẤU HIỆU: - Nhìn từ đầu

    private var headerView: some View {
        HStack {
            Spacer()
            // Bạn có thể thêm nút "Trợ lý", v.v. ở góc trên bên phải, tham khảo bản vẽ thiết kế


        }
        .padding()
    }
    
    // MARK: - Định tuyến xem nội dung

    @ViewBuilder
    private var contentView: some View {
        switch scanState {
        case .initial:
            initialView
        case .scanning:
            scanningView
        case .completed:
            resultsView
        case .cleaning:
            cleaningView
        case .finished:
            finishedView
        }
    }
    
    // MARK: - 1. Trang đầu tiên (Initial)

    private var initialView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // văn bản tiêu đề

            VStack(alignment: .leading, spacing: 16) {
                Text(L("Quyền riêng tư"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(L("Xóa lịch sử duyệt web và dấu vết hoạt động trực tuyến và ngoại tuyến ngay lập tức."))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: 400, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 60)
            
            HStack(spacing: 40) {
                // Danh sách chức năng bên trái

                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(icon: "theatermasks", title: L("Xóa dấu vết duyệt web"), description: L("Làm sạch lịch sử duyệt web, bao gồm các biểu mẫu tự động điền và dữ liệu khác được lưu trữ bởi các trình duyệt phổ biến."))
                    FeatureRow(icon: "message", title: L("Làm sạch dữ liệu trò chuyện"), description: L("Bạn có thể xóa lịch sử trò chuyện của Skype và các ứng dụng nhắn tin khác."))
                    FeatureRow(icon: "exclamationmark.triangle", title: L("Cấp Toàn quyền truy cập ổ đĩa để dọn sâu hơn"), description: L("MacOptimizer cần Toàn quyền truy cập ổ đĩa để xóa các mục riêng tư."), isWarning: true)
                    
                    Button(action: {
                        // Mở cài đặt hệ thống

                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text(L("Cấp quyền"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.yellow) // Nút màu vàng thiết kế phù hợp
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 40) // Indent under the warning icon
                }
                .frame(maxWidth: 500)
                
                // Biển báo dừng lớn ở bên phải - sử dụng yinsi.png

                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "yinsi", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    } else {
                        // Dự phòng: Biển báo dừng hình bát giác

                        PolygonShape(sides: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.6, blue: 0.8), // Long lanh
                                        Color(red: 0.8, green: 0.2, blue: 0.5)  // Hồng đậm
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 280, height: 280)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .overlay(
                                PolygonShape(sides: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            )
                            .overlay(
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.white.opacity(0.9))
                            )
                    }
                }
            }
            
            Spacer()
            
            // Nút quét phía dưới

            Button(action: startScan) {
                ZStack {
                     Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 76, height: 76)
                    
                    Text(L("Quét"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 2. Đang quét trang (Scanning)

    private var scanningView: some View {
        VStack {
            Spacer()
            
            // Hoạt ảnh quét - Dấu hiệu dừng lắc lư

                // Quét hoạt hình - Dấu hiệu dừng (yinsi.png)

                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "yinsi", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 240, height: 240)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .scaleEffect(pulse ? 1.05 : 1.0)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                    } else {
                        // Fallback shape if icon missing
                        PolygonShape(sides: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.9, green: 0.4, blue: 0.6),
                                        Color(red: 0.7, green: 0.2, blue: 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 180, height: 180)
                            .overlay(
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                            )
                    }
                }
            .padding(.bottom, 40)
            
            // Văn bản trạng thái quét

            Text(L("Đang tìm kiếm các mục riêng tư..."))
                .font(.title2)
                .foregroundColor(.white)
            
            // Hiển thị đường dẫn/dự án quét hiện tại

            if let lastItem = service.privacyItems.last {
                Text(lastItem.displayPath)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
                    .transition(.opacity)
                    .id("ScanPath")
            }
            
            Spacer()
            
            // nút dừng

            Button(action: stopScan) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Text(L("Dừng lại"))
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
        .onAppear {
            pulse = true
        }
    }
    
    // MARK: - 3. Trang kết quả quét (Kết quả)

    private var resultsView: some View {
        VStack(spacing: 0) {
            resultsHeaderView
            resultsTitleView
            resultsSplitView
            resultsBottomBar
        }
    }
    
    private var resultsHeaderView: some View {
        HStack {
            Button(action: {
                scanState = .initial
                service.privacyItems.removeAll()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text(L("Quay lại"))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(L("Quyền riêng tư"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Phần giữ chỗ trong hộp tìm kiếm

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                Text(L("Tìm kiếm"))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .frame(width: 200, height: 32)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            

        }
        .padding()
    }
    
    private var resultsTitleView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(selectedSidebarItem.title)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                Text(L("Bất kỳ ứng dụng nào cũng có thể yêu cầu thêm quyền..."))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var resultsSplitView: some View {
        HStack(spacing: 0) {
            categoryListView
                .frame(width: 250)

            
            detailListView
                .background(Color.white.opacity(0.05))
        }
    }
    
    private var categoryListView: some View {
        VStack(spacing: 0) {
            // tiêu đề

            HStack {
                Spacer()
                Text(L("Sắp xếp theo tên"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
            
            ScrollView {
                VStack(spacing: 4) {
                    // Application Permissions
                    if service.totalPermissionsCount > 0 || true { // Always show permissions if needed or check empty
                        categoryRow(for: .permissions, count: service.totalPermissionsCount)
                    }
                    
                    // Recent Items
                    let recentCount = service.privacyItems.filter { $0.type == .recentItems }.count
                    if recentCount > 0 {
                        categoryRow(for: .recentItems, count: recentCount)
                    }
                    
                    // Browsers
                    ForEach(BrowserType.allCases.filter { $0 != .system }, id: \.self) { browser in
                        let count = service.privacyItems.filter { $0.browser == browser }.count
                        if count > 0 {
                            categoryRow(for: .browser(browser), count: count)
                        }
                    }
                    
                    // Wi-Fi
                    let wifiCount = service.privacyItems.filter { $0.type == .wifi }.count
                    if wifiCount > 0 {
                        categoryRow(for: .wifi, count: wifiCount)
                    }
                    
                    // Chat
                    let chatCount = service.privacyItems.filter { $0.type == .chat }.count
                    if chatCount > 0 {
                        categoryRow(for: .chat, count: chatCount)
                    }
                    
                    // Development
                    let devCount = service.privacyItems.filter { $0.type == .development }.count
                    if devCount > 0 {
                        categoryRow(for: .development, count: devCount)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    // Helper to build a clickable row
    private func categoryRow(for item: SidebarCategory, count: Int) -> some View {
        let isAllSelected = isCategoryFullySelected(item)
        let appIcon = getAppIconForCategory(item)
        
        return PrivacyCategoryRow(
            icon: item.icon,
            appIcon: appIcon,
            title: item.title,
            count: count,
            isSelected: selectedSidebarItem == item,
            isChecked: isAllSelected,
            onCheckToggle: { toggleCategorySelection(item) },
            onRowTap: { selectedSidebarItem = item }
        )
    }
    
    private func isCategoryFullySelected(_ category: SidebarCategory) -> Bool {
        let items = itemsForCategory(category)
        return !items.isEmpty && items.allSatisfy { $0.isSelected }
    }
    
    private func itemsForCategory(_ category: SidebarCategory) -> [PrivacyItem] {
        switch category {
        case .permissions:
            return service.privacyItems.filter { $0.type == .permissions }
        case .recentItems:
            return service.privacyItems.filter { $0.type == .recentItems }
        case .wifi:
            return service.privacyItems.filter { $0.type == .wifi }
        case .chat:
            return service.privacyItems.filter { $0.type == .chat }
        case .development:
            return service.privacyItems.filter { $0.type == .development }
        case .browser(let b):
            return service.privacyItems.filter { $0.browser == b }
        }
    }
    
    private func toggleCategorySelection(_ category: SidebarCategory) {
        let items = itemsForCategory(category)
        print("🔘 [Toggle] Category: \(category.title), Items count: \(items.count)")
        
        guard !items.isEmpty else { 
            print("⚠️ [Toggle] No items for category!")
            return 
        }
        
        // If all are selected, unselect all; otherwise select all
        let allSelected = items.allSatisfy { $0.isSelected }
        let newValue = !allSelected
        print("🔘 [Toggle] allSelected=\(allSelected), newValue=\(newValue)")
        
        // Directly set the isSelected value for all items in this category
        var updatedCount = 0
        for i in 0..<service.privacyItems.count {
            let item = service.privacyItems[i]
            if items.contains(where: { $0.id == item.id }) {
                service.privacyItems[i].isSelected = newValue
                updatedCount += 1
                // Also update children if any
                if let children = service.privacyItems[i].children {
                    for j in 0..<children.count {
                        service.privacyItems[i].children![j].isSelected = newValue
                    }
                }
            }
        }
        print("✅ [Toggle] Updated \(updatedCount) items to isSelected=\(newValue)")
        service.objectWillChange.send()
    }
    
    private func getAppIconForCategory(_ category: SidebarCategory) -> NSImage? {
        switch category {
        case .browser(let b):
            switch b {
            case .chrome:
                return NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app")
            case .safari:
                return NSWorkspace.shared.icon(forFile: "/Applications/Safari.app")
            case .firefox:
                return NSWorkspace.shared.icon(forFile: "/Applications/Firefox.app")
            case .system:
                return nil
            }
        default:
            return nil
        }
    }
    
    private var detailListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("Nhóm theo loại"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(L("Sắp xếp theo tên"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
            
            List(filteredItems, children: \.children) { item in
                PrivacyRow(item: item, service: service)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var filteredItems: [PrivacyItem] {
        switch selectedSidebarItem {
        case .permissions:
            return service.privacyItems.filter { $0.type == .permissions }
        case .recentItems:
            return service.privacyItems.filter { $0.type == .recentItems }
        case .wifi:
            return service.privacyItems.filter { $0.type == .wifi }
        case .chat:
            return service.privacyItems.filter { $0.type == .chat }
        case .development:
            return service.privacyItems.filter { $0.type == .development }
        case .browser(let b):
            return service.privacyItems.filter { $0.browser == b }
        }
    }
    
    private var resultsBottomBar: some View {
        ZStack {
            // Clean Button (Round Floating)
             // Glow
             Circle()
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .frame(width: 90, height: 90)
            
            Button(action: startClean) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25)) // Semi-transparent button
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                    
                    VStack(spacing: 2) {
                        Text(L("Di dời"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 30)
        .padding(.top, 20)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var selectedItemCount: Int {
        var count = 0
        func countSelected(_ items: [PrivacyItem]) {
            for item in items {
                if item.isSelected { count += 1 }
                if let children = item.children { countSelected(children) }
            }
        }
        countSelected(service.privacyItems)
        return count
    }
    
    private func selectFirstAvailableCategory() {
        if service.totalPermissionsCount > 0 { selectedSidebarItem = .permissions }
        else if service.privacyItems.contains(where: { $0.type == .recentItems }) { selectedSidebarItem = .recentItems }
        else if let b = BrowserType.allCases.first(where: { br in service.privacyItems.contains(where: { $0.browser == br }) }) { selectedSidebarItem = .browser(b) }
        else if service.privacyItems.contains(where: { $0.type == .wifi }) { selectedSidebarItem = .wifi }
        else if service.privacyItems.contains(where: { $0.type == .chat }) { selectedSidebarItem = .chat }
        else if service.privacyItems.contains(where: { $0.type == .development }) { selectedSidebarItem = .development }
    }

    
    // MARK: - 4. Trang dọn dẹp (Cleaning)

    private var cleaningView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                PolygonShape(sides: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                
                 Image(systemName: "hand.raised.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            
            Text(L("Làm sạch dấu vết hoạt động..."))
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            // Dọn dẹp các mục tiến độ (mô phỏng)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock") // Icon
                        .font(.title2)
                        .foregroundColor(.blue)
                        
                    Text(L("Danh sách các mục gần đây"))
                        .foregroundColor(.white)
                    Spacer()
                    Text(L("15 dấu vết"))
                        .foregroundColor(.white.opacity(0.7))
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 40)
                
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.title2)
                        .foregroundColor(.blue)
                        
                    Text(L("Quyền ứng dụng"))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            // nút dừng

             Button(action: {
                // Cancel clean logic ?
             }) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.3) // Progress ring
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    Text(L("Dừng lại"))
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 5. Trang đã hoàn thành (Finished)

    private var finishedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.5), radius: 10)
            
            Text(L("Dọn dẹp hoàn tất"))
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
            
            Text(ByteCountFormatter.string(fromByteCount: cleanedSize, countStyle: .file))
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Button(action: {
                scanState = .initial
            }) {
                Text(L("Xong"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Logic Actions
    
    private func startScan() {
        withAnimation { scanState = .scanning }
        Task {
            await service.scanAll()
            // Nếu chưa bị dừng thì chuyển sang trạng thái hoàn tất và hiển thị kết quả

            if !service.shouldStop {
                withAnimation { scanState = .completed }
            } else {
                // If stopped, reset to initial
                withAnimation { scanState = .initial }
                service.shouldStop = false // Reset flag
            }
        }
    }
    
    private func stopScan() {
        service.stopScan()
        withAnimation { scanState = .initial }
    }
    
    private func startClean() {
        let runningBrowsers = service.checkRunningBrowsers()
        if !runningBrowsers.isEmpty {
            showingCloseBrowserAlert = true
        } else {
            Task {
                await performClean(closeBrowsers: false)
            }
        }
    }
    
    private func performClean(closeBrowsers: Bool) async {
        withAnimation { scanState = .cleaning }
        if closeBrowsers {
            _ = await service.closeBrowsers()
        }
        
        // Simulate progress or wait for service
        let result = await service.cleanSelected()
        await MainActor.run {
            cleanedSize = result.cleaned
            withAnimation { scanState = .finished }
        }
    }
}

// MARK: - Reusable Components

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isWarning ? .yellow : .white.opacity(0.7))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isWarning ? .yellow : .white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PrivacyCategoryRow: View {
    let icon: String
    var appIcon: NSImage? = nil
    let title: String
    let count: Int
    let isSelected: Bool
    var isChecked: Bool = false
    var onCheckToggle: (() -> Void)? = nil
    var onRowTap: (() -> Void)? = nil
    var isHidden: Bool = false
    
    var body: some View {
        if !isHidden {
            HStack(spacing: 10) {
                // Checkbox - has its own button action
                Button(action: { 
                    print("🔘 [UI] Checkbox button clicked!")
                    onCheckToggle?() 
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        
                        if isChecked {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue)
                                .frame(width: 14, height: 14)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Rest of the row - responds to row tap
                HStack(spacing: 10) {
                    // App Icon or SF Symbol
                    if let nsImage = appIcon {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(iconBackgroundColor)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Text(String(format: L("%d mục"), count))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onRowTap?()
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
    }
    
    private var iconBackgroundColor: Color {
        switch icon {
        case "lock.shield": return Color.purple.opacity(0.8)
        case "clock": return Color.blue.opacity(0.8)
        case "wifi": return Color.cyan.opacity(0.8)
        case "message": return Color.green.opacity(0.8)
        case "terminal": return Color.orange.opacity(0.8)
        default: return Color.gray.opacity(0.5)
        }
    }
}

// Polygon Shape for Stop Sign
struct PolygonShape: Shape {
    var sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        let angle = CGFloat.pi * 2 / CGFloat(sides)
        let rotationOffset = CGFloat.pi / CGFloat(sides) // Rotate to have flat top/bottom for octagon? No, flat side for stop sign usually requires 22.5 deg offset
        
        let startAngle = -CGFloat.pi / 2 + rotationOffset // Start from top
        
        for i in 0..<sides {
            let currentAngle = startAngle + angle * CGFloat(i)
            let x = center.x + radius * cos(currentAngle)
            let y = center.y + radius * sin(currentAngle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct PrivacyRow: View {
    let item: PrivacyItem
    @ObservedObject var service: PrivacyScannerService
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in
                    service.toggleSelection(for: item.id)
                }
            ))
            .toggleStyle(CheckboxStyle())
            .labelsHidden()
            
            // Icon
            Group {
                if let customIcon = getIconForType(item) {
                     Image(systemName: customIcon)
                } else {
                     Image(systemName: item.type.icon)
                }
            }
            .foregroundColor(.white)
            .frame(width: 20)
            
            // Name & Count Extraction
            let components = item.displayPath.components(separatedBy: " - ")
            let name = components.first ?? item.displayPath
            let countInfo = components.count > 1 ? components.last : nil
            
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white)
            
            Spacer()
            
            if let countText = countInfo {
                // Nếu chúng tôi có số lượng cụ thể (ví dụ: "1316 bản ghi"), hãy hiển thị nó một cách nổi bật

                Text(countText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.trailing, 8)
            } else {
                // Otherwise show size
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
    }
    
    // Helper to get better icons based on the display path content
    private func getIconForType(_ item: PrivacyItem) -> String? {
        let path = item.displayPath.lowercased()
        if path.contains("cookie") { return "cookie" } // Yêu cầu Ký hiệu SF 3.0+ cho cookie, dự phòng cho Circle.grid.crosh
        if path.contains("tải xuống") || path.contains("downloads") { return "arrow.down.circle" }
        if path.contains("mật khẩu") || path.contains("password") { return "key.fill" }
        if path.contains("tự động điền") || path.contains("autofill") { return "text.cursor" }
        if path.contains("lịch sử") || path.contains("history") { return "clock" }
        if path.contains("tìm kiếm") || path.contains("search") { return "magnifyingglass" }
        return nil
    }
}
