# Nhật ký thay đổi ApexTune v5.0.1

Ngày: 2026-09-30

## Tóm tắt

**Bản sửa hiệu năng**: cắt hai vòng render ngầm trong cửa sổ ẩn — nguyên nhân app vẫn ngốn 4–6% CPU khi tưởng rằng đang "nghỉ". CPU khi chạy nền (menu bar đóng, popup đóng) đo thực tế giảm từ ~4–6.7% xuống **~0.8%**.

### Sửa lỗi hiệu năng

- **Dừng sampling trong cửa sổ chính bị ẩn**: cửa sổ chính được ẩn ngay sau khi khởi động nhưng view SwiftUI bên trong vẫn sống và render lại theo nhịp monitoring (~mỗi giây) qua `UpdateCycle` của macOS. Giờ sampling của module "Trung tâm hệ thống" chỉ chạy khi cửa sổ **thực sự hiển thị** (theo occlusion state — kể cả thu nhỏ vào Dock hay ở Space khác), mở lại là số liệu tươi ngay.
- **Dừng render ngầm của popup menu bar**: đóng popup giờ tháo hẳn content khỏi cửa sổ (mở ra gắn lại, giữ nguyên trạng thái scroll/điều hướng). Trước đây view graph của popup vẫn render theo từng nhịp cập nhật dù cửa sổ đã đóng.
- **Timer cảnh báo RAM tôn trọng chế độ tiết kiệm**: khi idle, chu kỳ kiểm tra app ăn RAM chậm đi 3 lần (12s → 36s ở profile balanced) — hết spawn `/bin/ps` mỗi 12s mãi mãi.
- **Lệnh hệ thống có deadline 5 giây**: nếu `ioreg`/`ps`/`netstat`… treo, ApexTune SIGTERM rồi SIGKILL thay vì đóng băng im lặng cả bộ monitoring.

### Sửa lỗi chức năng

- **Tab "Tối ưu hóa mạng" giờ có dữ liệu**: view này giữ `SystemMonitorService` riêng nhưng không bao giờ khởi động monitoring nên tốc độ mạng/biểu đồ luôn hiển thị 0. Nay dùng chung một service với dashboard.
- Hết tình trạng tạo instance monitoring dư trong body của `MonitorView` (polling trùng, object churn mỗi lần render).

### Đo thực tế (Apple Silicon, macOS 27, idle sau 5 phút)

| Trạng thái | Trước (v5.0.0) | Sau (v5.0.1) |
|---|---|---|
| CPU trung bình khi chạy nền | 4.2–6.7% | **0.8–0.9%** |
| Frame `NSHostingView.layout` ngầm (sample 10s) | 154–446 | **0** |

### Xem thêm

- Đã qua cross-review độc lập: SHIP, 0 blocker/major.
- Còn tồn (không chặn): GPU sampling vẫn dùng subprocess `ioreg` (~0.6% CPU, ứng viên tối ưu tiếp theo bằng IOKit in-process); mỗi lần mở popup vẫn spawn 4 lệnh shell kiểm tra Ollama/Docker (ứng viên cache).

## Liên kết phiên bản trước

- [CHANGELOG_v5.0.0.md](CHANGELOG_v5.0.0.md)
