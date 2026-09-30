import Foundation

/// Tổng hợp số liệu nhanh cho các thẻ trên "Bảng điều khiển hệ thống":
/// số lượng và dung lượng model AI (Ollama) và image Docker.
/// Được làm mới mỗi khi popup menu bar mở ra.
final class DashboardInsights: ObservableObject {
    static let shared = DashboardInsights()

    @Published private(set) var aiModelsText: String = L("Đang kiểm tra…")
    @Published private(set) var dockerText: String = L("Đang kiểm tra…")
    @Published private(set) var aiModelCount: Int = 0
    @Published private(set) var aiModelTotalBytes: Int64 = 0
    @Published private(set) var dockerImageCount: Int = 0
    @Published private(set) var dockerTotalBytes: Int64 = 0

    private let queue = DispatchQueue(label: "com.apextune.dashboard-insights", qos: .utility)
    private var isRefreshing = false

    private init() {}

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        queue.async { [weak self] in
            guard let self else { return }

            // --- Ollama models ---
            var aiCount = 0
            var aiBytes: Int64 = 0
            if Self.runShell("command -v ollama") != nil,
               let raw = Self.runShell("ollama list") {
                let lines = raw.components(separatedBy: "\n").dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                aiCount = lines.count
                for line in lines {
                    let cols = line.split(separator: " ").map(String.init)
                    // Định dạng: NAME ID SIZE MODIFIED
                    if cols.count >= 3, let bytes = Self.parseOllamaSize(cols[2]) {
                        aiBytes += bytes
                    }
                }
            }

            // --- Docker images ---
            var dockerCount = 0
            var dockerBytes: Int64 = 0
            if Self.runShell("command -v docker") != nil,
               let raw = Self.runShell("docker images --format '{{.Size}}'") {
                let sizes = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                dockerCount = sizes.count
                dockerBytes = Int64(sizes.reduce(0.0) { $0 + DockerManager.parseDockerSize($1) })
            }

            DispatchQueue.main.async {
                self.aiModelCount = aiCount
                self.aiModelTotalBytes = aiBytes
                self.aiModelsText = aiCount == 0
                    ? L("Chưa phát hiện model nào")
                    : String(format: L("%d model · %@"), aiCount, ByteCountFormatter.string(fromByteCount: aiBytes, countStyle: .file))
                self.dockerImageCount = dockerCount
                self.dockerTotalBytes = dockerBytes
                self.dockerText = dockerCount == 0
                    ? L("Chưa có image nào")
                    : String(format: L("%d image · %@"), dockerCount, ByteCountFormatter.string(fromByteCount: dockerBytes, countStyle: .file))
                self.isRefreshing = false
            }
        }
    }

    private static func runShell(_ command: String) -> String? {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-lc", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Ollama in size dạng "4.7 GB", "20 GB", "2.7 GB" (dấu cách giữa số và đơn vị)
    private static func parseOllamaSize(_ text: String) -> Int64? {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        let units: [(String, Int64)] = [
            ("GB", 1_000_000_000), ("MB", 1_000_000), ("KB", 1_000), ("B", 1)
        ]
        for (suffix, factor) in units {
            if cleaned.hasSuffix(suffix) {
                let numberPart = cleaned.dropLast(suffix.count)
                if let value = Double(numberPart) {
                    return Int64(value * Double(factor))
                }
            }
        }
        return nil
    }
}
