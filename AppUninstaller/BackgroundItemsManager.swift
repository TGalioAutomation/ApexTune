import Foundation
import AppKit

/// Liệt kê các mục chạy ngầm của bên thứ ba (không phải của Apple) từ các thư mục
/// LaunchAgents/LaunchDaemons, kèm trạng thái và thao tác tạm tắt / bật lại.
final class BackgroundItemsManager: ObservableObject {
    static let shared = BackgroundItemsManager()

    enum ItemLocation: String {
        case userAgents = "LaunchAgents (người dùng)"
        case libraryAgents = "LaunchAgents (máy)"
        case libraryDaemons = "LaunchDaemons (máy)"
    }

    struct BackgroundItem: Identifiable {
        let label: String
        let programPath: String?
        let plistPath: String
        let location: ItemLocation
        let runAtLoad: Bool
        let keepAlive: Bool
        let isDisabled: Bool
        let isLoaded: Bool

        var id: String { plistPath }
        var name: String {
            if let programPath { return URL(fileURLWithPath: programPath).lastPathComponent }
            return label
        }
        var needsAdmin: Bool { location != .userAgents }
    }

    @Published private(set) var items: [BackgroundItem] = []
    @Published private(set) var isScanning = false

    var thirdPartyCount: Int { items.count }

    private var userHome: String { NSHomeDirectory() }
    private var currentUID: UInt32 { getuid() }

    // MARK: - Quét

    /// Quét các thư mục launch item, lọc bỏ mọi thứ thuộc về Apple.
    func refresh() {
        guard !isScanning else { return }
        isScanning = true

        let directories: [(String, ItemLocation)] = [
            (userHome + "/Library/LaunchAgents", .userAgents),
            ("/Library/LaunchAgents", .libraryAgents),
            ("/Library/LaunchDaemons", .libraryDaemons)
        ]

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let loadedLabels = self.fetchLoadedLabels()

            var found: [BackgroundItem] = []
            for (dir, location) in directories {
                guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
                for entry in entries {
                    let isDisabledVariant = entry.hasSuffix(".plist.disabled")
                    guard entry.hasSuffix(".plist") || isDisabledVariant else { continue }

                    let path = dir + "/" + entry
                    guard let data = FileManager.default.contents(atPath: path),
                          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                        continue
                    }

                    let label = plist["Label"] as? String ?? (entry as NSString).deletingPathExtension
                    let programArguments = plist["ProgramArguments"] as? [String] ?? []
                    let program = plist["Program"] as? String ?? programArguments.first

                    // Bỏ qua mọi thứ của hệ thống Apple
                    if label.hasPrefix("com.apple.") { continue }
                    if let program, program.hasPrefix("/System") || program.hasPrefix("/usr/libexec") || program.hasPrefix("/usr/sbin") { continue }

                    let disabled = (plist["Disabled"] as? Bool) ?? isDisabledVariant
                    let runAtLoad = (plist["RunAtLoad"] as? Bool) ?? true
                    let keepAlive = plist["KeepAlive"] != nil

                    found.append(BackgroundItem(
                        label: label,
                        programPath: program,
                        plistPath: path,
                        location: location,
                        runAtLoad: runAtLoad,
                        keepAlive: keepAlive,
                        isDisabled: disabled,
                        isLoaded: loadedLabels.contains(label) && !disabled
                    ))
                }
            }

            found.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.items = found
                self.isScanning = false
            }
        }
    }

    /// `launchctl list` cho biết label nào đang được nạp trong domain người dùng
    private func fetchLoadedLabels() -> Set<String> {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            var labels = Set<String>()
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.split(separator: "\t").map(String.init)
                if let label = parts.last {
                    labels.insert(label)
                }
            }
            return labels
        } catch {
            return []
        }
    }

    // MARK: - Thao tác

    /// Tạm tắt: đổi đuôi .plist sang .plist.disabled và bootout service đang nạp
    func disable(_ item: BackgroundItem, completion: ((Bool) -> Void)? = nil) {
        let newPath = item.plistPath + ".disabled"
        let label = item.label

        if item.needsAdmin {
            let command = "mv \(quoted(item.plistPath)) \(quoted(newPath)) && launchctl bootout system/\(quoted(label)) 2>/dev/null; true"
            let ok = PrivilegedShell.run(command)
            finishToggle(ok: ok, completion: completion)
        } else {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                var ok = false
                if let _ = try? FileManager.default.moveItem(atPath: item.plistPath, toPath: newPath) {
                    ok = self.runUserLaunchctl(["bootout", "gui/\(self.currentUID)/\(label)"])
                }
                DispatchQueue.main.async {
                    self.finishToggle(ok: ok, completion: completion)
                }
            }
        }
    }

    /// Bật lại: đổi đuôi .plist.disabled về .plist và bootstrap service
    func enable(_ item: BackgroundItem, completion: ((Bool) -> Void)? = nil) {
        let originalPath = String(item.plistPath.dropLast(".disabled".count))
        let label = item.label

        if item.needsAdmin {
            let command = "mv \(quoted(item.plistPath)) \(quoted(originalPath)) && launchctl bootstrap system \(quoted(originalPath)) 2>/dev/null; true"
            let ok = PrivilegedShell.run(command)
            finishToggle(ok: ok, completion: completion)
        } else {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                var ok = false
                if let _ = try? FileManager.default.moveItem(atPath: item.plistPath, toPath: originalPath) {
                    ok = self.runUserLaunchctl(["bootstrap", "gui/\(self.currentUID)", originalPath])
                }
                DispatchQueue.main.async {
                    self.finishToggle(ok: ok, completion: completion)
                }
            }
        }
    }

    func revealInFinder(_ item: BackgroundItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.plistPath)])
    }

    // MARK: - Helper

    private func finishToggle(ok: Bool, completion: ((Bool) -> Void)?) {
        if !ok {
            print("[BackgroundItems] Thao tác không thành công")
        }
        refresh()
        completion?(ok)
    }

    private func runUserLaunchctl(_ arguments: [String]) -> Bool {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = arguments
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func quoted(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
