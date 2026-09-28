import SwiftUI

struct UpdatePopupView: View {
    @ObservedObject var updateService = UpdateCheckerService.shared
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon & Header
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(L("Phiên bản mới có sẵn"))
                    .font(.title2)
                    .bold()
                
                Text("v\(updateService.latestVersion)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Release Notes
            ScrollView {
                Text(updateService.releaseNotes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            
            Divider()
            
            // Actions
            HStack(spacing: 16) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(L("Sau đó"))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let url = updateService.downloadURL {
                        NSWorkspace.shared.open(url)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text(L("Cập nhật ngay"))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
