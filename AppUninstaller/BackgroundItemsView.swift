import SwiftUI

/// Quản lý các dịch vụ chạy ngầm của bên thứ ba (LaunchAgents/LaunchDaemons không phải của Apple).
struct BackgroundItemsView: View {
    @StateObject private var manager = BackgroundItemsManager.shared
    @State private var searchText = ""
    @State private var busyItemID: String?

    private var filteredItems: [BackgroundItemsManager.BackgroundItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return manager.items }
        return manager.items.filter {
            $0.name.lowercased().contains(query) || $0.label.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    summarySection

                    if manager.items.isEmpty && !manager.isScanning {
                        emptyState
                    } else {
                        itemsSection
                    }
                }
                .padding(24)
            }
        }
        .background(AppModule.backgroundItems.backgroundGradient.ignoresSafeArea())
        .onAppear(perform: manager.refresh)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Dịch vụ chạy ngầm"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(L("Các tiến trình tự khởi động của bên thứ ba. Tạm tắt những mục không cần để máy nhẹ hơn khi khởi động."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryChip(icon: "list.bullet.rectangle", value: "\(manager.thirdPartyCount)", label: L("Mục của bên thứ ba"))
            summaryChip(icon: "pause.circle", value: "\(manager.items.filter(\.isDisabled).count)", label: L("Đang tạm tắt"))
            summaryChip(icon: "bolt.circle", value: "\(manager.items.filter { $0.isLoaded && !$0.isDisabled }.count)", label: L("Đang chạy"))
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField(L("Tìm theo tên hoặc label"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)

            LazyVStack(spacing: 10) {
                ForEach(filteredItems) { item in
                    BackgroundItemRow(
                        item: item,
                        isBusy: busyItemID == item.id,
                        onToggle: { toggle(item) },
                        onReveal: { manager.revealInFinder(item) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.green.opacity(0.9))
            Text(L("Không có dịch vụ nền của bên thứ ba"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(L("Tất cả mục tự khởi động đều thuộc về macOS."))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func summaryChip(icon: String, value: String, label: String) -> some View {
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

    private func toggle(_ item: BackgroundItemsManager.BackgroundItem) {
        busyItemID = item.id
        let completion: (Bool) -> Void = { _ in
            DispatchQueue.main.async {
                busyItemID = nil
            }
        }
        if item.isDisabled {
            manager.enable(item, completion: completion)
        } else {
            manager.disable(item, completion: completion)
        }
    }
}

private struct BackgroundItemRow: View {
    let item: BackgroundItemsManager.BackgroundItem
    let isBusy: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.isDisabled ? "pause.circle" : "arrow.clockwise.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(item.isDisabled ? .white.opacity(0.35) : .green.opacity(0.85))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(L(item.location.rawValue))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    if item.runAtLoad {
                        statusChip(L("Tự khởi động"))
                    }
                    if item.keepAlive {
                        statusChip(L("Tự phục hồi"))
                    }
                    if item.isDisabled {
                        statusChip(L("Tạm tắt"))
                    } else if item.isLoaded {
                        statusChip(L("Đang chạy"))
                    }
                }
            }

            Spacer()

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help(L("Mở vị trí trong Finder"))

            Button(action: onToggle) {
                Text(isBusy ? L("Đang xử lý…") : (item.isDisabled ? L("Bật lại") : L("Tạm tắt")))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            item.isDisabled
                                ? AnyShapeStyle(Color(hex: "4DB7FF").opacity(0.85))
                                : AnyShapeStyle(Color.white.opacity(0.12))
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }

    private func statusChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }
}
