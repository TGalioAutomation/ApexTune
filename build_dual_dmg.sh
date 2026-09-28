#!/bin/bash

# MacOptimizer 4.0.10 - Tập lệnh đóng gói DMG hai kiến trúc
# Build phiên bản Apple Silicon và Intel

set -e

# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    MacOptimizer v4.0.10 - Đóng gói hai kiến trúc${NC}"
echo -e "${BLUE}    Apple Silicon + Intel DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Định nghĩa biến
APP_NAME="MacOptimizer"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
SOURCE_DIR="AppUninstaller"
VERSION="4.0.10"

# Tên file DMG
DMG_ARM64="${APP_NAME}_v${VERSION}_AppleSilicon.dmg"
DMG_X86_64="${APP_NAME}_v${VERSION}_Intel.dmg"

# 1. Kiểm tra file nguồn
echo -e "${YELLOW}[1/5] Kiểm tra file nguồn...${NC}"
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "${SOURCE_DIR}" -name "*.swift" -print0)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Lỗi: Không tìm thấy file nguồn${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kiểm tra file nguồn thành công (Tìm thấy ${#SWIFT_FILES[@]} file)${NC}"
echo ""

# 2. Chuẩn bị môi trường build
echo -e "${YELLOW}[2/5] Chuẩn bị môi trường build...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
echo -e "${GREEN}✓ Môi trường build đã sẵn sàng${NC}"
echo ""

# Hàm: Build từng kiến trúc
build_architecture() {
    local ARCH=$1
    local TARGET=$2
    local ARCH_NAME=$3

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Build phiên bản ${ARCH_NAME}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local APP_DIR="${BUILD_DIR}/${ARCH}/${BUNDLE_NAME}"

    # a) Tạo cấu trúc App Bundle
    echo -e "${YELLOW}Chuẩn bị cấu trúc thư mục...${NC}"
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"
    echo -e "${GREEN}✓ Cấu trúc thư mục đã hoàn thành${NC}"

    # b) Sao chép tài nguyên
    echo -e "${YELLOW}Sao chép file tài nguyên...${NC}"
    cp "${SOURCE_DIR}/Info.plist" "${APP_DIR}/Contents/"

    # Sao chép icon
    if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
        cp "${SOURCE_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
        echo -e "${GREEN}✓ Đã sao chép AppIcon.icns${NC}"
    else
        echo -e "${YELLOW}⚠ Cảnh báo: Không tìm thấy file icon AppIcon.icns${NC}"
    fi

    # Sao chép ảnh PNG
    for png_file in "${SOURCE_DIR}"/*.png; do
        if [ -f "$png_file" ]; then
            cp "$png_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    PNG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PNG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Đã sao chép ${PNG_COUNT} ảnh PNG${NC}"
    fi

    # Sao chép ảnh JPG
    for jpg_file in "${SOURCE_DIR}"/*.jpg; do
        if [ -f "$jpg_file" ]; then
            cp "$jpg_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    JPG_COUNT=$(ls -1 "${SOURCE_DIR}"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
    if [ "$JPG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Đã sao chép ${JPG_COUNT} ảnh JPG${NC}"
    fi

    # Sao chép âm thanh
    for audio_file in "${SOURCE_DIR}"/*.m4a; do
        if [ -f "$audio_file" ]; then
            cp "$audio_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    AUDIO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.m4a 2>/dev/null | wc -l | tr -d ' ')
    if [ "$AUDIO_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Đã sao chép ${AUDIO_COUNT} file âm thanh${NC}"
    fi

    # Sao chép video
    for video_file in "${SOURCE_DIR}"/*.mp4; do
        if [ -f "$video_file" ]; then
            cp "$video_file" "${APP_DIR}/Contents/Resources/"
        fi
    done
    VIDEO_COUNT=$(ls -1 "${SOURCE_DIR}"/*.mp4 2>/dev/null | wc -l | tr -d ' ')
    if [ "$VIDEO_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Đã sao chép ${VIDEO_COUNT} file video${NC}"
    fi

    # c) Biên dịch
    echo -e "${YELLOW}Đang biên dịch ${ARCH_NAME}...${NC}"
    echo -n "    "
    swiftc -O \
        -target ${TARGET} \
        -sdk $(xcrun --sdk macosx --show-sdk-path) \
        -parse-as-library \
        -o "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" \
        "${SWIFT_FILES[@]}"
    echo -e "${GREEN}OK${NC}"

    # d) Ký ứng dụng
    echo -e "${YELLOW}Đang ký ứng dụng...${NC}"
    codesign --force --deep --sign - "${APP_DIR}" > /dev/null 2>&1
    echo -e "${GREEN}✓ Ký xong${NC}"

    echo -e "${GREEN}✓ Build phiên bản ${ARCH_NAME} hoàn tất${NC}"
    echo ""
}

# Hàm: Tạo DMG
create_dmg() {
    local ARCH=$1
    local DMG_FILE=$2
    local ARCH_NAME=$3

    echo -e "${YELLOW}Đang đóng gói DMG ${ARCH_NAME}...${NC}"

    local APP_DIR="${BUILD_DIR}/${ARCH}/${BUNDLE_NAME}"
    local DMG_TEMP_DIR="${BUILD_DIR}/${ARCH}/dmg_temp"
    local DMG_PATH="${BUILD_DIR}/${DMG_FILE}"

    # Chuẩn bị nội dung DMG
    rm -rf "${DMG_TEMP_DIR}"
    mkdir -p "${DMG_TEMP_DIR}"
    cp -R "${APP_DIR}" "${DMG_TEMP_DIR}/"
    ln -s /Applications "${DMG_TEMP_DIR}/Applications"

    # Sao chép ảnh nền
    mkdir -p "${DMG_TEMP_DIR}/.background"
    if [ -f "dmg_background.png" ]; then
        cp "dmg_background.png" "${DMG_TEMP_DIR}/.background/background.png"
        echo -e "${GREEN}✓ Đã sao chép ảnh nền${NC}"
    fi

    # Tạo DMG tạm thời
    TEMP_DMG="${BUILD_DIR}/${ARCH}/temp_rw.dmg"
    rm -f "${TEMP_DMG}"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${DMG_TEMP_DIR}" \
        -ov -format UDRW \
        "${TEMP_DMG}" > /dev/null

    # Gắn kết và thiết lập bố cục
    MOUNT_DIR="/Volumes/${APP_NAME}"

    if [ -d "${MOUNT_DIR}" ]; then
        hdiutil detach "${MOUNT_DIR}" -force > /dev/null 2>&1 || true
    fi

    hdiutil attach "${TEMP_DMG}" -nobrowse -mountpoint "${MOUNT_DIR}" > /dev/null

    echo -e "${YELLOW}Đang thiết lập bố cục cửa sổ...${NC}"
    osascript <<EOF > /dev/null 2>&1
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 150, 860, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "${BUNDLE_NAME}" of container window to {140, 180}
        set position of item "Applications" of container window to {500, 180}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

    sync
    hdiutil detach "${MOUNT_DIR}" > /dev/null

    # Chuyển sang DMG nén
    rm -f "${DMG_PATH}"
    hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" > /dev/null

    # Dọn dẹp
    rm -f "${TEMP_DMG}"
    rm -rf "${DMG_TEMP_DIR}"

    echo -e "${GREEN}✓ Đóng gói DMG ${ARCH_NAME} hoàn tất${NC}"
    echo ""
}

# 3. Build phiên bản Apple Silicon
echo -e "${YELLOW}[3/5] Build phiên bản Apple Silicon (arm64)...${NC}"
echo ""
build_architecture "arm64" "arm64-apple-macos13.0" "Apple Silicon (chip M)"

# 4. Build phiên bản Intel
echo -e "${YELLOW}[4/5] Build phiên bản Intel (x86_64)...${NC}"
echo ""
build_architecture "x86_64" "x86_64-apple-macos13.0" "Intel"

# 5. Tạo DMG
echo -e "${YELLOW}[5/5] Đóng gói ảnh DMG...${NC}"
echo ""
echo -e "${BLUE}━━ Apple Silicon DMG ━━${NC}"
create_dmg "arm64" "${DMG_ARM64}" "Apple Silicon"
echo -e "${BLUE}━━ Intel DMG ━━${NC}"
create_dmg "x86_64" "${DMG_X86_64}" "Intel"

# Hoàn tất
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Đóng gói DMG hai kiến trúc hoàn tất!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Phiên bản: ${YELLOW}v${VERSION}${NC}"
echo ""
echo -e "Apple Silicon (chip M): ${YELLOW}${BUILD_DIR}/${DMG_ARM64}${NC}"
echo -e "Intel (x86_64):         ${YELLOW}${BUILD_DIR}/${DMG_X86_64}${NC}"
echo ""
echo -e "Kích thước file:"
ls -lh "${BUILD_DIR}"/*.dmg 2>/dev/null || true
echo ""
echo -e "${GREEN}✓ Cả hai phiên bản đều bao gồm giao diện kéo thả cài đặt và shortcut Applications${NC}"
echo ""
