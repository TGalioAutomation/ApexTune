import SwiftUI

struct SettingsView: View {
    @ObservedObject var loc = LocalizationManager.shared
    @StateObject private var updateService = UpdateCheckerService.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    // Environment to close the sheet/window
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("Cài đặt"))
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.2))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // App Info Section
                    VStack(alignment: .center, spacing: 12) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 80, height: 80)

                        Text("ApexTune")
                            .font(.headline)

                        Text(String(format: L("Phiên bản %@"), updateService.currentVersion))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                    Divider().opacity(0.5)

                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Chung"))
                            .font(.headline)

                        Toggle(isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Khởi động cùng macOS"))
                                Text(L("Tự động chạy ApexTune và giám sát menu bar khi đăng nhập."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                        if let error = launchAtLogin.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Divider().opacity(0.5)

                    // Language Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Ngôn ngữ"))
                            .font(.headline)

                        Picker(L("Ngôn ngữ"), selection: Binding(
                            get: { loc.currentLanguage.code },
                            set: { loc.setLanguage($0) }
                        )) {
                            ForEach(loc.availableLanguages) { language in
                                Text("\(language.flag)  \(language.name)").tag(language.code)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()

                        Text(L("Chọn ngôn ngữ hiển thị cho toàn bộ ứng dụng."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider().opacity(0.5)

                    // Update Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L("Cập nhật phần mềm"))
                            .font(.headline)

                        // Auto Check Toggle
                        Toggle(isOn: $autoCheckUpdates) {
                            Text(L("Tự động kiểm tra cập nhật"))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                        // Check Button / Status
                        if updateService.isChecking {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text(L("Đang kiểm tra cập nhật..."))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if updateService.hasUpdate {
                                // New Version Available
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.yellow)
                                        Text(String(format: L("Đã có phiên bản mới: %@"), updateService.latestVersion))
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }

                                    if !updateService.releaseNotes.isEmpty {
                                        Text(updateService.releaseNotes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }

                                    Button(action: {
                                        if let url = updateService.downloadURL {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text(L("Cập nhật ngay"))
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )

                            } else {
                                // No Update / Checked
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(L("ApexTune đã được cập nhật"))
                                            .foregroundColor(.secondary)
                                        Text(L("Kiểm tra lần cuối: Vừa rồi"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        Task {
                                            await updateService.checkForUpdates()
                                        }
                                    }) {
                                        Text(L("Kiểm tra cập nhật"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if autoCheckUpdates && !updateService.hasUpdate && !updateService.isChecking {
                Task {
                    await updateService.checkForUpdates()
                }
            }
        }
    }
}
