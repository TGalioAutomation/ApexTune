import Foundation
import SwiftUI

// MARK: - Quản lý dịch vụ quét toàn cầu

/// Trình quản lý Singleton, duy trì trạng thái của tất cả các dịch vụ quét và ngăn ngừa mất tiến trình và kết quả quét khi chuyển đổi chế độ xem.

class ScanServiceManager: ObservableObject {
    static let shared = ScanServiceManager()
    
    // Dịch vụ quét riêng lẻ - được duy trì dưới dạng đơn lẻ

    let junkCleaner = JunkCleaner()
    let largeFileScanner = LargeFileScanner()
    let deepCleanScanner = DeepCleanScanner()
    let smartCleanerService = SmartCleanerService()
    let trashScanner = TrashScanner()  // Máy quét rác - Ngăn chặn quá trình quét bị gián đoạn khi chuyển đổi giao diện
    
    // Quét theo dõi trạng thái nhiệm vụ

    @Published var activeScans: Set<ScanType> = []
    
    // UI Update Batching
    private let uiUpdater = BatchedUIUpdater(debounceDelay: 0.05)
    
    private init() {}
    
    enum ScanType: String, CaseIterable {
        case junk = "Quét rác"
        case largeFiles = "Quét tệp lớn"
        case deepClean = "Dọn sâu"
        case smartClean = "Quét thông minh"
        case duplicates = "Tệp trùng lặp"
        case similarPhotos = "Ảnh tương tự"
        case localizations = "Tệp ngôn ngữ"
    }
    
    // MARK: - Quản lý quét nền

    
    /// Bắt đầu quét rác (nếu chưa tiến hành)

    func startJunkScanIfNeeded() {
        guard !junkCleaner.isScanning else { return }
        Task {
            // Batch the initial state update
            _ = await uiUpdater.batch {
                self.activeScans.insert(.junk)
            }
            
            // Perform scanning on background thread
            await junkCleaner.scanJunk()
            
            // Batch the final state update
            _ = await uiUpdater.batch {
                self.activeScans.remove(.junk)
            }
        }
    }
    
    /// Bắt đầu quét tệp lớn (nếu chưa được tiến hành)

    func startLargeFileScanIfNeeded() {
        guard !largeFileScanner.isScanning else { return }
        Task {
            // Batch the initial state update
            _ = await uiUpdater.batch {
                self.activeScans.insert(.largeFiles)
            }
            
            // Perform scanning on background thread
            await largeFileScanner.scan()
            
            // Batch the final state update
            _ = await uiUpdater.batch {
                self.activeScans.remove(.largeFiles)
            }
        }
    }
    
    /// Bắt đầu quét làm sạch sâu (nếu chưa tiến hành)

    func startDeepCleanScanIfNeeded() {
        guard !deepCleanScanner.isScanning else { return }
        Task {
            // Batch the initial state update
            _ = await uiUpdater.batch {
                self.activeScans.insert(.deepClean)
            }
            
            // Perform scanning on background thread
            await deepCleanScanner.startScan()
            
            // Batch the final state update
            _ = await uiUpdater.batch {
                self.activeScans.remove(.deepClean)
            }
        }
    }
    
    /// Bắt đầu quét dọn dẹp thông minh nếu chưa tiến hành

    func startSmartCleanScanIfNeeded() {
        guard !smartCleanerService.isScanning else { return }
        Task {
            // Batch the initial state update
            _ = await uiUpdater.batch {
                self.activeScans.insert(.smartClean)
            }
            
            // Perform scanning on background thread
            await smartCleanerService.scanAll()
            
            // Batch the final state update
            _ = await uiUpdater.batch {
                self.activeScans.remove(.smartClean)
            }
        }
    }
    
    /// Bắt đầu quét file trùng lặp

    func startDuplicatesScan() {
        guard !smartCleanerService.isScanning else { return }
        Task {
            // Batch the initial state update
            _ = await uiUpdater.batch {
                self.activeScans.insert(.duplicates)
            }
            
            // Perform scanning on background thread
            await smartCleanerService.scanDuplicates()
            
            // Batch the final state update
            _ = await uiUpdater.batch {
                self.activeScans.remove(.duplicates)
            }
        }
    }
    
    /// Kiểm tra xem có quá trình quét nào đang diễn ra không

    var isAnyScanning: Bool {
        junkCleaner.isScanning || 
        largeFileScanner.isScanning || 
        deepCleanScanner.isScanning ||
        smartCleanerService.isScanning
    }
    
    /// Nhận mô tả về quá trình quét đang diễn ra

    var activeScanDescriptions: [String] {
        var descriptions: [String] = []
        if junkCleaner.isScanning { descriptions.append(L("Quét rác")) }
        if largeFileScanner.isScanning { descriptions.append(L("Quét tệp lớn")) }
        if deepCleanScanner.isScanning { descriptions.append(L("Dọn sâu")) }
        if smartCleanerService.isScanning { descriptions.append(L("Quét thông minh")) }
        return descriptions
    }
    
    // MARK: - Quét toàn diện chỉ bằng một cú nhấp chuột

    
    /// Bắt đầu quét toàn bộ hệ thống (thực hiện tất cả các lần quét song song)

    func startComprehensiveScan() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                // Bắt đầu tất cả các lần quét song song

                group.addTask {
                    if !self.junkCleaner.isScanning {
                        _ = await self.uiUpdater.batch { self.activeScans.insert(.junk) }
                        await self.junkCleaner.scanJunk()
                        _ = await self.uiUpdater.batch { self.activeScans.remove(.junk) }
                    }
                }
                
                group.addTask {
                    if !self.largeFileScanner.isScanning {
                        _ = await self.uiUpdater.batch { self.activeScans.insert(.largeFiles) }
                        await self.largeFileScanner.scan()
                        _ = await self.uiUpdater.batch { self.activeScans.remove(.largeFiles) }
                    }
                }
                
                group.addTask {
                    if !self.deepCleanScanner.isScanning {
                        _ = await self.uiUpdater.batch { self.activeScans.insert(.deepClean) }
                        await self.deepCleanScanner.startScan()
                        _ = await self.uiUpdater.batch { self.activeScans.remove(.deepClean) }
                    }
                }
                
                group.addTask {
                    if !self.smartCleanerService.isScanning {
                        _ = await self.uiUpdater.batch { self.activeScans.insert(.smartClean) }
                        await self.smartCleanerService.scanAll()
                        _ = await self.uiUpdater.batch { self.activeScans.remove(.smartClean) }
                    }
                }
            }
        }
    }
    
    // ĐÁNH DẤU: - Thống kê

    
    /// Lấy tổng dung lượng có thể được làm sạch (chỉ tính các tệp đã chọn)

    var totalCleanableSize: Int64 {
        junkCleaner.selectedSize +
        deepCleanScanner.selectedSize +
        smartCleanerService.totalCleanableSize
    }
    
    /// Lấy tổng dung lượng các file lớn được tìm thấy

    var totalLargeFilesSize: Int64 {
        largeFileScanner.totalSize
    }
    
    /// Lấy số lượng tất cả các mục được quét

    var totalItemsFound: Int {
        let junkCount = junkCleaner.junkItems.count
        let largeFileCount = largeFileScanner.foundFiles.count
        let deepCleanCount = deepCleanScanner.items.count
        // Add other counts separately if needed
        return junkCount + largeFileCount + deepCleanCount
    }
}
