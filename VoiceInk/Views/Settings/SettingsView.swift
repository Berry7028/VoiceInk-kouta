import SwiftUI
import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @StateObject private var deviceManager = AudioDeviceManager.shared
    @ObservedObject private var mediaController = MediaController.shared
    @ObservedObject private var playbackController = PlaybackController.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("autoUpdateCheck") private var autoUpdateCheck = true
    @AppStorage("enableAnnouncements") private var enableAnnouncements = true
    @State private var showResetOnboardingAlert = false
    @State private var currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder)
    @State private var isCustomCancelEnabled = false

    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(
                    icon: "command.circle",
                    title: "VoiceInkショートカット",
                    subtitle: "VoiceInkを起動する方法を選択"
                ) {
                    VStack(alignment: .leading, spacing: 18) {
                        hotkeyView(
                            title: "ホットキー1",
                            binding: $hotkeyManager.selectedHotkey1,
                            shortcutName: .toggleMiniRecorder
                        )

                        if hotkeyManager.selectedHotkey2 != .none {
                            Divider()
                            hotkeyView(
                                title: "ホットキー2",
                                binding: $hotkeyManager.selectedHotkey2,
                                shortcutName: .toggleMiniRecorder2,
                                isRemovable: true,
                                onRemove: {
                                    withAnimation { hotkeyManager.selectedHotkey2 = .none }
                                }
                            )
                        }

                        if hotkeyManager.selectedHotkey1 != .none && hotkeyManager.selectedHotkey2 == .none {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation { hotkeyManager.selectedHotkey2 = .rightOption }
                                }) {
                                    Label("別のホットキーを追加", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            }
                        }

                        Text("クイックタップでハンズフリー録音を開始します（再度タップで停止）。長押しでプッシュトゥトーク（離すと録音停止）。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsSection(
                    icon: "keyboard.badge.ellipsis",
                    title: "その他のショートカット",
                    subtitle: "VoiceInkの追加ショートカット"
                ) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Paste Last Transcript (Original)
                        HStack(spacing: 12) {
                            Text("最後の文字起こしを貼り付け（元）")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            KeyboardShortcuts.Recorder(for: .pasteLastTranscription)
                                .controlSize(.small)

                            InfoTip(
                                title: "最後の文字起こしを貼り付け（元）",
                                message: "最新の文字起こしを貼り付けるショートカットです。"
                            )

                            Spacer()
                        }

                        // Paste Last Transcript (Enhanced)
                        HStack(spacing: 12) {
                            Text("最後の文字起こしを貼り付け（強化版）")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            KeyboardShortcuts.Recorder(for: .pasteLastEnhancement)
                                .controlSize(.small)

                            InfoTip(
                                title: "最後の文字起こしを貼り付け（強化版）",
                                message: "強化された文字起こしがある場合はそれを貼り付け、なければ元の文字起こしを使用します。"
                            )

                            Spacer()
                        }



                        // Retry Last Transcription
                        HStack(spacing: 12) {
                            Text("最後の文字起こしを再試行")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            KeyboardShortcuts.Recorder(for: .retryLastTranscription)
                                .controlSize(.small)

                            InfoTip(
                                title: "最後の文字起こしを再試行",
                                message: "現在のモデルを使用して最後に録音した音声を再文字起こしし、結果をコピーします。"
                            )

                            Spacer()
                        }

                        Divider()

                        
                        
                        // Custom Cancel Shortcut
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Toggle(isOn: $isCustomCancelEnabled.animation()) {
                                    Text("カスタムキャンセルショートカット")
                                }
                                .toggleStyle(.switch)
                                .onChange(of: isCustomCancelEnabled) { _, newValue in
                                    if !newValue {
                                        KeyboardShortcuts.setShortcut(nil, for: .cancelRecorder)
                                    }
                                }

                                InfoTip(
                                    title: "録音を閉じる",
                                    message: "現在の録音セッションをキャンセルするショートカットです。デフォルト: Escapeを2回タップ。"
                                )
                            }

                            if isCustomCancelEnabled {
                                HStack(spacing: 12) {
                                    Text("キャンセルショートカット")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)

                                    KeyboardShortcuts.Recorder(for: .cancelRecorder)
                                        .controlSize(.small)

                                    Spacer()
                                }
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Divider()

                        // Middle-Click Toggle
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Toggle("ミドルクリックトグルを有効化", isOn: $hotkeyManager.isMiddleClickToggleEnabled.animation())
                                    .toggleStyle(.switch)

                                InfoTip(
                                    title: "ミドルクリックトグル",
                                    message: "マウスの中ボタンでVoiceInkの録音を切り替えます。"
                                )
                            }

                            if hotkeyManager.isMiddleClickToggleEnabled {
                                HStack(spacing: 8) {
                                    Text("起動遅延")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)

                                    TextField("", value: $hotkeyManager.middleClickActivationDelay, formatter: {
                                        let formatter = NumberFormatter()
                                        formatter.numberStyle = .none
                                        formatter.minimum = 0
                                        return formatter
                                    }())
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6))
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(5)
                                    .frame(width: 70)

                                    Text("ms")
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }

                SettingsSection(
                    icon: "speaker.wave.2.bubble.left.fill",
                    title: "録音フィードバック",
                    subtitle: "アプリとシステムのフィードバックをカスタマイズ"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: .init(
                            get: { SoundManager.shared.isEnabled },
                            set: { SoundManager.shared.isEnabled = $0 }
                        )) {
                            Text("サウンドフィードバック")
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $mediaController.isSystemMuteEnabled) {
                            Text("録音中はシステム音声をミュート")
                        }
                        .toggleStyle(.switch)
                        .help("録音開始時にシステム音声を自動的にミュートし、録音停止時に復元します")

                        Toggle(isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "preserveTranscriptInClipboard") },
                            set: { UserDefaults.standard.set($0, forKey: "preserveTranscriptInClipboard") }
                        )) {
                            Text("クリップボードに文字起こしを保持")
                        }
                        .toggleStyle(.switch)
                        .help("元のクリップボードの内容を復元せず、文字起こしテキストをクリップボードに保持します")

                    }
                }

                PowerModeSettingsSection()

                ExperimentalFeaturesSection()

                SettingsSection(
                    icon: "rectangle.on.rectangle",
                    title: "レコーダースタイル",
                    subtitle: "録音画面の表示方法を選択"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("画面上に録音画面をどのように表示するかを選択してください。")
                            .settingsDescription()

                        Picker("レコーダースタイル", selection: $whisperState.recorderType) {
                            Text("ノッチレコーダー").tag("notch")
                            Text("ミニレコーダー").tag("mini")
                        }
                        .pickerStyle(.radioGroup)
                        .padding(.vertical, 4)
                    }
                }

                SettingsSection(
                    icon: "doc.on.clipboard",
                    title: "貼り付け方法",
                    subtitle: "テキストの貼り付け方法を選択"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("テキストの貼り付けに使用する方法を選択してください。標準以外のキーボードレイアウトを使用している場合はAppleScriptを使用してください。")
                            .settingsDescription()

                        Toggle("AppleScript貼り付け方法を使用", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "UseAppleScriptPaste") },
                            set: { UserDefaults.standard.set($0, forKey: "UseAppleScriptPaste") }
                        ))
                        .toggleStyle(.switch)
                    }
                }

                SettingsSection(
                    icon: "gear",
                    title: "一般",
                    subtitle: "外観、起動、アップデート"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Dockアイコンを非表示（メニューバーのみ）", isOn: $menuBarManager.isMenuBarOnly)
                            .toggleStyle(.switch)

                        LaunchAtLogin.Toggle()
                            .toggleStyle(.switch)

                        Toggle("自動アップデート確認を有効化", isOn: $autoUpdateCheck)
                            .toggleStyle(.switch)
                            .onChange(of: autoUpdateCheck) { _, newValue in
                                updaterViewModel.toggleAutoUpdates(newValue)
                            }

                        Toggle("アプリのお知らせを表示", isOn: $enableAnnouncements)
                            .toggleStyle(.switch)
                            .onChange(of: enableAnnouncements) { _, newValue in
                                if newValue {
                                    AnnouncementsService.shared.start()
                                } else {
                                    AnnouncementsService.shared.stop()
                                }
                            }

                        Button("今すぐアップデートを確認") {
                            updaterViewModel.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(!updaterViewModel.canCheckForUpdates)

                        Divider()

                        Button("オンボーディングをリセット") {
                            showResetOnboardingAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                
                SettingsSection(
                    icon: "lock.shield",
                    title: "データとプライバシー",
                    subtitle: "文字起こし履歴とストレージを管理"
                ) {
                    AudioCleanupSettingsView()
                }

                SettingsSection(
                    icon: "arrow.up.arrow.down.circle",
                    title: "データ管理",
                    subtitle: "設定のインポート・エクスポート"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("カスタムプロンプト、パワーモード、単語置換、キーボードショートカット、アプリの設定をバックアップファイルにエクスポートします。APIキーはエクスポートに含まれません。")
                            .settingsDescription()

                        HStack(spacing: 12) {
                            Button {
                                ImportExportService.shared.importSettings(
                                    enhancementService: enhancementService,
                                    whisperPrompt: whisperState.whisperPrompt,
                                    hotkeyManager: hotkeyManager,
                                    menuBarManager: menuBarManager,
                                    mediaController: MediaController.shared,
                                    playbackController: PlaybackController.shared,
                                    soundManager: SoundManager.shared,
                                    whisperState: whisperState
                                )
                            } label: {
                                Label("設定をインポート...", systemImage: "arrow.down.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)

                            Button {
                                ImportExportService.shared.exportSettings(
                                    enhancementService: enhancementService,
                                    whisperPrompt: whisperState.whisperPrompt,
                                    hotkeyManager: hotkeyManager,
                                    menuBarManager: menuBarManager,
                                    mediaController: MediaController.shared,
                                    playbackController: PlaybackController.shared,
                                    soundManager: SoundManager.shared,
                                    whisperState: whisperState
                                )
                            } label: {
                                Label("設定をエクスポート...", systemImage: "arrow.up.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isCustomCancelEnabled = KeyboardShortcuts.getShortcut(for: .cancelRecorder) != nil
        }
        .alert("オンボーディングをリセット", isPresented: $showResetOnboardingAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット", role: .destructive) {
                // Defer state change to avoid layout issues while alert dismisses
                DispatchQueue.main.async {
                    hasCompletedOnboarding = false
                }
            }
        } message: {
            Text("オンボーディングをリセットしてもよろしいですか？次回アプリを起動したときに、再度紹介画面が表示されます。")
        }
    }
    
    @ViewBuilder
    private func hotkeyView(
        title: String,
        binding: Binding<HotkeyManager.HotkeyOption>,
        shortcutName: KeyboardShortcuts.Name,
        isRemovable: Bool = false,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Menu {
                ForEach(HotkeyManager.HotkeyOption.allCases, id: \.self) { option in
                    Button(action: {
                        binding.wrappedValue = option
                    }) {
                        HStack {
                            Text(option.displayName)
                            if binding.wrappedValue == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(binding.wrappedValue.displayName)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            
            if binding.wrappedValue == .custom {
                KeyboardShortcuts.Recorder(for: shortcutName)
                    .controlSize(.small)
            }
            
            Spacer()
            
            if isRemovable {
                Button(action: {
                    onRemove?()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content
    var showWarning: Bool = false
    
    init(icon: String, title: String, subtitle: String, showWarning: Bool = false, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showWarning = showWarning
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(showWarning ? .red : .accentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(showWarning ? .red : .secondary)
                }
                
                if showWarning {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .help("Permission required for VoiceInk to function properly")
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: showWarning, useAccentGradientWhenSelected: true))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showWarning ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// Add this extension for consistent description text styling
extension Text {
    func settingsDescription() -> some View {
        self
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
