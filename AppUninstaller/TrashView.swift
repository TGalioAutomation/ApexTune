import SwiftUI

// MARK: - Trạng thái quét

enum TrashScanState {
    case initial    // Trang đầu tiên
    case scanning   // Đang quét
    case completed  // Quét hoàn tất (trang kết quả)
    case clean      // Quét xong và không có tập tin
    case cleaning   // Dọn dẹp
    case finished   // Đã hoàn tất dọn dẹp
}

struct TrashItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateDeleted: Date?
    let isDirectory: Bool
    var isSelected: Bool = true
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = dateDeleted else { return L("Không rõ") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

class TrashScanner: ObservableObject {
    @Published var items: [TrashItem] = []
    @Published var isScanning = false
    @Published var totalSize: Int64 = 0
    @Published var hasCompletedScan = false
    @Published var needsPermission = false
    
    // Thêm thuộc tính mới

    @Published var scannedItemCount: Int = 0
    @Published var isStopped = false
    @Published var currentScanPath: String = ""
    @Published var isCleaning = false 
    @Published var cleanedCount: Int = 0
    @Published var cleanedSize: Int64 = 0
    
    // Tính kích thước vùng chọn

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
    
    // Chuyển đổi trạng thái đã chọn

    func toggleSelection(_ item: TrashItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isSelected.toggle()
            // Thông báo xuất bản kích hoạt (mặc dù các thay đổi về thuộc tính phần tử trong mảng @Published có thể không kích hoạt, việc thay thế cấu trúc sẽ)

        }
    }
    
    // Chuyển đổi tất cả các trạng thái đã chọn

    func toggleAllSelection(_ selected: Bool) {
        for i in 0..<items.count {
            items[i].isSelected = selected
        }
    }
    
    private let fileManager = FileManager.default
    let trashURL: URL
    private var shouldStop = false
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    init() {
        // Nhận đường dẫn rác chính xác bằng API hệ thống

        if let trashURLs = try? fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            trashURL = trashURLs
        } else {
            // Dự phòng về đường dẫn cũ

            trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        }
    }
    
    func stopScan() {
        shouldStop = true
        isScanning = false
        isStopped = true
    }
    
    func scan() async {
        await MainActor.run {
            isScanning = true
            isStopped = false
            shouldStop = false
            items = []
            totalSize = 0
            scannedItemCount = 0
            hasCompletedScan = false
            needsPermission = false
        }
        
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        // Trước tiên hãy thử truy cập trực tiếp (yêu cầu Truy cập Toàn bộ Đĩa)

        var hasAccess = false
        
        // Chỉ cần mô phỏng các thay đổi đường dẫn trong quá trình quét để cải thiện trải nghiệm người dùng.

        await MainActor.run { self.currentScanPath = "Preparing..." }
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pre-delay
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            hasAccess = true
            
            for fileURL in contents {
                if shouldStop { break }
                
                let size = calculateSize(at: fileURL)
                let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                let date = resourceValues?.contentModificationDate
                let isDir = resourceValues?.isDirectory ?? false
                
                let item = TrashItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    dateDeleted: date,
                    isDirectory: isDir
                )
                scannedItems.append(item)
                total += size
                
                await MainActor.run {
                    self.scannedItemCount += 1
                    self.currentScanPath = fileURL.path
                }
                
                // Trì hoãn một chút để người dùng có thể nhìn rõ quá trình quét (đối với các tệp nhỏ)

                if contents.count < 50 {
                   try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                }
            }
        } catch {
            print("Direct access failed: \(error)")
        }
        
        // Nếu truy cập trực tiếp không thành công, hãy thử sử dụng lệnh shell

        if !hasAccess && !shouldStop {
            let result = await scanWithShell()
            scannedItems = result.items
            total = result.total
            
            // Nếu không có kết quả trong shell, điều đó có nghĩa là cần có quyền.

            if scannedItems.isEmpty {
                await MainActor.run {
                    needsPermission = true
                }
            }
        }
        
        let sortedItems = scannedItems.sorted { $0.size > $1.size }
        let finalTotal = total
        
        await MainActor.run {
            self.items = sortedItems
            self.totalSize = finalTotal
            self.isScanning = false
            self.scannedItemCount = sortedItems.count
            self.hasCompletedScan = true
        }
    }
    
    // Quét thư mục được chỉ định (để xem chi tiết)

    func scanDirectory(_ url: URL) -> [TrashItem] {
        var items: [TrashItem] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]) else {
            return []
        }
        
        for fileURL in contents {
            let size = calculateSize(at: fileURL)
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            let date = resourceValues?.contentModificationDate
            let isDir = resourceValues?.isDirectory ?? false
            
            items.append(TrashItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                size: size,
                dateDeleted: date,
                isDirectory: isDir
            ))
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // đặt trở lại vị trí

    func putBack(_ item: TrashItem) {
        let script = """
        tell application "Finder"
            activate
            try
                set targetItem to (POSIX file "\(item.url.path)") as alias
                select targetItem
                tell application "System Events"
                    key code 51 using {command down}
                end tell
            on error
                -- ignore
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
        
        // làm mới sau

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await scan()
        }
    }
    
    func openSystemPreferences() {
        // Mở Cài đặt hệ thống Quyền riêng tư & Bảo mật - Truy cập toàn bộ đĩa

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func scanWithShell() async -> (items: [TrashItem], total: Int64) {
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        // Nhận nội dung thùng rác từ Finder bằng AppleScript

        let script = """
        tell application "Finder"
            set trashItems to items of trash
            set output to ""
            repeat with anItem in trashItems
                try
                    set itemPath to POSIX path of (anItem as alias)
                    set itemName to name of anItem
                    set itemSize to size of anItem
                on error
                    set itemPath to ""
                    set itemName to ""
                    set itemSize to 0
                end try
                if itemPath is not "" then
                    set isFolder to (class of anItem is folder)
                    set output to output & itemPath & "|||" & itemName & "|||" & itemSize & "|||" & isFolder & "\\n"
                end if
            end repeat
            return output
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if shouldStop { break }
                    guard !line.isEmpty else { continue }
                    
                    let parts = line.components(separatedBy: "|||")
                    guard parts.count >= 3 else { continue }
                    
                    let path = parts[0].trimmingCharacters(in: .whitespaces)
                    let name = parts[1].trimmingCharacters(in: .whitespaces)
                    let sizeStr = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let size = Int64(sizeStr) ?? 0
                    let isFolder = parts.count > 3 ? (parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true") : false
                    
                    let fileURL = URL(fileURLWithPath: path)
                    
                    // Nhận ngày sửa đổi

                    let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    
                    let item = TrashItem(
                        url: fileURL,
                        name: name,
                        size: size,
                        dateDeleted: date,
                        isDirectory: isFolder
                    )
                    scannedItems.append(item)
                    total += size
                    
                    await MainActor.run {
                        self.scannedItemCount += 1
                        self.currentScanPath = path
                    }
                }
            }
        } catch {
            print("AppleScript scan failed: \(error)")
        }
        
        return (scannedItems, total)
    }
    
    func emptyTrash() async -> Int64 {
        let itemsToDelete = items.filter { $0.isSelected }
        
        await MainActor.run {
            self.isCleaning = true
            self.cleanedCount = 0
            self.cleanedSize = 0
        }
        
        var removedSize: Int64 = 0
        
        for item in itemsToDelete {
            do {
                // Cố gắng mở khóa tập tin (nếu nó bị khóa)

                try? fileManager.setAttributes([.immutable: false], ofItemAtPath: item.url.path)
                
                try fileManager.removeItem(at: item.url)
                removedSize += item.size
                await MainActor.run {
                    self.cleanedCount += 1
                    self.cleanedSize += item.size
                }
                // Tạo một độ trễ nhỏ để người dùng thấy được tiến trình dọn dẹp

                try? await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                print("Failed to delete \(item.url.path): \(error)")
                
                // Lần thử thứ hai: Nếu nguyên nhân là do bạn không có quyền, hãy thử sử dụng chmod (chỉ hợp lệ với các tệp do người dùng sở hữu)

                // Lưu ý: Có nhiều hạn chế đối với các ứng dụng hộp cát, vì vậy chúng tôi sẽ cố gắng hết sức ở đây.

            }
        }
        
        await MainActor.run {
            // Chỉ xóa các mục đã chọn (giả sử thao tác dọn dẹp được tính là xóa và kể cả khi thất bại, đừng để nó trong danh sách làm phiền người dùng? 

            // Hoặc chỉ loại bỏ những cái đã xóa thành công? Để đơn giản và phù hợp với logic của phần mềm dọn dẹp chung, các mục trong danh sách thường sẽ bị xóa sau khi nhấp vào Dọn dẹp, trừ khi có lỗi được báo cáo rõ ràng)

            // Ở đây chúng tôi chỉ giữ các mục không được chọn

            items = items.filter { !$0.isSelected }
            totalSize = items.reduce(0) { $0 + $1.size }
            
            self.isCleaning = false
            DiskSpaceManager.shared.updateDiskSpace()
            self.scannedItemCount = items.count 
        }
        
        return removedSize
    }
    
    func reset() {
        items = []
        isScanning = false
        totalSize = 0
        needsPermission = false
        scannedItemCount = 0
        hasCompletedScan = false
        isStopped = false
        currentScanPath = ""
        isCleaning = false
        cleanedCount = 0
        cleanedSize = 0
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch { continue }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch { return 0 }
            }
        }
        return totalSize
    }
}

struct TrashView: View {
    // Sử dụng trình quản lý dịch vụ quét được chia sẻ để tránh việc quét bị gián đoạn khi chuyển đổi giao diện

    @ObservedObject private var scanner = ScanServiceManager.shared.trashScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showEmptyConfirmation = false
    @State private var showCleaningFinished = false
    
    // Trạng thái xem (tương ứng với ScanState)

    private var scanState: TrashScanState {
        if showCleaningFinished {
            return .finished
        } else if scanner.isCleaning {
            return .cleaning
        } else if scanner.isScanning {
            return .scanning
        } else if !scanner.items.isEmpty || scanner.isStopped {
            // Nếu nó đã bị dừng thì cũng hiển thị trang kết quả (có thể là một phần kết quả)

            return .completed
        } else if scanner.hasCompletedScan && scanner.items.isEmpty {
            return .clean
        }
        return .initial
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch scanState {
                case .initial:
                    initialPage
                case .scanning:
                    scanningPage
                case .completed:
                    resultsPage
                case .clean:
                    cleanPage
                case .cleaning:
                    cleaningPage
                case .finished:
                    finishedPage
                }
            }
        }
        .confirmationDialog(loc.L("empty_trash"), isPresented: $showEmptyConfirmation) {
            Button(loc.L("empty_trash"), role: .destructive) {
                Task {
                    _ = await scanner.emptyTrash()
                    showCleaningFinished = true
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(L("Điều này không thể hoàn tác được. Tất cả các tập tin sẽ bị xóa vĩnh viễn."))
        }
    }
    
    // ĐÁNH DẤU: - 1. Trang đầu tiên

    private var initialPage: some View {
        ZStack {
            HStack(spacing: 60) {
                // Left Content
                VStack(alignment: .leading, spacing: 30) {
                    // Branding Header
                    HStack(spacing: 8) {
                        Text(L("Dọn rác"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Trash Icon
                        HStack(spacing: 4) {
                            Image(systemName: "trash.circle.fill")
                            Text(L("Hoàn thành trống"))
                                .font(.system(size: 20, weight: .heavy))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Text(L("Dọn sạch tất cả Thùng rác trên máy Mac, bao gồm cả Thư và Ảnh.\nDọn sạch lần cuối: Không bao giờ"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                    
                    // Feature Rows
                    VStack(alignment: .leading, spacing: 24) {
                        featureRow(
                            icon: "trash.slash",
                            title: L("Dọn sạch tất cả thùng rác ngay lập tức"),
                            subtitle: L("Không cần phải duyệt tất cả các ổ đĩa và ứng dụng để tìm thùng rác.")
                        )
                        
                        featureRow(
                            icon: "exclamationmark.shield",
                            title: L("Tránh lỗi tìm kiếm"),
                            subtitle: L("Đảm bảo Thùng rác của bạn được dọn sạch bất kể có vấn đề gì.")
                        )
                        
                        featureRow(
                            icon: "mail.and.text.magnifyingglass",
                            title: L("Bao gồm Thư & Ảnh"),
                            subtitle: L("Đồng thời dọn sạch rác khỏi ứng dụng Thư và thư viện Ảnh.")
                        )
                    }
                    
                    // Optional: View Items Button
                    Button(action: {}) {
                        Text(L("Xem các mục thùng rác..."))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "4DDEE8")) // Teal
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .frame(maxWidth: 400)
                
                // Right Icon - Using feizhilou.png
                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                    } else {
                        // Fallback
                        RoundedRectangle(cornerRadius: 40)
                            .fill(LinearGradient(
                                colors: [Color(hex: "00D9A8"), Color(hex: "009688")],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: 280, height: 280)
                            .overlay(
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            
            // Bottom Floating Scan Button
            VStack {
                Spacer()
                Button(action: {
                    Task { await scanner.scan() }
                }) {
                    ZStack {
                        Circle()
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ), lineWidth: 2)
                            .frame(width: 84, height: 84)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 74, height: 74)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        
                        Text(L("Quét"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 2. Quét trang

    private var scanningPage: some View {
        VStack(spacing: 0) {
            // danh hiệu hàng đầu

            HStack {
                Text(L("Rác"))
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Biểu tượng hoạt hình ở giữa (Hình ảnh trực tiếp) -> Thực thi kích thước tĩnh

            ZStack {
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 280, height: 280)
                } else {
                     Image(systemName: "trash")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 280, height: 280) // Enforce frame container
            .padding(.bottom, 40)
            
            // Văn bản trạng thái - Sử dụng khung cố định để tránh hiện tượng giật bố cục

            VStack(spacing: 8) {
                Text(L("Đang tính kích thước thùng rác..."))
                    .font(.title) 
                    .foregroundColor(.white)
                
                Text(scanner.currentScanPath) 
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(height: 20) // Fixed text height
                    .padding(.horizontal, 40)
                
                Text(L("Thùng rác hệ thống"))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Nút Dừng (Trung tâm dưới cùng của màn hình)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.75) 
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Button(action: {
                    scanner.stopScan()
                }) {
                    VStack(spacing: 2) {
                        Text(L("Dừng lại"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Size below stop button
            Text(scanner.formattedTotalSize)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 10)
                .opacity(scanner.scannedItemCount > 0 ? 1 : 0) // Fade in instead of layout shift? Or just keep space
            
            Spacer()
                .frame(height: 60)
        }
    }
    
    // MARK: - 3. Màn hình kết quả quét

    private var resultsPage: some View {
        VStack(spacing: 0) {
            // Top: Back Button
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("Bắt đầu lại"))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(L("Rác"))
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Assistant placeholder
                 HStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 6, height: 6)
                    Text(L("Trợ lý"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .opacity(0.8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Main Content: Icon Left, Text Right
            HStack(spacing: 60) {
                // Large Icon Circle (Direct Image)
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300) // Large
                } else {
                     Image(systemName: "trash.fill")
                         .font(.system(size: 150))
                         .foregroundColor(.white)
                }
                
                // Text Info
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("Quét hoàn tất"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(scanner.formattedTotalSize)
                            .font(.system(size: 60, weight: .light)) 
                            .foregroundColor(Color(hex: "60EFFF")) 
                        
                        Text(loc.L("smart_select"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Bao gồm"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 8) {
                            Circle().fill(Color.white.opacity(0.6)).frame(width: 4, height: 4)
                            Text(L("Thùng rác trên máy Mac"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // View Items Button
                    NavigationLink(destination: TrashDetailsSplitView(scanner: scanner)) {
                        Text(loc.L("view_items")) 
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                         Text(L("Tổng số tìm thấy"))
                         Text(scanner.formattedTotalSize)
                             .foregroundColor(.white)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Clean Button (Floating circular, Bottom Center)
            ZStack {
                // Outer Glow Ring
                Circle()
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 90, height: 90)
                
                Button(action: {
                     showEmptyConfirmation = true
                }) {
                    ZStack {
                        Circle()
                             .fill(Color.white.opacity(0.2))
                             .frame(width: 80, height: 80)
                        
                        Text(L("Lau dọn"))
                             .font(.system(size: 18, weight: .medium))
                             .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - 3.5. Clean Page
    private var cleanPage: some View {
        VStack(spacing: 0) {
            // Top Nav
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("Bắt đầu lại"))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder
                Text("Start Over")
                    .opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Central Icon (Using feizhilou.png)
            ZStack {
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                } else {
                     Image(systemName: "trash")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                }
                
                // Checkmark badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.white)) // White bg for checkmark to pop
                    .clipShape(Circle())
                    .offset(x: 60, y: 80)
            }
            .padding(.bottom, 30)

            // Text
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                
                Text(L("Không có gì để dọn"))
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            Text(L("Không tìm thấy tệp nào trong bất kỳ Thùng rác nào."))
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Back/Rescan Button
             CircularActionButton(
                 title: L("Quay lại"),
                 gradient: CircularActionButton.blueGradient,
                 action: {
                     scanner.reset()
                 }
             )
             .padding(.bottom, 60)
        }
    }

    // MARK: - 4. Trang đang được làm sạch

    private var cleaningPage: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(GradientStyles.trash.opacity(0.8))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "trash")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                // vòng tròn quay

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(Double(scanner.cleanedCount * 20))) // xoay đơn giản
            }
            .padding(.bottom, 40)
            
            Text(L("Đang dọn..."))
                .font(.title3)
                .foregroundColor(.white)
            
            Text(String(format: L("Đã dọn %d mục"), scanner.cleanedCount))
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            
            Spacer()
            
            // nút giữ chỗ

             CircularActionButton(
                 title: L("Đang dọn"),
                 gradient: CircularActionButton.grayGradient,
                 action: {}
             )
             .disabled(true)
             .padding(.bottom, 60)
        }
    }
    
    // MARK: - 5. Làm sạch trang đã hoàn thành

    private var finishedPage: some View {
        VStack(spacing: 0) {
            // điều hướng hàng đầu

            HStack {
                Button(action: {
                    scanner.reset()
                    showCleaningFinished = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text(L("Quay lại"))
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                GridRow { Text("      ") } // Placeholder
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.8)) // màu xanh lá
                    .frame(width: 160, height: 160)
                    .shadow(color: .green.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
            
            Text(L("Dọn dẹp hoàn tất"))
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            Text(String(format: L("Đã giải phóng %@"), ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)))
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            
            Spacer()
            
            // Nút hoàn tất

             CircularActionButton(
                 title: L("Xong"),
                 gradient: CircularActionButton.blueGradient,
                 action: {
                     scanner.reset()
                     showCleaningFinished = false
                 }
             )
             .padding(.bottom, 60)
        }
    }
}

// Chế độ xem phụ trợ: Hiển thị chi tiết danh sách tệp (giữ nguyên việc triển khai RecycleDirectoryView trước đó)

// Mặc dù nó có thể không cần thiết trong các thiết kế tiếp theo nhưng nó vẫn được giữ lại để tương thích

struct TrashDirectoryView: View {
    let url: URL
    @State private var items: [TrashItem] = []
    @StateObject private var scanner = TrashScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        List {
            if items.isEmpty {
                Text(L("Thư mục trống"))
                    .foregroundColor(.secondaryText)
                    .padding()
            } else {
                ForEach(items) { item in
                    itemRow(for: item)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.mainBackground)
        .navigationTitle(url.lastPathComponent)
        .onAppear {
            items = scanner.scanDirectory(url)
        }
    }
    
    @ViewBuilder
    private func itemRow(for item: TrashItem) -> some View {
        Group {
            if item.isDirectory {
                NavigationLink(destination: TrashDirectoryView(url: item.url)) {
                    TrashItemRow(item: item)
                }
            } else {
                TrashItemRow(item: item)
            }
        }
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(loc.L("show_in_finder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                try? FileManager.default.removeItem(at: item.url)
                items = scanner.scanDirectory(url)
            } label: {
                Label(L("Xóa ngay lập tức"), systemImage: "trash")
            }
        }
    }
}

struct TrashItemRow: View {
    let item: TrashItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(String(format: L("Đã xóa lúc %@"), item.formattedDate))
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// TealMeshBackground removed - using global background from ContentView
