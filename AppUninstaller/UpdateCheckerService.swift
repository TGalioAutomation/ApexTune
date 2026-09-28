import Foundation
import SwiftUI
import Network

// MARK: - Update Checker Service
class UpdateCheckerService: ObservableObject {
    static let shared = UpdateCheckerService()
    
    @Published var hasUpdate = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var downloadURL: URL?
    @Published var isChecking = false
    @Published var errorMessage: String?
    
    // GitHub Repo Info
    private let repoOwner = "apexdev"
    private let repoName = "MacOptimizer"
    
    // Giám sát trạng thái mạng

    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.4"
    }
    
    private init() {
        setupNetworkMonitor()
    }
    
    deinit {
        networkMonitor?.cancel()
    }
    
    /// Thiết lập giám sát trạng thái mạng

    private func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = (path.status == .satisfied)
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
    }
    
    func checkForUpdates() async {
        // Trì hoãn kiểm tra để đảm bảo màn hình mạng đã được khởi tạo

        try? await Task.sleep(nanoseconds: 500_000_000) // 0,5 giây
        
        // Kiểm tra xem mạng có sẵn không

        guard isNetworkAvailable else {
            print("[UpdateChecker] ⚠️ Network not available, skipping update check")
            await MainActor.run {
                self.errorMessage = L("Không có kết nối mạng")
            }
            return
        }
        
        await MainActor.run {
            self.isChecking = true
            self.errorMessage = nil
        }
        
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.isChecking = false
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            // Sử dụng thời gian chờ ngắn hơn để tránh bị treo lâu trong trường hợp có sự cố về proxy/mạng

            request.timeoutInterval = 5
            
            // Sử dụng cấu hình không có proxy (tùy chọn, nếu có vấn đề với proxy)

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 10
            config.waitsForConnectivity = false // Đừng chờ mạng phục hồi
            
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            await MainActor.run {
                self.isChecking = false
                // Remove 'v' prefix if present for comparison
                let serverVer = release.tag_name.replacingOccurrences(of: "v", with: "")
                let localVer = self.currentVersion.replacingOccurrences(of: "v", with: "")
                
                if serverVer.compare(localVer, options: .numeric) == .orderedDescending {
                    self.hasUpdate = true
                    self.latestVersion = release.tag_name
                    self.releaseNotes = release.body
                    self.downloadURL = URL(string: release.html_url)
                } else {
                    self.hasUpdate = false
                    self.latestVersion = release.tag_name
                }
            }
        } catch {
            await MainActor.run {
                self.isChecking = false
                // Xử lý lỗi mạng một cách âm thầm mà không ảnh hưởng đến việc khởi động ứng dụng

                self.errorMessage = error.localizedDescription
                print("[UpdateChecker] ⚠️ Update check failed (possibly no network): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let body: String
}
