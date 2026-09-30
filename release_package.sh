#!/bin/bash

# ApexTune - Tập lệnh đóng gói phát hành v5.0.1
#
# Chức năng:
# 1. Biên dịch riêng phiên bản Intel (x86_64) và Apple Silicon (arm64)
# 2. Tạo hai gói cài đặt DMG độc lập

set -e

# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="5.0.1"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    ApexTune v${VERSION} - Đóng gói phát hành${NC}"
echo -e "${BLUE}    Intel & Apple Silicon DMG Generator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Biến cấu hình
APP_NAME="ApexTune"
EXECUTABLE_NAME="AppUninstaller"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build_release"
SOURCE_DIR="AppUninstaller"

# Danh sách file nguồn
SWIFT_FILES=(
    "${SOURCE_DIR}/Models.swift"
    "${SOURCE_DIR}/LocalizationManager.swift"
    "${SOURCE_DIR}/ConcurrentScanner.swift"
    "${SOURCE_DIR}/ScanServiceManager.swift"
    "${SOURCE_DIR}/AppScanner.swift"
    "${SOURCE_DIR}/ResidualFileScanner.swift"
    "${SOURCE_DIR}/FileRemover.swift"
    "${SOURCE_DIR}/DiskSpaceManager.swift"
    "${SOURCE_DIR}/DiskUsageView.swift"
    "${SOURCE_DIR}/Styles.swift"
    "${SOURCE_DIR}/LargeFileScanner.swift"
    "${SOURCE_DIR}/LargeFileView.swift"
    "${SOURCE_DIR}/LargeFileDetailsSplitView.swift"
    "${SOURCE_DIR}/TrashView.swift"
    "${SOURCE_DIR}/DeepCleanScanner.swift"
    "${SOURCE_DIR}/DeepCleanView.swift"
    "${SOURCE_DIR}/TrashDetailsSplitView.swift"
    "${SOURCE_DIR}/FileExplorerService.swift"
    "${SOURCE_DIR}/FileExplorerView.swift"
    "${SOURCE_DIR}/SystemMonitorService.swift"
    "${SOURCE_DIR}/ProcessService.swift"
    "${SOURCE_DIR}/PortScannerService.swift"
    "${SOURCE_DIR}/MonitorView.swift"
    "${SOURCE_DIR}/ContentView.swift"
    "${SOURCE_DIR}/AppDetailView.swift"
    "${SOURCE_DIR}/AppUninstallerView.swift"
    "${SOURCE_DIR}/NavigationSidebar.swift"
    "${SOURCE_DIR}/JunkCleaner.swift"
    "${SOURCE_DIR}/JunkCleanerView.swift"
    "${SOURCE_DIR}/SystemOptimizer.swift"
    "${SOURCE_DIR}/MaintenanceView.swift"
    "${SOURCE_DIR}/OptimizerView.swift"
    "${SOURCE_DIR}/MalwareScanner.swift"
    "${SOURCE_DIR}/MalwareView.swift"
    "${SOURCE_DIR}/PrivacyScannerService.swift"
    "${SOURCE_DIR}/PrivacyView.swift"
    "${SOURCE_DIR}/SmartCleanerService.swift"
    "${SOURCE_DIR}/CircularActionButton.swift"
    "${SOURCE_DIR}/SmartCleanerView.swift"
    "${SOURCE_DIR}/SmartScanLegacySupport.swift"
    "${SOURCE_DIR}/ShredderService.swift"
    "${SOURCE_DIR}/ShredderView.swift"
    "${SOURCE_DIR}/ShredderComponents.swift"
    "${SOURCE_DIR}/AppUninstallerApp.swift"
    "${SOURCE_DIR}/UpdateCheckerService.swift"
    "${SOURCE_DIR}/UpdatePopupView.swift"
    "${SOURCE_DIR}/SettingsView.swift"
)

# Hàm tạo App Bundle
create_app_bundle() {
    local ARCH=$1
    local OUTPUT_DIR=$2

    mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS"
    mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/Resources"

    # Sao chép file thực thi
    cp "${BUILD_DIR}/${ARCH}/${EXECUTABLE_NAME}" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS/"

    # Sao chép tài nguyên
    cp "${SOURCE_DIR}/Info.plist" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/"
    if [ -f "${SOURCE_DIR}/AppIcon.icns" ]; then
        cp "${SOURCE_DIR}/AppIcon.icns" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/Resources/"
    fi

    # Ký ứng dụng
    codesign --force --deep --sign - "${OUTPUT_DIR}/${BUNDLE_NAME}"
}

# Hàm tạo DMG
create_dmg() {
    local ARCH=$1
    local SOURCE_APP=$2
    local OUTPUT_PATH=$3

    # Tạo thư mục tạm
    local DMG_SRC="${BUILD_DIR}/dmg_${ARCH}"
    rm -rf "${DMG_SRC}"
    mkdir -p "${DMG_SRC}"

    # Sao chép ứng dụng và tạo liên kết Applications
    cp -r "${SOURCE_APP}" "${DMG_SRC}/"
    ln -s /Applications "${DMG_SRC}/Applications"

    # Tạo DMG
    rm -f "${OUTPUT_PATH}"
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_SRC}" \
        -ov -format UDZO \
        "${OUTPUT_PATH}"

    # Dọn dẹp
    rm -rf "${DMG_SRC}"
}

# 1. Dọn sạch môi trường
echo -e "${YELLOW}[1/7] Dọn sạch môi trường build...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/arm64"
mkdir -p "${BUILD_DIR}/x86_64"
mkdir -p "${BUILD_DIR}/app_arm64"
mkdir -p "${BUILD_DIR}/app_x86_64"

# 2. Biên dịch phiên bản ARM64 (Apple Silicon)
echo -e "${YELLOW}[2/7] Đang biên dịch phiên bản Apple Silicon (arm64)...${NC}"
swiftc \
    -O \
    -target arm64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/arm64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"
echo -e "${GREEN}✓ Biên dịch Apple Silicon hoàn tất${NC}"

# 3. Biên dịch phiên bản Intel (x86_64)
echo -e "${YELLOW}[3/7] Đang biên dịch phiên bản Intel (x86_64)...${NC}"
swiftc \
    -O \
    -target x86_64-apple-macos13.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -parse-as-library \
    -o "${BUILD_DIR}/x86_64/${EXECUTABLE_NAME}" \
    "${SWIFT_FILES[@]}"
echo -e "${GREEN}✓ Biên dịch Intel hoàn tất${NC}"

# 4. Tạo App Bundle ARM64
echo -e "${YELLOW}[4/7] Tạo App Bundle Apple Silicon...${NC}"
create_app_bundle "arm64" "${BUILD_DIR}/app_arm64"
echo -e "${GREEN}✓ App Bundle Apple Silicon đã tạo xong${NC}"

# 5. Tạo App Bundle Intel
echo -e "${YELLOW}[5/7] Tạo App Bundle Intel...${NC}"
create_app_bundle "x86_64" "${BUILD_DIR}/app_x86_64"
echo -e "${GREEN}✓ App Bundle Intel đã tạo xong${NC}"

# 6. Tạo DMG Apple Silicon
echo -e "${YELLOW}[6/7] Tạo Apple Silicon DMG...${NC}"
ARM64_DMG="${BUILD_DIR}/${APP_NAME}_v${VERSION}_AppleSilicon.dmg"
create_dmg "arm64" "${BUILD_DIR}/app_arm64/${BUNDLE_NAME}" "${ARM64_DMG}"
echo -e "${GREEN}✓ Apple Silicon DMG đã tạo xong${NC}"

# 7. Tạo DMG Intel
echo -e "${YELLOW}[7/7] Tạo Intel DMG...${NC}"
INTEL_DMG="${BUILD_DIR}/${APP_NAME}_v${VERSION}_Intel.dmg"
create_dmg "x86_64" "${BUILD_DIR}/app_x86_64/${BUNDLE_NAME}" "${INTEL_DMG}"
echo -e "${GREEN}✓ Intel DMG đã tạo xong${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Đóng gói phát hành hoàn tất!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Phiên bản: ${YELLOW}v${VERSION}${NC}"
echo ""
echo -e "File DMG đã tạo:"
echo -e "  Apple Silicon (M1/M2/M3): ${YELLOW}${ARM64_DMG}${NC}"
echo -e "  Intel (x86_64):           ${YELLOW}${INTEL_DMG}${NC}"
echo ""
echo -e "Kích thước file:"
ls -lh "${ARM64_DMG}" | awk '{print "  Apple Silicon: " $5}'
ls -lh "${INTEL_DMG}" | awk '{print "  Intel:         " $5}'
echo ""
