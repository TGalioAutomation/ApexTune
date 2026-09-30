import Foundation
import AppKit

// MARK: - Mô hình ghi thùng rác (dùng để theo dõi file đã xóa để phục hồi)

struct TrashRecord: Codable, Identifiable {
    let id: UUID
    let originalPath: String      // đường dẫn gốc
    let trashPath: String?        // Đường dẫn vào Thùng rác
    let fileName: String          // tên tập tin
    let size: Int64               // kích thước tập tin
    let deletionDate: Date        // Xóa thời gian
    let category: String          // Xóa các nguồn (SmartClean, DeepClean, v.v.)
    var isRestored: Bool          // Nó đã được khôi phục chưa?
    
    init(originalPath: String, trashPath: String?, size: Int64, category: String) {
        self.id = UUID()
        self.originalPath = originalPath
        self.trashPath = trashPath
        self.fileName = URL(fileURLWithPath: originalPath).lastPathComponent
        self.size = size
        self.deletionDate = Date()
        self.category = category
        self.isRestored = false
    }
}

// MARK: - Xóa nhật ký dịch vụ

///Ghi lại các tập tin đã xóa và hỗ trợ khôi phục về vị trí ban đầu

class DeletionLogService: ObservableObject {
    static let shared = DeletionLogService()
    
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let dateFormatter: ISO8601DateFormatter
    
    @Published var deletionRecords: [TrashRecord] = []
    
    // Số ngày lưu giữ nhật ký

    private let retentionDays: Int = 30
    
    private init() {
        // Thư mục lưu trữ nhật ký: ~/Library/Application Support/ApexTune/deletion_logs/

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("ApexTune/deletion_logs")
        
        // Tạo thư mục

        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        // Tải nhật ký ngày hôm nay

        loadTodayLog()
        
        // Dọn dẹp nhật ký hết hạn

        cleanupOldLogs()
    }
    
    // ĐÁNH DẤU: - API công khai

    
    /// Xóa và ghi nhật ký tệp một cách an toàn (hỗ trợ khôi phục từ Thùng rác)

    /// - Parameters:
    /// - url: URL của file cần xóa

    /// - danh mục: xóa danh mục nguồn

    /// - Trả về: Việc xóa có thành công hay không

    @discardableResult
    func logAndDelete(at url: URL, category: String = "SmartClean") -> Bool {
        let originalPath = url.path
        
        // Nhận kích thước tập tin

        let size: Int64
        if let attrs = try? fileManager.attributesOfItem(atPath: originalPath),
           let fileSize = attrs[.size] as? Int64 {
            size = fileSize
        } else {
            // Nếu là thư mục thì tính tổng kích thước

            size = calculateSize(at: url)
        }
        
        // Sử dụng thùng rác và lấy đường dẫn mới vào thùng rác

        var trashURL: NSURL?
        do {
            try fileManager.trashItem(at: url, resultingItemURL: &trashURL)
            
            let trashPath = trashURL?.path
            
            // Tạo bản ghi xóa

            let record = TrashRecord(
                originalPath: originalPath,
                trashPath: trashPath,
                size: size,
                category: category
            )
            
            // Thêm vào bản ghi bộ nhớ

            DispatchQueue.main.async {
                self.deletionRecords.append(record)
            }
            
            // Lưu vào tập tin nhật ký

            saveRecord(record)
            
            print("[DeletionLog] ✅ Logged deletion: \(originalPath) -> \(trashPath ?? "unknown")")
            return true
            
        } catch {
            print("[DeletionLog] ❌ Failed to delete: \(originalPath) - \(error.localizedDescription)")
            return false
        }
    }
    
    ///Khôi phục tập tin về vị trí ban đầu

    /// - Bản ghi tham số: xóa bản ghi

    /// - Returns: Việc khôi phục có thành công hay không

    func restore(_ record: TrashRecord) -> Bool {
        guard let trashPath = record.trashPath else {
            print("[DeletionLog] ❌ Cannot restore: no trash path recorded")
            return false
        }
        
        let trashURL = URL(fileURLWithPath: trashPath)
        let originalURL = URL(fileURLWithPath: record.originalPath)
        
        // Kiểm tra xem tệp trong Thùng rác có tồn tại không

        guard fileManager.fileExists(atPath: trashPath) else {
            print("[DeletionLog] ❌ Cannot restore: file not found in trash")
            return false
        }
        
        // Đảm bảo thư mục gốc tồn tại

        let originalDir = originalURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: originalDir, withIntermediateDirectories: true)
        } catch {
            print("[DeletionLog] ❌ Cannot create original directory: \(error)")
            return false
        }
        
        // Nếu tệp đã tồn tại ở vị trí ban đầu, hãy sao lưu nó trước.

        if fileManager.fileExists(atPath: record.originalPath) {
            let backupURL = originalURL.appendingPathExtension("backup_\(Date().timeIntervalSince1970)")
            try? fileManager.moveItem(at: originalURL, to: backupURL)
        }
        
        // Di chuyển tập tin trở lại vị trí ban đầu

        do {
            try fileManager.moveItem(at: trashURL, to: originalURL)
            
            // Cập nhật trạng thái bản ghi

            if let index = deletionRecords.firstIndex(where: { $0.id == record.id }) {
                DispatchQueue.main.async {
                    self.deletionRecords[index].isRestored = true
                }
            }
            
            print("[DeletionLog] ✅ Restored: \(record.originalPath)")
            return true
            
        } catch {
            print("[DeletionLog] ❌ Failed to restore: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Lấy danh sách file có thể phục hồi

    func getRestorableRecords() -> [TrashRecord] {
        return deletionRecords.filter { record in
            guard let trashPath = record.trashPath else { return false }
            return !record.isRestored && fileManager.fileExists(atPath: trashPath)
        }
    }
    
    /// Tải tất cả nhật ký (N ngày qua)

    func loadAllLogs(days: Int = 30) {
        var allRecords: [TrashRecord] = []
        
        let calendar = Calendar.current
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateString = dateFormatter.string(from: date)
            let logFile = logDirectory.appendingPathComponent("deletions_\(dateString).json")
            
            if let data = try? Data(contentsOf: logFile),
               let records = try? JSONDecoder().decode([TrashRecord].self, from: data) {
                allRecords.append(contentsOf: records)
            }
        }
        
        DispatchQueue.main.async {
            self.deletionRecords = allRecords.sorted { $0.deletionDate > $1.deletionDate }
        }
    }
    
    // MARK: - phương pháp riêng tư

    
    private func loadTodayLog() {
        let dateString = dateFormatter.string(from: Date())
        let logFile = logDirectory.appendingPathComponent("deletions_\(dateString).json")
        
        if let data = try? Data(contentsOf: logFile),
           let records = try? JSONDecoder().decode([TrashRecord].self, from: data) {
            DispatchQueue.main.async {
                self.deletionRecords = records
            }
        }
    }
    
    private func saveRecord(_ record: TrashRecord) {
        let dateString = dateFormatter.string(from: Date())
        let logFile = logDirectory.appendingPathComponent("deletions_\(dateString).json")
        
        // Đọc hồ sơ hiện có

        var records: [TrashRecord] = []
        if let data = try? Data(contentsOf: logFile),
           let existingRecords = try? JSONDecoder().decode([TrashRecord].self, from: data) {
            records = existingRecords
        }
        
        // Thêm bản ghi mới

        records.append(record)
        
        // cứu

        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: logFile)
        }
    }
    
    private func cleanupOldLogs() {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        
        if let files = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files {
                if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attrs.creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                    print("[DeletionLog] 🗑️ Cleaned up old log: \(file.lastPathComponent)")
                }
            }
        }
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
}

// MÃ: - Tiện ích mở rộng tiện lợi

extension FileManager {
    /// Xóa và ghi file an toàn (sử dụng DeletionLogService)

    func safeTrashItem(at url: URL, category: String = "General") -> Bool {
        return DeletionLogService.shared.logAndDelete(at: url, category: category)
    }
}
