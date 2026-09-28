import SwiftUI

// MARK: - Scan Result Card Component
struct ScanResultCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 30)
                .fill(gradient)
                .frame(width: 160, height: 160)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Glass Highlight Overlay
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: 160, height: 160)
            
            VStack(spacing: 12) {
                // Icon Container
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                            
                        Image(systemName: icon)
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    } else {
                        // Loading state if needed
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                
                // Text
                if isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
            }
        }
    }
}

// MARK: - Scan Result Stat Component
struct ScanResultStat: View {
    let value: String
    let unit: String
    let detailsAction: (() -> Void)?
    let color: Color
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Value + Unit
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 42, weight: .light)) // Thin/Light font like design
                    .foregroundColor(color) // Custom Color
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color)
                }
            }
            
            // Details Button
            if let action = detailsAction {
                Button(action: action) {
                    Text(L("Xem chi tiết..."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                Text(L("Tốt")) // thiết kế phù hợp "tốt"
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.green)
            }
        }
    }
}
