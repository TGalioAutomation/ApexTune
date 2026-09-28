#!/bin/bash

# MacOptimizer - Tập lệnh build
# Biên dịch Universal Binary (Intel + Apple Silicon) và đóng gói DMG

set -e

# Toolchain: CommandLineTools đang thiếu macro plugin (SwiftUIMacros) khiến
# swift build lỗi "@State... plugin for module 'SwiftUIMacros' not found".
# Ưu tiên toolchain Xcode khi có (không ghi đè nếu người dùng đã đặt DEVELOPER_DIR).
if [ -z "${DEVELOPER_DIR}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    MacOptimizer - Tập lệnh Build${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. Định nghĩa biến
APP_NAME="MacOptimizer"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
SOURCE_DIR="AppUninstaller"
DMG_NAME="${APP_NAME}.dmg"

# 2. Kiểm tra file nguồn
echo -e "${YELLOW}[1/7] Kiểm tra file nguồn...${NC}"
# Dùng find để đệ quy tìm tất cả file .swift
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -name "*.swift" -print0)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Lỗi: Không tìm thấy file nguồn${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kiểm tra file nguồn thành công (Tìm thấy ${#SWIFT_FILES[@]} file)${NC}"

# 3. Chuẩn bị thư mục build
echo -e "${YELLOW}[2/7] Chuẩn bị thư mục build...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources"
echo -e "${GREEN}✓ Thư mục đã được chuẩn bị xong${NC}"

# 4. Sao chép tài nguyên
echo -e "${YELLOW}[3/7] Sao chép file tài nguyên...${NC}"
cp "${SOURCE_DIR}/Info.plist" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/"
if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
    cp "${SOURCE_DIR}/AppIcon.icns" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    echo -e "${GREEN}✓ Đã sao chép AppIcon.icns${NC}"
else
    echo -e "${YELLOW}⚠ Cảnh báo: Không tìm thấy file icon AppIcon.icns${NC}"
fi

# Sao chép tài nguyên ảnh PNG
for png_file in "${SOURCE_DIR}"/*.png; do
    if [ -f "$png_file" ]; then
        cp "$png_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
PNG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$PNG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Đã sao chép ${PNG_COUNT} ảnh PNG${NC}"
fi

# Sao chép tài nguyên ảnh JPG
for jpg_file in "${SOURCE_DIR}"/*.jpg; do
    if [ -f "$jpg_file" ]; then
        cp "$jpg_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
JPG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
if [ "$JPG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Đã sao chép ${JPG_COUNT} ảnh JPG${NC}"
fi

# Sao chép tài nguyên âm thanh (m4a)
for audio_file in "${SOURCE_DIR}"/*.m4a; do
    if [ -f "$audio_file" ]; then
        cp "$audio_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
AUDIO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.m4a 2>/dev/null | wc -l | tr -d ' ')
if [ "$AUDIO_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Đã sao chép ${AUDIO_COUNT} file âm thanh${NC}"
fi

# Sao chép tài nguyên video (mp4)
for video_file in "${SOURCE_DIR}"/*.mp4; do
    if [ -f "$video_file" ]; then
        cp "$video_file" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi
done
VIDEO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.mp4 2>/dev/null | wc -l | tr -d ' ')
if [ "$VIDEO_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Đã sao chép ${VIDEO_COUNT} file video${NC}"
fi

# 5. Biên dịch (Swift Package — bao gồm thư viện AIModelKit)
echo -e "${YELLOW}[4/7] Đang biên dịch (Swift Package, release)...${NC}"

echo -n "  - swift build -c release ... "
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}"
RESOURCE_BUNDLE="${BIN_DIR}/MacOptimizer_AppUninstaller.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    rm -rf "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/MacOptimizer_AppUninstaller.bundle"
    cp -R "${RESOURCE_BUNDLE}" "${BUILD_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    echo -e "${GREEN}OK (kèm resource bundle SPM)${NC}"
else
    echo -e "${YELLOW}⚠ Không thấy MacOptimizer_AppUninstaller.bundle — chỉ chép binary${NC}"
    echo -e "${GREEN}OK${NC}"
fi

# 5.1 Widget extension (WidgetKit — Notification Center / Desktop)
echo -e "${YELLOW}[5.1/7] Đóng gói widget extension...${NC}"
echo -n "  - swift build --target MacOptimizerWidget ... "
swift build -c release --target MacOptimizerWidget
WIDGET_BIN="${BIN_DIR}/MacOptimizerWidget"
APPEX="${BUILD_DIR}/${BUNDLE_NAME}/Contents/PlugIns/MacOptimizerWidget.appex"
mkdir -p "${APPEX}/Contents/MacOS"
cp "WidgetExtension/Info.plist" "${APPEX}/Contents/Info.plist"
cp "${WIDGET_BIN}" "${APPEX}/Contents/MacOS/MacOptimizerWidget"
# Widget extension BẮT BUỘC có app-sandbox entitlement, nếu không dasd/pluginkit bỏ qua.
codesign --force --sign - --entitlements "WidgetExtension/widget.entitlements" "${APPEX}"
echo -e "${GREEN}OK (PlugIns/MacOptimizerWidget.appex)${NC}"

# 6. Ký ứng dụng
echo -e "${YELLOW}[5/7] Ký ứng dụng...${NC}"
codesign --force --deep --sign - "${BUILD_DIR}/${BUNDLE_NAME}"
# --deep ký lại appex lồng bên trong mà KHÔNG có entitlements (mất app-sandbox),
# nên phải ký lại appex với entitlements sandbox SAU CÙNG.
codesign --force --sign - --entitlements "WidgetExtension/widget.entitlements" "${APPEX}"
echo -e "${GREEN}✓ Ký xong${NC}"

# 7. Đóng gói DMG (kèm ảnh nền và Applications shortcut)
echo -e "${YELLOW}[6/7] Đóng gói ảnh cài đặt DMG...${NC}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
if [ -f "${DMG_PATH}" ]; then
    rm "${DMG_PATH}"
fi

# Tạo thư mục tạm cho nội dung DMG
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# Sao chép ứng dụng vào thư mục tạm
cp -R "${BUILD_DIR}/${BUNDLE_NAME}" "${DMG_TEMP_DIR}/"

# Tạo symlink đến thư mục Applications
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Tạo thư mục ảnh nền ẩn
mkdir -p "${DMG_TEMP_DIR}/.background"
if [ -f "dmg_background.png" ]; then
    cp "dmg_background.png" "${DMG_TEMP_DIR}/.background/background.png"
    echo -e "${GREEN}✓ Đã sao chép ảnh nền${NC}"
fi

# Tạo DMG đọc-ghi tạm thời
TEMP_DMG="${BUILD_DIR}/temp_rw.dmg"
if [ -f "${TEMP_DMG}" ]; then
    rm "${TEMP_DMG}"
fi

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDRW \
    "${TEMP_DMG}" > /dev/null

# Gắn DMG và thiết lập bố cục cửa sổ
MOUNT_DIR="/Volumes/${APP_NAME}"

# Ngắt kết nối ổ đĩa cùng tên nếu đã tồn tại
if [ -d "${MOUNT_DIR}" ]; then
    hdiutil detach "${MOUNT_DIR}" -force > /dev/null 2>&1 || true
fi

# Gắn DMG
hdiutil attach "${TEMP_DMG}" -nobrowse -mountpoint "${MOUNT_DIR}" > /dev/null

# Thiết lập bố cục cửa sổ Finder bằng AppleScript
echo -e "  - Đang thiết lập bố cục cửa sổ..."

# Chờ DMG gắn hoàn toàn và được Finder nhận biết
sleep 2

# Bỏ qua AppleScript (có thể gây lỗi)
echo "  ⚠ Bỏ qua thiết lập bố cục cửa sổ (không ảnh hưởng đến chức năng DMG)"
# Đảm bảo ghi xong
sync

# Ngắt DMG
hdiutil detach "${MOUNT_DIR}" > /dev/null

# Chuyển sang định dạng nén chỉ đọc
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" > /dev/null

# Dọn file tạm
rm -f "${TEMP_DMG}"
rm -rf "${DMG_TEMP_DIR}"

echo -e "${GREEN}✓ Đóng gói DMG hoàn tất (kèm giao diện kéo thả cài đặt)${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Build & Đóng gói hoàn tất!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Gói ứng dụng: ${YELLOW}${BUILD_DIR}/${BUNDLE_NAME}${NC}"
echo -e "File DMG:     ${YELLOW}${DMG_PATH}${NC}"
echo -e "  └─ ${GREEN}✓ Kèm giao diện kéo thả cài đặt và shortcut Applications${NC}"
echo ""
