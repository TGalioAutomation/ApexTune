import SwiftUI

/// Quản lý image Docker cục bộ: xem dung lượng, xóa image, dọn image lơ lửng.
struct DockerView: View {
    @StateObject private var manager = DockerManager.shared
    @State private var pendingDelete: DockerManager.DockerImage?
    @State private var confirmPrune = false
    @State private var searchText = ""

    private var filteredImages: [DockerManager.DockerImage] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return manager.images }
        return manager.images.filter {
            $0.repository.lowercased().contains(query) || $0.tag.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection

                    if !manager.isInstalled {
                        notInstalledState
                    } else if !manager.isDaemonRunning {
                        daemonNotRunningState
                    } else {
                        summarySection
                        imagesSection
                    }
                }
                .padding(24)
            }
        }
        .background(AppModule.docker.backgroundGradient.ignoresSafeArea())
        .onAppear(perform: manager.refresh)
        .alert(
            L("Xóa image này?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { image in
            Button(L("Xóa"), role: .destructive) {
                manager.deleteImage(image)
            }
            Button(L("Hủy"), role: .cancel) {}
        } message: { image in
            Text(String(format: L("Xóa %@:%@? Sẽ giải phóng %@. Hành động này không thể hoàn tác."), image.displayName, image.tag, image.sizeText))
        }
        .alert(L("Dọn image lơ lửng?"), isPresented: $confirmPrune) {
            Button(L("Dọn dẹp"), role: .destructive) {
                manager.pruneDangling()
            }
            Button(L("Hủy"), role: .cancel) {}
        } message: {
            Text(L("Sẽ xóa các image không gán tên (dangling) không được container nào dùng."))
        }
    }

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Image Docker"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(L("Danh sách image trên máy kèm dung lượng để kiểm soát đĩa."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button(action: manager.refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(manager.isLoading)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            chip(icon: "shippingbox.fill", value: "\(manager.imageCount)", label: "Image")
            chip(icon: "internaldrive.fill", value: manager.totalSizeText, label: L("Tổng dung lượng"))
            Spacer()
            Button(action: { confirmPrune = true }) {
                Label(L("Dọn image lơ lửng"), systemImage: "sparkles.rectangle.stack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(manager.images.isEmpty)
        }
    }

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !manager.statusMessage.isEmpty {
                Text(manager.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField(L("Tìm theo tên hoặc tag"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)

            if filteredImages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))
                    Text(L("Không có image nào"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(L("Docker trên máy chưa lưu image nào."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredImages) { image in
                        DockerImageRow(image: image) {
                            pendingDelete = image
                        }
                    }
                }
            }
        }
    }

    private var notInstalledState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.6))
            Text(L("Chưa cài Docker"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(L("Cài Docker Desktop để xem và quản lý image ngay tại đây."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var daemonNotRunningState: some View {
        VStack(spacing: 12) {
            Image(systemName: "power.dotted")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.6))
            Text(L("Docker Desktop chưa chạy"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(L("Mở Docker Desktop rồi quay lại đây để xem danh sách image."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button(action: launchDocker) {
                Label(L("Mở Docker Desktop"), systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(GradientStyles.aiModels))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func chip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func launchDocker() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Docker"]
        try? task.run()
    }
}

private struct DockerImageRow: View {
    let image: DockerManager.DockerImage
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "4DB7FF"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(image.displayName):\(image.tag)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(image.imageID)
                        .font(.system(size: 11, design: .monospaced))
                    Text("• \(image.createdText)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
            }

            Spacer()

            Text(image.sizeText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.9))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "FF6B6B"))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help(L("Xóa image"))
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}
