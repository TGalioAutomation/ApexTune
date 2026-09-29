import SwiftUI
import AppKit
import Combine
import WidgetKit

enum MenuBarStatusMetric: String, CaseIterable, Identifiable {
    case gpu
    case storage
    case memory
    case cpu
    case network
    case battery
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .gpu: return "GPU"
        case .storage: return L("Ổ đĩa")
        case .memory: return "RAM"
        case .cpu: return "CPU"
        case .network: return L("Mạng")
        case .battery: return "Pin"
        }
    }
    
    var tooltipDescription: String {
        switch self {
        case .gpu: return L("Mức tải GPU hiện tại")
        case .storage: return L("Dung lượng trống và đã dùng của ổ đĩa")
        case .memory: return L("Phần trăm RAM đang được sử dụng")
        case .cpu: return L("Mức tải CPU hiện tại")
        case .network: return L("Tốc độ tải xuống và tải lên hiện tại")
        case .battery: return L("Phần trăm pin hiện tại")
        }
    }
    
    var symbolName: String {
        switch self {
        case .gpu: return "square.3.layers.3d.top.filled"
        case .storage: return "internaldrive"
        case .memory: return "memorychip"
        case .cpu: return "cpu"
        case .network: return "arrow.up.arrow.down"
        case .battery: return "battery.75"
        }
    }
}

public enum MenuBarRoute {
    case overview
    case storage
    case memory
    case battery
    case cpu
    case network
    case forceQuitApps
    case customization
}

class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()
    
    /// Kích thước popup "Bảng điều khiển hệ thống" — dùng chung cho view và cửa sổ.
    /// Chiều cao 720 để toàn bộ nội dung (kể cả footer điều hướng) hiển thị không cần cuộn.
    static let popupSize = CGSize(width: 390, height: 720)
    
    var statusItem: NSStatusItem?
    var popoverWindow: MenuBarWindow?
    var detailWindow: MenuBarWindow?
    var memoryAlertController: MemoryAlertWindowController?
    
    // Shared Source of Truth
    var systemMonitor = SystemMonitorService()
    private let diskManager = DiskSpaceManager.shared
    
    @Published var isOpen: Bool = false
    @Published var currentDetailRoute: MenuBarRoute? = nil
    @Published var selectedStatusMetrics: [MenuBarStatusMetric] = [.gpu, .cpu, .storage, .memory]
    @Published var showsStatusIcon: Bool = true
    /// Giao diện dải số liệu trên thanh menu (xem MenuBarBannerTheme).
    @Published var bannerTheme: MenuBarBannerTheme = .dark {
        didSet {
            guard oldValue != bannerTheme else { return }
            UserDefaults.standard.set(bannerTheme.rawValue, forKey: bannerThemeKey)
            updateStatusItemAppearance()
        }
    }
    
    // Cờ đã hoàn thành khởi tạo hay chưa

    private var isSetupComplete = false
    private var cancellables = Set<AnyCancellable>()
    private var diskRefreshTimer: Timer?
    /// Làm mới timeline widget theo định kỳ (widget tự đo lại mỗi 15 phút, app đôn thêm).
    private var widgetRefreshTimer: Timer?
    private let statusMetricsKey = "MenuBar.StatusMetrics"
    private let statusIconKey = "MenuBar.ShowsStatusIcon"
    private let bannerThemeKey = "MenuBar.BannerTheme"
    /// Leading mark in the menu bar banner; matches sidebar `AppBrandMark` (SF Symbol).
    private lazy var statusBarIconImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold, scale: .medium)
        if let image = NSImage(systemSymbolName: "shield.lefthalf.filled.badge.checkmark", accessibilityDescription: "MacOptimizer")?
            .withSymbolConfiguration(config) {
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(systemSymbolName: "macpro.gen3", accessibilityDescription: "MacOptimizer")
        fallback?.isTemplate = true
        return fallback
    }()

    /// Cache icon đã tô màu theo tint (theme nền sáng).
    private var tintedIconCache: [String: NSImage] = [:]

    /// Cache key nội dung banner lần vẽ gần nhất (tránh vẽ lại khi giá trị hiển thị không đổi)
    private var lastStatusRenderKey: String?
    
    override init() {
        super.init()
        // Trì hoãn việc khởi tạo để đảm bảo ứng dụng được khởi động hoàn toàn trước khi tạo mục trạng thái

        // Điều này ngăn ngừa sự cố do truy cập NSStatusBar khi ứng dụng khởi động

        DispatchQueue.main.async { [weak self] in
            self?.performDelayedSetup()
        }
    }
    
    /// Cài đặt thực thi bị trì hoãn để đảm bảo NSApp được khởi tạo hoàn toàn

    private func performDelayedSetup() {
        guard !isSetupComplete else { return }
        isSetupComplete = true
        
        loadStatusBarPreferences()
        systemMonitor.configureMenuBarSampling(statusMetrics: selectedStatusMetrics, detailRoute: currentDetailRoute, isMenuBarWindowOpen: isOpen)
        setupStatusItem()
        setupWindow()
        bindStatusBarUpdates()
        systemMonitor.startMonitoring()
        setupAutoClose()
        startWidgetRefresh()
    }

    /// Đôn WidgetKit làm mới timeline: mỗi 10 phút và mỗi lần mở bảng điều khiển.
    private func startWidgetRefresh() {
        widgetRefreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    ///Phương thức công khai: Đảm bảo rằng cài đặt đã hoàn tất (đối với các trường hợp yêu cầu sử dụng ngay)

    func ensureSetup() {
        if !isSetupComplete {
            performDelayedSetup()
        }
    }
    
    private func setupStatusItem() {
        // Hãy chắc chắn rằng bạn đang ở trong luồng chính và NSApp đã sẵn sàng

        guard Thread.isMainThread, NSApp != nil else {
            print("[MenuBarManager] ⚠️ NSApp not ready, deferring status item setup")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setupStatusItem()
            }
            return
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Chuột trái mở popup, chuột phải mở menu (bao gồm Thoát MacOptimizer)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusItemAppearance()
        }
    }
    
    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            showStatusMenu()
        } else {
            toggleWindow()
        }
    }
    
    /// Menu chuột phải của status item — nơi duy nhất có đường Thoát app
    private func showStatusMenu() {
        let menu = NSMenu()
        
        let openPanel = NSMenuItem(title: L("Mở bảng điều khiển"), action: #selector(toggleWindow), keyEquivalent: "")
        openPanel.target = self
        menu.addItem(openPanel)
        
        let openApp = NSMenuItem(title: L("Mở MacOptimizer"), action: #selector(openMainAppFromMenu), keyEquivalent: "")
        openApp.target = self
        menu.addItem(openApp)
        
        menu.addItem(.separator())
        
        let quit = NSMenuItem(title: L("Thoát MacOptimizer"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        
        // Gắn menu tạm thời để click hiển thị menu hệ thống, sau đó gỡ ra
        // để chuột trái tiếp tục mở popup như thường lệ
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func openMainAppFromMenu() {
        openMainApp()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func setupWindow() {
        // Main Overview Window
        // Pass self as EnvironmentObject so Views can call showDetail/closeWindow
        let contentView = MenuBarView()
            .environmentObject(self)
            .environmentObject(systemMonitor)
            .edgesIgnoringSafeArea(.all)
        
        let hostingController = NSHostingController(rootView: contentView)
        let window = MenuBarWindow(contentViewController: hostingController)
        self.popoverWindow = window
        window.level = .floating
        window.setContentSize(NSSize(width: Self.popupSize.width, height: Self.popupSize.height))
        
        // Khởi tạo bộ điều khiển cảnh báo bộ nhớ

        memoryAlertController = MemoryAlertWindowController(
            systemMonitor: systemMonitor,
            statusBarButton: statusItem?.button
        )
    }
    
    @objc func toggleWindow() {
        guard let _ = popoverWindow, let button = statusItem?.button else { return }
        
        if isOpen {
            closeWindow()
        } else {
            showWindow(relativeTo: button)
        }
    }
    
    private func showWindow(relativeTo button: NSStatusBarButton) {
        guard let window = popoverWindow else { return }
        
        // Neo popup vào chính giữa icon status item thay vì mặc định ở góc phải màn hình
        let padding: CGFloat = 12
        if let screen = button.window?.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            
            var anchorX = screenFrame.maxX - windowSize.width / 2 - padding
            if let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
                anchorX = buttonFrame.midX
            }
            
            let xPos = min(max(anchorX - windowSize.width / 2, screenFrame.minX + padding), screenFrame.maxX - windowSize.width - padding)
            let yPos = screenFrame.maxY - windowSize.height - 5
            
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        isOpen = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    func closeWindow() {
        // Close Detail First
        closeDetail()
        
        guard let window = popoverWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.isOpen = false
        })
    }
    
    // MARK: - Detail Window Logic
    
    func showDetail(route: MenuBarRoute) {
        // If already open with same route, do nothing or maybe just bring to front
        if currentDetailRoute == route && detailWindow != nil { return }
        
        // Close existing detail if different
        if detailWindow != nil {
             // For smooth transition, maybe just update content?
             // But for now, let's close and reopen or just swap root view if possible.
             // Swapping controller is easier.
             updateDetailWindow(route: route)
             return
        }
        
        createAndShowDetailWindow(route: route)
    }
    
    func closeDetail() {
        guard let window = detailWindow else { return }
        currentDetailRoute = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.detailWindow = nil
        })
    }
    
    private func createAndShowDetailWindow(route: MenuBarRoute) {
        let detailView = MenuBarDetailContainer(manager: self, systemMonitor: systemMonitor, route: route)
            .edgesIgnoringSafeArea(.all)
        
        let controller = NSHostingController(rootView: detailView)
        let window = MenuBarWindow(contentViewController: controller)
        self.detailWindow = window
        self.currentDetailRoute = route
        window.level = .floating
        
        if let mainWindow = popoverWindow {
            let detailSize = detailWindowSize(for: route)
            let targetFrame = detailWindowFrame(relativeTo: mainWindow, detailSize: detailSize)
            window.setFrame(targetFrame, display: true)
        }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    private func updateDetailWindow(route: MenuBarRoute) {
        // Just replace the rootViewController
        guard let window = detailWindow else { return }
        
        let detailView = MenuBarDetailContainer(manager: self, systemMonitor: systemMonitor, route: route)
             .edgesIgnoringSafeArea(.all)
        let newController = NSHostingController(rootView: detailView)
        
        window.contentViewController = newController
        let detailSize = detailWindowSize(for: route)
        if let mainWindow = popoverWindow {
            let targetFrame = detailWindowFrame(relativeTo: mainWindow, detailSize: detailSize)
            window.setFrame(targetFrame, display: true, animate: true)
        }
        currentDetailRoute = route
    }

    private func detailWindowSize(for route: MenuBarRoute) -> CGSize {
        switch route {
        case .forceQuitApps:
            return CGSize(width: 360, height: 520)
        case .customization:
            return CGSize(width: 348, height: 520)
        default:
            return CGSize(width: 360, height: 620)
        }
    }

    private func detailWindowFrame(relativeTo mainWindow: NSWindow, detailSize: CGSize) -> NSRect {
        let gap: CGFloat = 10
        let edgePadding: CGFloat = 8
        let mainFrame = mainWindow.frame
        let screenFrame = mainWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? mainFrame
        
        let preferredLeftX = mainFrame.minX - detailSize.width - gap
        let preferredRightX = mainFrame.maxX + gap
        let y = min(
            max(mainFrame.maxY - detailSize.height, screenFrame.minY + edgePadding),
            screenFrame.maxY - detailSize.height - edgePadding
        )
        
        let x: CGFloat
        if preferredLeftX >= screenFrame.minX + edgePadding {
            x = preferredLeftX
        } else if preferredRightX + detailSize.width <= screenFrame.maxX - edgePadding {
            x = preferredRightX
        } else {
            x = min(
                max(screenFrame.minX + edgePadding, preferredLeftX),
                screenFrame.maxX - detailSize.width - edgePadding
            )
        }
        
        return NSRect(origin: NSPoint(x: x, y: y), size: detailSize)
    }
    
    // MARK: - Open Main App
    
    func openMainApp(module: AppModule? = nil) {
        // Close menu bar windows
        closeWindow()
        // Keep utility behavior: no Dock icon even when opening main window.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and show the main window
        // The main app window usually exists if app is running.
        // We need to bring it to front or open it.
        
        // Option 1: Find existing window by looking for ContentView or similar
        for window in NSApp.windows {
            // Skip our own menu bar windows
            if window == popoverWindow || window == detailWindow {
                continue
            }
            
            // Look for the main app window (usually the one with title or specific content)
            if window.contentViewController != nil && window.isVisible == false {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                if let module {
                    NotificationCenter.default.post(name: .macOptimizerOpenModule, object: module)
                }
                return
            }
            
            if window.contentViewController != nil {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                if let module {
                    NotificationCenter.default.post(name: .macOptimizerOpenModule, object: module)
                }
                return
            }
        }
        
        // If no window found, just activate the app (it should open main window automatically)
        NSApp.activate(ignoringOtherApps: true)
        if let module {
            NotificationCenter.default.post(name: .macOptimizerOpenModule, object: module)
        }
    }
}

extension MenuBarManager {
    func toggleStatusMetric(_ metric: MenuBarStatusMetric) {
        if let existingIndex = selectedStatusMetrics.firstIndex(of: metric) {
            selectedStatusMetrics.remove(at: existingIndex)
        } else {
            selectedStatusMetrics.append(metric)
        }
    }
    
    func isStatusMetricEnabled(_ metric: MenuBarStatusMetric) -> Bool {
        selectedStatusMetrics.contains(metric)
    }
    
    func toggleStatusIcon() {
        showsStatusIcon.toggle()
    }
    
    func resetStatusBarPreferences() {
        selectedStatusMetrics = [.gpu, .cpu, .storage, .memory]
        showsStatusIcon = true
        bannerTheme = .dark
    }
    
    func setStatusMetrics(_ metrics: [MenuBarStatusMetric]) {
        selectedStatusMetrics = metrics
    }
    
    func moveStatusMetric(_ metric: MenuBarStatusMetric, direction: Int) {
        guard let currentIndex = selectedStatusMetrics.firstIndex(of: metric) else { return }
        let newIndex = currentIndex + direction
        guard selectedStatusMetrics.indices.contains(newIndex) else { return }
        selectedStatusMetrics.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: direction > 0 ? newIndex + 1 : newIndex)
    }
    
    var statusMetricsSummary: String {
        if selectedStatusMetrics.isEmpty {
            return L("Chỉ biểu tượng")
        }
        return selectedStatusMetrics.map(\.title).joined(separator: ", ")
    }
    
    var statusItemPreviewText: String {
        let segments = selectedStatusMetrics.map { formattedValueText(for: $0) }.filter { !$0.isEmpty }
        return segments.isEmpty ? L("Chỉ biểu tượng") : segments.joined(separator: "   ")
    }
    
    var statusItemTooltipText: String {
        let lines = statusMetricDisplays.map { display in
            switch display.metric {
            case .gpu:
                return "\(display.metric.title): \(display.text) • \(systemMonitor.gpuName)"
            default:
                return "\(display.metric.title): \(display.text)"
            }
        }
        return lines.isEmpty ? "MacOptimizer" : lines.joined(separator: "\n")
    }
    
    private func loadStatusBarPreferences() {
        if let rawValues = UserDefaults.standard.array(forKey: statusMetricsKey) as? [String] {
            let metrics = rawValues.compactMap(MenuBarStatusMetric.init(rawValue:))
            if !metrics.isEmpty {
                selectedStatusMetrics = metrics
            }
        }
        if UserDefaults.standard.object(forKey: statusIconKey) != nil {
            showsStatusIcon = UserDefaults.standard.bool(forKey: statusIconKey)
        }
        if let raw = UserDefaults.standard.string(forKey: bannerThemeKey),
           let theme = MenuBarBannerTheme(rawValue: raw) {
            bannerTheme = theme
        }
    }

    private func saveStatusBarPreferences() {
        UserDefaults.standard.set(selectedStatusMetrics.map(\.rawValue), forKey: statusMetricsKey)
        UserDefaults.standard.set(showsStatusIcon, forKey: statusIconKey)
        UserDefaults.standard.set(bannerTheme.rawValue, forKey: bannerThemeKey)
    }
    
    private func bindStatusBarUpdates() {
        cancellables.removeAll()
        
        let refreshPublishers: [AnyPublisher<Void, Never>] = [
            systemMonitor.$gpuUsage.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.$cpuUsage.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.$memoryUsage.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.$downloadSpeed.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.$uploadSpeed.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.$batteryLevel.map { _ in () }.eraseToAnyPublisher(),
            diskManager.$freeSize.map { _ in () }.eraseToAnyPublisher(),
            diskManager.$usedSize.map { _ in () }.eraseToAnyPublisher(),
            $selectedStatusMetrics.map { _ in () }.eraseToAnyPublisher(),
            $showsStatusIcon.map { _ in () }.eraseToAnyPublisher(),
            $currentDetailRoute.map { _ in () }.eraseToAnyPublisher()
        ]
        
        Publishers.MergeMany(refreshPublishers)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateStatusItemAppearance()
            }
            .store(in: &cancellables)
        
        $selectedStatusMetrics
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.systemMonitor.configureMenuBarSampling(statusMetrics: self.selectedStatusMetrics, detailRoute: self.currentDetailRoute, isMenuBarWindowOpen: self.isOpen)
                self.configureDiskRefreshTimer()
                self.saveStatusBarPreferences()
            }
            .store(in: &cancellables)
        
        $showsStatusIcon
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveStatusBarPreferences()
            }
            .store(in: &cancellables)
        
        $currentDetailRoute
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route in
                guard let self = self else { return }
                self.systemMonitor.configureMenuBarSampling(statusMetrics: self.selectedStatusMetrics, detailRoute: route, isMenuBarWindowOpen: self.isOpen)
                self.configureDiskRefreshTimer()
            }
            .store(in: &cancellables)

        $isOpen
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOpen in
                guard let self = self else { return }
                self.systemMonitor.configureMenuBarSampling(statusMetrics: self.selectedStatusMetrics, detailRoute: self.currentDetailRoute, isMenuBarWindowOpen: isOpen)
                self.configureDiskRefreshTimer()
                // Mỗi lần mở popup làm mới số liệu các thẻ tổng hợp
                if isOpen {
                    HostsProtectionManager.shared.refresh()
                    BackgroundItemsManager.shared.refresh()
                    DashboardInsights.shared.refresh()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .store(in: &cancellables)
        
        systemMonitor.$menuBarSamplingConfiguration
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.configureDiskRefreshTimer()
            }
            .store(in: &cancellables)
        
        configureDiskRefreshTimer()
    }

    private func configureDiskRefreshTimer() {
        diskRefreshTimer?.invalidate()
        diskRefreshTimer = nil
        
        let interval = max(systemMonitor.storageRefreshInterval, 5)
        diskRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isOpen || self.selectedStatusMetrics.contains(.storage) || self.currentDetailRoute == .storage {
                self.diskManager.updateDiskSpace()
                self.updateStatusItemAppearance()
            }
        }
    }
    
    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }

        let displays = statusMetricDisplays
        // Mỗi lần vẽ banner là lockFocus + đo chuỗi + vẽ capsule/CoreText cho mọi chip
        // nên chỉ vẽ lại khi nội dung hiển thị (hoặc giao diện) thật sự đổi. Giá trị
        // sampling giữ nguyên thì bỏ qua hoàn toàn — đây là nguồn spike CPU menu bar.
        let renderKey = [
            displays.map(\.text).joined(separator: "|"),
            bannerTheme.rawValue,
            String(showsStatusIcon),
            NSApp.effectiveAppearance.name.rawValue,
            statusItemTooltipText
        ].joined(separator: "#")

        if renderKey != lastStatusRenderKey {
            lastStatusRenderKey = renderKey
            let renderedImage = makeStatusItemImage(from: displays)
            button.image = renderedImage
            button.toolTip = statusItemTooltipText
            statusItem?.length = renderedImage.map { max($0.size.width + 10, NSStatusItem.squareLength) } ?? NSStatusItem.squareLength
        }

        button.imagePosition = .imageOnly
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
    }
    
    struct StatusMetricDisplay: Identifiable {
        let metric: MenuBarStatusMetric
        let text: String
        var id: String { metric.rawValue }
    }
    
    var statusMetricDisplays: [StatusMetricDisplay] {
        selectedStatusMetrics.compactMap { metric in
            let text = formattedValueText(for: metric)
            guard !text.isEmpty else { return nil }
            return StatusMetricDisplay(metric: metric, text: text)
        }
    }
    
    private func formattedValueText(for metric: MenuBarStatusMetric) -> String {
        switch metric {
        case .gpu:
            return "\(Int(systemMonitor.gpuUsage * 100))%"
        case .storage:
            // Dùng "đã dùng/tổng" để đồng nhất ngữ nghĩa với RAM/CPU (mức dùng)
            // và với thẻ Ổ đĩa trong panel ("Đã dùng X / Y").
            return "\(compactByteString(diskManager.usedSize))/\(compactByteString(diskManager.totalSize))"
        case .memory:
            return "\(Int(systemMonitor.memoryUsage * 100))%"
        case .cpu:
            return "\(Int(systemMonitor.cpuUsage * 100))%"
        case .network:
            return "↓\(shortSpeedString(systemMonitor.downloadSpeed)) ↑\(shortSpeedString(systemMonitor.uploadSpeed))"
        case .battery:
            return "\(Int(systemMonitor.batteryLevel * 100))%"
        }
    }

    func statusItemPreviewImage() -> NSImage? {
        makeStatusItemImage(from: statusMetricDisplays)
    }

    private struct StatusBannerSegment {
        let metric: MenuBarStatusMetric
        let label: String
        let value: String
        let accentColor: NSColor
    }

    private func makeStatusItemImage(from displays: [StatusMetricDisplay]) -> NSImage? {
        let segments = displays.map(statusBannerSegment(for:))
        let shouldShowLeadingIcon = showsStatusIcon || segments.isEmpty
        let palette = bannerTheme.palette
        let bannerHeight: CGFloat = 20
        let iconWidth: CGFloat = shouldShowLeadingIcon ? 22 : 0
        let spacing: CGFloat = 5
        let horizontalInset: CGFloat = 8
        let labelFont = NSFont.systemFont(ofSize: 8.5, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        
        var totalWidth: CGFloat = 0
        var chipRects: [NSRect] = []
        
        if shouldShowLeadingIcon {
            totalWidth += iconWidth
        }
        
        if shouldShowLeadingIcon && !segments.isEmpty {
            totalWidth += spacing
        }
        
        for (index, segment) in segments.enumerated() {
            let width = statusBannerChipWidth(for: segment, labelFont: labelFont, valueFont: valueFont, horizontalInset: horizontalInset)
            chipRects.append(NSRect(x: totalWidth, y: 0, width: width, height: bannerHeight))
            totalWidth += width
            if index < segments.count - 1 {
                totalWidth += spacing
            }
        }
        
        if totalWidth == 0 {
            totalWidth = iconWidth
        }
        
        let imageSize = NSSize(width: totalWidth, height: bannerHeight)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        
        if shouldShowLeadingIcon {
            let iconRect = NSRect(x: 0, y: 0, width: iconWidth, height: bannerHeight)
            if let iconFills = palette.iconFills {
                drawStatusBannerCapsule(in: iconRect, fills: iconFills, stroke: palette.iconStroke, inner: palette.innerHighlight)
                drawStatusBannerIcon(in: iconRect.insetBy(dx: 4, dy: 3), tintOverride: palette.iconTintOverride)
            } else {
                // Theme tối giản: icon nổi không nền, cần bóng đổ để đọc được
                setBannerShadow(palette.textShadow)
                drawStatusBannerIcon(in: iconRect.insetBy(dx: 4, dy: 3), tintOverride: palette.iconTintOverride)
                setBannerShadow(nil)
            }
        }

        for (segment, rect) in zip(segments, chipRects) {
            if palette.hasChipBackground {
                drawStatusBannerCapsule(
                    in: rect,
                    fills: palette.chipFills(segment.accentColor),
                    stroke: palette.chipStroke(segment.accentColor),
                    inner: palette.innerHighlight
                )
            }
            setBannerShadow(palette.textShadow)
            drawStatusBannerText(segment, in: rect, labelFont: labelFont, valueFont: valueFont, horizontalInset: horizontalInset, palette: palette)
            setBannerShadow(nil)
        }
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func statusBannerChipWidth(
        for segment: StatusBannerSegment,
        labelFont: NSFont,
        valueFont: NSFont,
        horizontalInset: CGFloat
    ) -> CGFloat {
        let labelAttributes: [NSAttributedString.Key: Any] = [.font: labelFont]
        let valueAttributes: [NSAttributedString.Key: Any] = [.font: valueFont]
        let labelWidth = (segment.label as NSString).size(withAttributes: labelAttributes).width
        let valueWidth = (segment.value as NSString).size(withAttributes: valueAttributes).width
        return ceil(labelWidth + valueWidth + horizontalInset * 2 + 8)
    }

    private func drawStatusBannerCapsule(in rect: NSRect, fills: [NSColor], stroke: NSColor?, inner: NSColor?) {
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        if let gradient = NSGradient(colors: fills) {
            gradient.draw(in: path, angle: 0)
        }

        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        if let inner {
            let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: (rect.height - 1) / 2, yRadius: (rect.height - 1) / 2)
            inner.setStroke()
            highlight.lineWidth = 0.5
            highlight.stroke()
        }
    }

    private func drawStatusBannerIcon(in rect: NSRect, tintOverride: NSColor?) {
        let insetRect = rect
        if let tint = tintOverride {
            tintedStatusBarIcon(tint: tint)?.draw(in: insetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return
        }
        guard let icon = statusBarIconImage?.copy() as? NSImage else { return }
        icon.isTemplate = true
        icon.draw(in: insetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    /// Icon đã tô màu (dùng cho theme nền sáng), cache theo tint để tránh vẽ lại mỗi lần làm mới.
    private func tintedStatusBarIcon(tint: NSColor) -> NSImage? {
        if let cached = tintedIconCache[String(describing: tint)] { return cached }
        guard let base = statusBarIconImage else { return nil }
        let size = base.size
        let image = NSImage(size: size)
        image.lockFocus()
        tint.set()
        NSRect(origin: .zero, size: size).fill(using: .copy)
        base.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .destinationIn, fraction: 1)
        image.unlockFocus()
        image.isTemplate = false
        tintedIconCache[String(describing: tint)] = image
        return image
    }

    /// Bật/tắt bóng đổ trong ngữ cảnh vẽ hiện tại (nil = tắt).
    private func setBannerShadow(_ shadow: NSShadow?) {
        if let shadow {
            shadow.set()
        } else {
            NSShadow().set()
        }
    }

    private func drawStatusBannerText(
        _ segment: StatusBannerSegment,
        in rect: NSRect,
        labelFont: NSFont,
        valueFont: NSFont,
        horizontalInset: CGFloat,
        palette: MenuBarBannerPalette
    ) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: palette.labelColor(segment.accentColor)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: palette.valueColor
        ]
        
        let labelSize = (segment.label as NSString).size(withAttributes: labelAttributes)
        let valueSize = (segment.value as NSString).size(withAttributes: valueAttributes)
        let totalWidth = labelSize.width + 8 + valueSize.width
        let startX = rect.minX + max(horizontalInset, (rect.width - totalWidth) / 2)
        let labelRect = NSRect(
            x: startX,
            y: rect.midY - labelSize.height / 2 - 0.5,
            width: labelSize.width,
            height: labelSize.height
        )
        let valueRect = NSRect(
            x: labelRect.maxX + 8,
            y: rect.midY - valueSize.height / 2 - 0.5,
            width: valueSize.width,
            height: valueSize.height
        )
        
        (segment.label as NSString).draw(in: labelRect, withAttributes: labelAttributes)
        (segment.value as NSString).draw(in: valueRect, withAttributes: valueAttributes)
    }

    private func statusBannerSegment(for display: StatusMetricDisplay) -> StatusBannerSegment {
        switch display.metric {
        case .gpu:
            return StatusBannerSegment(metric: .gpu, label: "GPU", value: display.text, accentColor: NSColor(calibratedRed: 0.98, green: 0.57, blue: 0.78, alpha: 1.0))
        case .storage:
            return StatusBannerSegment(
                metric: .storage,
                label: "DISK",
                value: display.text,
                accentColor: NSColor(calibratedRed: 0.55, green: 0.80, blue: 1.0, alpha: 1.0)
            )
        case .memory:
            return StatusBannerSegment(metric: .memory, label: "RAM", value: display.text, accentColor: NSColor(calibratedRed: 0.63, green: 0.98, blue: 0.80, alpha: 1.0))
        case .cpu:
            return StatusBannerSegment(metric: .cpu, label: "CPU", value: display.text, accentColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.53, alpha: 1.0))
        case .network:
            return StatusBannerSegment(
                metric: .network,
                label: "NET",
                value: display.text,
                accentColor: NSColor(calibratedRed: 0.58, green: 0.92, blue: 1.0, alpha: 1.0)
            )
        case .battery:
            return StatusBannerSegment(metric: .battery, label: "PIN", value: display.text, accentColor: NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.52, alpha: 1.0))
        }
    }
    
    private func shortByteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useTB, .useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes).replacingOccurrences(of: " ", with: "")
    }

    private func compactByteString(_ bytes: Int64) -> String {
        shortByteString(bytes)
            .replacingOccurrences(of: "GB", with: "G")
            .replacingOccurrences(of: "MB", with: "M")
            .replacingOccurrences(of: "TB", with: "T")
    }
    
    private func shortSpeedString(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.1fG", bytesPerSecond / 1_000_000_000)
        } else if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.0fK", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
}

// Custom NSWindow with auto-close logic
class MenuBarWindow: NSWindow {
    init(contentViewController: NSViewController) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView], 
            backing: .buffered,
            defer: false
        )
        
        self.contentViewController = contentViewController
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
    }
    
    override var canBecomeKey: Bool { return true }
    
    // Auto-close handler needs to be managed by Manager via delegate or notification
    // But let's keep it simple: MenuBarManager will subscribe to interruptions.
}

extension MenuBarManager {
    func setupAutoClose() {
        // Monitor global clicks to close if clicked outside
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isOpen else { return event }
            
            // Click vào chính icon status item do toggleWindow xử lý, không đóng ở đây
            // để tránh vòng lặp đóng/mở giữa monitor và action của nút
            
            if let window = event.window,
               (window == self.popoverWindow || window == self.detailWindow || window == self.statusItem?.button?.window) {
                return event
            }
            
            self.closeWindow()
            return event
        }
        
        // Also listen for ResignKey
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, self.isOpen else { return }
            guard let resignedWindow = notification.object as? NSWindow else { return }
            
            // Only care if one of OUR windows resigned key
            if resignedWindow == self.popoverWindow || resignedWindow == self.detailWindow {
                // Check what the NEW key window is.
                // It might need a slight delay to be set?
                DispatchQueue.main.async {
                    let newKeyWindow = NSApp.keyWindow
                    
                    // If the new key window is one of ours, don't close.
                    if newKeyWindow == self.popoverWindow || newKeyWindow == self.detailWindow {
                        return
                    }
                    
                    // If we are still "active" app but focus shifted to maybe a dialog? 
                    // Or if user clicked desktop (newKeyWindow might be nil or Finder).
                    
                    // Simple rule: If neither of our windows is key, close.
                    self.closeWindow()
                }
            }
        }
        
        // Listen for App Deactivation (switching to another app)
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.closeWindow()
        }
    }
}
