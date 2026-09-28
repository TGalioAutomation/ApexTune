import SwiftUI
import AppKit
import AVKit

extension Notification.Name {
    static let macOptimizerOpenModule = Notification.Name("macOptimizerOpenModule")
}

struct ContentView: View {
    @StateObject private var aiModelManager = AIModelManager()
    @State private var selectedModule: AppModule = .smartClean
    /// Shown while the main panel swaps views after sidebar selection (matches `selectedModule` animation).
    @State private var isModuleTransitioning = false
    @State private var moduleTransitionGeneration = 0
    // @State private var showIntro = false // Video disabled
    
    var body: some View {
        ZStack {
            // nội dung chính

            mainContent
        }
        .frame(minWidth: 1000, minHeight: 700)
        .environmentObject(aiModelManager)
        .onReceive(NotificationCenter.default.publisher(for: .macOptimizerOpenModule)) { notification in
            guard let module = notification.object as? AppModule else { return }
            selectedModule = module
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Nền toàn màn hình (đắm chìm)

            selectedModule.backgroundGradient
                .ignoresSafeArea()
            
            HStack(spacing: 16) {
                // Điều hướng bên trái (Thẻ kính nổi)

                NavigationSidebar(selectedModule: $selectedModule)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.leading, 16)
                    .padding(.vertical, 16)
                    .zIndex(1)
                
                // Đúng nội dung

                ZStack {
                    Group {
                        switch selectedModule {
                        case .uninstaller:
                            UninstallerMainView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .deepClean:
                            DeepCleanView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .cleaner:
                            JunkCleanerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .maintenance:
                            MaintenanceView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .optimizer:
                            OptimizerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .largeFiles:
                            LargeFileView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .shredder:
                            ShredderView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .fileExplorer:
                            FileExplorerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .spaceLens:
                            SpaceLensView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .aiModels:
                            AIModelsView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .docker:
                            DockerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .backgroundItems:
                            BackgroundItemsView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .trash:
                            TrashView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .monitor:
                            MonitorView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .privacy:
                            PrivacyView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .malware:
                            MalwareView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .smartClean:
                            SmartCleanerView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .updater:
                            AppUpdaterView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedModule)

                    if isModuleTransitioning {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                ProgressView()
                                    .controlSize(.regular)
                                    .tint(.white)
                                    .accessibilityLabel("Loading module")
                            }
                            .allowsHitTesting(true)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isModuleTransitioning)
                .onChange(of: selectedModule) { _ in
                    moduleTransitionGeneration += 1
                    let token = moduleTransitionGeneration
                    isModuleTransitioning = true
                    let duration: TimeInterval = 0.38
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        if token == moduleTransitionGeneration {
                            isModuleTransitioning = false
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) // Glass Card Background
                .padding(.trailing, 16)
                .padding(.vertical, 16)
            }
        }
    }
}

// MARK: - Mở chế độ xem video

struct IntroVideoView: View {
    let onComplete: () -> Void
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                // Sử dụng VideoPlayerView tùy chỉnh để thay thế VideoPlayer của SwiftUI

                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
            
            // nút bỏ qua

            VStack {
                HStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text(L("Bỏ qua"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp4") else {
            // Nếu bạn không tìm thấy video, hãy hoàn thành nó

            onComplete()
            return
        }
        
        player = AVPlayer(url: url)
        player?.play()
        
        // Gọi lại khi phát xong video

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            onComplete()
        }
    }
}

// MARK: - Chế độ xem trình phát video tùy chỉnh (sử dụng AVPlayerLayer để tránh các vấn đề về tương thích)

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = VideoLayerView()
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? VideoLayerView {
            view.player = player
        }
    }
}

// Sử dụng chế độ xem của CALayer để lưu trữ AVPlayerLayer

class VideoLayerView: NSView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    private let playerLayer = AVPlayerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer = CALayer()
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

// Bao bọc chế độ xem Trình gỡ cài đặt hiện có

struct UninstallerMainView: View {
    @StateObject private var appScanner = AppScanner()
    
    var body: some View {
        AppUninstallerView(appScanner: appScanner)
    }
}

// Chia chế độ xem danh sách ứng dụng

struct AppListView: View {
    let apps: [InstalledApp]
    let selectedApp: InstalledApp?
    let isScanning: Bool
    @Binding var searchText: String
    let onSelect: (InstalledApp) -> Void
    let onRefresh: () -> Void
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Thanh công cụ tiêu đề

            HStack {
                Text(L("Danh sách ứng dụng"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            // thanh tìm kiếm

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.3))
                TextField(loc.L("search_apps"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            if isScanning {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text(L("Đang quét ứng dụng..."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                List(apps) { app in
                    AppListRow(app: app, isSelected: selectedApp?.id == app.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(app)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // thống kê dưới cùng

            HStack {
                Text(String(format: L("%d ứng dụng"), apps.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
        }
        .background(Color.black.opacity(0.2))
    }
}

// Tách chế độ xem trạng thái trống

struct EmptySelectionView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.square")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.1))
            Text(L("Chọn một ứng dụng để xem chi tiết"))
                .font(.title3)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// Thành phần hàng danh sách (được điều chỉnh theo kiểu mới)

struct AppListRow: View {
    @ObservedObject var app: InstalledApp
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primaryText)
                
                Text(app.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondaryText)
            }
            
            Spacer()
            
            if !app.residualFiles.isEmpty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
    }
}
