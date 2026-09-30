import Foundation
import Combine
import AppKit
import CoreWLAN

struct HighMemoryApp: Identifiable {
    let id: pid_t
    let name: String
    let usage: Double // GB
    let icon: NSImage?
}

enum SamplingProfile: String, CaseIterable, Identifiable, Codable {
    case economy
    case balanced
    case live
    case custom
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .economy: return L("Tiết kiệm")
        case .balanced: return L("Cân bằng")
        case .live: return L("Theo dõi sát")
        case .custom: return L("Tùy chỉnh")
        }
    }
    
    var subtitle: String {
        switch self {
        case .economy: return L("Ưu tiên giảm tác động nền")
        case .balanced: return L("Mặc định, đủ mượt cho hầu hết máy")
        case .live: return L("Cập nhật nhanh hơn khi cần quan sát sát")
        case .custom: return L("Bạn tự đặt nhịp lấy mẫu cho từng loại")
        }
    }
}

enum SamplingMetricKind: String, CaseIterable, Identifiable, Codable {
    case storage
    case gpu
    case cpu
    case memory
    case network
    case battery
    case processes
    case alerts
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .storage: return L("Ổ đĩa")
        case .gpu: return "GPU"
        case .cpu: return "CPU"
        case .memory: return "RAM"
        case .network: return L("Mạng")
        case .battery: return L("Pin")
        case .processes: return L("Top tiến trình")
        case .alerts: return L("Cảnh báo RAM")
        }
    }
    
    var subtitle: String {
        switch self {
        case .storage: return L("Dùng cho DISK trên thanh menu và panel ổ đĩa")
        case .gpu: return L("Mức tải GPU hiện tại")
        case .cpu: return L("Tải CPU tổng cho status item và widget")
        case .memory: return L("Mức dùng RAM tổng và thống kê bộ nhớ")
        case .network: return L("Tốc độ mạng và lịch sử truyền nhận")
        case .battery: return L("Mức pin và trạng thái sạc")
        case .processes: return L("Danh sách app nặng để force quit")
        case .alerts: return L("Quét app dùng RAM vượt ngưỡng")
        }
    }
    
    var range: ClosedRange<Double> {
        switch self {
        case .storage: return 10...60
        case .gpu: return 1...6
        case .cpu: return 1...5
        case .memory: return 1...6
        case .network: return 1...6
        case .battery: return 15...120
        case .processes: return 5...30
        case .alerts: return 5...30
        }
    }
    
    var step: Double {
        switch self {
        case .gpu, .cpu, .memory, .network:
            return 0.5
        case .storage, .processes, .alerts:
            return 5
        case .battery:
            return 15
        }
    }
}

struct MenuBarSamplingConfiguration: Codable, Equatable {
    var storageInterval: TimeInterval
    var gpuInterval: TimeInterval
    var cpuInterval: TimeInterval
    var memoryInterval: TimeInterval
    var networkInterval: TimeInterval
    var batteryInterval: TimeInterval
    var processInterval: TimeInterval
    var alertInterval: TimeInterval
    
    static func preset(_ profile: SamplingProfile) -> MenuBarSamplingConfiguration {
        switch profile {
        case .economy:
            return MenuBarSamplingConfiguration(
                storageInterval: 30,
                gpuInterval: 3.0,
                cpuInterval: 3.0,
                memoryInterval: 4.0,
                networkInterval: 5.0,
                batteryInterval: 90.0,
                processInterval: 20.0,
                alertInterval: 20.0
            )
        case .balanced, .custom:
            return MenuBarSamplingConfiguration(
                storageInterval: 15,
                gpuInterval: 2.0,
                cpuInterval: 1.5,
                memoryInterval: 2.0,
                networkInterval: 2.5,
                batteryInterval: 45.0,
                processInterval: 8.0,
                alertInterval: 12.0
            )
        case .live:
            return MenuBarSamplingConfiguration(
                storageInterval: 10,
                gpuInterval: 1.5,
                cpuInterval: 1.0,
                memoryInterval: 1.5,
                networkInterval: 1.5,
                batteryInterval: 30.0,
                processInterval: 5.0,
                alertInterval: 8.0
            )
        }
    }
    
    func interval(for kind: SamplingMetricKind) -> TimeInterval {
        switch kind {
        case .storage: return storageInterval
        case .gpu: return gpuInterval
        case .cpu: return cpuInterval
        case .memory: return memoryInterval
        case .network: return networkInterval
        case .battery: return batteryInterval
        case .processes: return processInterval
        case .alerts: return alertInterval
        }
    }
    
    mutating func setInterval(_ interval: TimeInterval, for kind: SamplingMetricKind) {
        switch kind {
        case .storage: storageInterval = interval
        case .gpu: gpuInterval = interval
        case .cpu: cpuInterval = interval
        case .memory: memoryInterval = interval
        case .network: networkInterval = interval
        case .battery: batteryInterval = interval
        case .processes: processInterval = interval
        case .alerts: alertInterval = interval
        }
    }

    init(
        storageInterval: TimeInterval,
        gpuInterval: TimeInterval,
        cpuInterval: TimeInterval,
        memoryInterval: TimeInterval,
        networkInterval: TimeInterval,
        batteryInterval: TimeInterval,
        processInterval: TimeInterval,
        alertInterval: TimeInterval
    ) {
        self.storageInterval = storageInterval
        self.gpuInterval = gpuInterval
        self.cpuInterval = cpuInterval
        self.memoryInterval = memoryInterval
        self.networkInterval = networkInterval
        self.batteryInterval = batteryInterval
        self.processInterval = processInterval
        self.alertInterval = alertInterval
    }

    private enum CodingKeys: String, CodingKey {
        case storageInterval
        case gpuInterval
        case cpuInterval
        case memoryInterval
        case networkInterval
        case batteryInterval
        case processInterval
        case alertInterval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarSamplingConfiguration.preset(.balanced)
        storageInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .storageInterval) ?? defaults.storageInterval
        gpuInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .gpuInterval) ?? defaults.gpuInterval
        cpuInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .cpuInterval) ?? defaults.cpuInterval
        memoryInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .memoryInterval) ?? defaults.memoryInterval
        networkInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .networkInterval) ?? defaults.networkInterval
        batteryInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .batteryInterval) ?? defaults.batteryInterval
        processInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .processInterval) ?? defaults.processInterval
        alertInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .alertInterval) ?? defaults.alertInterval
    }
}

class SystemMonitorService: ObservableObject {
    private struct SamplingNeeds {
        var gpu: Bool
        var cpu: Bool
        var memory: Bool
        var network: Bool
        var networkDetails: Bool
        var battery: Bool
        var processDetails: Bool
        var detailedMemory: Bool
        var batteryDetails: Bool
        var highMemoryAlerts: Bool
        /// true khi cửa sổ bảng điều khiển đóng và không mở trang chi tiết nào,
        /// tức sampling chỉ còn phục vụ dòng chữ trên status item của menu bar
        var statusItemOnly: Bool

        static let dashboard = SamplingNeeds(
            gpu: false,
            cpu: true,
            memory: true,
            network: true,
            networkDetails: false,
            battery: false,
            processDetails: true,
            detailedMemory: false,
            batteryDetails: false,
            highMemoryAlerts: true,
            statusItemOnly: false
        )
    }

    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0 // Percentage
    @Published var memoryUsedString: String = "0 GB"
    @Published var memoryTotalString: String = "0 GB"
    
    // High Memory Alert
    @Published var highMemoryApp: HighMemoryApp?
    @Published var showHighMemoryAlert: Bool = false
    /// Ngưỡng % RAM toàn hệ thống để bật cảnh báo (cấu hình được trong tùy chỉnh)
    @Published private(set) var memoryAlertThresholdPercent: Double = 85
    private let memoryAlertThresholdKey = "MemoryMonitor.AlertThresholdPercent"
    /// PID người dùng đã chọn "Không nhắc lại" cho phiên hiện tại
    private var ignoredPids: Set<pid_t> = []
    
    // Mới: nhắc nhở theo lịch trình và bỏ qua vĩnh viễn

    private var snoozedUntil: Date?  // Tạm ẩn lời nhắc cho đến thời điểm này
    private var permanentlyIgnoredApps: Set<String> = []  // Danh sách tên ứng dụng vĩnh viễn bỏ qua
    private let ignoredAppsKey = "MemoryMonitor.IgnoredApps"
    
    // Network Speed Monitoring
    @Published var downloadSpeed: Double = 0.0 // bytes per second
    @Published var uploadSpeed: Double = 0.0   // bytes per second
    @Published var downloadSpeedHistory: [Double] = Array(repeating: 0, count: 20)
    @Published var uploadSpeedHistory: [Double] = Array(repeating: 0, count: 20)
    
    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastNetworkCheck: Date = Date()
    
    // Battery Monitoring
    @Published var batteryLevel: Double = 1.0
    @Published var isCharging: Bool = false
    @Published var batteryState: String = L("Không xác định") 
    @Published var gpuUsage: Double = 0.0
    @Published var gpuName: String = "GPU"
    @Published private(set) var samplingProfile: SamplingProfile = .balanced
    @Published private(set) var menuBarSamplingConfiguration: MenuBarSamplingConfiguration = .preset(.balanced)

    private var gpuTimer: Timer?
    private var cpuTimer: Timer?
    private var memoryTimer: Timer?
    private var networkTimer: Timer?
    private var batteryTimer: Timer?
    private var processTimer: Timer?
    private var alertTimer: Timer?
    private var isMonitoring = false
    private var samplingNeeds: SamplingNeeds = .dashboard
    private let samplingProfileKey = "MenuBar.SamplingProfile"
    private let samplingConfigurationKey = "MenuBar.SamplingConfiguration"
    
    // UI Update Batching
    private let uiUpdater = BatchedUIUpdater(debounceDelay: 0.05)

    // Cả CPU/RAM/GPU/NET publish qua cùng một nhịp throttle 1 Hz: khi bảng điều khiển mở,
    // các timer lệch pha không còn gây ra từng vòng layout window riêng cho mỗi metric
    private static let samplingFlushKey = "monitorSampling"
    private static let samplingFlushMinInterval: TimeInterval = 1.0
    
    // Hàng đợi nối tiếp cho toàn bộ việc lấy mẫu: các subprocess còn lại (netstat, ioreg,
    // pmset, ps cho danh sách tiến trình) chạy ở đây để không bao giờ chặn main thread
    
    private let samplingQueue = DispatchQueue(label: "com.apextune.systemmonitor.sampling", qos: .utility)

    // Process Monitoring
    struct AppProcess: Identifiable {
        let id: pid_t
        let name: String
        let icon: NSImage?
        let cpu: Double // Percentage
        let memory: Double // GB
    }
    
    @Published var topMemoryProcesses: [AppProcess] = []
    @Published var topCPUProcesses: [AppProcess] = []
    
    // Speed Test
    @Published var isTestingSpeed: Bool = false
    @Published var speedTestResult: Double = 0.0 // Mbps
    @Published var speedTestProgress: Double = 0.0
    
    // WiFi Info
    @Published var wifiSSID: String = "Wi-Fi"
    @Published var wifiSecurity: String = L("Không xác định")
    @Published var wifiSignalStrength: String = L("Tốt")
    @Published var connectionDuration: String = L("0 giờ 0 phút 0 giây")
    private var connectionStartTime: Date = Date()
    
    // Total Traffic
    @Published var totalDownload: String = "0 KB"
    @Published var totalUpload: String = "0 KB"
    
    // ... updateStats logic ...
    
    /// Chạy lệnh hệ thống và trả về stdout. CHỈ gọi từ samplingQueue.
    
    private func runCommand(_ launchPath: String, _ arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            print("Command Error [\(launchPath)]: \(error)")
            return nil
        }
    }

    // Tick CPU của lần đo trước. CHỈ truy cập trên samplingQueue (nối tiếp) để tránh data race.

    private var previousCPUTicks: (idle: UInt64, total: UInt64)?

    // Tên GPU lần đọc gần nhất. CHỈ truy cập trên samplingQueue; bản @Published gpuName
    // chỉ đọc/ghi trên main thread nên không được đụng từ queue này.

    private var lastGPUName: String = "GPU"

    /// Đọc mức dùng CPU toàn máy qua Mach API, tính từ delta tick giữa hai lần gọi liên tiếp.
    /// Thay cho việc spawn `ps -A` mỗi chu kỳ (fork tiến trình + quét toàn bộ process list rất tốn CPU).
    /// CHỈ gọi từ samplingQueue.
    private func systemCPUUsage() -> Double? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }

        var idle: UInt64 = 0
        var total: UInt64 = 0
        let stateMax = Int(CPU_STATE_MAX)
        let idleState = Int(CPU_STATE_IDLE)
        for core in 0..<Int(processorCount) {
            let base = core * stateMax
            idle += UInt64(info[base + idleState])
            for state in 0..<stateMax {
                total += UInt64(info[base + state])
            }
        }

        let current = (idle: idle, total: total)
        let previous = previousCPUTicks
        previousCPUTicks = current
        guard let previous else {
            // Lần gọi đầu chưa có delta: trả mức dùng trung bình từ lúc khởi động máy
            // để UI có giá trị ngay thay vì chờ thêm một chu kỳ sampling
            guard current.total > current.idle else { return nil }
            return Double(current.total - current.idle) / Double(current.total)
        }

        let idleDelta = current.idle > previous.idle ? current.idle - previous.idle : 0
        let totalDelta = current.total > previous.total ? current.total - previous.total : 0
        // Tick từng state là counter 32-bit độc lập có thể wrap lệch nhau giữa 2 lần lấy mẫu;
        // nếu idleDelta vượt totalDelta thì bỏ tick này thay vì để UInt64 underflow
        guard totalDelta > 0, idleDelta <= totalDelta else { return nil }
        return min(max(Double(totalDelta - idleDelta) / Double(totalDelta), 0), 1)
    }

    /// Thống kê trang RAM đọc trực tiếp từ kernel, tương đương output `vm_stat` nhưng không spawn process.
    private struct VMPageCounts {
        let active: UInt64
        let inactive: UInt64
        let speculative: UInt64
        let wired: UInt64
        let compressed: UInt64
        let pageSize: UInt64
    }

    private func readVMPageCounts() -> VMPageCounts? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return VMPageCounts(
            active: UInt64(stats.active_count),
            inactive: UInt64(stats.inactive_count),
            speculative: UInt64(stats.speculative_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count),
            pageSize: UInt64(vm_kernel_page_size)
        )
    }
    
    private func fetchUserProcesses() {
        // NSWorkspace.runningApplications chỉ an toàn ở main thread nên danh sách app GUI
        // được chụp tại đây trước, rồi phần quét ps nặng mới chạy trên hàng đợi nền
        
        struct AppSnapshot {
            let pid: pid_t
            let name: String
            let icon: NSImage?
        }
        let snapshots = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { AppSnapshot(pid: $0.processIdentifier, name: $0.localizedName ?? L("Không rõ"), icon: $0.icon) }
        
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/bin/ps", ["-x", "-o", "pid,ppid,%cpu,rss,comm"]) else { return }
            
            struct ProcessInfo {
                let pid: Int32
                let ppid: Int32
                let cpu: Double
                let rss: Double // GB
                let name: String
            }
            
            var allProcesses: [Int32: ProcessInfo] = [:]
            var childrenMap: [Int32: [Int32]] = [:] // Parent -> [Children]
            
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
                if parts.count >= 5,
                   let pid = Int32(parts[0]),
                   let ppid = Int32(parts[1]),
                   let cpu = Double(parts[2]),
                   let rssKB = Double(parts[3]) {
                    
                    let nameParts = parts.dropFirst(4)
                    let fullPath = nameParts.joined(separator: " ")
                    let name = URL(fileURLWithPath: fullPath).lastPathComponent
                    
                    let info = ProcessInfo(pid: pid, ppid: ppid, cpu: cpu, rss: rssKB / 1024.0 / 1024.0, name: name)
                    allProcesses[pid] = info
                    
                    childrenMap[ppid, default: []].append(pid)
                }
            }
            
            func getAggregatedStats(for pid: Int32, visited: inout Set<Int32>) -> (cpu: Double, mem: Double) {
                if visited.contains(pid) { return (0, 0) }
                visited.insert(pid)
                
                var totalCPU = 0.0
                var totalMem = 0.0
                
                if let process = allProcesses[pid] {
                    totalCPU += process.cpu
                    totalMem += process.rss
                }
                
                if let children = childrenMap[pid] {
                    for child in children {
                        let childStats = getAggregatedStats(for: child, visited: &visited)
                        totalCPU += childStats.cpu
                        totalMem += childStats.mem
                    }
                }
                
                return (totalCPU, totalMem)
            }
            
            var appProcesses: [AppProcess] = []
            for snapshot in snapshots {
                var visited = Set<Int32>()
                let stats = getAggregatedStats(for: snapshot.pid, visited: &visited)
                appProcesses.append(AppProcess(
                    id: snapshot.pid,
                    name: snapshot.name,
                    icon: snapshot.icon,
                    cpu: stats.cpu,
                    memory: stats.mem
                ))
            }
            
            let sortedByMem = appProcesses.sorted { $0.memory > $1.memory }.prefix(10)
            let sortedByCPU = appProcesses.sorted { $0.cpu > $1.cpu }.prefix(10)
            
            Task {
                await self.uiUpdater.batch {
                    self.topMemoryProcesses = Array(sortedByMem)
                    self.topCPUProcesses = Array(sortedByCPU)
                }
            }
        }
    }
    
    func runSpeedTest() {
        guard !isTestingSpeed,
              let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000") else { return }
        isTestingSpeed = true
        speedTestResult = 0
        speedTestProgress = 0
        
        let startTime = Date()
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTestingSpeed = false
                self?.speedTestProgress = 1.0
                
                if let data = data {
                    let duration = Date().timeIntervalSince(startTime)
                    let bits = Double(data.count) * 8
                    let mbps = (bits / duration) / 1_000_000
                    self?.speedTestResult = mbps
                }
            }
        }
        
        // Fake Progress or delegate? simpler for now just wait.
        // Or implement delegate for progress.
        task.resume()
    }
    
    // ... add fetchUserProcesses() to updateStats ...
    
    init() {
        // Disable high memory alert for the first 30 seconds after app launch
        snoozedUntil = Date().addingTimeInterval(30)
        
        loadIgnoredApps()
        loadMemoryAlertThreshold()
        loadSamplingPreferences()
    }
    
    private func loadMemoryAlertThreshold() {
        let saved = UserDefaults.standard.double(forKey: memoryAlertThresholdKey)
        if saved > 0 {
            memoryAlertThresholdPercent = min(max(saved, 60), 95)
        }
    }
    
    /// Đặt ngưỡng % RAM toàn hệ thống để bật cảnh báo (60–95%)
    func updateMemoryAlertThreshold(_ percent: Double) {
        memoryAlertThresholdPercent = min(max(percent, 60), 95)
        UserDefaults.standard.set(memoryAlertThresholdPercent, forKey: memoryAlertThresholdKey)
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Tải danh sách ứng dụng bị bỏ qua vĩnh viễn từ UserDefaults

    private func loadIgnoredApps() {
        if let savedApps = UserDefaults.standard.array(forKey: ignoredAppsKey) as? [String] {
            permanentlyIgnoredApps = Set(savedApps)
        }
    }
    
    /// Lưu danh sách ứng dụng bị bỏ qua vĩnh viễn vào UserDefaults

    private func saveIgnoredApps() {
        UserDefaults.standard.set(Array(permanentlyIgnoredApps), forKey: ignoredAppsKey)
    }
    
    func startMonitoring() {
        guard !isMonitoring else {
            refreshSamplingSchedule(runImmediately: false)
            return
        }
        
        isMonitoring = true
        refreshSamplingSchedule(runImmediately: true)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        [gpuTimer, cpuTimer, memoryTimer, networkTimer, batteryTimer, processTimer, alertTimer].forEach { $0?.invalidate() }
        gpuTimer = nil
        cpuTimer = nil
        memoryTimer = nil
        networkTimer = nil
        batteryTimer = nil
        processTimer = nil
        alertTimer = nil
    }
    
    func configureDashboardSampling() {
        samplingNeeds = .dashboard
        refreshSamplingSchedule(runImmediately: isMonitoring)
    }
    
    func configureMenuBarSampling(statusMetrics: [MenuBarStatusMetric], detailRoute: MenuBarRoute?, isMenuBarWindowOpen: Bool) {
        let metricSet = Set(statusMetrics)
        samplingNeeds = SamplingNeeds(
            gpu: metricSet.contains(.gpu),
            cpu: metricSet.contains(.cpu) || detailRoute == .cpu || isMenuBarWindowOpen,
            memory: metricSet.contains(.memory) || detailRoute == .memory || isMenuBarWindowOpen,
            network: metricSet.contains(.network) || detailRoute == .network || isMenuBarWindowOpen,
            networkDetails: detailRoute == .network,
            battery: metricSet.contains(.battery) || detailRoute == .battery || isMenuBarWindowOpen,
            processDetails: detailRoute == .cpu || detailRoute == .memory,
            detailedMemory: detailRoute == .memory,
            batteryDetails: detailRoute == .battery,
            highMemoryAlerts: true,
            statusItemOnly: !isMenuBarWindowOpen && detailRoute == nil
        )
        refreshSamplingSchedule(runImmediately: isMonitoring)
    }
    
    var storageRefreshInterval: TimeInterval {
        menuBarSamplingConfiguration.interval(for: .storage)
    }
    
    func formattedSamplingInterval(for kind: SamplingMetricKind) -> String {
        let seconds = menuBarSamplingConfiguration.interval(for: kind)
        if seconds.rounded(.towardZero) == seconds {
            return String(format: L("%d giây"), Int(seconds))
        }
        return String(format: L("%.1f giây"), seconds)
    }
    
    func applySamplingProfile(_ profile: SamplingProfile) {
        samplingProfile = profile
        menuBarSamplingConfiguration = MenuBarSamplingConfiguration.preset(profile == .custom ? .balanced : profile)
        saveSamplingPreferences()
        refreshSamplingSchedule(runImmediately: isMonitoring)
    }
    
    func updateSamplingInterval(for kind: SamplingMetricKind, to newValue: Double) {
        let normalizedValue = normalizeInterval(newValue, for: kind)
        menuBarSamplingConfiguration.setInterval(normalizedValue, for: kind)
        samplingProfile = .custom
        saveSamplingPreferences()
        refreshSamplingSchedule(runImmediately: isMonitoring)
    }
    
    private func normalizeInterval(_ value: Double, for kind: SamplingMetricKind) -> Double {
        let step = kind.step
        let range = kind.range
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let rounded = (clamped / step).rounded() * step
        return min(max(rounded, range.lowerBound), range.upperBound)
    }
    
    private func loadSamplingPreferences() {
        if let rawValue = UserDefaults.standard.string(forKey: samplingProfileKey),
           let profile = SamplingProfile(rawValue: rawValue) {
            samplingProfile = profile
        }
        
        if let data = UserDefaults.standard.data(forKey: samplingConfigurationKey),
           let configuration = try? JSONDecoder().decode(MenuBarSamplingConfiguration.self, from: data) {
            menuBarSamplingConfiguration = configuration
        } else {
            menuBarSamplingConfiguration = MenuBarSamplingConfiguration.preset(samplingProfile == .custom ? .balanced : samplingProfile)
        }
    }
    
    private func saveSamplingPreferences() {
        UserDefaults.standard.set(samplingProfile.rawValue, forKey: samplingProfileKey)
        if let data = try? JSONEncoder().encode(menuBarSamplingConfiguration) {
            UserDefaults.standard.set(data, forKey: samplingConfigurationKey)
        }
    }
    
    // Định dạng tốc độ mạng

    func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bytesPerSecond / 1_000_000_000)
        } else if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }

    private func refreshSamplingSchedule(runImmediately: Bool) {
        guard isMonitoring else { return }

        // Khi cửa sổ đóng và không mở trang chi tiết, sampling chỉ còn phục vụ dòng chữ
        // trên status item nên nới chu kỳ ra 3 lần để giảm CPU; mở lại là quay về tốc độ cấu hình
        let idleFactor: Double = samplingNeeds.statusItemOnly ? 3.0 : 1.0

        configureTimer(&gpuTimer, enabled: samplingNeeds.gpu, interval: menuBarSamplingConfiguration.interval(for: .gpu) * idleFactor, runImmediately: runImmediately) { [weak self] in
            self?.sampleGPUUsage()
        }

        configureTimer(&cpuTimer, enabled: samplingNeeds.cpu, interval: menuBarSamplingConfiguration.interval(for: .cpu) * idleFactor, runImmediately: runImmediately) { [weak self] in
            self?.sampleCPUUsage()
        }

        configureTimer(&memoryTimer, enabled: samplingNeeds.memory, interval: menuBarSamplingConfiguration.interval(for: .memory) * idleFactor, runImmediately: runImmediately) { [weak self] in
            self?.sampleMemoryUsage(includeDetailedStats: self?.samplingNeeds.detailedMemory ?? false)
        }

        configureTimer(&networkTimer, enabled: samplingNeeds.network, interval: menuBarSamplingConfiguration.interval(for: .network) * idleFactor, runImmediately: runImmediately) { [weak self] in
            self?.sampleNetworkUsage(includeDetails: self?.samplingNeeds.networkDetails ?? false)
        }

        configureTimer(&batteryTimer, enabled: samplingNeeds.battery, interval: menuBarSamplingConfiguration.interval(for: .battery) * idleFactor, runImmediately: runImmediately) { [weak self] in
            self?.sampleBatteryStatus(includeDetails: self?.samplingNeeds.batteryDetails ?? false)
        }
        
        configureTimer(&processTimer, enabled: samplingNeeds.processDetails, interval: menuBarSamplingConfiguration.interval(for: .processes), runImmediately: runImmediately) { [weak self] in
            self?.fetchUserProcesses()
        }
        
        configureTimer(&alertTimer, enabled: samplingNeeds.highMemoryAlerts, interval: menuBarSamplingConfiguration.interval(for: .alerts), runImmediately: runImmediately) { [weak self] in
            self?.sampleMemoryUsage(includeDetailedStats: false)
            self?.checkHighMemoryApps()
        }
    }
    
    private func configureTimer(
        _ timer: inout Timer?,
        enabled: Bool,
        interval: TimeInterval,
        runImmediately: Bool,
        action: @escaping () -> Void
    ) {
        timer?.invalidate()
        timer = nil
        
        guard enabled else { return }
        
        if runImmediately {
            action()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
        // Cho phép hệ thống dồn lịch để tiết kiệm pin; độ trễ tối đa 10% chu kỳ là chấp nhận được với giám sát
        timer?.tolerance = min(interval * 0.1, 1.0)
    }
    
    private func sampleCPUUsage() {
        samplingQueue.async { [weak self] in
            guard let self, let usage = self.systemCPUUsage() else { return }

            // Khi bảng điều khiển đóng, status item chỉ cần độ chính xác bậc 5%: giá trị
            // đổi ít hơn nhiều lần nên bớt số vòng render lại view graph (~200ms mỗi lần)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let steps: Double = self.samplingNeeds.statusItemOnly ? 20 : 100
                let quantized = (usage * steps).rounded() / steps
                await self.uiUpdater.throttle(Self.samplingFlushKey, minInterval: Self.samplingFlushMinInterval) {
                    guard self.cpuUsage != quantized else { return }
                    self.cpuUsage = quantized
                }
            }
        }
    }

    private func sampleGPUUsage() {
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/usr/sbin/ioreg", ["-r", "-d", "1", "-w", "0", "-c", "IOAccelerator"]) else { return }
            
            let deviceUtilization = self.extractIntegerValue(for: "\"Device Utilization %\"", in: output)
            let rendererUtilization = self.extractIntegerValue(for: "\"Renderer Utilization %\"", in: output)
            let tilerUtilization = self.extractIntegerValue(for: "\"Tiler Utilization %\"", in: output)
            let usage = deviceUtilization ?? max(rendererUtilization ?? 0, tilerUtilization ?? 0)
            // lastGPUName là bản của samplingQueue, không đọc @Published từ queue nền
            let name = self.extractQuotedValue(for: "\"model\"", in: output) ?? self.lastGPUName
            self.lastGPUName = name
            
            Task {
                await self.uiUpdater.throttle(Self.samplingFlushKey, minInterval: Self.samplingFlushMinInterval) {
                    let usageValue = Double(usage) / 100.0
                    // Bỏ qua publish khi giá trị hiển thị không đổi để khỏi layout lại window
                    guard self.gpuUsage != usageValue || self.gpuName != name else { return }
                    self.gpuUsage = usageValue
                    self.gpuName = name
                }
            }
        }
    }
    
    private func extractIntegerValue(for key: String, in output: String) -> Int? {
        guard let keyRange = output.range(of: key) else { return nil }
        let tail = output[keyRange.upperBound...]
        guard let match = tail.range(of: "\\d+", options: .regularExpression) else { return nil }
        return Int(tail[match])
    }
    
    private func extractQuotedValue(for key: String, in output: String) -> String? {
        guard let keyRange = output.range(of: key) else { return nil }
        let tail = output[keyRange.upperBound...]
        guard let firstQuote = tail.firstIndex(of: "\"") else { return nil }
        let afterFirstQuote = tail.index(after: firstQuote)
        guard let secondQuote = tail[afterFirstQuote...].firstIndex(of: "\"") else { return nil }
        return String(tail[afterFirstQuote..<secondQuote])
    }
    
    private func sampleMemoryUsage(includeDetailedStats: Bool) {
        samplingQueue.async { [weak self] in
            guard let self, let pages = self.readVMPageCounts() else { return }

            let totalRAM = ProcessInfo.processInfo.physicalMemory
            // Trang speculative là cache có thể thu hồi ngay nên không tính vào RAM đã dùng
            // (khớp với cách Activity Monitor đếm "Memory Used")

            let usedPages = pages.active + pages.wired + pages.compressed
            let usedRAM = usedPages * pages.pageSize

            let memoryUsageValue = Double(usedRAM) / Double(totalRAM)
            let memoryUsedStringValue = ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
            let memoryTotalStringValue = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)

            Task {
                await self.uiUpdater.throttle(Self.samplingFlushKey, minInterval: Self.samplingFlushMinInterval) {
                    // Chỉ publish khi chuỗi hiển thị đổi; giá trị như cũ thì khỏi layout lại window
                    guard self.memoryUsedString != memoryUsedStringValue else { return }
                    self.memoryUsage = memoryUsageValue
                    self.memoryUsedString = memoryUsedStringValue
                    self.memoryTotalString = memoryTotalStringValue
                }
            }

            if includeDetailedStats {
                self.updateDetailedStats(
                    pagesActive: pages.active + pages.inactive + pages.speculative,
                    pagesWired: pages.wired,
                    pagesCompressed: pages.compressed,
                    pageSize: pages.pageSize,
                    totalRAM: totalRAM
                )
            }
        }
    }
    
    private func sampleNetworkUsage(includeDetails: Bool) {
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/bin/netstat", ["-ib"]) else { return }
            
            // netstat in nhiều dòng cho cùng một interface (mỗi loại địa chỉ một dòng)
            // nên chỉ lấy dòng đầu tiên của từng interface
            
            var byInterface: [String: (rx: UInt64, tx: UInt64)] = [:]
            var interfaceOrder: [String] = []
            
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count >= 10,
                      let rx = UInt64(parts[6]),
                      let tx = UInt64(parts[9]) else { continue }
                let name = parts[0]
                if byInterface[name] == nil {
                    byInterface[name] = (rx, tx)
                    interfaceOrder.append(name)
                }
            }
            
            // Cộng dồn các interface vật lý en*; VPN chạy qua utun sẽ bị đếm trùng
            // trên en* bên dưới nên không tính
            
            let physical = interfaceOrder.filter { $0.hasPrefix("en") && $0.dropFirst(2).allSatisfy(\.isNumber) }
            let targets = physical.isEmpty
                ? interfaceOrder.filter { !$0.hasPrefix("lo") }
                : physical
            guard !targets.isEmpty else { return }
            
            let bytesIn = targets.reduce(UInt64(0)) { $0 + (byInterface[$1]?.rx ?? 0) }
            let bytesOut = targets.reduce(UInt64(0)) { $0 + (byInterface[$1]?.tx ?? 0) }
            
            let now = Date()
            let timeDiff = now.timeIntervalSince(self.lastNetworkCheck)
            
            if timeDiff > 0 && self.lastBytesReceived > 0 {
                let downloadDelta = bytesIn > self.lastBytesReceived ? Double(bytesIn - self.lastBytesReceived) : 0
                let uploadDelta = bytesOut > self.lastBytesSent ? Double(bytesOut - self.lastBytesSent) : 0
                
                let downloadRate = downloadDelta / timeDiff
                let uploadRate = uploadDelta / timeDiff
                let totalDownloadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesIn), countStyle: .file)
                let totalUploadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesOut), countStyle: .file)
                
                Task {
                    await self.uiUpdater.throttle(Self.samplingFlushKey, minInterval: Self.samplingFlushMinInterval) {
                        self.downloadSpeed = downloadRate
                        self.uploadSpeed = uploadRate
                        self.totalDownload = totalDownloadStr
                        self.totalUpload = totalUploadStr
                        self.downloadSpeedHistory.removeFirst()
                        self.downloadSpeedHistory.append(downloadRate)
                        self.uploadSpeedHistory.removeFirst()
                        self.uploadSpeedHistory.append(uploadRate)
                    }
                }
            }
            
            self.lastBytesReceived = bytesIn
            self.lastBytesSent = bytesOut
            self.lastNetworkCheck = now
            
            if includeDetails {
                self.fetchWiFiInfo()
                self.updateConnectionDuration()
            }
        }
    }
    
    private func sampleBatteryStatus(includeDetails: Bool) {
        updateBatteryStatus()
        if includeDetails {
            updateBatteryDetails()
        }
    }
    
    // Lấy SSID qua CoreWLAN; binary airport đã bị Apple xoá khỏi macOS 14.4+
    // và không thể đọc SSID nếu người dùng không cấp quyền Vị trí
    
    private func fetchWiFiInfo() {
        let interface = CWWiFiClient.shared().interface()
        let ssid = interface?.ssid() ?? interface?.interfaceName
        
        Task {
            await uiUpdater.batch {
                self.wifiSSID = ssid ?? "Wi-Fi"
            }
        }
    }
    
    private func updateConnectionDuration() {
        let duration = Date().timeIntervalSince(connectionStartTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        let connectionDurationValue = String(format: L("%d giờ %d phút %d giây"), hours, minutes, seconds)
        
        Task {
            await uiUpdater.batch {
                self.connectionDuration = connectionDurationValue
            }
        }
    }
    
    private func updateBatteryStatus() {
        // Use pmset -g batt
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/usr/bin/pmset", ["-g", "batt"]) else { return }
            // Example output:
            // Now drawing from 'AC Power'
            // -InternalBattery-0 (id=1234567)	98%; charging; 0:10 remaining present: true
            
            let lines = output.components(separatedBy: "\n")
            guard lines.count >= 2 else { return }
            let statusLine = lines[1]
            
            // Parse Percentage
            var batteryLevelValue: Double = 1.0
            var isChargingValue = false
            var batteryStateValue = L("Không xác định")
            
            if let range = statusLine.range(of: "\\d+%", options: .regularExpression) {
                let percentString = String(statusLine[range]).dropLast()
                if let percent = Double(percentString) {
                    batteryLevelValue = percent / 100.0
                }
            }
            
            // Parse Charging State
            if output.contains("AC Power") {
                isChargingValue = true
                if statusLine.contains("charging") {
                    batteryStateValue = L("Đang sạc")
                } else {
                    batteryStateValue = L("Đã cắm nguồn")
                }
            } else {
                isChargingValue = false
                batteryStateValue = L("Đang dùng pin")
            }
            
            // Batch battery status update
            Task {
                await self.uiUpdater.batch {
                    self.batteryLevel = batteryLevelValue
                    self.isCharging = isChargingValue
                    self.batteryState = batteryStateValue
                }
            }
        }
    }
    

    func checkHighMemoryApps() {
        // Kiểm tra xem trong khi tạm dừng

        if let snoozedUntil = snoozedUntil, Date() < snoozedUntil {
            return  // Không phát hiện được khi tạm dừng
        }
        
        // Cảnh báo chỉ đúng khi TOÀN HỆ THỐNG thật sự hết RAM (memoryUsage vừa được
        // sample trong cùng tick bởi alertTimer), chứ không phải khi một app đơn lẻ vượt fixed 2GB
        
        let threshold = memoryAlertThresholdPercent / 100.0
        guard memoryUsage >= threshold else {
            if showHighMemoryAlert || highMemoryApp != nil {
                // Hết áp lực thì tự ẩn cảnh báo
                Task {
                    await uiUpdater.batch {
                        self.highMemoryApp = nil
                        self.showHighMemoryAlert = false
                    }
                }
            }
            return
        }
        
        // Chỉ xét app GUI của người dùng; RSS được cộng dồn cả tiến trình con
        // để con số hiển thị khớp với những gì người dùng thấy ở Activity Monitor
        
        struct AppSnapshot {
            let pid: pid_t
            let name: String
            let icon: NSImage?
        }
        let snapshots = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .map { AppSnapshot(pid: $0.processIdentifier, name: $0.localizedName ?? L("Không rõ"), icon: $0.icon) }
        
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/bin/ps", ["-axo", "pid,ppid,rss,comm"]) else { return }
            
            var rssByPid: [Int32: Double] = [:]     // GB
            var childrenMap: [Int32: [Int32]] = [:]
            
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
                if parts.count >= 3,
                   let pid = Int32(parts[0]),
                   let ppid = Int32(parts[1]),
                   let rssKB = Double(parts[2]) {
                    rssByPid[pid] = rssKB / 1024.0 / 1024.0
                    childrenMap[ppid, default: []].append(pid)
                }
            }
            
            // Dọn các PID đã thoát để tránh PID bị tái sử dụng làm mất cảnh báo oan
            self.ignoredPids = self.ignoredPids.filter { rssByPid[$0] != nil }
            
            func aggregateRSS(for pid: Int32, visited: inout Set<Int32>) -> Double {
                if visited.contains(pid) { return 0 }
                visited.insert(pid)
                var total = rssByPid[pid] ?? 0
                if let children = childrenMap[pid] {
                    for child in children {
                        total += aggregateRSS(for: child, visited: &visited)
                    }
                }
                return total
            }
            
            var maxRSS: Double = 0
            var maxSnapshot: AppSnapshot?
            
            for snapshot in snapshots {
                if self.ignoredPids.contains(snapshot.pid) { continue }
                if self.permanentlyIgnoredApps.contains(snapshot.name) { continue }
                
                var visited = Set<Int32>()
                let totalGB = aggregateRSS(for: snapshot.pid, visited: &visited)
                if totalGB > maxRSS {
                    maxRSS = totalGB
                    maxSnapshot = snapshot
                }
            }
            
            guard let snapshot = maxSnapshot else { return }
            let targetPid = snapshot.pid
            
            Task {
                await self.uiUpdater.batch { [weak self] in
                    guard let self = self else { return }
                    // Only update if it's a new alert or different app
                    if self.highMemoryApp?.id != targetPid {
                        self.highMemoryApp = HighMemoryApp(id: targetPid, name: snapshot.name, usage: maxRSS, icon: snapshot.icon)
                        self.showHighMemoryAlert = true
                    }
                }
            }
        }
    }
    
    func ignoreCurrentHighMemoryApp() {
        if let app = highMemoryApp {
            ignoredPids.insert(app.id)
            
            Task {
                await uiUpdater.batch {
                    self.highMemoryApp = nil
                    self.showHighMemoryAlert = false
                }
            }
        }
    }
    
    /// Tạm dừng cảnh báo bộ nhớ trong một khoảng thời gian (nhắc nhở theo lịch trình)

    /// - Tham số phút: Số phút tạm dừng

    func snoozeAlert(minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozedUntil = until
        
        // Tạm thời tắt cảnh báo hiện tại

        Task {
            await uiUpdater.batch {
                self.highMemoryApp = nil
                self.showHighMemoryAlert = false
            }
        }
        
        print("[MemoryMonitor] Snoozed for \(minutes) minutes until \(until)")
    }
    
    /// Bỏ qua vĩnh viễn ứng dụng có bộ nhớ cao hiện tại

    func ignoreAppPermanently() {
        guard let app = highMemoryApp else { return }
        
        // Thêm vào danh sách bỏ qua vĩnh viễn

        permanentlyIgnoredApps.insert(app.name)
        saveIgnoredApps()
        
        // Tắt cảnh báo

        Task {
            await uiUpdater.batch {
                self.highMemoryApp = nil
                self.showHighMemoryAlert = false
            }
        }
        
        print("[MemoryMonitor] Permanently ignored app: \(app.name)")
    }
    
    /// Xóa vĩnh viễn các ứng dụng bị bỏ qua (đối với giao diện cài đặt)

    /// - Tham số appName: tên ứng dụng

    func removeFromIgnoredApps(_ appName: String) {
        permanentlyIgnoredApps.remove(appName)
        saveIgnoredApps()
    }
    
    /// Nhận danh sách tất cả các ứng dụng bị bỏ qua vĩnh viễn

    func getIgnoredApps() -> [String] {
        return Array(permanentlyIgnoredApps).sorted()
    }
    
    /// Xóa tất cả các ứng dụng bị bỏ qua vĩnh viễn

    func clearAllIgnoredApps() {
        permanentlyIgnoredApps.removeAll()
        saveIgnoredApps()
    }
    
    @discardableResult
    func terminateHighMemoryApp() -> Bool {
        guard let app = highMemoryApp else { return false }
        guard confirmTermination(of: app) else { return false }
        forceQuitProcess(app.id, dismissAlert: true)
        return true
    }
    
    /// Hộp thoại xác nhận trước khi buộc thoát để người dùng không mất dữ liệu chưa lưu
    
    private func confirmTermination(of app: HighMemoryApp) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Buộc thoát %@?"), app.name)
        alert.informativeText = String(format: L("Ứng dụng đang dùng khoảng %.1f GB bộ nhớ. Buộc thoát có thể làm mất dữ liệu chưa lưu trong ứng dụng này."), app.usage)
        alert.addButton(withTitle: L("Buộc thoát"))
        alert.addButton(withTitle: L("Hủy"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    func forceQuitProcess(_ pid: pid_t, dismissAlert: Bool = false) {
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            _ = runningApp.forceTerminate()
        } else {
            let killTask = Process()
            killTask.launchPath = "/bin/kill"
            killTask.arguments = ["-9", "\(pid)"]
            try? killTask.run()
        }
        
        ignoredPids.insert(pid)
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if dismissAlert {
                await uiUpdater.batch {
                    if self.highMemoryApp?.id == pid {
                        self.highMemoryApp = nil
                        self.showHighMemoryAlert = false
                    }
                }
            }
            
            self.fetchUserProcesses()
            self.checkHighMemoryApps()
        }
    }
    
    // Detailed Stats
    @Published var systemUptime: TimeInterval = 0
    @Published var memoryApp: Double = 0
    @Published var memoryWired: Double = 0
    @Published var memoryCompressed: Double = 0
    @Published var memoryPressure: Double = 0.0 // Percentage
    @Published var memorySwapUsed: String = "0 B"
    @Published var memorySwapTotal: String = "0 B"
    @Published var batteryHealth: String = L("Đang đo")
    @Published var batteryCycleCount: Int = 0
    @Published var batteryCondition: String = L("Đang kiểm tra")

    // Add logic to updateStats
    private func updateDetailedStats(pagesActive: UInt64, pagesWired: UInt64, pagesCompressed: UInt64, pageSize: UInt64, totalRAM: UInt64) {
        let memoryAppValue = Double(pagesActive * pageSize) / Double(totalRAM)
        let memoryWiredValue = Double(pagesWired * pageSize) / Double(totalRAM)
        let memoryCompressedValue = Double(pagesCompressed * pageSize) / Double(totalRAM)
        
        // Uptime
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var systemUptimeValue: TimeInterval = 0
        if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000.0)
            systemUptimeValue = Date().timeIntervalSince(bootDate)
        }
        
        // Batch detailed stats update
        Task {
            await self.uiUpdater.batch {
                self.memoryApp = memoryAppValue
                self.memoryWired = memoryWiredValue
                self.memoryCompressed = memoryCompressedValue
                self.systemUptime = systemUptimeValue
            }
        }
        
        updateMemoryPressureAndSwap()
    }
    
    private func updateMemoryPressureAndSwap() {
        // Memory Pressure — chạy trên samplingQueue (nối tiếp) để các lần đo không chồng lên nhau
        
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/usr/bin/memory_pressure", ["-Q"]) else { return }
            
            // Output: "System-wide memory free percentage: 48%"
            if let range = output.range(of: "\\d+%", options: .regularExpression) {
                let percentString = String(output[range]).dropLast()
                if let freePercent = Double(percentString) {
                    let memoryPressureValue = (100.0 - freePercent) / 100.0
                    
                    // Batch pressure update
                    Task {
                        await self.uiUpdater.batch {
                            self.memoryPressure = memoryPressureValue
                        }
                    }
                }
            }
        }
        
        // Swap Usage — sysctl vm.swapusage
        samplingQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.runCommand("/usr/sbin/sysctl", ["vm.swapusage"]) else { return }
            
            // vm.swapusage: total = 5120.00M  used = 4426.56M  free = 693.44M  (encrypted)
            let components = output.components(separatedBy: " ")
            var usedStr = ""
            
            for (index, comp) in components.enumerated() {
                if comp == "used" && index + 2 < components.count {
                     // index+1 is "=", index+2 is value
                     usedStr = components[index + 2]
                }
            }
            
            // Batch swap update
            if !usedStr.isEmpty {
                Task {
                    await self.uiUpdater.batch {
                        self.memorySwapUsed = usedStr
                    }
                }
            }
        }
    }
    
    private var isUpdatingBatteryDetails = false
    
    private func updateBatteryDetails() {
        // system_profiler mất vài giây nên chặn chạy chồng giữa các lần lấy mẫu
        guard !isUpdatingBatteryDetails else { return }
        isUpdatingBatteryDetails = true
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPPowerDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            defer { self?.isUpdatingBatteryDetails = false }
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse Cycle Count and Condition
                    // "Cycle Count: 123"
                    // "Condition: Normal"
                    var cycleCount = 0
                    var condition = L("Bình thường")
                    var maxCapacity = 100
                    
                    let lines = output.components(separatedBy: "\n")
                    for line in lines {
                        if line.contains("Cycle Count:") {
                            if let val = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") {
                                cycleCount = val
                            }
                        } else if line.contains("Condition:") {
                            let raw = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                            condition = SystemMonitorService.localizedBatteryCondition(raw)
                        } else if line.contains("Maximum Capacity:") {
                            if let val = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "") ?? "") {
                                maxCapacity = val
                            }
                        }
                    }
                    
                    // Batch battery details update
                    Task {
                        await self?.uiUpdater.batch {
                            self?.batteryCycleCount = cycleCount
                            self?.batteryCondition = condition
                            self?.batteryHealth = "\(maxCapacity)%"
                        }
                    }
                }
            } catch {
                print("Battery Detail Error: \(error)")
            }
        }
    }
    
    private static func localizedBatteryCondition(_ raw: String) -> String {
        switch raw {
        case "Normal": return L("Bình thường")
        case "Service Recommended": return L("Nên bảo dưỡng")
        case "Replace Soon": return L("Sắp cần thay")
        default: return raw.isEmpty ? L("Không xác định") : raw
        }
    }
}
