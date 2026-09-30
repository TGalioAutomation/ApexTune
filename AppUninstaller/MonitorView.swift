import SwiftUI
import AppKit

// MARK: - Console Dashboard
struct MonitorView: View {
    @State private var viewState: DashboardState = .dashboard
    @ObservedObject var loc = LocalizationManager.shared
    /// Một instance duy nhất cho cả module: tạo service riêng trong body (hoặc riêng từng view con)
    /// sẽ sinh polling trùng và mất dữ liệu đã lấy; lifecycle start/stop tập trung ở đây
    @StateObject private var systemService = SystemMonitorService()
    /// Observer occlusion của cửa sổ — cửa sổ ẩn thì phải dừng sampling (xem onAppear)
    @State private var windowVisibilityObservers: [NSObjectProtocol] = []
    
    enum DashboardState {
        case dashboard
        case appManager
        case portManager
        case processManager

        case networkOptimize  // Mới: Tối ưu hóa mạng
        case protection // Mới: Bảo vệ an ninh
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            ConsoleSidebar(selection: $viewState)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Right Content
            ZStack {
                switch viewState {
                case .dashboard:
                    ConsoleOverviewView(viewState: $viewState, systemMonitor: systemService)
                        .transition(.opacity)
                case .protection:
                    ConsoleProtectionView(viewState: $viewState)
                        .transition(.opacity)
                case .appManager:
                    ConsoleAppManagerView(viewState: $viewState)
                        .transition(.opacity)
                case .portManager:
                    ConsolePortManagerView(viewState: $viewState)
                        .transition(.opacity)
                case .processManager:
                    ConsoleProcessManagerView(viewState: $viewState)
                        .transition(.opacity)
                case .networkOptimize:
                    ConsoleNetworkOptimizeView(viewState: $viewState, systemService: systemService)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear) // Gradient is in main window
        }
        .animation(.easeInOut(duration: 0.2), value: viewState)
        .onAppear {
            // Cửa sổ chính bị orderOut ngay sau launch nhưng view tree vẫn sống:
            // nếu chỉ bám vào onAppear thì sampling sẽ chạy mãi trong cửa sổ ẩn và
            // render lại ngầm ~mỗi giây (~4-6% CPU). Chỉ sampling khi cửa sổ thật sự hiển thị.
            syncMonitoringWithWindowVisibility()
            observeWindowVisibility()
        }
        .onDisappear {
            removeWindowVisibilityObservers()
            systemService.stopMonitoring()
        }
    }

    /// Cửa sổ chuẩn = cửa sổ chính của app, đang hiển thị. Loại popup menu bar
    /// (MenuBarWindow), các window của status item (NSStatusBarWindow là class private
    /// nên phải soi tên — chúng luôn báo isVisible=true khiến predicate chỉ lọc
    /// is NSPanel bị hỏng), và mọi panel
    private static func anyStandardWindowVisible() -> Bool {
        NSApp.windows.contains { (window: NSWindow) in
            // occlusionState thay cho isVisible: isVisible vẫn true với cửa sổ thu nhỏ
            // vào Dock hoặc nằm ở Space khác (không ai thấy) — sampling sẽ chạy thừa
            window.occlusionState.contains(.visible)
                && window.level == .normal
                && !(window is MenuBarWindow)
                && !String(describing: type(of: window)).contains("StatusBar")
        }
    }

    private func syncMonitoringWithWindowVisibility() {
        if Self.anyStandardWindowVisible() {
            systemService.startMonitoring()
        } else {
            systemService.stopMonitoring()
        }
    }

    private func observeWindowVisibility() {
        guard windowVisibilityObservers.isEmpty else { return }
        windowVisibilityObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: nil,
                queue: .main
            ) { _ in
                syncMonitoringWithWindowVisibility()
            }
        )
    }

    private func removeWindowVisibilityObservers() {
        windowVisibilityObservers.forEach(NotificationCenter.default.removeObserver)
        windowVisibilityObservers = []
    }
}

// MARK: - 1. Dashboard Home View
struct ConsoleDashboardView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var loc = LocalizationManager.shared
    @ObservedObject var scanManager = ScanServiceManager.shared
    @StateObject private var systemService = SystemMonitorService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(L("Trung tâm hệ thống"))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Text(L("Tổng quan và quản lý hệ thống"))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(32)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top Stats: System Stats, Network (Reorganized)
                    HStack(spacing: 16) {
                        // CPU & Memory Circle
                        MonitorCard(title: L("Tải hệ thống"), icon: "cpu", color: .blue) {
                            HStack(spacing: 20) {
                                UsageRing(percentage: systemService.cpuUsage, label: "CPU", subLabel: String(format: "%.0f%%", systemService.cpuUsage * 100))
                                UsageRing(percentage: systemService.memoryUsage, label: "RAM", subLabel: String(format: "%.0f%%", systemService.memoryUsage * 100))
                            }
                        }
                        
                        // Network Speed ​​Card - Click để vào tối ưu mạng

                        Button(action: {
                            viewState = .networkOptimize
                        }) {
                            MonitorCard(title: L("Mạng"), icon: "wifi", color: .green) {
                                VStack(spacing: 8) {
                                    // Đồ thị dạng sóng

                                    NetworkWaveform(downloadHistory: systemService.downloadSpeedHistory, uploadHistory: systemService.uploadSpeedHistory)
                                        .frame(height: 40)
                                    
                                    // hiển thị tốc độ

                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green)
                                            Text(systemService.formatSpeed(systemService.downloadSpeed))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 10))
                                                .foregroundColor(.cyan)
                                            Text(systemService.formatSpeed(systemService.uploadSpeed))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 160)
                    
                    Text(L("Công cụ quản lý"))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    // Function Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // App Management
                        DashboardButton(
                            title: L("Trình quản lý ứng dụng"),
                            description: L("Quản lý ứng dụng, buộc thoát, đặt lại"),
                            icon: "square.grid.2x2.fill",
                            color: .cyan
                        ) {
                            viewState = .appManager
                        }
                        
                        // Port Management
                        DashboardButton(
                            title: L("Quản lý cổng mạng"),
                            description: L("Xem và đóng các cổng mạng"),
                            icon: "network",
                            color: .purple
                        ) {
                            viewState = .portManager
                        }
                        
                        // Process Management
                        DashboardButton(
                            title: L("Quản lý tiến trình"),
                            description: L("Giám sát và tiêu diệt các tiến trình nền"),
                            icon: "waveform.path.ecg",
                            color: .green
                        ) {
                            viewState = .processManager
                        }
                        
                        // Protection Center
                        DashboardButton(
                            title: L("Bảo vệ hệ thống"),
                            description: ProtectionService.shared.isMonitoring ? L("Bật bảo vệ thời gian thực") : L("Bảo vệ bị vô hiệu hóa"),
                            icon: "shield.checkerboard",
                            color: ProtectionService.shared.isMonitoring ? .green : .orange
                        ) {
                            viewState = .protection
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            systemService.startMonitoring()
            // Đảm bảo kích thước rác được cập nhật

            if !scanManager.isAnyScanning && scanManager.totalCleanableSize == 0 {
                Task {
                    // Tùy chọn: Bắt đầu quét rác một cách âm thầm

                     scanManager.startJunkScanIfNeeded()
                     scanManager.startSmartCleanScanIfNeeded()
                }
            }
        }
        .onDisappear {
            systemService.stopMonitoring()
        }
    }
}

// MARK: - 2. App Management View
struct ConsoleAppManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var appScanner = AppScanner()
    @StateObject private var processService = ProcessService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    @State private var isScanning = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            ConsoleHeader(
                title: L("Trình quản lý ứng dụng"),
                backAction: { viewState = .dashboard }
            )
            
            // Search & Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(L("Tìm kiếm ứng dụng..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if isScanning {
                Spacer()
                ProgressView()
                Text(L("Đang tải ứng dụng..."))
                    .foregroundColor(.secondaryText)
                    .padding(.top)
                Spacer()
            } else {
                List {
                    // Header Row
                    HStack {
                        Text(L("Tên ứng dụng"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(L("Trạng thái"))
                            .frame(width: 80, alignment: .leading)
                        Text(L("hành động"))
                            .frame(width: 200, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    ForEach(filteredApps) { app in
                        AppManagerRow(app: app, processService: processService, appScanner: appScanner, loc: loc)
                            .listRowBackground(Color.white.opacity(0.02))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // Combine AppScanner data with Running status
    struct AppViewModel: Identifiable {
        let id: UUID
        let installedApp: InstalledApp
        var isRunning: Bool
        var processItem: ProcessItem?
    }
    
    @State private var appViewModels: [AppViewModel] = []
    
    var filteredApps: [AppViewModel] {
        if searchText.isEmpty {
            return appViewModels
        }
        return appViewModels.filter { $0.installedApp.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func loadData() {
        Task {
            isScanning = true
            if appScanner.apps.isEmpty {
                await appScanner.scanApplications()
            }
            
            await processService.scanProcesses(showApps: true)
            
            var viewModels: [AppViewModel] = []
            // Map validation path (bundle path) to running process items
            let runningMap = Dictionary(grouping: processService.processes, by: { $0.validationPath ?? "" })
            
            for app in appScanner.apps {
                var isRunning = false
                var pItem: ProcessItem? = nil
                
                if let processes = runningMap[app.path.path], let first = processes.first {
                    isRunning = true
                    pItem = first
                } else if let p = processService.processes.first(where: { $0.name == app.name }) {
                     isRunning = true
                     pItem = p
                }
                
                viewModels.append(AppViewModel(id: app.id, installedApp: app, isRunning: isRunning, processItem: pItem))
            }
            
            viewModels.sort {
                if $0.isRunning != $1.isRunning {
                    return $0.isRunning
                }
                return $0.installedApp.name < $1.installedApp.name
            }
            
            await MainActor.run {
                self.appViewModels = viewModels
                self.isScanning = false
            }
        }
    }
}

struct AppManagerRow: View {
    let app: ConsoleAppManagerView.AppViewModel
    @ObservedObject var processService: ProcessService
    @ObservedObject var appScanner: AppScanner // Mới
    @ObservedObject var installedApp: InstalledApp // Đối tượng này phải được quan sát để kích hoạt làm mới
    var loc: LocalizationManager
    
    @State private var isRunningLocal: Bool
    @State private var isSpinning = false
    @State private var showSuccess = false
    @State private var showCleanConfirmation = false
    
    init(app: ConsoleAppManagerView.AppViewModel, processService: ProcessService, appScanner: AppScanner, loc: LocalizationManager) {
        self.app = app
        self.processService = processService
        self.appScanner = appScanner
        self.installedApp = app.installedApp // Liên kết đối tượng quan sát
        self.loc = loc
        self._isRunningLocal = State(initialValue: app.isRunning)
    }
    
    var body: some View {
        HStack {
            appIconView
            appInfoView
            Spacer()
            statusView
            actionsView
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var appIconView: some View {
        Image(nsImage: installedApp.icon)
            .resizable()
            .frame(width: 32, height: 32)
    }
    
    private var appInfoView: some View {
        VStack(alignment: .leading) {
            Text(installedApp.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(String(format: L("Kích thước ứng dụng: %@"), installedApp.formattedSize))
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var statusView: some View {
        HStack {
            if isRunningLocal {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text(L("Đang chạy"))
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text(L("Đã dừng"))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(width: 80, alignment: .leading)
    }
    
    private var actionsView: some View {
        HStack(spacing: 12) {
            cleanButton
            forceQuitButton
        }
        .frame(width: 200, alignment: .trailing)
    }
    
    private var cleanButton: some View {
        Button(action: {
            showCleanConfirmation = true
        }) {
            HStack(spacing: 4) {
                if isSpinning {
                    ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                    Text(L("Làm sạch..."))
                } else if showSuccess {
                    Image(systemName: "checkmark")
                    Text(L("Xong"))
                } else {
                    Image(systemName: "eraser")
                    Text(L("Lau dọn"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(showSuccess ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
            .foregroundColor(showSuccess ? .green : .white)
            .cornerRadius(6)
            .frame(width: 100)
        }
        .disabled(isSpinning)
        .buttonStyle(.plain)
        .help(L("Làm sạch dữ liệu ứng dụng (giữ ứng dụng được cài đặt)"))
        .alert(isPresented: $showCleanConfirmation) {
            Alert(
                title: Text(L("Xác nhận sạch")),
                message: Text(String(format: L("Thao tác này sẽ xóa tất cả bộ nhớ đệm, nhật ký và dữ liệu cấu hình.\nBản thân ứng dụng (%@ ) sẽ được giữ lại."), app.installedApp.formattedSize)),
                primaryButton: .destructive(Text(L("Làm sạch dữ liệu"))) {
                    Task {
                        isSpinning = true
                        showSuccess = false
                        
                        // Minimum 1s delay for visual feedback
                        let startTime = Date()
                        
                        if isRunningLocal, let item = app.processItem {
                             await processService.cleanAppData(for: item)
                             withAnimation { isRunningLocal = false }
                        } else {
                            // If stopped, manually scan and remove residuals
                            let scanner = ResidualFileScanner()
                            let files = await scanner.scanResidualFiles(for: app.installedApp)
                            
                             if !files.isEmpty {
                                 for file in files { file.isSelected = true }
                                 let appWithFiles = app.installedApp
                                 appWithFiles.residualFiles = files
                                 let remover = FileRemover()
                                 _ = await remover.removeResidualFiles(of: appWithFiles, moveToTrash: true)
                             }
                        }
                        
                        // Ensure spinner shows for at least a moment
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed < 0.8 {
                            try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                        }
                        
                        // Làm mới kích thước ứng dụng

                        await appScanner.refreshAppSize(for: app.installedApp)
                        
                        await MainActor.run {
                            isSpinning = false
                            showSuccess = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSuccess = false
                            }
                        }
                    }
                },
                secondaryButton: .cancel(Text(L("Hủy bỏ")))
            )
        }
    }
    
    private var forceQuitButton: some View {
        Group {
            if isRunningLocal {
                Button(action: {
                    if let item = app.processItem {
                        processService.forceTerminateProcess(item)
                        withAnimation { isRunningLocal = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.octagon.fill")
                        Text(L("Buộc thoát"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                // Placeholder
                Color.clear.frame(width: 90, height: 26)
            }
        }
    }
}

// MARK: - 3. Port Management View
struct ConsolePortManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var portService = PortScannerService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Quản lý cổng mạng"),
                backAction: { viewState = .dashboard },
                refreshAction: { Task { await portService.scanPorts() } }
            )
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(L("Tìm kiếm cổng, PID..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if portService.isScanning {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        HStack {
                            Text(L("Quá trình"))
                                .frame(width: 150, alignment: .leading)
                            Text("PID")
                                .frame(width: 60, alignment: .leading)
                            Text(L("Cảng"))
                                .frame(width: 80, alignment: .leading)
                            Text(L("nguyên mẫu"))
                                .frame(width: 60, alignment: .leading)
                            Spacer()
                            Text(L("Hoạt động"))
                                .frame(width: 60)
                        }
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        
                        ForEach(portService.ports.filter {
                            searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || String($0.pid).contains(searchText) || $0.portString.contains(searchText)
                        }) { port in
                            HStack {
                                HStack(spacing: 8) {
                                    if let icon = port.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "network")
                                            .foregroundColor(.cyan)
                                    }
                                    Text(port.displayName).lineLimit(1)
                                }
                                .frame(width: 150, alignment: .leading)
                                
                                Text(String(port.pid))
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(port.portString)
                                    .frame(width: 80, alignment: .leading)
                                    .foregroundColor(.cyan)
                                    .fontWeight(.medium)
                                
                                Text(port.protocol)
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                                
                                Button(action: { portService.terminateProcess(port) }) {
                                    Text(L("Giết"))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.6))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 60)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.02))
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await portService.scanPorts() }
        }
    }
}

// MARK: - 4. Process Management View
struct ConsoleProcessManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var processService = ProcessService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Quy trình nền"),
                backAction: { viewState = .dashboard },
                refreshAction: { Task { await processService.scanProcesses(showApps: false) } }
            )
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(L("Quá trình tìm kiếm..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if processService.isScanning {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(processService.processes.filter { 
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) 
                        }) { item in
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("PID: \(item.pid)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Text(item.formattedMemory)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.trailing, 10)
                                
                                Button(action: { processService.forceTerminateProcess(item) }) {
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                .help(L("Buộc thoát"))
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(6)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .onAppear {
            Task { await processService.scanProcesses(showApps: false) }
        }
    }
}

// MARK: - Components

struct ConsoleHeader: View {
    let title: String
    let backAction: () -> Void
    var refreshAction: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Button(action: backAction) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text(title)
                        .font(.title2)
                        .bold()
                }
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if let refresh = refreshAction {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
    }
}

struct DashboardButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .padding(12)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white.opacity(isHovering ? 0.1 : 0.05))
            .cornerRadius(16)
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3), value: isHovering)
    }
}

struct MonitorCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct UsageRing: View {
    let percentage: Double
    let label: String
    let subLabel: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: percentage)
            
            VStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(subLabel)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - 5. Console Junk Clean View (Dọn dẹp Console Junk)

struct ConsoleJunkCleanView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showCleaningFinished = false
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // Kiểm tra xem có kết quả quét không

    private var hasScanResults: Bool {
        return service.systemJunkTotalSize > 0 ||
               !service.duplicateGroups.isEmpty ||
               !service.similarPhotoGroups.isEmpty ||
               !service.largeFiles.isEmpty ||
               !service.userCacheFiles.isEmpty ||
               !service.systemCacheFiles.isEmpty
    }
    
    // Tính tổng kích thước được quét

    private var totalScannedSize: Int64 {
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .largeFiles
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
            if service.isScanning {
                scanningView
            } else if service.isCleaning || showRetryWithAdmin {
                cleaningView
            } else if showCleaningFinished {
                cleaningFinishedView
            } else if hasScanResults {
                resultsView
            } else {
                noDataView
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
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
            Button(loc.L("cancel"), role: .cancel) {
                showCleaningFinished = true
            }
        } message: {
            let totalFailedSize = failedFiles.reduce(0) { $0 + $1.size }
            Text(String(format: L("Không thể xóa một số tệp (%@)."), ByteCountFormatter.string(fromByteCount: totalFailedSize, countStyle: .file)))
        }
    }
    
    // MARK: - Không xem dữ liệu (quét kích hoạt)

    private var noDataView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Dọn dẹp rác"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "trash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
            }
            .padding(.bottom, 30)
            
            Text(L("Chưa có dữ liệu rác"))
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(L("Chạy quét hệ thống để phát hiện các tập tin rác có thể dọn dẹp được"))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 40)
            
            Button(action: {
                Task {
                    await service.scanAll()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(L("Bắt đầu quét"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - Chế độ xem quét

    private var scanningView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Dọn dẹp rác"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            Text(L("Đang quét..."))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            VStack(alignment: .leading, spacing: 20) {
                let categories: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                
                ForEach(categories, id: \.self) { category in
                    CleaningTaskRow(
                        icon: category.icon,
                        color: category.color,
                        title: category.rawValue,
                        status: getScanningStatus(for: category),
                        fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                    )
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            CircularActionButton(
                title: L("Dừng lại"),
                gradient: CircularActionButton.stopGradient,
                progress: service.scanProgress,
                showProgress: true,
                scanSize: ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file),
                action: {
                    service.stopScanning()
                }
            )
            .padding(.bottom, 40)
            
            Text(service.currentScanPath)
                .font(.caption)
                .foregroundColor(.secondaryText.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - xem kết quả

    private var resultsView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Dọn dẹp rác"),
                backAction: { viewState = .dashboard },
                refreshAction: {
                    Task {
                        service.resetAll()
                        await service.scanAll()
                    }
                }
            )
            
            Spacer()
            
            Text(L("Quét hoàn tất"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(L("Đã tìm thấy các tập tin rác sau"))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 30)
            
            // Tổng quan về kết quả

            HStack(spacing: 20) {
                ResultCategoryCard(
                    icon: "internaldrive.fill",
                    iconColor: .blue,
                    title: L("Dọn dẹp"),
                    subtitle: L("Xóa rác"),
                    value: ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file),
                    hasDetails: true,
                    onDetailTap: {
                        initialDetailCategory = nil
                        showDetailSheet = true
                    }
                )
            }
            
            Spacer()
            
            CircularActionButton(
                title: L("Dọn dẹp"),
                gradient: CircularActionButton.greenGradient,
                action: {
                    showDeleteConfirmation = true
                }
            )
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Dọn dẹp giữa view

    private var cleaningView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Dọn dẹp rác"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            Text(L("Đang dọn hệ thống..."))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            VStack(alignment: .leading, spacing: 20) {
                let categoriesToClean: [CleanerCategory] = {
                    let all: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                    return all.filter { service.sizeFor(category: $0) > 0 }
                }()
                
                ForEach(categoriesToClean, id: \.self) { category in
                    CleaningTaskRow(
                        icon: category.icon,
                        color: category.color,
                        title: category.rawValue,
                        status: getCleaningStatus(for: category),
                        fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                    )
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                
                Text(L("Vệ sinh"))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Dọn dẹp khung nhìn hoàn thành

    private var cleaningFinishedView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Dọn dẹp rác"),
                backAction: {
                    showCleaningFinished = false
                    viewState = .dashboard
                }
            )
            
            Spacer()
            
            // biểu tượng máy tính

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.pink.opacity(0.8))
                    .frame(width: 200, height: 140)
                    .shadow(color: .pink.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 40)
            
            // Tiêu đề kết quả

            Text(L("Làm tốt!"))
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(L("Máy Mac của bạn đang ở trạng thái tốt."))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 30)
            
            // Thống kê kết quả

            HStack(spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(ByteCountFormatter.string(fromByteCount: (deleteResult?.size ?? 0), countStyle: .file))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Text(L("Đã xóa rác"))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            Button(action: {
                showCleaningFinished = false
                // Sau khi dọn dẹp xong, quét lại để làm mới số liệu thống kê

                Task {
                    service.resetAll()
                    await service.scanAll()
                }
                viewState = .dashboard
            }) {
                Text(L("Quay lại Trung tâm hệ thống"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Helper Functions
    private func getScanningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        let isCurrent = service.currentCategory == category
        let isCompleted = !isCurrent && (
            (category == .systemJunk && [.duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) ||
            (category == .duplicates && [.similarPhotos, .largeFiles].contains(service.currentCategory)) ||
            (category == .similarPhotos && [.largeFiles].contains(service.currentCategory))
        )
        
        if isCurrent { return .processing }
        if isCompleted { return .completed }
        return .waiting
    }
    
    private func getCleaningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        if service.cleanedCategories.contains(category) {
            return .completed
        } else if service.cleaningCurrentCategory == category {
            return .processing
        } else {
            return .waiting
        }
    }
}

// MARK: - Network Waveform Component
struct NetworkWaveform: View {
    let downloadHistory: [Double]
    let uploadHistory: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Download Wave (green)
                Path { path in
                    drawWave(path: &path, data: downloadHistory, size: geometry.size)
                }
                .stroke(
                    LinearGradient(colors: [.green.opacity(0.8), .green.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
                
                // Download Fill
                Path { path in
                    drawWaveFill(path: &path, data: downloadHistory, size: geometry.size)
                }
                .fill(
                    LinearGradient(colors: [.green.opacity(0.3), .green.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )
                
                // Upload Wave (cyan)
                Path { path in
                    drawWave(path: &path, data: uploadHistory, size: geometry.size)
                }
                .stroke(
                    LinearGradient(colors: [.cyan.opacity(0.8), .cyan.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            }
        }
    }
    
    private func drawWave(path: inout Path, data: [Double], size: CGSize) {
        guard data.count > 1 else { return }
        
        let maxValue = max(data.max() ?? 1, 1000) // Tỷ lệ tối thiểu ít nhất là 1KB/s
        let stepX = size.width / CGFloat(data.count - 1)
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = min(value / maxValue, 1.0)
            let y = size.height - (CGFloat(normalizedY) * size.height * 0.9)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func drawWaveFill(path: inout Path, data: [Double], size: CGSize) {
        guard data.count > 1 else { return }
        
        let maxValue = max(data.max() ?? 1, 1000)
        let stepX = size.width / CGFloat(data.count - 1)
        
        path.move(to: CGPoint(x: 0, y: size.height))
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = min(value / maxValue, 1.0)
            let y = size.height - (CGFloat(normalizedY) * size.height * 0.9)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
    }
}

// MARK: - 6. Network Optimize View
struct ConsoleNetworkOptimizeView: View {
    @Binding var viewState: MonitorView.DashboardState
    /// Dùng chung service từ MonitorView — trước đây view này giữ service riêng nhưng không bao giờ
    /// startMonitoring nên tốc độ mạng/biểu đồ luôn hiển thị 0
    @ObservedObject var systemService: SystemMonitorService
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var isOptimizing = false
    @State private var optimizationComplete = false
    @State private var optimizationProgress = 0.0
    @State private var currentOptimization = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Tối ưu hóa mạng"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            if isOptimizing {
                optimizingView
            } else if optimizationComplete {
                completeView
            } else {
                mainView
            }
            
            Spacer()
        }
    }
    
    // Giao diện chính

    private var mainView: some View {
        VStack(spacing: 30) {
            // biểu tượng mạng

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "wifi")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            
            // Hiển thị tốc độ mạng hiện tại

            VStack(spacing: 16) {
                Text(L("Tốc độ mạng hiện tại"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text(L("Tải xuống"))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        Text(systemService.formatSpeed(systemService.downloadSpeed))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.cyan)
                            Text(L("Tải lên"))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        Text(systemService.formatSpeed(systemService.uploadSpeed))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Đồ thị dạng sóng

                NetworkWaveform(downloadHistory: systemService.downloadSpeedHistory, uploadHistory: systemService.uploadSpeedHistory)
                    .frame(height: 80)
                    .frame(maxWidth: 400)
                    .padding(.top, 20)
            }
            
            // Nút tối ưu hóa

            Button(action: { startOptimization() }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text(L("Tối ưu hóa mạng"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            
            // Hướng dẫn tối ưu hóa

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Tối ưu hóa mạng sẽ:"))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    OptimizationItem(text: L("Xóa bộ đệm DNS"))
                    OptimizationItem(text: L("Xóa các tập tin tạm thời mạng"))
                    OptimizationItem(text: L("Tối ưu hóa cài đặt mạng"))
                }
            }
            .padding(.top, 30)
        }
    }
    
    // Chế độ xem được tối ưu hóa

    private var optimizingView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: optimizationProgress)
                    .stroke(
                        LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "wifi")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            
            Text(L("Tối ưu hóa mạng..."))
                .font(.title2)
                .foregroundColor(.white)
            
            Text(currentOptimization)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
    
    // Chế độ xem hoàn chỉnh

    private var completeView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(L("Hoàn tất tối ưu hóa mạng"))
                .font(.title2)
                .foregroundColor(.white)
            
            Text(L("Mạng của bạn đã được tối ưu hóa"))
                .font(.body)
                .foregroundColor(.secondaryText)
            
            Button(action: { viewState = .dashboard }) {
                Text(L("Quay lại Trung tâm hệ thống"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }
    
    private func startOptimization() {
        isOptimizing = true
        optimizationProgress = 0
        
        let steps = [
            (L("Đang xóa bộ đệm DNS..."), "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"),
            (L("Làm sạch các tập tin tạm thời mạng..."), "rm -rf ~/Library/Caches/com.apple.network* 2>/dev/null"),
            (L("Đang tối ưu hóa cài đặt mạng..."), "networksetup -setairportpower en0 off 2>/dev/null; sleep 1; networksetup -setairportpower en0 on 2>/dev/null")
        ]
        
        Task {
            for (index, step) in steps.enumerated() {
                await MainActor.run {
                    currentOptimization = step.0
                }
                
                // Mô phỏng quá trình tối ưu hóa

                try? await Task.sleep(nanoseconds: 800_000_000)
                
                await MainActor.run {
                    optimizationProgress = Double(index + 1) / Double(steps.count)
                }
            }
            
            await MainActor.run {
                isOptimizing = false
                optimizationComplete = true
            }
        }
    }
}

struct OptimizationItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Protection View
struct ConsoleProtectionView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var protectionService = ProtectionService.shared
    @ObservedObject var loc = LocalizationManager.shared
    @State private var selectedTab = 0 // 0: Ads, 1: Threats
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: L("Bảo vệ hệ thống"),
                backAction: { viewState = .dashboard }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(protectionService.isMonitoring ? L("Bảo vệ thời gian thực: BẬT") : L("Bảo vệ thời gian thực: TẮT"))
                                .font(.title3)
                                .bold()
                                .foregroundColor(protectionService.isMonitoring ? .green : .white)
                            
                            Text(L("Giám sát tải xuống và chặn quảng cáo"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { protectionService.isMonitoring },
                            set: { newValue in
                                if newValue {
                                    protectionService.startMonitoring() 
                                } else {
                                    protectionService.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Statistics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Downloads Monitored
                        MonitorStatCard(
                            title: L("Tải xuống"),
                            value: L("Active"),
                            icon: "arrow.down.circle.fill",
                            color: .blue
                        )
                        
                        // Ads Blocked
                        MonitorStatCard(
                            title: L("Quảng cáo bị chặn"),
                            value: "\(protectionService.adBlockedCount)",
                            icon: "hand.raised.fill",
                            color: .orange
                        )
                        
                        // Threats
                        MonitorStatCard(
                            title: L("Mối đe dọa"),
                            value: "\(protectionService.threatHistory.count)",
                            icon: "exclamationmark.shield.fill",
                            color: .red
                        )
                    }
                    
                    // Details Section
                    VStack(spacing: 16) {
                        // Tab Picker
                        Picker("", selection: $selectedTab) {
                            Text(L("Quảng cáo bị chặn")).tag(0)
                            Text(L("Các mối đe dọa đã phát hiện")).tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if selectedTab == 0 {
                            // Ads List
                            if protectionService.blockedAds.isEmpty {
                                EmptyStateView(
                                    icon: "hand.raised",
                                    title: L("Không có quảng cáo nào bị chặn"),
                                    subtitle: L("Quảng cáo sẽ bị chặn khi duyệt")
                                )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(protectionService.blockedAds) { ad in
                                        HStack {
                                            Image(systemName: "safari.fill") // Generic browser icon or based on source
                                                .foregroundColor(.orange)
                                                .frame(width: 20)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ad.domain)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                Text("\(ad.source) • \(formatDate(ad.date))")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(L("Bị chặn"))
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            // Threat List
                            if protectionService.threatHistory.isEmpty {
                                EmptyStateView(
                                    icon: "checkmark.shield",
                                    title: L("Không có mối đe dọa nào được phát hiện"),
                                    subtitle: L("Hệ thống của bạn hiện đang an toàn")
                                )
                            } else {
                                ForEach(protectionService.threatHistory) { threat in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        VStack(alignment: .leading) {
                                            Text(threat.name)
                                                .foregroundColor(.white)
                                            Text(threat.path.path)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        Text(L(threat.type.rawValue))
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.red.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.2))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
        .padding(40)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MonitorStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
