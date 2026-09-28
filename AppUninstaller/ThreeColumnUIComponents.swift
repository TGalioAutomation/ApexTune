//
//  ThreeColumnUIComponents.swift
//  Thành phần giao diện người dùng bố cục ba cột mới

//
//  Created for Smart Scan Detail View Redesign
//

import SwiftUI

// MARK: - Thành phần hộp kiểm ba trạng thái

struct TriStateCheckbox: View {
    let state: SmartCleanerService.SelectionState
    let action: () -> Void
    @State private var isHovering: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(borderColor, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            
            if state != .none {
                Circle()
                    .fill(fillColor)
                    .frame(width: 20, height: 20)
                
                if state == .all {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 20, height: 20)
        .opacity(isHovering ? 0.8 : 1.0)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { @MainActor in
                action()
            }
        }
        .onHover { isHovering = $0 }
    }
    
    private var fillColor: Color {
        // Design uses a bright cyan-blue. 
        // Using a color close to the screenshot (approx #28C8FF or #40C4FF)
        return Color(red: 40/255, green: 200/255, blue: 255/255) // Cyan-Blue
    }
    
    private var borderColor: Color {
        state == .none ? Color.white.opacity(0.3) : fillColor
    }
}

// MARK: - Hàng danh mục chính (cột bên trái)


struct MainCategoryRow: View {
    let mainCategory: MainCategory
    let totalItems: Int
    let totalSize: Int64
    let isSelected: Bool
    let selectionState: SmartCleanerService.SelectionState
    let toggleAction: () -> Void
    let onSelect: () -> Void
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // hộp đánh dấu

            TriStateCheckbox(state: selectionState, action: toggleAction)
                .frame(width: 20, height: 20) // Smaller checkbox
                .contentShape(Rectangle())
            
            // khu vực nội dung

            HStack(spacing: 6) { // Smaller spacing 8->6
                // biểu tượng

                ZStack {
                    Circle()
                        .fill(mainCategory.color.opacity(0.2))
                        .frame(width: 24, height: 24) // Smaller 32->24
                    
                    Image(systemName: mainCategory.icon)
                        .font(.system(size: 12)) // Smaller 14->12
                        .foregroundColor(mainCategory.color)
                }
                
                VStack(alignment: .leading, spacing: 1) { // Tighter spacing
                    Text(L(mainCategory.rawValue))
                        .font(.system(size: 12, weight: .medium)) // Smaller 13->12
                        .foregroundColor(.white)
                    
                    Text("\(totalItems)")
                        .font(.system(size: 10)) // Smaller 11->10
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    if [.virus, .startupItems, .performanceApps, .appUpdates].contains(mainCategory) {
                        Text(String(format: L("%d mục"), totalItems))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 12, weight: .semibold)) // Smaller font
                            .foregroundColor(.white)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
        .padding(.vertical, 8) // Reduced padding
        .padding(.horizontal, 8)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? mainCategory.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - dòng danh mục con (cột giữa)


struct SubCategoryRow: View {
    let subcategory: CleanerCategory
    let fileCount: Int
    let totalSize: Int64
    let isSelected: Bool
    let selectionState: SmartCleanerService.SelectionState
    let onSelect: () -> Void
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Hộp kiểm ba trạng thái

            TriStateCheckbox(state: selectionState) {
                service.toggleCategorySelection(subcategory)
            }
            .frame(width: 20, height: 20) // Smaller
            
            // khu vực nội dung

            HStack(spacing: 6) { // Compact 8->6
                // biểu tượng

                ZStack {
                    Circle()
                        .fill(subcategory.color.opacity(0.15))
                        .frame(width: 24, height: 24) // Smaller 28->24
                    
                    Image(systemName: subcategory.icon)
                        .font(.system(size: 11)) // Smaller 13->11
                        .foregroundColor(subcategory.color)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(L(subcategory.rawValue))
                        .font(.system(size: 12, weight: .medium)) // Smaller 13->12
                        .foregroundColor(.white)
                    
                    Text(String(format: L("%d tệp"), fileCount))
                        .font(.system(size: 10)) // Smaller 11->10
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    if [.virus, .startupItems, .performanceApps, .appUpdates].contains(subcategory) {
                        Text(String(format: L("%d mục"), fileCount))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
        .padding(.vertical, 6) // Reduced 10->6
        .padding(.horizontal, 8)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Chế độ xem danh sách danh mục chính


struct MainCategoryListView: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var selectedMainCategory: MainCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // tiêu đề

            Text(L("Kết quả quét"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(MainCategory.allCases) { mainCat in
                        let stats = service.statisticsFor(mainCategory: mainCat)
                        
                        MainCategoryRow(
                            mainCategory: mainCat,
                            totalItems: stats.count,
                            totalSize: stats.size,
                            isSelected: selectedMainCategory == mainCat,
                            selectionState: service.getSelectionState(for: mainCat),
                            toggleAction: { service.toggleMainCategorySelection(mainCat) },
                            onSelect: { selectedMainCategory = mainCat },
                            loc: loc
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 220)
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - Xem danh sách danh mục con


struct SubCategoryListView: View {
    let mainCategory: MainCategory
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var selectedSubcategory: CleanerCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // tiêu đề

            HStack {
                Text(L(mainCategory.rawValue))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // sắp xếp theo

                Text(L("Theo kích thước ▼"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(mainCategory.subcategories, id: \.self) { subcat in
                        let stats = service.statisticsFor(category: subcat)
                        
                        SubCategoryRow(
                            subcategory: subcat,
                            fileCount: stats.count,
                            totalSize: stats.size,
                            isSelected: selectedSubcategory == subcat,
                            selectionState: service.getSelectionState(for: subcat),
                            onSelect: { selectedSubcategory = subcat },
                            service: service,
                            loc: loc
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 350)
        .background(Color.black.opacity(0.15))
    }
}
