import SwiftUI
import AppKit

///Bộ điều khiển cửa sổ nổi cảnh báo bộ nhớ riêng biệt

/// Tự động bật lên từ biểu tượng thanh menu khi phát hiện mức sử dụng bộ nhớ cao

class MemoryAlertWindowController: NSObject, ObservableObject {
    private var window: NSWindow?
    private var systemMonitor: SystemMonitorService
    private var statusBarButton: NSStatusBarButton?
    
    init(systemMonitor: SystemMonitorService, statusBarButton: NSStatusBarButton?) {
        self.systemMonitor = systemMonitor
        self.statusBarButton = statusBarButton
        super.init()
        setupObserver()
    }
    
    private func setupObserver() {
        // Theo dõi các thay đổi trạng thái cảnh báo bộ nhớ
        // Chỉ nổi cửa sổ riêng khi popup menu bar đang đóng để tránh hai cảnh báo hiện cùng lúc
        
        systemMonitor.$showHighMemoryAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldShow in
                guard let self else { return }
                if shouldShow && !MenuBarManager.shared.isOpen {
                    self.showAlert()
                } else if !shouldShow {
                    self.hideAlert()
                }
            }
            .store(in: &cancellables)
        
        MenuBarManager.shared.$isOpen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOpen in
                guard let self else { return }
                if isOpen {
                    self.hideAlert()
                } else if self.systemMonitor.showHighMemoryAlert {
                    self.showAlert()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    ///hiển thị cửa sổ cảnh báo bộ nhớ

    private func showAlert() {
        // Nếu cửa sổ đã tồn tại, hãy đặt lại vị trí và hiển thị nó

        if let existingWindow = window {
            positionWindow(existingWindow)
            existingWindow.orderFrontRegardless()
            return
        }
        
        // Lấy lại tham chiếu nút trước mỗi màn hình (đảm bảo nó được cập nhật)

        statusBarButton = MenuBarManager.shared.statusItem?.button
        print("[MemoryAlert] Lấy nút menu bar: \(statusBarButton != nil ? "thành công" : "thất bại")")
        
        // Tạo chế độ xem cảnh báo

        let alertView = MemoryAlertFloatingView(
            systemMonitor: systemMonitor,
            onClose: { [weak self] in
                self?.hideAlert()
            },
            onOpenApp: { [weak self] in
                self?.hideAlert()
                MenuBarManager.shared.openMainApp()
            }
        )
        
        let hostingController = NSHostingController(rootView: alertView)
        
        // Tạo cửa sổ nổi (thay đổi kích thước cho gọn hơn)

        let alertWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        alertWindow.contentViewController = hostingController
        alertWindow.backgroundColor = .clear
        alertWindow.isOpaque = false
        alertWindow.hasShadow = true
        alertWindow.level = .floating  // ở trên các cửa sổ khác
        alertWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        alertWindow.isMovableByWindowBackground = false
        
        // Quan trọng: Đặt làm cửa sổ không hoạt động để tránh cảnh báo canBecomeKeyWindow

        alertWindow.hidesOnDeactivate = false
        alertWindow.ignoresMouseEvents = false
        
        // Vị trí bên dưới biểu tượng thanh menu

        positionWindow(alertWindow)
        
        // Hiển thị hoạt ảnh (không trở thành cửa sổ chính, tránh cảnh báo)

        alertWindow.alphaValue = 0
        alertWindow.orderFrontRegardless()  // Sử dụng orderFrontRegardless thay vì makeKeyAndOrderFront
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            alertWindow.animator().alphaValue = 1
        }
        
        self.window = alertWindow
    }
    
    ///ẩn cửa sổ cảnh báo

    private func hideAlert() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.window = nil
        })
    }
    
    /// Tính vị trí cửa sổ (ngay bên dưới biểu tượng thanh menu)

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let fullScreenFrame = screen.frame  // Toàn màn hình bao gồm thanh menu
        
        // Sử dụng kích thước cửa sổ cố định (phù hợp với quá trình tạo) để tránh sự cố size=0 do độ trễ bố cục SwiftUI gây ra

        let windowSize = CGSize(width: 320, height: 280)
        let menuBarHeight: CGFloat = 24  // chiều cao thanh menu macOS
        
        print("[MemoryAlert] Thông tin màn hình - visible: \(screenFrame), full: \(fullScreenFrame)")
        print("[MemoryAlert] Kích thước cửa sổ - frame.size: \(window.frame.size), fixed: \(windowSize)")
        
        // Cố gắng lấy nút thanh menu

        if let button = statusBarButton ?? MenuBarManager.shared.statusItem?.button {
            var buttonScreenX: CGFloat?
            
            // Cách 1: Chuyển đổi tọa độ thông qua nút.window

            if let buttonWindow = button.window {
                let buttonFrameInWindow = button.frame
                let buttonFrameScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
                print("[MemoryAlert] Cách 1 dữ liệu gốc: window frame=\(buttonFrameInWindow), screen frame=\(buttonFrameScreen)")
                
                // Kiểm tra xem tọa độ có hợp lý không (biểu tượng thanh menu phải ở nửa trên của màn hình)

                if buttonFrameScreen.minY > screenFrame.midY || buttonFrameScreen.minX < 10 {
                    print("[MemoryAlert] ⚠️ Cách 1 cho tọa độ bất thường, x=\(buttonFrameScreen.minX), y=\(buttonFrameScreen.minY)")
                    // Tọa độ không hợp lý, hãy thử các phương pháp khác

                } else {
                    buttonScreenX = buttonFrameScreen.midX
                    print("[MemoryAlert] ✅ Cách 1 thành công: buttonScreenX=\(buttonScreenX!)")
                }
            }
            
            // Cách 2: Nếu cách 1 không thành công thì sử dụng ước tính vị trí chuột (khi người dùng nhấn vào biểu tượng)

            if buttonScreenX == nil {
                let mouseLocation = NSEvent.mouseLocation
                print("[MemoryAlert] Cách 2: thử dùng vị trí chuột=\(mouseLocation)")
                
                // Nếu chuột của bạn ở khu vực thanh menu ở đầu màn hình, có thể bạn vừa nhấp vào một biểu tượng.

                if mouseLocation.y > fullScreenFrame.maxY - menuBarHeight - 5 {
                    buttonScreenX = mouseLocation.x
                    print("[MemoryAlert] ✅ Cách 2 thành công: dùng vị trí chuột x=\(buttonScreenX!)")
                }
            }
            
            // Cách 3: Sử dụng thông tin độ dài của StatusItem để tính vị trí

            if buttonScreenX == nil {
                // Các biểu tượng trên thanh menu thường được sắp xếp từ phải sang trái

                // Chúng tôi giả sử rằng biểu tượng nằm ở khu vực góc trên bên phải

                if MenuBarManager.shared.statusItem != nil {
                    // Bắt đầu ước lượng từ cạnh phải (giả sử biểu tượng thứ nhất hoặc thứ hai)

                    let estimatedX = fullScreenFrame.maxX - 50  // Lề phải -50px như ước tính
                    buttonScreenX = estimatedX
                    print("[MemoryAlert] Cách 3: dùng vị trí ước lượng x=\(buttonScreenX!)")
                }
            }
            
            // Nếu thu được tọa độ X thì tính vị trí cửa sổ

            if let buttonX = buttonScreenX {
                let xPos = buttonX - (windowSize.width / 2)
                
                // Tọa độ Y: lệch xuống từ trên cùng của vùng nhìn thấy

                // screenFrame.maxY là phần trên cùng của vùng hiển thị (bên dưới thanh menu)

                let yPos = screenFrame.maxY - windowSize.height - 8
                
                // Đảm bảo bạn luôn ở trong ranh giới của màn hình

                let finalX = max(screenFrame.minX + 10, min(xPos, screenFrame.maxX - windowSize.width - 10))
                let finalY = max(screenFrame.minY + 10, min(yPos, screenFrame.maxY - windowSize.height - 8))
                
                // Đặt kích thước và vị trí cửa sổ cùng lúc để đảm bảo kích thước cửa sổ chính xác

                window.setFrame(NSRect(x: finalX, y: finalY, width: windowSize.width, height: windowSize.height), display: true)
                print("[MemoryAlert] ✅ Định vị cửa sổ thành công: x=\(finalX), y=\(finalY), buttonX=\(buttonX)")
                print("[MemoryAlert] Chi tiết tọa độ: screenFrame.maxY=\(screenFrame.maxY), windowHeight=\(windowSize.height), actualHeight=\(window.frame.height)")
                return
            }
        }
        
        // Cách 4: Phương án dự phòng tối ưu - sử dụng góc trên bên phải màn hình

        print("[MemoryAlert] ⚠️ Dùng phương án dự phòng cuối cùng")
        let xPos = screenFrame.maxX - windowSize.width - 20
        // Sử dụng phần trên cùng của vùng hiển thị, đảm bảo nó ở bên dưới thanh menu

        let yPos = screenFrame.maxY - windowSize.height - 8
        
        // Đặt đồng thời kích thước và vị trí cửa sổ

        window.setFrame(NSRect(x: xPos, y: yPos, width: windowSize.width, height: windowSize.height), display: true)
        print("[MemoryAlert] Dùng vị trí dự phòng: x=\(xPos), y=\(yPos), screenFrame.maxY=\(screenFrame.maxY), windowHeight=\(windowSize.height)")
    }
}

// MARK: - Chế độ xem cảnh báo nổi (tham khảo thiết kế CleanMyMac)

struct MemoryAlertFloatingView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    let onClose: () -> Void
    let onOpenApp: () -> Void

    /// Nội dung cảnh báo khớp điều kiện thật: % RAM toàn hệ thống vượt ngưỡng
    private var alertMessage: String {
        let percent = Int(systemMonitor.memoryUsage * 100)
        let threshold = Int(systemMonitor.memoryAlertThresholdPercent)
        if let app = systemMonitor.highMemoryApp {
            return String(format: L("Mac đang dùng %d%% RAM, vượt ngưỡng %d%%. Ứng dụng chiếm nhiều nhất là %@ với khoảng %.1f GB tổng bộ nhớ."), percent, threshold, app.name, app.usage)
        }
        return String(format: L("Mac đang dùng %d%% RAM, vượt ngưỡng %d%%. Hãy giải phóng bộ nhớ để máy chạy mượt hơn."), percent, threshold)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // tam giác chỉ báo (trỏ vào biểu tượng thanh menu)

            Triangle()
                .fill(Color(hex: "F2F2F7"))
                .frame(width: 20, height: 10)
                .padding(.bottom, -1)
            
            // khu vực nội dung chính

            VStack(alignment: .leading, spacing: 16) {
                // tiêu đề

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Bộ nhớ hệ thống đang cao"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.85))

                    Text(alertMessage)
                        .font(.system(size: 13))
                        .foregroundColor(Color.black.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                
                // Nút khởi chạy ứng dụng

                Button(action: onOpenApp) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        Text(L("Mở ApexTune"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.black)
                }
                .buttonStyle(.plain)
                
                // Thẻ hiển thị bộ nhớ

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "FFFFFF"))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 12) {
                        // Biểu tượng RAM

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "00C7BE"))
                                .frame(width: 40, height: 40)
                            
                            Text("RAM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: -5)
                            
                            // Mock "pins" or chip look
                            VStack(spacing: 2) {
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 2, height: 6)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        
                        // Progress
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("RAM + Swap")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.85))
                                Spacer()
                                let isNearFull = systemMonitor.memoryUsage > 0.9
                                Text(isNearFull ? L("Gần đầy") : L("Bình thường"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isNearFull ? Color(hex: "FF6B6B") : Color(hex: "34C759"))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "FF9F6B"), Color(hex: "FF6B6B")]), startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geometry.size.width * CGFloat(systemMonitor.memoryUsage), height: 8)
                                        .animation(.easeInOut, value: systemMonitor.memoryUsage)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 72)
                .background(Color(hex: "F2F2F7"))
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                // Nút thao tác phía dưới

                HStack {
                    // bỏ qua menu

                    Menu {
                        Button(L("Nhắc lại sau 10 phút")) {
                            systemMonitor.snoozeAlert(minutes: 10)
                            onClose()
                        }
                        Button(L("Nhắc lại sau 1 giờ")) {
                            systemMonitor.snoozeAlert(minutes: 60)
                            onClose()
                        }
                        Divider()
                        Button(L("Không nhắc lại")) {
                            systemMonitor.ignoreAppPermanently()
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(L("Bỏ qua"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                    
                    // nút nhả

                    Button(action: {
                        // Chỉ đóng cảnh báo khi người dùng xác nhận buộc thoát
                        if systemMonitor.terminateHighMemoryApp() {
                            onClose()
                        }
                    }) {
                        Text(L("Giải phóng"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color(hex: "F2F2F7"))
            .cornerRadius(16)
        }
        .frame(width: 320)
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

import Combine
