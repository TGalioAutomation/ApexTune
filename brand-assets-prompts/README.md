# ApexTune Brand Assets — Prompts tạo ảnh mới (tránh bản quyền)

Folder này chứa **prompt tiếng Anh chuẩn hoá** để tạo toàn bộ ảnh thương hiệu mới của
ApexTune bằng công cụ sinh ảnh AI (Midjourney / DALL·E / Ideogram / Flux / Stable Diffusion /
Gemini). Mọi ảnh hiện tại đang dùng artwork cũ (di sản MacOptimizer) — cần thay hết để
đảm bảo danh tính riêng, không dính bản quyền.

## Quy tắc chung khi sinh (áp cho mọi prompt)

- Nền **phong cách**: graphite tối (#0B0E14 → #151A26), accent xanh dương #3B82F6,
  điểm nhấn cyan #22D3EE / tím #8B5CF6 — khớp với UI app và website hiện tại.
- **Không** chứa chữ "MacOptimizer", không dùng biểu tượng Apple, không mô phỏng
  icon app nổi tiếng (CleanMyMac, DaisyDisk, iStat Menus…).
- **Không** có chữ trong ảnh (trừ logo wordmark nơi ghi rõ) — chữ do AI sinh hay sai.
- Sinh ở kích thước **vuông 1024×1024** (trừ banner 1920×960), tỉ lệ 1:1 hoặc 2:1.
- Sau khi tạo xong, đặt file đúng **Vị trí lưu** ghi ở mỗi prompt, thay file cùng tên
  (giữ nguyên tên file để không phải sửa code).

## Danh sách prompt (xem từng file .txt cùng folder)

| # | File prompt | Ảnh tạo ra | Vị trí lưu (thay file cũ) | Dùng ở đâu |
|---|---|---|---|---|
| 1 | `01-app-icon-master.txt` | Icon app chính 1024×1024 | `AppUninstaller/BrandAssets/AppIcon-master-1024.png` | Icon /Applications, Dock, DMG — chạy `./scripts/generate_app_icon.sh` sau khi thay |
| 2 | `02-hero-wordmark.txt` | Ảnh hero wordmark "APEXTUNE" | `AppUninstaller/welcome.png` | Màn hình welcome + ảnh đầu README + hero website (nên thêm chữ bằng Figma/Canva sau khi AI ra nền) |
| 3 | 03-menu-bar-glyph.txt | Glyph mini 2 tông (template/symbol) | *(tham khảo để vẽ tay)* `MenuBarManager.makeStatusItemImage` | Banner menu bar vẽ bằng code — glyph chỉ là tham khảo hình dạng |
| 4 | `04-website-og-image.txt` | Ảnh OG 1920×960 | `website/assets/og.png` (+ thêm thẻ meta og:image vào `website/index.html`) | Preview khi chia sẻ link website |
| 5 | `05-appicon-safari-pinned.txt` | Maskable icon tối giản | *(tham khảo)* — sinh từ #1 bằng cách bo tròn | Không bắt buộc |

## Checklist sau khi thay ảnh

```bash
# 1. Icon app (sau khi thay AppIcon-master-1024.png)
./scripts/generate_app_icon.sh

# 2. Build lại + cài
./build.sh
rm -rf /Applications/ApexTune.app && cp -R build/ApexTune.app /Applications/

# 3. Screenshot lại 2 ảnh website (mở app, dashboard, main window) đè lên
#    website/assets/mainwindow.png và website/assets/dashboard.png

# 4. Commit + push — GitHub Pages tự deploy
git add -A && git commit -m "brand: new ApexTune artwork" && git push
```

## Ghi chú bản quyền

- Ảnh do AI sinh theo prompt tự viết: an toàn hơn nhiều so với lấy artwork có sẵn,
  nhưng vẫn nên **kiểm tra ngược** (Google Lens / TinEye) trước khi phát hành công khai.
- Nếu dùng Midjourney: thêm `--no apple, logo, text, watermark` vào cuối prompt.
- File `.icns` cũ trong build history vẫn tồn tại trong git — nếu cần xoá sạch khỏi
  lịch sử thì phải rewrite git history (chỉ làm khi thật sự cần).
