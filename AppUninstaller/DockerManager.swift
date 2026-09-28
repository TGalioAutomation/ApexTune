import Foundation

/// Quản lý image Docker cục bộ qua Docker CLI (`docker images`, `docker rmi`).
/// CLI được gọi qua zsh login shell để kế thừa PATH của người dùng
/// (Docker Desktop đặt binary ở /usr/local/bin, ~/.docker/bin hoặc /opt/homebrew/bin).
final class DockerManager: ObservableObject {
    static let shared = DockerManager()

    struct DockerImage: Identifiable {
        let imageID: String
        let repository: String
        let tag: String
        let sizeText: String
        let createdText: String

        var id: String { imageID }
        var displayName: String {
            repository == "<none>" ? L("Ảnh không gán tên") : repository
        }
    }

    @Published private(set) var isInstalled: Bool = false
    @Published private(set) var isDaemonRunning: Bool = false
    @Published private(set) var images: [DockerImage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var totalSizeText: String = "—"
    @Published private(set) var statusMessage: String = ""

    private let shellQueue = DispatchQueue(label: "com.macoptimizer.docker", qos: .utility)

    var imageCount: Int { images.count }

    // MARK: - Làm mới

    func refresh() {
        guard !isLoading else { return }
        isLoading = true

        shellQueue.async { [weak self] in
            guard let self else { return }

            // command -v docker là cách đáng tin duy nhất vì GUI app không kế thừa PATH đầy đủ
            guard Self.runShell("command -v docker") != nil else {
                self.publish(isInstalled: false, daemonRunning: false, images: [], total: "—", message: L("Chưa cài Docker"))
                return
            }

            guard let raw = Self.runShell("docker images --format '{{.ID}}\\t{{.Repository}}\\t{{.Tag}}\\t{{.Size}}\\t{{.CreatedSince}}'") else {
                self.publish(isInstalled: true, daemonRunning: false, images: [], total: "—", message: L("Docker Desktop chưa chạy"))
                return
            }

            var parsed: [DockerImage] = []
            for line in raw.components(separatedBy: "\n") where !line.isEmpty {
                let cols = line.components(separatedBy: "\t")
                guard cols.count >= 5 else { continue }
                parsed.append(DockerImage(
                    imageID: cols[0],
                    repository: cols[1],
                    tag: cols[2],
                    sizeText: cols[3],
                    createdText: cols[4]
                ))
            }

            let totalBytes = parsed.reduce(0.0) { $0 + Self.parseDockerSize($1.sizeText) }
            let total = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)

            self.publish(isInstalled: true, daemonRunning: true, images: parsed, total: total, message: "")
        }
    }

    // MARK: - Thao tác

    /// Xóa một image (đã xác nhận ở tầng giao diện)
    func deleteImage(_ image: DockerImage, completion: ((Bool) -> Void)? = nil) {
        shellQueue.async { [weak self] in
            let output = Self.runShell("docker rmi -f \(image.imageID)")
            let ok = output != nil
            DispatchQueue.main.async {
                self?.refresh()
                completion?(ok)
            }
        }
    }

    /// Dọn các image lơ lửng (dangling, repository = <none>)
    func pruneDangling(completion: ((Bool) -> Void)? = nil) {
        shellQueue.async { [weak self] in
            let output = Self.runShell("docker image prune -f")
            let ok = output != nil
            DispatchQueue.main.async {
                self?.refresh()
                completion?(ok)
            }
        }
    }

    // MARK: - Helper

    private func publish(isInstalled: Bool, daemonRunning: Bool, images: [DockerImage], total: String, message: String) {
        DispatchQueue.main.async {
            self.isInstalled = isInstalled
            self.isDaemonRunning = daemonRunning
            self.images = images
            self.totalSizeText = total
            self.statusMessage = message
            self.isLoading = false
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

    /// Parse chuỗi size của docker, ví dụ "724.3MB", "1.24GB", "84.5kB"
    static func parseDockerSize(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let units: [(String, Double)] = [
            ("kB", 1_000), ("KB", 1_000), ("MB", 1_000_000), ("GB", 1_000_000_000), ("TB", 1_000_000_000_000),
            ("B", 1)
        ]
        for (suffix, factor) in units {
            if trimmed.hasSuffix(suffix) {
                let numberPart = trimmed.dropLast(suffix.count)
                if let value = Double(numberPart) {
                    return value * factor
                }
            }
        }
        return 0
    }
}
