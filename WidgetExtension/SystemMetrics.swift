import Foundation
import Darwin

/// Bộ lấy số liệu hệ thống gọn cho widget — tự đo trực tiếp qua Mach/sysctl,
/// không phụ thuộc app chính (widget chạy trong tiến trình riêng).
struct SystemMetrics {
    var cpuUsage: Double = 0        // 0...1
    var memoryUsage: Double = 0     // 0...1
    var diskUsage: Double = 0       // 0...1
    var diskFreeText = "—"
    var memoryUsedText = "—"
    var uptimeText = ""

    /// Điểm sức khỏe 0...100 — cùng công thức với bảng điều khiển
    /// (CPU 45% · RAM 40% · Ổ đĩa 15%).
    var healthScore: Int {
        let load = cpuUsage * 0.45 + memoryUsage * 0.40 + diskUsage * 0.15
        return max(0, min(100, Int((100 - load * 100).rounded())))
    }

    var statusText: String {
        switch healthScore {
        case 75...: return WidgetL.t("Ổn định")
        case 50..<75: return WidgetL.t("Cần chú ý")
        default: return WidgetL.t("Quá tải")
        }
    }

    /// Màu nhấn hex theo trạng thái (mint / vàng / đỏ) — khớp bảng điều khiển.
    var accentHex: String {
        switch healthScore {
        case 75...: return "7DEBCE"
        case 50..<75: return "FBBF24"
        default: return "F87171"
        }
    }

    static func sample() -> SystemMetrics {
        var m = SystemMetrics()
        m.cpuUsage = readCPUUsage()
        m.memoryUsage = readMemoryUsage()
        readDisk(&m)
        m.memoryUsedText = ByteCountFormatter.string(fromByteCount: Int64(m.memoryUsage * Double(totalPhysicalBytes())), countStyle: .file)
        m.uptimeText = readUptime()
        return m
    }

    // MARK: - CPU (hai lần đọc tick cách nhau 200ms)

    private static func readCPUUsage() -> Double {
        func loadTicks() -> (busy: Double, total: Double)? {
            var processorCount: natural_t = 0
            var info: processor_info_array_t?
            var count: mach_msg_type_number_t = 0
            guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &count) == KERN_SUCCESS,
                  let info else { return nil }
            defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride)) }

            var busy = 0.0, total = 0.0
            for i in 0..<Int(count) {
                let offset = i * Int(CPU_STATE_MAX)
                let user = Double(info[offset + Int(CPU_STATE_USER)])
                let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
                let nice = Double(info[offset + Int(CPU_STATE_NICE)])
                let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
                busy += user + system + nice
                total += user + system + nice + idle
            }
            return (busy, total)
        }

        guard let first = loadTicks() else { return 0 }
        usleep(200_000)
        guard let second = loadTicks(), second.total > first.total else { return 0 }
        let busyDelta = second.busy - first.busy
        let totalDelta = second.total - first.total
        guard totalDelta > 0 else { return 0 }
        return min(1, busyDelta / totalDelta)
    }

    // MARK: - RAM (host_statistics64)

    private static func readMemoryUsage() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = UInt64(getpagesize()) // hàm thay cho global var vm_kernel_page_size (Swift 6 an toàn concurrency)
        let total = totalPhysicalBytes()
        // Trên macOS: internal = bộ nhớ ẩn danh của tiến trình, compressor = trang đã nén.
        let used = (UInt64(stats.internal_page_count) + UInt64(stats.compressor_page_count)) * pageSize
        guard total > 0 else { return 0 }
        return min(1, Double(used) / Double(total))
    }

    private static func totalPhysicalBytes() -> UInt64 {
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0)
        return size
    }

    // MARK: - Ổ đĩa (statfs trên root)

    private static func readDisk(_ m: inout SystemMetrics) {
        var stats = statfs()
        guard statfs("/", &stats) == 0 else { return }
        let blockSize = UInt64(stats.f_bsize)
        let total = UInt64(stats.f_blocks) * blockSize
        let free = UInt64(stats.f_bavail) * blockSize
        guard total > 0 else { return }
        m.diskUsage = min(1, Double(total - free) / Double(total))
        m.diskFreeText = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
    }

    // MARK: - Uptime

    private static func readUptime() -> String {
        var boottime = timeval()
        var length = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boottime, &length, nil, 0) == 0 else { return "" }
        let interval = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec)))
        let hours = Int(interval) / 3600
        let days = hours / 24
        if days > 0 {
            return String(format: WidgetL.t("%d ngày %d giờ"), days, hours % 24)
        }
        return String(format: WidgetL.t("%d giờ %d phút"), hours, Int(interval) % 3600 / 60)
    }
}
