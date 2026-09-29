# Nhật ký thay đổi MacOptimizer v4.0.11

Ngày: 2026-09-29

## Tóm tắt

**Bản tối ưu hiệu năng** — giảm mức CPU nền của app từ ~20% liên tục xuống ~1–3% trung bình. Root cause: bộ giám sát hệ thống spawn subprocess (`ps`, `vm_stat`) mỗi 1.5–2 giây và mỗi lần giá trị đổi là render lại toàn bộ view graph SwiftUI.

### Tối ưu hóa

- **Đo CPU bằng Mach API:** thay `ps -A -o %cpu` (fork tiến trình + quét toàn bộ danh sách process mỗi 1.5s) bằng `host_processor_info(PROCESS_CPU_LOAD_INFO)` tính delta tick trực tiếp từ kernel. Ngữ nghĩa chỉ số khớp Activity Monitor (mức dùng CPU thật của hệ thống) và đồng nhất với widget.
- **Đo RAM bằng Mach API:** thay parse output `vm_stat` bằng `host_statistics64(HOST_VM_INFO64)`. Xóa hàm parse `extractPageCount` không còn dùng.
- **Chế độ tiết kiệm khi bảng điều khiển đóng:** khi cửa sổ đóng và không mở trang chi tiết, chu kỳ sampling GPU/CPU/RAM/mạng/pin được nới ra 3 lần so với cấu hình; mở lại là quay về nhịp gốc và làm mới ngay.
- **Throttle publish 1 Hz:** CPU/RAM/GPU/mạng xuất bản qua cùng một nhịp throttle (mới trong `BatchedUIUpdater`), các timer lệch pha không còn gây từng vòng layout window riêng cho từng metric.
- **Bỏ publish/ vẽ lại khi giá trị không đổi:** CPU làm tròn theo bậc 1% (bậc 5% khi chỉ còn status item), RAM so theo chuỗi hiển thị, banner menu bar chỉ vẽ lại khi chữ hiển thị/theme/icon thực sự đổi (cache render key).
- **Rà bởi reviewer, đã sửa kèm:** guard underflow UInt64 khi tick counter 32-bit wrap lệch nhau + clamp 0–1 cho CPU; `mach_port_deallocate` sau `mach_host_self()` để không rò send right mỗi lần lấy mẫu; `lastGPUName` riêng cho sampling queue, không đọc `@Published` từ queue nền.

### Số đo trước/sau (Apple Silicon, macOS 27)

| Trạng thái | v4.0.10 | v4.0.11 |
|---|---|---|
| Menu bar chạy nền | 19–21% liên tục | ~0–2% (thỉnh thoảng 1 đỉnh ngắn) |
| Bảng điều khiển đang mở | ~20% | ~4–5% |
| Energy impact | ~12–21 | ~0–4 |

### Còn biết rõ, chưa xử lý (xem audit)

- Mỗi lần giá trị hiển thị đổi vẫn còn 1 spike ~170ms do render lại toàn bộ view graph (cần tách ObservableObject theo widget).
- `ioreg` (GPU) và `netstat` (mạng) vẫn là subprocess.

### Phiên bản

- `CFBundleShortVersionString` 4.0.11, `CFBundleVersion` 6; sidebar, `build_dual_dmg.sh`, README đồng bộ version.
- Thêm website landing page (`website/`) và bật GitHub Pages.

## Liên kết phiên bản trước

- [CHANGELOG_v4.0.10.md](CHANGELOG_v4.0.10.md)
