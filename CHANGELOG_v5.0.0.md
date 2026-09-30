# Nhật ký thay đổi ApexTune v5.0.0

Ngày: 2026-09-30

## Tóm tắt

**Rebrand hoàn toàn** — ứng dụng đổi tên từ MacOptimizer thành **ApexTune**, không còn gắn với repo phân phối cũ: bản cá nhân độc lập.

### Danh tính mới

- Tên ứng dụng: **ApexTune** (`/Applications/ApexTune.app`, binary `ApexTune`)
- Bundle ID: `com.apexdev.apextune` (widget: `com.apexdev.apextune.widget`)
- Widget extension: `ApexTuneWidget.appex`; DMG: `ApexTune.dmg`
- Toàn bộ chuỗi UI (Việt + English JSON), tooltip, menu thoát, cảnh báo quyền quản trị đổi sang ApexTune
- Ứng dụng không còn tự kiểm tra cập nhật từ bất kỳ repo nào (UpdateChecker bị vô hiệu hoá an toàn)

### Chuyển đổi dữ liệu người dùng (tự động, một lần)

- Toàn bộ preferences (theme banner, metrics hiển thị, profile sampling, ngưỡng RAM cảnh báo…) được copy từ domain cũ `com.apexdev.MacOptimizer` sang `com.apexdev.apextune` ngay lần khởi động đầu
- Dữ liệu `~/Library/Application Support/MacOptimizer/` (nhật ký xoá file) được copy sang `ApexTune/`
- File hosts: khối chặn quảng cáo/tracker do bản cũ ghi với marker `# BEGIN MacOptimizer …` vẫn được nhận diện — lần áp dụng tiếp theo sẽ được ghi lại bằng marker `ApexTune AdBlock/AntiTrack`, không còn khối mồ côi

### Mục đích bản 5.0.0

Đánh dấu bước đổi tên lớn (major). Kèm toàn bộ tối ưu hiệu năng của 4.0.11: đo CPU/RAM bằng Mach API, throttle publish 1 Hz, chế độ tiết kiệm khi đóng dashboard, cache vẽ banner.

## Liên kết phiên bản trước

- [CHANGELOG_v4.0.11.md](CHANGELOG_v4.0.11.md)
