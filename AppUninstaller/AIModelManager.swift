import SwiftUI
import AppKit
import AIModelKit

final class AIModelManager: ObservableObject {
    @Published var providerStates: [AIModelProvider: AIProviderState] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?
    @Published var activeItemID: UUID?
    @Published var isPulling = false
    @Published var ollamaPullName = ""

    private let fileManager = FileManager.default
    private let modelFileExtensions: Set<String> = [
        "gguf", "safetensors", "bin", "pth", "pt", "onnx", "ckpt"
    ]

    init() {
        refresh()
    }

    var allItems: [AIModelItem] {
        providerStates.values
            .flatMap(\.items)
            .sorted { lhs, rhs in
                if lhs.size == rhs.size {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.size > rhs.size
            }
    }

    var totalManagedSize: Int64 {
        providerStates.values.reduce(0) { $0 + $1.totalSize }
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let ollama = self.scanOllamaState()
            let lmStudio = self.scanLMStudioState()

            DispatchQueue.main.async {
                self.providerStates = [
                    .ollama: ollama,
                    .lmStudio: lmStudio
                ]
                self.isLoading = false
            }
        }
    }

    func openRoot(for provider: AIModelProvider) {
        guard let root = providerStates[provider]?.roots.first else { return }
        NSWorkspace.shared.selectFile(root.path, inFileViewerRootedAtPath: root.deletingLastPathComponent().path)
    }

    func reveal(_ item: AIModelItem) {
        guard let url = item.url else {
            openRoot(for: item.provider)
            return
        }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    func delete(_ item: AIModelItem, completion: @escaping (Bool, String) -> Void) {
        activeItemID = item.id
        actionMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result: (Bool, String)

            switch item.deleteStrategy {
            case .ollama(let name):
                let escapedName = self.shellEscaped(name)
                let output = self.runShell("ollama rm \(escapedName)")
                if output.status == 0 {
                    result = (true, String(format: L("Đã xóa model `%@` khỏi Ollama."), name))
                } else {
                    result = (false, output.output.isEmpty ? L("Không thể xóa model Ollama.") : output.output)
                }

            case .trash(let url):
                if DeletionLogService.shared.logAndDelete(at: url, category: "AIModels") {
                    result = (true, String(format: L("Đã chuyển `%@` vào Thùng rác."), item.name))
                } else {
                    result = (false, String(format: L("Không thể chuyển `%@` vào Thùng rác."), item.name))
                }

            case .none:
                result = (false, L("Model này hiện chưa có thao tác xóa trực tiếp."))
            }

            DispatchQueue.main.async {
                self.activeItemID = nil
                self.actionMessage = result.1
                if result.0 {
                    self.refresh()
                }
                completion(result.0, result.1)
            }
        }
    }

    func pullOllamaModel(completion: @escaping (Bool, String) -> Void) {
        let trimmed = ollamaPullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, L("Nhập tên model Ollama trước khi pull."))
            return
        }

        isPulling = true
        actionMessage = String(format: L("Đang tải `%@` từ Ollama..."), trimmed)

        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.runShell("ollama pull \(self.shellEscaped(trimmed))")
            let success = output.status == 0
            let message = success
                ? String(format: L("Đã pull xong `%@`."), trimmed)
                : (output.output.isEmpty ? L("Pull model thất bại.") : output.output)

            DispatchQueue.main.async {
                self.isPulling = false
                self.actionMessage = message
                if success {
                    self.ollamaPullName = ""
                    self.refresh()
                }
                completion(success, message)
            }
        }
    }

    private func scanOllamaState() -> AIProviderState {
        let roots = AIModelProvider.ollama.candidateRoots.filter { fileManager.fileExists(atPath: $0.path) }
        let commandResult = runShell("command -v ollama")
        let hasCLI = commandResult.status == 0

        var items: [AIModelItem] = []
        if hasCLI {
            let listResult = runShell("ollama list")
            items = AIModelParsing.parseOllamaList(listResult.output, root: roots.first)
        }

        let totalSize: Int64
        if !items.isEmpty {
            totalSize = items.reduce(0) { $0 + $1.size }
        } else if let root = roots.first {
            totalSize = directorySize(at: root)
        } else {
            totalSize = 0
        }

        let status: String
        if !hasCLI && !roots.isEmpty {
            status = L("Có dữ liệu Ollama cục bộ nhưng không tìm thấy lệnh `ollama`.")
        } else if hasCLI && items.isEmpty {
            status = L("Ollama sẵn sàng nhưng chưa có model nào được pull.")
        } else if !hasCLI {
            status = L("Chưa phát hiện Ollama trên máy này.")
        } else {
            status = String(format: L("Đã phát hiện %d model Ollama."), items.count)
        }

        return AIProviderState(
            provider: .ollama,
            items: items.sorted { $0.size > $1.size },
            totalSize: totalSize,
            roots: roots,
            isDetected: hasCLI || !roots.isEmpty,
            status: status,
            canPull: hasCLI,
            canDelete: hasCLI,
        )
    }

    private func scanLMStudioState() -> AIProviderState {
        let roots = deduplicateRoots(AIModelProvider.lmStudio.candidateRoots.filter { fileManager.fileExists(atPath: $0.path) })

        var items: [AIModelItem] = []
        for root in roots {
            items.append(contentsOf: scanLMStudioRoot(root))
        }

        let totalSize: Int64
        if !items.isEmpty {
            totalSize = items.reduce(0) { $0 + $1.size }
        } else {
            totalSize = roots.reduce(0) { $0 + directorySize(at: $1) }
        }

        let status: String
        if roots.isEmpty {
            status = L("Chưa tìm thấy thư mục model của LM Studio.")
        } else if items.isEmpty {
            status = L("Có thư mục LM Studio nhưng chưa nhận diện được file model quen thuộc.")
        } else {
            status = String(format: L("Đã phát hiện %d model trong LM Studio."), items.count)
        }

        return AIProviderState(
            provider: .lmStudio,
            items: items.sorted { $0.size > $1.size },
            totalSize: totalSize,
            roots: roots,
            isDetected: !roots.isEmpty,
            status: status,
            canPull: false,
            canDelete: true,
        )
    }

    private func scanLMStudioRoot(_ root: URL) -> [AIModelItem] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var collected: [AIModelItem] = []

        for child in children {
            if isModelFile(child) {
                collected.append(makeLMStudioItem(from: child))
                continue
            }

            guard isDirectory(child) else { continue }
            let subdirectories = directSubdirectories(of: child)
            let childHasModelFiles = directoryContainsModelArtifacts(child)
            let nestedModelDirectories = subdirectories.filter { directoryContainsModelArtifacts($0) }

            if nestedModelDirectories.count >= 2 && !directoryContainsDirectModelFiles(child) {
                collected.append(contentsOf: nestedModelDirectories.map(makeLMStudioItem(from:)))
            } else if childHasModelFiles {
                collected.append(makeLMStudioItem(from: child))
            }
        }

        return deduplicateLMStudioItems(collected)
    }

    private func makeLMStudioItem(from url: URL) -> AIModelItem {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let modifiedDate = values?.contentModificationDate
        let isDirectoryItem = isDirectory(url)
        let name = isDirectoryItem ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent

        return AIModelItem(
            provider: .lmStudio,
            name: name,
            size: isDirectoryItem ? directorySize(at: url) : fileSize(at: url),
            modifiedDate: modifiedDate,
            url: url,
            locationDescription: url.path,
            details: isDirectoryItem ? L("Thư mục model của LM Studio") : L("Tệp model của LM Studio"),
            deleteStrategy: .trash(url: url)
        )
    }

    private func deduplicateLMStudioItems(_ items: [AIModelItem]) -> [AIModelItem] {
        var seenPaths = Set<String>()
        return items.filter { item in
            guard let path = item.url?.standardizedFileURL.path else { return true }
            if seenPaths.contains(path) {
                return false
            }
            seenPaths.insert(path)
            return true
        }
    }

    private func deduplicateRoots(_ roots: [URL]) -> [URL] {
        let sortedRoots = roots.sorted { $0.path.count < $1.path.count }
        var result: [URL] = []

        for root in sortedRoots {
            let path = root.standardizedFileURL.path
            if result.contains(where: { path.hasPrefix($0.standardizedFileURL.path + "/") || path == $0.standardizedFileURL.path }) {
                continue
            }
            result.append(root)
        }

        return result
    }

    private func directSubdirectories(of url: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter(isDirectory)
    }

    private func directoryContainsModelArtifacts(_ url: URL) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return false
        }

        for case let candidate as URL in enumerator {
            if isModelFile(candidate) {
                return true
            }
        }
        return false
    }

    private func directoryContainsDirectModelFiles(_ url: URL) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return contents.contains(where: isModelFile)
    }

    private func isModelFile(_ url: URL) -> Bool {
        guard !isDirectory(url) else { return false }
        return modelFileExtensions.contains(url.pathExtension.lowercased())
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func fileSize(at url: URL) -> Int64 {
        let sizeValue = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return Int64(sizeValue ?? 0)
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            totalSize += Int64(values?.fileSize ?? 0)
        }
        return totalSize
    }

    private func shellEscaped(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private func runShell(_ command: String) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (1, error.localizedDescription)
        }
    }
}
