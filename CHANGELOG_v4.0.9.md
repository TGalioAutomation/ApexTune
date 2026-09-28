# Nhật ký thay đổi MacOptimizer v4.0.9

Ngày: 2026-09-28

## Tóm tắt

Bản release lớn gom toàn bộ nhóm thay đổi từ 2026-09-08 đến 2026-09-28: thiết kế lại menu bar dashboard, hệ thống đa ngôn ngữ (Việt/Anh), widget WidgetKit và các module tiện ích mới.

### Đa ngôn ngữ (vi + en)

- **Hệ thống i18n file JSON:** mọi chuỗi UI là khóa tiếng Việt bọc `L(...)`, bản dịch nằm trong `AppUninstaller/Languages/{vi,en}.json` (~1.3k khóa). Đổi ngôn ngữ trong **Cài đặt → Ngôn ngữ**, toàn app cập nhật ngay không cần restart.
- **Tự nhận diện ngôn ngữ hệ thống** ở lần chạy đầu: hệ thống English → UI English; không có bản dịch thì mặc định tiếng Việt.
- **Widget đã dịch:** widget dùng bảng dịch của app qua `WidgetLocalization.swift`, tự theo ngôn ngữ hệ thống.
- **Kiểm tra bản dịch:** `python3 scripts/validate_localizations.py`; hướng dẫn tại [docs/LOCALIZATION.md](docs/LOCALIZATION.md).
- **README song ngữ:** `README.md` (English) + `README.vi.md` (Tiếng Việt), cập nhật trạng thái v4.0.9.

### Menu bar dashboard

- **Thiết kế "graphite" mới:** nền charcoal gradient, card viền hairline, nhóm theo section; tiêu điểm là **vòng điểm sức khỏe** (CPU 45% · RAM 40% · ổ đĩa 15%) kèm nhãn Ổn định / Cần chú ý / Quá tải.
- **5 theme banner** cho dải số liệu trên status item: Tối, Sáng, Đơn sắc, Màu nhấn, Tối giản — chọn trong trang tùy biến, có preview thật.
- **Cảnh báo RAM mới:** theo ngưỡng RAM toàn hệ thống (60–95%, tùy chỉnh), hiển thị app GUI nặng nhất (gộp RSS tiến trình con), buộc thoát phải xác nhận, tự ẩn khi hết cảnh báo.
- Chi tiết metric (CPU/RAM/ổ đĩa/mạng/pin/buộc thoát) mở từ dashboard; cửa sổ popup 390×720 vừa nội dung.

### Bảo vệ & tiện ích mới

- **Chặn quảng cáo / chống theo dõi thật** qua `/etc/hosts` (`HostsProtectionManager`): danh sách hostname tuyển chọn, backup `/etc/hosts.macoptimizer.bak`, khôi phục khi tắt.
- **Dịch vụ nền** (`Dịch vụ nền`): quét LaunchAgents/LaunchDaemons bên thứ ba, tắt/mở lại, xem trạng thái nạp.
- **Docker**: danh sách image, dung lượng, xóa image và dọn image treo.
- **Khởi động cùng macOS** qua `SMAppService`.

### Widget

- **WidgetKit widget** "MacOptimizer" (Small/Medium): vòng điểm sức khỏe, CPU/RAM/ổ đĩa, uptime; tự làm mới 15 phút, app reload khi mở dashboard.

### Nền & độ tin cậy

- Toàn bộ subprocess lấy mẫu (`ps`, `vm_stat`, `netstat`, `ioreg`...) chuyển sang queue riêng, không chặn main thread; SSID đọc qua CoreWLAN.
- `build.sh` tự đặt `DEVELOPER_DIR` sang Xcode khi Command Line Tools thiếu SwiftUIMacros.
- Sửa lỗi brace nested giấu hàm trùng `formatSpeed(_:)`; loại view chết `MenuBarAlertView`, `DiskUsageView` không còn được tham chiếu.

### Phiên bản

- `CFBundleShortVersionString` 4.0.9, `CFBundleVersion` 4; sidebar và `build_dual_dmg.sh` đồng bộ version.

## Liên kết phiên bản trước

- [CHANGELOG_v4.0.8.md](CHANGELOG_v4.0.8.md)
