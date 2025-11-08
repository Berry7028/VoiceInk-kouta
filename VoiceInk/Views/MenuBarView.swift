import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var updaterViewModel: UpdaterViewModel
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var menuRefreshTrigger = false  // Added to force menu updates
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            Menu {
                ForEach(whisperState.usableModels, id: \.id) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultTranscriptionModel(model)
                        }
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if whisperState.currentTranscriptionModel?.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()

                Button("モデルを管理") {
                    menuBarManager.openMainWindowAndNavigate(to: "AIモデル")
                }
            } label: {
                HStack {
                    Text("文字起こしモデル: \(whisperState.currentTranscriptionModel?.displayName ?? "なし")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Divider()

            Toggle("AI機能強化", isOn: $enhancementService.isEnhancementEnabled)
            
            Menu {
                ForEach(enhancementService.allPrompts) { prompt in
                    Button {
                        enhancementService.setActivePrompt(prompt)
                    } label: {
                        HStack {
                            Image(systemName: prompt.icon)
                                .foregroundColor(.accentColor)
                            Text(prompt.title)
                            if enhancementService.selectedPromptId == prompt.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("プロンプト: \(enhancementService.activePrompt?.title ?? "なし")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .disabled(!enhancementService.isEnhancementEnabled)
            
            Menu {
                ForEach(aiService.connectedProviders, id: \.self) { provider in
                    Button {
                        aiService.selectedProvider = provider
                    } label: {
                        HStack {
                            Text(provider.rawValue)
                            if aiService.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if aiService.connectedProviders.isEmpty {
                    Text("プロバイダーが接続されていません")
                        .foregroundColor(.secondary)
                }

                Divider()

                Button("AIプロバイダーを管理") {
                    menuBarManager.openMainWindowAndNavigate(to: "機能強化")
                }
            } label: {
                HStack {
                    Text("AIプロバイダー: \(aiService.selectedProvider.rawValue)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .disabled(!enhancementService.isEnhancementEnabled)
            
            Menu {
                ForEach(aiService.availableModels, id: \.self) { model in
                    Button {
                        aiService.selectModel(model)
                    } label: {
                        HStack {
                            Text(model)
                            if aiService.currentModel == model {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if aiService.availableModels.isEmpty {
                    Text("利用可能なモデルがありません")
                        .foregroundColor(.secondary)
                }

                Divider()

                Button("AIモデルを管理") {
                    menuBarManager.openMainWindowAndNavigate(to: "機能強化")
                }
            } label: {
                HStack {
                    Text("AIモデル: \(aiService.currentModel)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .disabled(!enhancementService.isEnhancementEnabled)
            
            LanguageSelectionView(whisperState: whisperState, displayMode: .menuItem, whisperPrompt: whisperState.whisperPrompt)

            Menu("追加機能") {
                Button {
                    enhancementService.useClipboardContext.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("クリップボードコンテキスト")
                        Spacer()
                        if enhancementService.useClipboardContext {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(!enhancementService.isEnhancementEnabled)

                Button {
                    enhancementService.useScreenCaptureContext.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("コンテキスト認識")
                        Spacer()
                        if enhancementService.useScreenCaptureContext {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(!enhancementService.isEnhancementEnabled)
            }
            .id("additional-menu-\(menuRefreshTrigger)")
            
            Divider()

            Button("最後の文字起こしを再試行") {
                LastTranscriptionService.retryLastTranscription(from: whisperState.modelContext, whisperState: whisperState)
            }

            Button("最後の文字起こしをコピー") {
                LastTranscriptionService.copyLastTranscription(from: whisperState.modelContext)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("履歴") {
                menuBarManager.openMainWindowAndNavigate(to: "履歴")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Button("設定") {
                menuBarManager.openMainWindowAndNavigate(to: "設定")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button(menuBarManager.isMenuBarOnly ? "Dockアイコンを表示" : "Dockアイコンを非表示") {
                menuBarManager.toggleMenuBarOnly()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Toggle("ログイン時に起動", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { oldValue, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }

            Divider()

            Button("アップデートを確認") {
                updaterViewModel.checkForUpdates()
            }
            .disabled(!updaterViewModel.canCheckForUpdates)

            Button("ヘルプとサポート") {
                EmailSupport.openSupportEmail()
            }

            Divider()

            Button("VoiceInkを終了") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
