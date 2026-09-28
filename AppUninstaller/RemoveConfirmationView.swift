import SwiftUI

struct RemoveConfirmationView: View {
    let items: [FileNode]
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onCancel()
                }
            
            // Dialog Card
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Bạn sẽ xóa các tập tin!"))
                            .font(.system(size: 20, weight: .bold)) // Larger bold font
                            .foregroundColor(.white)
                        
                        Text(L("Lưu ý: Các tệp đã chọn sẽ biến mất vĩnh viễn. Kiểm tra cẩn thận."))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .lineSpacing(4)
                    }
                    Spacer()
                }
                .padding(32) // More padding
                
                // File List
                ScrollView {
                    VStack(spacing: 16) { // More spacing
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                // Checkmark
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 1.0)) // Vibrant Blue
                                    .font(.system(size: 18))
                                    .background(Circle().fill(Color.white).frame(width: 10, height: 10))
                                
                                // Icon
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                
                                // Details
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(item.url.path)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                // Size
                                Text(item.formattedSize)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            // No background on items
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxHeight: 220) // Limit height
                
                // Actions
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text(L("Hủy bỏ"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onConfirm) {
                        Text(L("Di dời"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color(red: 0.4, green: 0.8, blue: 1.0)) // Light Cyan/Blue
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
            }
            .frame(width: 540) // Slightly wider
            .background(Color(red: 0.18, green: 0.18, blue: 0.20)) // Dark Grey specific
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        }
    }
}
