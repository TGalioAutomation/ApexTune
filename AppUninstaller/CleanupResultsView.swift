import SwiftUI

struct CleanupResultsView: View {
    let cleanedSize: Int64
    let cleanedCount: Int
    let recommendations: [CleanupRecommendation]
    let onDismiss: () -> Void
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: cleanedSize, countStyle: .file)
    }
    
    var body: some View {
        ZStack {
            // Gradient background - Purple to Blue
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.6, green: 0.4, blue: 0.8),  // Purple
                    Color(red: 0.4, green: 0.3, blue: 0.7)   // Darker Purple-Blue
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L("Quay lại"))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                    Text(L("Dọn dẹp hoàn tất"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Spacer()
                
                // Main content
                VStack(spacing: 32) {
                    // Illustration area
                    ZStack {
                        // Decorative circle background
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 280, height: 280)
                        
                        // Computer illustration (using SF Symbols as placeholder)
                        VStack(spacing: 8) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .opacity(0.9)
                        }
                    }
                    .frame(height: 280)
                    
                    // Results section
                    VStack(spacing: 20) {
                        // Title
                        VStack(spacing: 8) {
                            Text(L("Làm tốt lắm!"))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(L("Mac của bạn đang ở trạng thái tốt."))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Results cards
                        VStack(spacing: 12) {
                            ResultCard(
                                icon: "2",
                                title: formattedSize,
                                subtitle: L("Rác không cần thiết đã được dọn sạch"),
                                color: Color(red: 0.4, green: 0.8, blue: 1.0)
                            )
                            
                            ResultCard(
                                icon: "fingerprint",
                                title: L("Nên chạy quét sâu"),
                                subtitle: L("Quét sâu có thể tìm thêm tệp rác. Nên chạy mỗi tuần một lần."),
                                color: Color(red: 0.4, green: 0.9, blue: 0.6)
                            )
                            
                            ResultCard(
                                icon: "checkmark.circle",
                                title: String(format: L("%d tác vụ"), cleanedCount),
                                subtitle: L("Hiệu năng Mac đã được tối ưu"),
                                color: Color(red: 1.0, green: 0.5, blue: 0.6)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Bottom action
                VStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text(L("Về trang chính"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Text(L("Xem nhật ký chi tiết"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

struct ResultCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                if icon.count == 1 {
                    Text(icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(color)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CleanupRecommendation {
    let title: String
    let description: String
    let priority: Int // 1-3, higher = more important
}

#if DEBUG
struct CleanupResultsView_Previews: PreviewProvider {
    static var previews: some View {
        CleanupResultsView(
            cleanedSize: 2_645_000_000,
            cleanedCount: 2,
            recommendations: [
                CleanupRecommendation(
                    title: "Quét sâu",
                    description: "Tìm thêm tệp rác",
                    priority: 1
                )
            ],
            onDismiss: {}
        )
    }
}
#endif
