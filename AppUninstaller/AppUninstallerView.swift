import SwiftUI

struct AppUninstallerView: View {
    @ObservedObject var appScanner: AppScanner
    @State private var selectedCategory: AppCategory = .all
    @State private var searchText = ""
    @State private var selectedAppIds: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var detailedApp: InstalledApp?
    @ObservedObject private var loc = LocalizationManager.shared
    
    // Gỡ cài đặt trạng thái liên quan

    @State private var isUninstalling = false
    @State private var uninstallProgress: String = ""
    @State private var uninstallResults: [RemovalResult] = []
    @State private var showingResults = false
    @State private var totalRemovedSize: Int64 = 0
    @State private var totalSuccessCount = 0
    @State private var totalFailedCount = 0
    
    private let fileRemover = FileRemover()
    
    enum AppCategory: Hashable {
        case all
        case leftovers
        case appStore
        case vendor(String)
        
        var title: String {
            switch self {
            case .all: return L("Tất cả ứng dụng")
            case .leftovers: return L("Thức ăn thừa")
            case .appStore: return "App Store"
            case .vendor(let name): return name
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .leftovers: return "trash.slash"
            case .appStore: return "bag" // or app.badge
            case .vendor: return "building.2"
            }
        }
    }
    
    var filteredApps: [InstalledApp] {
        let baseApps: [InstalledApp]
        switch selectedCategory {
        case .all:
            baseApps = appScanner.apps
        case .leftovers:
            baseApps = appScanner.apps.filter { !$0.residualFiles.isEmpty } // Placeholder logic
        case .appStore:
            baseApps = appScanner.apps.filter { $0.isAppStore }
        case .vendor(let name):
            baseApps = appScanner.apps.filter { $0.vendor == name }
        }
        
        if searchText.isEmpty {
            return baseApps
        }
        return baseApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Vendors list
    var vendors: [String] {
        let allVendors = appScanner.apps.map { $0.vendor }
        let unique = Array(Set(allVendors)).sorted()
        return unique.filter { $0 != "Unknown" }
    }
    
    var totalSelectedSize: Int64 {
        appScanner.apps.filter { selectedAppIds.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // MARK: - Sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(loc.L("Trình gỡ cài đặt"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.3))
                    TextField(loc.L("search_apps"), text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                List {
                    // All Apps
                    SidebarRow(category: .all, count: appScanner.apps.count, isSelected: selectedCategory == .all)
                        .onTapGesture { selectedCategory = .all }
                    
                    // Leftovers (Placeholder)
                    SidebarRow(category: .leftovers, count: 0, isSelected: selectedCategory == .leftovers)
                        .onTapGesture { selectedCategory = .leftovers }
                    
                    Text(loc.L("Cửa hàng"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        .padding(.leading, 8)
                    
                    SidebarRow(category: .appStore, count: appScanner.apps.filter { $0.isAppStore }.count, isSelected: selectedCategory == .appStore)
                        .onTapGesture { selectedCategory = .appStore }
                    
                    Text(loc.L("Nhà cung cấp"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        .padding(.leading, 8)
                    
                    ForEach(vendors, id: \.self) { vendor in
                        SidebarRow(category: .vendor(vendor), count: appScanner.apps.filter { $0.vendor == vendor }.count, isSelected: selectedCategory == .vendor(vendor))
                            .onTapGesture { selectedCategory = .vendor(vendor) }
                    }
                }

                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(width: 250)
            // Left panel background removed for unification

            
            // MARK: - App List or Detail
            ZStack {
                if let app = detailedApp {
                    VStack(spacing: 0) {
                        // Navigation Bar
                        HStack {
                            Button(action: {
                                withAnimation {
                                    detailedApp = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(loc.L("Quay lại"))
                                }
                                .foregroundColor(.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .padding()
                            
                            Spacer()
                        }
                        .background(Color.cardBackground)
                        
                        AppDetailView(
                            app: app,
                            onDelete: { includeApp, toTrash in
                                Task {
                                    await performSingleAppUninstall(app: app, includeApp: includeApp, moveToTrash: toTrash)
                                }
                            }
                        )
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text(selectedCategory.title)
                                .font(.title2)
                                .foregroundColor(.white)
                            Spacer()
                            
                            Text(loc.L("Sắp xếp theo tên"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        
                        if appScanner.isScanning {
                             Spacer()
                             ProgressView()
                             Text(loc.L("Đang quét ứng dụng..."))
                                .padding(.top)
                             Spacer()
                        } else {
                            LazyListView(items: filteredApps, itemHeight: 56) { app in
                                AppChecklistRow(
                                    app: app,
                                    isSelected: selectedAppIds.contains(app.id),
                                    onToggleSelection: {
                                        if selectedAppIds.contains(app.id) {
                                            selectedAppIds.remove(app.id)
                                        } else {
                                            selectedAppIds.insert(app.id)
                                        }
                                    },
                                    onViewDetails: {
                                        withAnimation {
                                            detailedApp = app
                                        }
                                    }
                                )
                            }
                        }
                        
                        // Bottom Bar (Uninstall Action)
                        if !selectedAppIds.isEmpty {
                            HStack {
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Button(action: {
                                        showingDeleteConfirmation = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Circle().stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                                )
                                            
                                            VStack {
                                                Text(loc.L("Gỡ cài đặt"))
                                                    .foregroundColor(.white)
                                                    .fontWeight(.medium)
                                                Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.bottom, 20)
                                
                                Spacer()
                            }
                            .background(Color.white.opacity(0.05))
                            .transition(.move(edge: .bottom))
                        }
                    }
                    .transition(.move(edge: .leading))
                }
            }

            .frame(maxWidth: .infinity)
        }
        }
        .onAppear {
             if appScanner.apps.isEmpty {
                 Task { await appScanner.scanApplications() }
             }
        }
        // Hộp thoại xác nhận gỡ cài đặt

        .alert(loc.L("Xác nhận Gỡ cài đặt?"), isPresented: $showingDeleteConfirmation) {
            Button(loc.L("Hoàn tất Gỡ cài đặt"), role: .destructive) {
                Task {
                    await performUninstall()
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.L("Thao tác này sẽ xóa các ứng dụng đã chọn cùng toàn bộ tệp liên quan như tùy chọn, bộ đệm và nhật ký. Tệp sẽ được chuyển vào Thùng rác để có thể khôi phục nếu cần."))
        }
        // Chỉ báo tiến trình gỡ cài đặt

        .overlay {
            if isUninstalling {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(loc.L("Đang gỡ cài đặt..."))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(uninstallProgress)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardBackground)
                    )
                }
            }
        }
        // Hộp thoại gỡ cài đặt kết quả

        .alert(loc.L("Gỡ cài đặt hoàn tất"), isPresented: $showingResults) {
            Button("OK") {
                showingResults = false
            }
        } message: {
            if totalFailedCount > 0 {
                Text(String(format: loc.L("Đã xóa thành công %d mục, giải phóng %@, %d mục xóa thất bại"), totalSuccessCount, ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file), totalFailedCount))
            } else {
                Text(String(format: loc.L("Đã xóa thành công %d mục, giải phóng %@"), totalSuccessCount, ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file)))
            }
        }
    }
    
    // ĐÁNH DẤU: - Logic gỡ cài đặt

    
    ///Thực hiện quá trình gỡ cài đặt hoàn tất

    private func performUninstall() async {
        let appsToUninstall = appScanner.apps.filter { selectedAppIds.contains($0.id) }
        guard !appsToUninstall.isEmpty else { return }
        
        await MainActor.run {
            isUninstalling = true
            uninstallProgress = loc.L("Chuẩn bị...")
            totalRemovedSize = 0
            totalSuccessCount = 0
            totalFailedCount = 0
            uninstallResults = []
        }
        
        for app in appsToUninstall {
            // cập nhật tiến độ

            await MainActor.run {
                uninstallProgress = String(format: loc.L("Đang xử lý: %@"), app.name)
            }
            
            // Kiểm tra xem ứng dụng có đang chạy không

            if fileRemover.isAppRunning(app) {
                await MainActor.run {
                    uninstallProgress = String(format: loc.L("Đang đóng ứng dụng: %@"), app.name)
                }
                // Cố gắng chấm dứt ứng dụng

                let _ = fileRemover.terminateApp(app)
                // Đợi ứng dụng đóng

                try? await Task.sleep(nanoseconds: 1_000_000_000) // đợi 1 giây
                
                // Nếu nó vẫn đang chạy, buộc chấm dứt

                if fileRemover.isAppRunning(app) {
                    let _ = fileRemover.forceTerminateApp(app)
                    try? await Task.sleep(nanoseconds: 500_000_000) // Đợi 0,5 giây
                }
            }
            
            // Quét các tập tin còn sót lại

            await MainActor.run {
                uninstallProgress = String(format: loc.L("Đang quét tệp còn sót: %@"), app.name)
            }
            await appScanner.scanResidualFiles(for: app)
            
            // thực hiện xóa

            await MainActor.run {
                uninstallProgress = String(format: loc.L("Đang xóa: %@"), app.name)
            }
            
            let result = await fileRemover.removeApp(app, includeApp: true, moveToTrash: true)
            
            await MainActor.run {
                uninstallResults.append(result)
                totalSuccessCount += result.successCount
                totalFailedCount += result.failedCount
                totalRemovedSize += result.totalSizeRemoved
            }
            
            // Xóa ứng dụng đã gỡ cài đặt khỏi danh sách

            if result.failedCount == 0 || (result.successCount > 0 && result.failedPaths.first?.path != app.path.path) {
                await appScanner.removeFromList(app: app)
            }
        }
        
        await MainActor.run {
            isUninstalling = false
            selectedAppIds.removeAll()
            showingResults = true
        }
    }
    
    /// Thực hiện gỡ cài đặt một ứng dụng (được gọi từ trang chi tiết)

    private func performSingleAppUninstall(app: InstalledApp, includeApp: Bool, moveToTrash: Bool) async {
        await MainActor.run {
            isUninstalling = true
            uninstallProgress = String(format: loc.L("Đang xử lý: %@"), app.name)
            totalRemovedSize = 0
            totalSuccessCount = 0
            totalFailedCount = 0
        }
        
        // Kiểm tra xem ứng dụng có đang chạy không

        if includeApp && fileRemover.isAppRunning(app) {
            await MainActor.run {
                uninstallProgress = String(format: loc.L("Đang đóng ứng dụng: %@"), app.name)
            }
            let _ = fileRemover.terminateApp(app)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            if fileRemover.isAppRunning(app) {
                let _ = fileRemover.forceTerminateApp(app)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        
        // thực hiện xóa

        await MainActor.run {
            uninstallProgress = String(format: loc.L("Đang xóa: %@"), app.name)
        }
        
        let result = await fileRemover.removeApp(app, includeApp: includeApp, moveToTrash: moveToTrash)
        
        await MainActor.run {
            totalSuccessCount = result.successCount
            totalFailedCount = result.failedCount
            totalRemovedSize = result.totalSizeRemoved
        }
        
        // Xóa các ứng dụng đã gỡ cài đặt khỏi danh sách (chỉ khi chính ứng dụng đó cũng bị xóa)

        if includeApp && (result.failedCount == 0 || result.failedPaths.first?.path != app.path.path) {
            await appScanner.removeFromList(app: app)
            await MainActor.run {
                detailedApp = nil // Quay lại chế độ xem danh sách
            }
        }
        
        await MainActor.run {
            isUninstalling = false
            showingResults = true
        }
    }
    
    // MARK: - Subviews
    
    func SidebarRow(category: AppCategory, count: Int, isSelected: Bool) -> some View {
        HStack {
            // Radio button style selection indicator (from design image 1)
            ZStack {
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 16, height: 16)
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 10, height: 10)
                }
            }
            
            Text(category.title)
                .foregroundColor(.white)
                .font(.system(size: 13))
            
            Spacer()
            
            if count > 0 {
                Text("\(count)") // or size if preferred
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    struct AppChecklistRow: View {
        @ObservedObject var app: InstalledApp
        let isSelected: Bool
        let onToggleSelection: () -> Void
        let onViewDetails: () -> Void
        
        var body: some View {
            HStack(spacing: 12) {
                // Checkbox - Toggle Selection
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .purple : .secondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                // Content - View Details
                HStack(spacing: 12) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                    
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(app.formattedSize)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onViewDetails()
                }
            }
            .padding(12)
            .background(Color.clear) // Unified background, no specific row background
            .cornerRadius(8)
        }
    }
}
