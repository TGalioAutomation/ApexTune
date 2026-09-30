import Foundation
import AppKit

///Recovery Manager - Cung cấp khả năng hoàn tác và làm lại cho các hoạt động dọn dẹp

class RecoveryManager: ObservableObject {
    static let shared = RecoveryManager()
    
    private let fileManager = FileManager.default
    private let backupDirectory: URL
    private let historyFile: URL
    
    @Published var deletionHistory: [DeletionRecord] = []
    @Published var backupSize: Int64 = 0
    
    // ĐÁNH DẤU: - khởi tạo

    
    private init() {
        // Thư mục sao lưu: ~/Thư viện/Hỗ trợ ứng dụng/ApexTune/Sao lưu

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        backupDirectory = appSupport
            .appendingPathComponent("ApexTune")
            .appendingPathComponent("Backups")
        
        historyFile = appSupport
            .appendingPathComponent("ApexTune")
            .appendingPathComponent("deletion_history.json")
        
        // Tạo thư mục sao lưu

        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        // tải lịch sử

        loadHistory()
        
        // Tính toán kích thước dự phòng

        calculateBackupSize()
    }
    
    // ĐÁNH DẤU: - API công khai

    
    /// File sao lưu (được gọi trước khi xóa)

    /// - Parameters:
    /// - url: URL của file cần backup

    /// - danh mục: Danh mục sạch sẽ

    /// - Trả về: Backup có thành công hay không

    @discardableResult
    func backupBeforeDeletion(_ url: URL, category: String) -> Bool {
        // Chỉ sao lưu các tập tin cấu hình quan trọng

        let shouldBackup = url.path.contains("/Library/Preferences") ||
                          url.path.contains("/Library/Application Support")
        
        guard shouldBackup else { return true }
        
        // Tạo thư mục con sao lưu

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let backupSubdir = backupDirectory
            .appendingPathComponent(category)
            .appendingPathComponent(timestamp)
        
        do {
            try fileManager.createDirectory(at: backupSubdir, withIntermediateDirectories: true)
            
            // Sao chép tập tin vào thư mục sao lưu

            let backupURL = backupSubdir.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: backupURL)
            
            print("[RecoveryManager] ✅ Backed up: \(url.lastPathComponent)")
            return true
        } catch {
            print("[RecoveryManager] ⚠️ Backup failed: \(error)")
            return false
        }
    }
    
    /// thao tác xóa bản ghi

    /// - Parameters:
    /// - url: URL file đã xóa

    /// - danh mục: Danh mục sạch sẽ

    /// - size: kích thước file

    /// - wasBackedUp: đã được sao lưu chưa

    func recordDeletion(url: URL, category: String, size: Int64, wasBackedUp: Bool) {
        let record = DeletionRecord(
            originalPath: url.path,
            fileName: url.lastPathComponent,
            category: category,
            size: size,
            deletionDate: Date(),
            wasBackedUp: wasBackedUp,
            canRecover: wasBackedUp || isInTrash(url)
        )
        
        DispatchQueue.main.async {
            self.deletionHistory.insert(record, at: 0)
            self.saveHistory()
        }
    }
    
    ///Khôi phục tập tin (từ bản sao lưu hoặc Thùng rác)

    /// - Bản ghi tham số: xóa bản ghi

    /// - Returns: Việc khôi phục có thành công hay không

    func recoverFile(_ record: DeletionRecord) async -> Bool {
        // 1. Cố gắng khôi phục từ bản sao lưu

        if record.wasBackedUp {
            // Tìm tập tin sao lưu

            if let backupURL = findBackupFile(for: record) {
                do {
                    let originalURL = URL(fileURLWithPath: record.originalPath)
                    
                    // Kiểm tra xem tệp đã tồn tại ở vị trí ban đầu chưa

                    if fileManager.fileExists(atPath: originalURL.path) {
                        print("[RecoveryManager] ⚠️ File already exists at original location")
                        return false
                    }
                    
                    // Khôi phục tập tin

                    try fileManager.copyItem(at: backupURL, to: originalURL)
                    print("[RecoveryManager] ✅ Recovered from backup: \(record.fileName)")
                    
                    // Xóa khỏi lịch sử

                    await MainActor.run {
                        deletionHistory.removeAll { $0.id == record.id }
                        saveHistory()
                    }
                    
                    return true
                } catch {
                    print("[RecoveryManager] ❌ Recovery failed: \(error)")
                    return false
                }
            }
        }
        
        // 2. Cố gắng khôi phục từ Thùng rác

        // TODO: Triển khai logic phục hồi thùng rác

        // Việc khôi phục thùng rác trên macOS phức tạp hơn và yêu cầu phân tích cú pháp tệp .DS_Store.

        
        return false
    }
    
    /// Dọn dẹp các bản sao lưu hết hạn (thời gian lưu giữ mặc định là 30 ngày)

    func cleanupExpiredBackups(daysToKeep: Int = 30) {
        let cutoffDate = Date().addingTimeInterval(-Double(daysToKeep * 86400))
        
        // Xóa lịch sử

        deletionHistory.removeAll { $0.deletionDate < cutoffDate }
        saveHistory()
        
        // Làm sạch tập tin sao lưu

        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for categoryDir in contents {
            guard let subdirs = try? fileManager.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { continue }
            
            for backupDir in subdirs {
                if let creationDate = try? backupDir.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: backupDir)
                    print("[RecoveryManager] 🗑️ Removed expired backup: \(backupDir.lastPathComponent)")
                }
            }
        }
        
        calculateBackupSize()
    }
    
    // MARK: - phương pháp riêng tư

    
    private func isInTrash(_ url: URL) -> Bool {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let trashPath = trashURL.path
        
        // Kiểm tra xem tập tin có ở trong thùng rác không

        // Lưu ý: Phương pháp này chỉ có thể kiểm tra Thùng rác của người dùng chứ không thể kiểm tra Thùng rác của các tập khác.

        return url.path.hasPrefix(trashPath)
    }
    
    private func findBackupFile(for record: DeletionRecord) -> URL? {
        let categoryDir = backupDirectory.appendingPathComponent(record.category)
        
        guard let timestampDirs = try? fileManager.contentsOfDirectory(
            at: categoryDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        // Sắp xếp theo thời gian để tìm bản sao lưu gần nhất với thời điểm xóa

        let sortedDirs = timestampDirs.sorted { dir1, dir2 in
            let date1 = try? dir1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? dir2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
        }
        
        for dir in sortedDirs {
            let backupFile = dir.appendingPathComponent(record.fileName)
            if fileManager.fileExists(atPath: backupFile.path) {
                return backupFile
            }
        }
        
        return nil
    }
    
    private func calculateBackupSize() {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        DispatchQueue.main.async {
            self.backupSize = totalSize
        }
    }
    
    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFile.path),
              let data = try? Data(contentsOf: historyFile),
              let records = try? JSONDecoder().decode([DeletionRecord].self, from: data) else {
            return
        }
        
        deletionHistory = records
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(deletionHistory) else { return }
        try? data.write(to: historyFile)
    }
}

// ĐÁNH DẤU: - xóa bản ghi


struct DeletionRecord: Identifiable, Codable {
    let id = UUID()
    let originalPath: String
    let fileName: String
    let category: String
    let size: Int64
    let deletionDate: Date
    let wasBackedUp: Bool
    let canRecover: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: deletionDate)
    }
    
    enum CodingKeys: String, CodingKey {
        case originalPath, fileName, category, size, deletionDate, wasBackedUp, canRecover
    }
}
