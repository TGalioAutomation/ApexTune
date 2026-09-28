# Đa ngôn ngữ (Localization)

Ứng dụng hỗ trợ nhiều ngôn ngữ thông qua các file JSON trong `AppUninstaller/Languages/`. Hiện có: **Tiếng Việt** (ngôn ngữ nguồn) và **English**.

## Nguyên tắc hoạt động

- Toàn bộ chuỗi UI trong mã nguồn được **viết bằng tiếng Việt** và được bọc bằng hàm toàn cục:

  ```swift
  Text(L("Dọn dẹp"))
  ```

- Khi ngôn ngữ hiện tại là **tiếng Việt**, `L("Dọn dẹp")` trả về chính chuỗi đó — không cần tra bảng.
- Khi là **ngôn ngữ khác**, hệ tra bảng của ngôn ngữ đó (file JSON); nếu thiếu bản dịch thì fallback về chuỗi tiếng Việt gốc, nên **thiếu bản dịch không bao giờ gây lỗi**, chỉ hiển thị tiếng Việt chỗ đó.
- Chuỗi có biến số dùng format string giống C:

  ```swift
  Text(String(format: L("Đã dọn %d mục"), count))
  L("Bạn có %.2f GB trống", freeGB)          // hàm L có variadic args
  ```

  Specifier: `%d` cho Int, `%.1f`/`%.2f` cho Double, `%@` cho String, `%%` cho dấu %.
- Lựa chọn ngôn ngữ được lưu trong `UserDefaults` (khóa `app_language`), đổi ngôn ngữ trong **Cài đặt → Ngôn ngữ**, toàn app cập nhật ngay lập tức.
- **Lần đầu chạy** (chưa có lựa chọn lưu): app tự dùng ngôn ngữ hệ thống nếu có file bản dịch cho nó (ví dụ hệ thống "en-US" → tiếng Anh), ngược lại mặc định tiếng Việt. Giá trị đoán này không được ghi lại — chỉ khi người dùng chủ động chọn ngôn ngữ thì lựa chọn mới được lưu.

## Thêm một ngôn ngữ mới (không cần sửa mã)

1. Tạo file `AppUninstaller/Languages/<mã>.json`, ví dụ `ja.json`:

   ```json
   {
     "_name": "日本語",
     "_flag": "🇯🇵",
     "Dọn dẹp": "クリーンアップ",
     "Đã dọn %d mục": "%d個の項目をクリーンアップしました"
   }
   ```

   - `_name`: tên ngôn ngữ viết bằng chính ngôn ngữ đó (hiện trong Cài đặt).
   - `_flag`: emoji cờ.
   - Khóa là **chuỗi tiếng Việt gốc** trong mã nguồn (với chuỗi format thì khóa là format string).
2. Build lại (`./build.sh`) — ngôn ngữ mới tự xuất hiện trong Cài đặt → Ngôn ngữ.

Mẹo: có thể dịch dần dần. Khóa nào chưa có bản dịch sẽ hiển thị tiếng Việt thay thế.

## Thêm chuỗi UI mới

1. Viết chuỗi tiếng Việt trong code và bọc `L(...)` (hoặc `String(format: L(...), args)` nếu có biến).
2. Thêm bản dịch tiếng Anh (và các ngôn ngữ khác nếu có) vào file JSON tương ứng.
3. Chạy kiểm tra:

   ```bash
   python3 scripts/validate_localizations.py
   ```

   Script kiểm tra: JSON hợp lệ, đủ `_name`/`_flag`, mọi khóa `L(...)` trong mã đều có bản dịch, format specifier giữa khóa và bản dịch khớp nhau.

## Kiến trúc

- `AppUninstaller/LocalizationManager.swift` — engine: quét `Languages/*.json` trong resource bundle (tên file = mã ngôn ngữ), expose `LocalizationManager.shared` (`t(...)`/`L(...)`) và hàm toàn cục `L(...)`. Đổi ngôn ngữ phát `Notification.Name.appLanguageDidChange` cho các UI dựng bằng lệnh (NSMenu...).
- `AppUninstaller/Languages/vi.json`, `en.json` — bảng dịch. `vi.json` cũng chứa các khóa legacy dạng semantic (`"monitor": "Điều khiển"`) từ thế hệ localization cũ — vẫn được hỗ trợ tra fallback.
- Root view (`AppUninstallerApp`) gắn `.id(loc.currentLanguage)` để dựng lại toàn bộ cây SwiftUI khi đổi ngôn ngữ.
- Lưu ý quy ước khi viết code mới:
  - KHÔNG bọc `L()` cho: comment, `print`/Logger, NSPredicate/SQL, identifier/rawValue khai báo, chuỗi so sánh/đối chiếu dữ liệu, đường dẫn.
  - Chuỗi hiển thị từ `enum.rawValue` tiếng Việt: bọc ở **chỗ hiển thị** — `Text(L(status.rawValue))` — và thêm bản dịch cho giá trị rawValue vào JSON.
  - Đừng cache kết quả `L(...)` ở `static let` (sẽ không cập nhật khi đổi ngôn ngữ); dùng computed property.
