import Foundation
import AppKit
import UserNotifications

class ProtectionService: ObservableObject {
    static let shared = ProtectionService()
    
    @Published var isMonitoring = false
    @Published var adBlockedCount: Int {
        didSet {
            UserDefaults.standard.set(adBlockedCount, forKey: "AdBlockedCount")
        }
    }
    @Published var threatHistory: [DetectedThreat] = []
    @Published var blockedAds: [BlockedAd] = []
    
    struct BlockedAd: Identifiable {
        let id = UUID()
        let domain: String
        let date: Date
        let source: String // e.g., "Safari", "Chrome"
    }
    
    private var downloadMonitorSource: DispatchSourceFileSystemObject?
    private var downloadFileDescriptor: CInt = -1
    private let malwareScanner = MalwareScanner()
    
    // Mock timer for ad block simulation (since we don't have a real Safari Extension connected)
    private var adSimulationTimer: Timer?
    
    private init() {
        self.adBlockedCount = UserDefaults.standard.integer(forKey: "AdBlockedCount")
        requestNotificationPermission()
    }
    
    func startMonitoring() {
        print("Starting Protection Service...")
        isMonitoring = true
        monitorDownloads()
        startAdBlockSimulation()
    }
    
    func stopMonitoring() {
        print("Stopping Protection Service...")
        isMonitoring = false
        stopDownloadsMonitor()
        stopAdBlockSimulation()
    }
    
    // MARK: - Download Monitoring
    
    private func monitorDownloads() {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
        let url = URL(fileURLWithPath: downloadsPath)
        
        // Open the directory
        downloadFileDescriptor = open(downloadsPath, O_EVTONLY)
        guard downloadFileDescriptor != -1 else {
            print("Failed to open Downloads folder")
            return
        }
        
        // Create Dispatch Source
        downloadMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: downloadFileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        downloadMonitorSource?.setEventHandler { [weak self] in
            // When file is written to Downloads, check for new files
            // For simplicity in this demo, we just scan "recently added" or do a quick scan of the folder
            // A better production approach is using FSEvents to get exact file paths.
            // Here we will just perform a quick check on the latest files in Downloads.
            self?.checkRecentDownloads(in: url)
        }
        
        downloadMonitorSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.downloadFileDescriptor)
            self.downloadFileDescriptor = -1
        }
        
        downloadMonitorSource?.resume()
        print("Monitoring Downloads folder at: \(downloadsPath)")
    }
    
    private func stopDownloadsMonitor() {
        downloadMonitorSource?.cancel()
        downloadMonitorSource = nil
    }
    
    private func checkRecentDownloads(in folder: URL) {
        // Find files modified in the last 10 seconds
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        
        let recentFiles = contents.filter { url in
            guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return false }
            return Date().timeIntervalSince(date) < 10 // Changed in last 10s
        }
        
        for file in recentFiles {
            if let threat = malwareScanner.scanFile(at: file) {
                // Virus Found!
                DispatchQueue.main.async {
                    self.reportThreat(threat)
                }
            }
        }
    }
    
    private func reportThreat(_ threat: DetectedThreat) {
        // 1. Add to history
        if !threatHistory.contains(where: { $0.path == threat.path }) {
            threatHistory.append(threat)
        }
        
        // 2. Send Notification
        let content = UNMutableNotificationContent()
        content.title = L("Phát hiện mối đe dọa virus")
        content.body = String(format: L("Đã phát hiện %@ trong thư mục Tải xuống. Hãy xử lý ngay."), threat.name)
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        // 3. Show Alert if App is active
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("Cảnh báo bảo mật: phát hiện virus")
        alert.informativeText = String(format: L("Tệp '%@' chứa virus hoặc phần mềm độc hại (%@).\nBạn nên xóa ngay."), threat.path.lastPathComponent, threat.name)
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("Xóa ngay"))
        alert.addButton(withTitle: L("Để sau"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User chose to delete
            try? FileManager.default.removeItem(at: threat.path)
            // Remove from history if deleted
            threatHistory.removeAll(where: { $0.path == threat.path })
        }
    }
    
    // MARK: - Ad Block Simulation
    // In a real app, this would be connected to a Safari Content Blocker Extension
    private func startAdBlockSimulation() {
        // Every 30 seconds, if a browser is running, increment ad count
        adSimulationTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkBrowserAndBlockAds()
        }
    }
    
    private func stopAdBlockSimulation() {
        adSimulationTimer?.invalidate()
        adSimulationTimer = nil
    }
    
    private func checkBrowserAndBlockAds() {
        let browserBundleIds = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"]
        let runningApps = NSWorkspace.shared.runningApplications
        
        let isBrowserRunning = runningApps.contains { app in
            guard let id = app.bundleIdentifier else { return false }
            return browserBundleIds.contains(id)
        }
        
        if isBrowserRunning {
            // Simulate blocking 1-3 ads
            let newBlocks = Int.random(in: 1...3)
            let domains = ["doubleclick.net", "googleadservices.com", "facebook.com/tr", "analytics.twitter.com", "ads.yahoo.com", "trackers.amazon.com"]
            
            DispatchQueue.main.async {
                self.adBlockedCount += newBlocks
                
                // Add mock details
                for _ in 0..<newBlocks {
                    let randomDomain = domains.randomElement() ?? "ads.example.com"
                    let source = ["Safari", "Chrome", "Edge"].randomElement() ?? "Browser"
                    let ad = BlockedAd(domain: randomDomain, date: Date(), source: source)
                    self.blockedAds.insert(ad, at: 0)
                    
                    // Keep list size manageable
                    if self.blockedAds.count > 100 {
                        self.blockedAds.removeLast()
                    }
                }
            }
            print("Simulated blocking \(newBlocks) ads.")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}
