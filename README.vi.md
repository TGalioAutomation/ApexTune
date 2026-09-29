<div align="center">
  <img src="AppUninstaller/welcome.png" alt="MacOptimizer Hero" width="180" />

  # MacOptimizer

  **Bộ công cụ dọn dẹp, tối ưu và giám sát macOS — giao diện tiếng Việt & tiếng Anh**

  [English](README.md) · **Tiếng Việt**

  <p>
    <img src="https://img.shields.io/badge/macOS-13%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13+">
    <img src="https://img.shields.io/badge/Swift-5.9-F97316?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9">
    <img src="https://img.shields.io/badge/Version-4.0.11-2563EB?style=for-the-badge" alt="Version 4.0.9">
    <img src="https://img.shields.io/badge/UI-Vi%E1%BB%87t%20Nam%20%2F%20English-059669?style=for-the-badge" alt="UI Việt / English">
    <img src="https://img.shields.io/badge/Menu%20Bar-GPU%20%2F%20CPU%20%2F%20DISK%20%2F%20RAM-7C3AED?style=for-the-badge" alt="Menu bar metrics">
  </p>
</div>

---

## Tổng quan

MacOptimizer là app macOS viết bằng SwiftUI, chạy thường trú trên menu bar, tập trung vào bốn nhóm việc chính:

- dọn dẹp rác hệ thống, cache, log và file lớn,
- gỡ cài đặt app kèm file liên quan,
- giám sát máy trực tiếp từ menu bar với metric thời gian thực,
- quản lý model AI local (Ollama, LM Studio) và image Docker để kiểm soát dung lượng.

Giao diện có **tiếng Việt và tiếng Anh**, thêm ngôn ngữ mới chỉ cần thả một file JSON (xem [Đa ngôn ngữ](#đa-ngôn-ngữ)).

App chạy dạng utility (`LSUIElement`): không có icon ở Dock, mọi thứ thao tác qua menu bar; cửa sổ chính phục vụ các luồng dọn dẹp và quản trị chi tiết.

---

## Tính năng chính

### Menu bar dashboard

- Bảng điều khiển dạng popup ngay từ status item: **điểm sức khỏe hệ thống** (vòng điểm theo tải CPU/RAM/ổ đĩa), thẻ metric gọn, dải ổ đĩa & mạng bấm vào được.
- Status item hiển thị động `GPU`, `CPU`, `DISK`, `RAM`, `Mạng`, `Pin` — bật/tắt từng metric, đổi thứ tự, preset hiển thị, profile lấy mẫu.
- **5 theme banner** cho dải số liệu trên menu bar: Tối, Sáng, Đơn sắc, Màu nhấn, Tối giản.
- **Cảnh báo RAM** theo ngưỡng toàn hệ thống (tùy chỉnh 60–95%), kèm gợi ý app nặng nhất và buộc thoát có xác nhận.
- **Widget** WidgetKit (Small/Medium) hiển thị điểm sức khỏe, CPU/RAM/ổ đĩa và uptime. *(Lỗi đã biết: trên macOS 27.0 tiến trình widget crash trong bootstrap của ExtensionFoundation trước khi code widget chạy — ảnh hưởng appex build thủ công bằng SPM; hoạt động tốt trên macOS 26.)*
- Chi tiết từng metric (CPU, RAM, ổ đĩa, mạng, pin, buộc thoát app) mở từ dashboard.
- Khởi động cùng macOS, tùy chọn giữ icon app trên status item.

### Bảo vệ thời gian thực

- **Chặn quảng cáo & chống theo dõi** qua `/etc/hosts` (danh sách hostname được tuyển chọn, tự backup và khôi phục được, có Marker section rõ ràng).
- **Quét phần mềm độc hại / adware** theo dấu hiệu phổ biến.
- **Bảo vệ riêng tư**: quét và dọn lịch sử duyệt, cookie, lịch sử tải xuống, dấu vết phát triển.

### Bộ công cụ dọn dẹp và tối ưu

| Module | Mục đích |
| --- | --- |
| Smart Clean | Quét nhanh các nhóm dữ liệu thường cần dọn |
| Junk Cleaner | Dọn cache, log và file rác hệ thống |
| Deep Clean | Rà sâu các file dư thừa và phần còn sót của app |
| Large Files | Tìm file lớn, file cũ, file tốn dung lượng |
| Duplicates / Ảnh tương tự | Tìm file trùng lặp và ảnh giống nhau |
| Trash | Xem và làm trống Thùng rác |
| File Explorer | Duyệt file hệ thống và thao tác nhanh |
| Space Lens | Bản đồ dung lượng trực quan |
| Shredder | Hủy tệp an toàn |
| Maintenance | Bảo trì hệ thống (Spotlight, DNS, snapshot Time Machine...) |
| Optimizer | Tối ưu trạng thái hệ thống và mục khởi động |
| Dịch vụ nền | Quét & tắt LaunchAgents/LaunchDaemons của bên thứ ba |
| AI Models | Quản lý model local Ollama/LM Studio |
| Docker | Xem và dọn image Docker |
| App Updater | Kiểm tra cập nhật ứng dụng |
| Uninstaller | Gỡ app kèm file liên quan |

### Gỡ cài đặt ứng dụng

- quét app đã cài,
- hiển thị file liên quan như `Preferences`, `Caches`, `Logs`, `Application Support`,
- gỡ bỏ có chọn lọc,
- ưu tiên đưa vào Thùng rác để an toàn hơn.

---

## Đa ngôn ngữ

- **Tiếng Việt** (ngôn ngữ nguồn) và **English** có sẵn; chuyển ngay trong **Cài đặt → Ngôn ngữ**, toàn app cập nhật không cần khởi động lại.
- Lần đầu chạy, app tự dùng ngôn ngữ hệ thống nếu có bản dịch (hệ thống English → giao diện English), ngược lại mặc định tiếng Việt.
- Widget menu bar dùng chung bảng dịch của app (`WidgetExtension/WidgetLocalization.swift`), tự theo ngôn ngữ hệ thống.
- Thêm ngôn ngữ mới **không cần sửa mã**: thả file `AppUninstaller/Languages/<mã>.json` (khóa là chuỗi tiếng Việt gốc) rồi build lại. Chi tiết tại [docs/LOCALIZATION.md](docs/LOCALIZATION.md); kiểm tra bằng `python3 scripts/validate_localizations.py`.

---

## Ảnh giao diện

### Menu bar và dashboard

<p align="center">
  <img src="AppUninstaller/system_clean_menu.png" alt="Menu bar monitoring" width="31%" />
  <img src="AppUninstaller/yibiaopan_2026.png" alt="Dashboard monitoring" width="31%" />
  <img src="AppUninstaller/yinpan_2026.png" alt="Disk cleanup module" width="31%" />
</p>

### Dọn dẹp và tối ưu

<p align="center">
  <img src="AppUninstaller/smart-scan.2f4ddf59.png" alt="Smart Scan" width="31%" />
  <img src="AppUninstaller/shenduqingli.png" alt="Deep Clean" width="31%" />
  <img src="AppUninstaller/youhua.png" alt="Optimizer" width="31%" />
</p>

### Quyền riêng tư và bảo vệ

<p align="center">
  <img src="AppUninstaller/yinsi.png" alt="Privacy" width="31%" />
  <img src="AppUninstaller/zhiwendunpai_2026.png" alt="Protection" width="31%" />
  <img src="AppUninstaller/malware@2x.png" alt="Malware scan" width="31%" />
</p>

### Công cụ quản lý ứng dụng

<p align="center">
  <img src="AppUninstaller/Uninstaller@2x.jpg" alt="Uninstaller" width="31%" />
  <img src="AppUninstaller/clean-up.866fafd0.png" alt="Cleanup results" width="31%" />
  <img src="AppUninstaller/welcome.png" alt="Welcome screen" width="31%" />
</p>

---

## Build từ source

### Yêu cầu

- macOS 13 trở lên
- Swift 5.9
- Xcode hoặc Command Line Tools phù hợp

### Build nhanh

```bash
git clone git@github.com:TGalioAutomation/MacOptimizervn.git
cd MacOptimizervn
./build.sh
```

Artifact sau build:

- `build/MacOptimizer.app`
- `build/MacOptimizer.dmg`

Chạy app trực tiếp:

```bash
open build/MacOptimizer.app
```

### Build gói phát hành hai kiến trúc

```bash
./build_dual_dmg.sh
```

Artifact sau build:

- `build_release/MacOptimizer_v4.0.11_AppleSilicon.dmg`
- `build_release/MacOptimizer_v4.0.11_Intel.dmg`

### Build kiểm tra package

```bash
swift build
```

### Tái tạo App icon (.icns)

```bash
./scripts/generate_app_icon.sh
```

Nguồn icon master: `AppUninstaller/BrandAssets/AppIcon-master-1024.png`.

---

## Cấu trúc repo

```text
MacOptimizervn/
├── AppUninstaller/             # Source app macOS
│   ├── AppDelegate.swift       # Khởi động accessory utility và menu bar
│   ├── AppUninstallerApp.swift
│   ├── ContentView.swift
│   ├── Languages/              # Bản dịch JSON (vi, en) — thêm ngôn ngữ tại đây
│   ├── MenuBar/                # Menu bar popup, detail, customization, theme
│   ├── SystemMonitorService.swift
│   ├── SmartCleanerService.swift
│   ├── PrivacyScannerService.swift
│   ├── MalwareScanner.swift
│   ├── BrandAssets/            # Master brand/icon assets
│   └── ...
├── WidgetExtension/            # WidgetKit widget (điểm sức khỏe)
├── Sources/                    # Shared SPM modules (AIModelKit, verify tool)
├── Tests/                      # Unit tests
├── contracts/                  # Contract và checklist công việc
├── docs/                       # Technical docs (LOCALIZATION.md, audit...)
├── scripts/                    # Utility scripts (icon, validator bản dịch...)
├── build.sh                    # Build cục bộ + DMG
├── build_dual_dmg.sh           # DMG Apple Silicon + Intel
├── README.md                   # Bản tiếng Anh
└── README.vi.md                # Bản tiếng Việt
```

---

## Tài liệu liên quan

- [docs/LOCALIZATION.md](docs/LOCALIZATION.md) — hướng dẫn đa ngôn ngữ
- [CHANGELOG_v4.0.9.md](CHANGELOG_v4.0.9.md)
- [CHANGELOG_v4.0.8.md](CHANGELOG_v4.0.8.md)
- [CHANGELOG_v4.0.7.md](CHANGELOG_v4.0.7.md)
- [CHANGELOG_v4.0.6.md](CHANGELOG_v4.0.6.md)
- [docs/audit-2026-04-06.md](docs/audit-2026-04-06.md)
- [contracts/vietnamese-only-sweep-checklist.md](contracts/vietnamese-only-sweep-checklist.md)

---

## Ghi chú vận hành

- App tối ưu cho trải nghiệm menu bar trước; cửa sổ chính dành cho các luồng dọn dẹp và quản trị chi tiết.
- `GPU` usage phụ thuộc dữ liệu hệ thống macOS; mức chi tiết có thể khác giữa các máy.
- Một số tính năng cần quyền: **Full Disk Access** (quét sâu), **Location** (đọc tên Wi-Fi), mật khẩu quản trị (sửa `/etc/hosts`, dọn file hệ thống).
- Với thao tác dọn dẹp nhạy cảm, nên rà soát danh sách file trước khi xóa hàng loạt và ưu tiên đưa vào Thùng rác; sao lưu dữ liệu quan trọng trước khi dùng tính năng dọn dẹp sâu.
- Chặn quảng cáo / chống theo dõi sửa `/etc/hosts` (có backup tự động tại `/etc/hosts.macoptimizer.bak`) — tắt tính năng sẽ khôi phục như cũ.

---

<div align="center">
  <strong>MacOptimizer</strong><br/>
  Gọn, nhanh, theo dõi trực tiếp từ menu bar.
</div>
