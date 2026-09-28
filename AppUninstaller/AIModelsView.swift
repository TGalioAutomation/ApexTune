import SwiftUI
import AIModelKit

struct AIModelsView: View {
    @EnvironmentObject private var manager: AIModelManager
    @State private var searchText = ""
    @State private var pendingDeleteItem: AIModelItem?
    @State private var feedbackMessage: String?

    private var filteredItems: [AIModelItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return manager.allItems }

        return manager.allItems.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
            || item.provider.rawValue.localizedCaseInsensitiveContains(query)
            || item.locationDescription.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                providerSummarySection
                actionSection
                modelsSection
            }
            .padding(28)
        }
        .background(BackgroundStyles.aiModels)
        .alert(item: $pendingDeleteItem) { item in
            let title = item.provider == .ollama ? L("Xóa model Ollama?") : L("Chuyển model vào Thùng rác?")
            let message: String
            if item.provider == .ollama {
                message = String(format: L("Model `%@` sẽ bị xóa khỏi Ollama. Hành động này không đi qua Thùng rác."), item.name)
            } else {
                message = String(format: L("Model `%@` sẽ được chuyển vào Thùng rác để có thể phục hồi sau."), item.name)
            }

            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .destructive(Text(L("Xóa"))) {
                    manager.delete(item) { _, statusMessage in
                        feedbackMessage = statusMessage
                    }
                },
                secondaryButton: .cancel(Text(L("Hủy")))
            )
        }
        .onReceive(manager.$actionMessage) { message in
            if let message, !message.isEmpty {
                feedbackMessage = message
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Quản lý mô hình AI"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(L("Nhìn rõ dung lượng Ollama và LM Studio, mở đúng thư mục lưu model, pull thêm model mới và xóa nhanh khi ổ đĩa sắp đầy."))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.78))
                        .lineSpacing(4)
                        .frame(maxWidth: 560, alignment: .leading)
                }

                Spacer()

                Button(action: manager.refresh) {
                    Label(L("Làm mới"), systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(CapsuleButtonStyle(gradient: GradientStyles.aiModels))
            }

            HStack(spacing: 16) {
                summaryChip(
                    title: L("Tổng dung lượng model"),
                    value: ByteCountFormatter.string(fromByteCount: manager.totalManagedSize, countStyle: .file),
                    icon: "internaldrive.fill"
                )

                summaryChip(
                    title: L("Số model đang quản lý"),
                    value: "\(manager.allItems.count)",
                    icon: "shippingbox.fill"
                )

                summaryChip(
                    title: L("Provider phát hiện"),
                    value: "\(manager.providerStates.values.filter(\.isDetected).count)/2",
                    icon: "checkmark.shield.fill"
                )
            }

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var providerSummarySection: some View {
        HStack(spacing: 18) {
            ForEach(AIModelProvider.allCases) { provider in
                providerCard(state: manager.providerStates[provider] ?? emptyState(for: provider))
            }
        }
    }

    private var actionSection: some View {
        HStack(alignment: .top, spacing: 18) {
            ollamaPullCard
            tipsCard
        }
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Model đang chiếm dung lượng"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(L("Sắp xếp theo dung lượng lớn nhất để user dọn nhanh hơn."))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
            }

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.55))
                    TextField(L("Tìm theo tên model hoặc đường dẫn"), text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                if manager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 32, height: 32)
                }
            }

            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    modelRow(item)
                }
            }

            if filteredItems.isEmpty && !manager.isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.5))
                    Text(L("Chưa có model nào khớp bộ lọc hiện tại."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var ollamaPullCard: some View {
        let ollamaState = manager.providerStates[.ollama] ?? emptyState(for: .ollama)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AIModelProvider.ollama.tint)
                Text(L("Pull model với Ollama"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(L("Nhập model như `llama3.2:3b`, `qwen2.5:7b` hoặc `deepseek-r1:8b` để tải trực tiếp."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.68))
                .lineSpacing(4)

            HStack(spacing: 10) {
                TextField(L("Ví dụ: qwen2.5:7b"), text: $manager.ollamaPullName)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                Button(action: {
                    manager.pullOllamaModel { _, message in
                        feedbackMessage = message
                    }
                }) {
                    if manager.isPulling {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 76)
                    } else {
                        Text("Pull")
                            .frame(width: 76)
                    }
                }
                .buttonStyle(CapsuleButtonStyle(gradient: GradientStyles.aiModels))
                .disabled(!ollamaState.canPull || manager.isPulling)
            }

            Text(ollamaState.canPull ? L("Ollama đã sẵn sàng.") : ollamaState.status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ollamaState.canPull ? Color.success : Color.warning)
        }
        .padding(20)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Gợi ý dọn dung lượng"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            tipRow(icon: "checkmark.seal.fill", text: L("Model LM Studio được xóa qua Thùng rác để an toàn hơn."))
            tipRow(icon: "exclamationmark.triangle.fill", text: L("Model Ollama bị xóa trực tiếp khỏi registry local khi dùng `ollama rm`."))
            tipRow(icon: "folder.fill", text: L("Nếu chưa chắc, bấm `Mở vị trí` để xem folder trước khi xóa."))
        }
        .padding(20)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerCard(state: AIProviderState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(state.provider.tint)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: state.provider.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.provider.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(state.provider.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 14) {
                providerMetric(title: L("Dung lượng"), value: state.formattedTotalSize)
                providerMetric(title: "Model", value: "\(state.itemCount)")
            }

            Text(state.status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineSpacing(3)

            HStack(spacing: 10) {
                Button(L("Mở vị trí")) {
                    manager.openRoot(for: state.provider)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
                .disabled(state.roots.isEmpty)

                if let firstRoot = state.roots.first {
                    Text(firstRoot.path)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func summaryChip(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func modelRow(_ item: AIModelItem) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(item.provider.tint)
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: item.provider.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(item.provider.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.82))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                Text(item.details)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.62))

                Text(item.locationDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(item.formattedSize)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                if let modifiedDate = item.modifiedDate {
                    Text(modifiedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            HStack(spacing: 10) {
                Button(L("Mở vị trí")) {
                    manager.reveal(item)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)

                Button {
                    pendingDeleteItem = item
                } label: {
                    if manager.activeItemID == item.id {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 64, height: 18)
                    } else {
                        Text(L("Xóa"))
                            .frame(width: 64)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
                .disabled(manager.activeItemID == item.id)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
    }

    private func emptyState(for provider: AIModelProvider) -> AIProviderState {
        AIProviderState(
            provider: provider,
            items: [],
            totalSize: 0,
            roots: [],
            isDetected: false,
            status: L("Đang kiểm tra..."),
            canPull: false,
            canDelete: false
        )
    }
}
