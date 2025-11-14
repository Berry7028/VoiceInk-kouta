# CLAUDE.md - AI Assistant Guide for VoiceInk

This document provides comprehensive guidance for AI assistants working on the VoiceInk codebase. It covers the project structure, development workflows, conventions, and important context to help you work effectively.

## Table of Contents

- [Project Overview](#project-overview)
- [Codebase Structure](#codebase-structure)
- [Architecture & Design Patterns](#architecture--design-patterns)
- [Key Components](#key-components)
- [Development Workflows](#development-workflows)
- [Coding Conventions](#coding-conventions)
- [Common Tasks](#common-tasks)
- [Testing Strategy](#testing-strategy)
- [Build & Deployment](#build--deployment)
- [Important Guidelines](#important-guidelines)

---

## Project Overview

**VoiceInk** is a native macOS application (macOS 14.0+) that provides high-accuracy voice-to-text transcription using local AI models. The app is built with Swift, SwiftUI, and integrates multiple transcription engines.

### Key Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + Combine
- **Data Persistence**: SwiftData (for transcription history) + UserDefaults (for settings)
- **Audio Processing**: AVFoundation
- **Transcription Engines**:
  - Local: whisper.cpp (primary), FluidAudio Parakeet
  - Cloud: OpenAI, Groq, Deepgram, Mistral, Gemini, ElevenLabs, Soniox
  - Native: macOS Speech Recognition Framework
- **AI Enhancement**: Multi-provider support (OpenAI, Anthropic, Gemini, etc.)
- **Build System**: Xcode + Makefile + GitHub Actions

### Project Statistics
- **Lines of Code**: ~13,600 lines of Swift
- **Files**: 70+ Swift files
- **Dependencies**: 9 Swift packages + 1 external framework (whisper.cpp)
- **License**: GNU GPL v3.0

---

## Codebase Structure

### Directory Organization

```
VoiceInk-kouta/
├── VoiceInk/                          # Main application source
│   ├── AppIntents/                    # Siri Shortcuts integration
│   │   ├── AppShortcuts.swift
│   │   ├── DismissMiniRecorderIntent.swift
│   │   └── ToggleMiniRecorderIntent.swift
│   ├── Assets.xcassets/               # Images, icons, colors
│   ├── Models/                        # Data models and entities
│   │   ├── Transcription.swift        # @Model - SwiftData entity for history
│   │   ├── TranscriptionModel.swift   # Protocol for transcription models
│   │   ├── CustomPrompt.swift         # User-defined AI prompts
│   │   ├── PredefinedPrompts.swift    # Built-in prompt templates
│   │   ├── PredefinedModels.swift     # Model definitions
│   │   ├── AIPrompts.swift            # AI system messages
│   │   └── PromptTemplates.swift      # Prompt template structures
│   ├── Notifications/                 # Notification system
│   ├── PowerMode/                     # Context-aware mode system
│   │   ├── PowerModeSessionManager.swift
│   │   ├── BrowserURLService.swift
│   │   └── EmojiPickerView.swift
│   ├── Resources/                     # Non-code assets
│   │   ├── Sounds/                   # Audio feedback files
│   │   ├── models/                   # ML model files
│   │   └── *.scpt                    # AppleScript utilities
│   ├── Services/                      # Business logic layer
│   │   ├── AIEnhancement/            # AI text processing
│   │   │   ├── AIEnhancementService.swift
│   │   │   ├── AIService.swift
│   │   │   └── *.swift               # Provider implementations
│   │   ├── CloudTranscription/       # Cloud provider integrations
│   │   │   ├── CloudTranscriptionService.swift
│   │   │   ├── GroqTranscriptionService.swift
│   │   │   ├── OpenAITranscriptionService.swift
│   │   │   ├── DeepgramTranscriptionService.swift
│   │   │   ├── MistralTranscriptionService.swift
│   │   │   ├── GeminiTranscriptionService.swift
│   │   │   ├── ElevenLabsTranscriptionService.swift
│   │   │   ├── SonioxTranscriptionService.swift
│   │   │   └── OpenAICompatibleTranscriptionService.swift
│   │   ├── TranscriptionService.swift # Protocol definition
│   │   ├── LocalTranscriptionService.swift
│   │   ├── NativeAppleTranscriptionService.swift
│   │   ├── ParakeetTranscriptionService.swift
│   │   ├── AudioDeviceManager.swift
│   │   ├── ClipboardManager.swift
│   │   ├── ScreenCaptureService.swift
│   │   ├── SelectedTextService.swift
│   │   ├── WordReplacementService.swift
│   │   ├── VoiceActivityDetector.swift
│   │   ├── TranscriptionFallbackManager.swift
│   │   └── TranscriptionAutoCleanupService.swift
│   ├── Views/                         # SwiftUI UI components
│   │   ├── AI Models/                # Model selection UI
│   │   ├── Common/                   # Reusable components
│   │   ├── Components/               # Small UI building blocks
│   │   ├── Dictionary/               # Custom word replacement UI
│   │   ├── Metrics/                  # Analytics dashboard
│   │   ├── Onboarding/               # First-launch experience
│   │   ├── Recorder/                 # Recording UI
│   │   │   ├── MiniRecorderView.swift
│   │   │   └── NotchRecorderView.swift
│   │   ├── Settings/                 # Preferences UI
│   │   ├── ContentView.swift         # Main navigation view
│   │   ├── AudioTranscribeView.swift # File upload view
│   │   └── TranscriptionHistoryView.swift
│   ├── Whisper/                       # Whisper.cpp integration
│   │   ├── WhisperState.swift        # Main orchestrator (18KB, critical)
│   │   ├── WhisperState+*.swift      # Extensions for specific functionality
│   │   └── Recorder.swift            # Audio recording (AVAudioRecorder)
│   ├── VoiceInk.swift                 # @main app entry point
│   ├── AppDelegate.swift              # App lifecycle management
│   ├── WindowManager.swift            # Window state management
│   ├── MenuBarManager.swift           # Menu bar mode control
│   ├── HotkeyManager.swift            # Global keyboard shortcuts (15KB)
│   ├── MediaController.swift          # Media playback control
│   ├── PlaybackController.swift       # Audio playback
│   ├── ClipboardManager.swift         # Clipboard operations
│   ├── Info.plist                     # App configuration
│   └── VoiceInk.entitlements         # Security permissions
├── VoiceInkTests/                     # Unit tests (minimal coverage)
├── VoiceInkUITests/                   # UI tests (minimal coverage)
├── VoiceInk.xcodeproj/               # Xcode project files
├── .github/workflows/                # CI/CD automation
├── Makefile                           # Build automation
├── BUILDING.md                        # Build instructions
├── CONTRIBUTING.md                    # Contribution guidelines
└── README.md                          # Project documentation
```

---

## Architecture & Design Patterns

### Core Architecture: MVVM + Service Layer

```
┌─────────────────┐
│  SwiftUI Views  │ ← User Interface Layer
└────────┬────────┘
         │ @StateObject, @EnvironmentObject
┌────────▼────────┐
│ State/ViewModel │ ← State Management (ObservableObject)
│  (@Published)   │   - WhisperState
└────────┬────────┘   - AIEnhancementService
         │             - HotkeyManager
┌────────▼────────┐   - MenuBarManager
│    Services     │ ← Business Logic
│   (Protocol)    │   - TranscriptionService
└────────┬────────┘   - AIService
         │             - AudioDeviceManager
┌────────▼────────┐
│ External APIs   │ ← External Integrations
│ & Frameworks    │   - whisper.cpp, AVFoundation
└─────────────────┘   - Cloud APIs, macOS APIs
```

### Key Design Patterns

#### 1. **Protocol-Oriented Design**
Services are defined by protocols for flexibility and testability:

```swift
protocol TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String
}

// Multiple implementations:
// - LocalTranscriptionService (whisper.cpp)
// - CloudTranscriptionService (routes to providers)
// - NativeAppleTranscriptionService (macOS SpeechRecognition)
// - ParakeetTranscriptionService (FluidAudio)
```

#### 2. **Strategy Pattern**
Used for cloud provider selection and AI enhancement:

```swift
CloudTranscriptionService (dispatcher)
├── GroqTranscriptionService
├── OpenAITranscriptionService
├── DeepgramTranscriptionService
└── ... (8 more providers)
```

#### 3. **Singleton Pattern**
For system-wide services that should have one instance:

```swift
class AudioDeviceManager {
    static let shared = AudioDeviceManager()
    private init() { }
}

// Also used by: Recorder, WindowManager, PowerModeManager, EmojiManager
```

#### 4. **State Machine**
Recording workflow uses strict state transitions:

```swift
enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case enhancing
    case busy
}
// Managed in WhisperState with controlled transitions
```

#### 5. **Observer Pattern**
Notification-driven communication between components:

```swift
extension Notification.Name {
    static let AppSettingsDidChange = Notification.Name("appSettingsDidChange")
    static let toggleMiniRecorder = Notification.Name("toggleMiniRecorder")
    static let didChangeModel = Notification.Name("didChangeModel")
    // ... 10+ custom notifications
}
```

#### 6. **Async/Await Concurrency**
Modern Swift concurrency for async operations:

```swift
@MainActor
class WhisperState: ObservableObject {
    @Published var recordingState: RecordingState = .idle

    func transcribe() async throws {
        recordingState = .transcribing
        let text = try await transcriptionService.transcribe(...)
        recordingState = .idle
    }
}
```

---

## Key Components

### 1. WhisperState (Central Orchestrator)

**Location**: `VoiceInk/Whisper/WhisperState.swift` (18KB, ~450 lines)

**Role**: Main state manager that orchestrates the entire transcription workflow.

**Key Responsibilities**:
- Recording state management
- Model selection and loading
- Transcription service coordination
- AI enhancement integration
- Post-processing pipeline
- History persistence

**Extensions**:
- `WhisperState+LocalModelManager.swift` - Model loading/unloading
- `WhisperState+ModelManagement.swift` - Model switching
- `WhisperState+ModelQueries.swift` - Model queries
- `WhisperState+Parakeet.swift` - Parakeet-specific logic
- `WhisperState+UI.swift` - UI coordination

**Critical Methods**:
- `startRecording()` - Initiates recording
- `stopRecording()` - Stops recording and triggers transcription
- `transcribe()` - Main transcription pipeline
- `enhanceText()` - AI enhancement workflow
- `loadModel()` - Loads selected transcription model

### 2. HotkeyManager (Keyboard Shortcuts)

**Location**: `VoiceInk/HotkeyManager.swift` (15KB)

**Role**: Manages global keyboard shortcuts for triggering recording.

**Features**:
- Multiple hotkey support (up to 3 concurrent)
- Push-to-talk functionality
- Modifier key detection
- Debouncing and cooldown logic
- Integration with KeyboardShortcuts package

### 3. TranscriptionService Hierarchy

**Protocol**: `Services/TranscriptionService.swift`

**Implementations**:

| Service | Engine | Use Case |
|---------|--------|----------|
| `LocalTranscriptionService` | whisper.cpp | Default, privacy-focused |
| `ParakeetTranscriptionService` | FluidAudio Parakeet | Alternative local model |
| `NativeAppleTranscriptionService` | macOS SpeechRecognition | Built-in macOS |
| `CloudTranscriptionService` | Multiple providers | Internet-based, high accuracy |

**Cloud Providers** (10 implementations in `Services/CloudTranscription/`):
- OpenAI Whisper API
- Groq
- Deepgram
- Mistral
- Gemini
- ElevenLabs
- Soniox
- Custom OpenAI-compatible endpoints

### 4. AIEnhancementService

**Location**: `Services/AIEnhancement/AIEnhancementService.swift`

**Role**: Enhances transcribed text using AI models.

**Features**:
- Context gathering (clipboard, screen capture)
- Custom prompt application
- Multi-provider support (OpenAI, Anthropic, Gemini, etc.)
- Streaming response handling
- Output filtering

**Workflow**:
```
Transcription → Context Gathering → Prompt Building → AI API Call → Filter → Enhanced Text
```

### 5. PowerMode System

**Location**: `PowerMode/PowerModeSessionManager.swift`

**Role**: Context-aware configuration that adapts based on active application and browser URL.

**Features**:
- Active window detection
- Browser URL extraction (via AppleScript)
- Per-app/URL configuration profiles
- Automatic model and prompt switching

**Use Case**: Different transcription settings for different contexts (e.g., coding vs. writing vs. messaging).

### 6. Recorder

**Location**: `Whisper/Recorder.swift` (8KB)

**Role**: Audio recording using AVFoundation.

**Features**:
- AVAudioRecorder wrapper
- Audio device management
- Real-time metering
- Voice activity detection support
- 16kHz PCM format (optimized for Whisper)

---

## Development Workflows

### Recording & Transcription Workflow

```
1. User triggers recording (hotkey/button)
   ↓
2. HotkeyManager → NotificationCenter → toggleMiniRecorder
   ↓
3. WhisperState → shows MiniRecorderView
   ↓
4. Recorder.startRecording()
   - Validate audio device
   - Setup AVAudioRecorder (16kHz PCM)
   - Start metering task
   ↓
5. Recording phase
   - Audio frames captured
   - Real-time visualization
   - Optional: Voice Activity Detection
   ↓
6. User stops recording
   ↓
7. Recorder.stopRecording() → WhisperState.transcribe()
   ↓
8. TranscriptionService selection based on model type
   - Local → LocalTranscriptionService (whisper.cpp)
   - Cloud → CloudTranscriptionService → specific provider
   - Native → NativeAppleTranscriptionService
   - Parakeet → ParakeetTranscriptionService
   ↓
9. Transcription returned (raw text)
   ↓
10. Post-processing pipeline:
    - TranscriptionOutputFilter (cleanup)
    - WordReplacementService (custom dictionary)
    - TranscriptionFallbackManager (retry on failure)
   ↓
11. Optional: AI Enhancement
    - AIEnhancementService.enhance()
    - Context gathering (clipboard, screen)
    - Prompt application
    - AI API call
    - AIEnhancementOutputFilter
   ↓
12. Save to SwiftData (Transcription model)
   ↓
13. Paste to active app (if enabled)
   ↓
14. Show notification (if enabled)
```

### PowerMode Workflow

```
1. User switches to different app
   ↓
2. ActiveWindowService detects window change
   ↓
3. PowerModeSessionManager evaluates:
   - App bundle identifier (e.g., com.apple.Safari)
   - Browser URL (if applicable)
   ↓
4. Match against saved PowerMode configurations
   ↓
5. If match found:
   - Apply custom transcription model
   - Apply custom AI enhancement prompt
   - Enable/disable screen capture
   - Post notification
   ↓
6. If no match: Use default settings
```

### AI Enhancement Workflow

```
1. Transcription complete
   ↓
2. Check: isEnhancementEnabled?
   - No → Done
   - Yes → Continue
   ↓
3. Gather context:
   - Clipboard text (if enabled)
   - Screen capture (if enabled)
   - Dictionary context
   ↓
4. Build AI prompt:
   - System message (from CustomPrompt)
   - Context concatenation
   - Selected prompt template
   ↓
5. Call AIService:
   - Provider selection (from settings)
   - Model selection (from settings)
   - API key retrieval
   - Request with timeout (30s default)
   - Rate limiting (1.0s interval)
   ↓
6. Process response:
   - AIEnhancementOutputFilter
   - Streaming handling
   - Completion notification
   ↓
7. Save enhanced text to SwiftData
```

### Build Workflow

#### Using Makefile (Recommended)

```bash
# First-time setup
make all          # Builds everything including whisper.cpp

# Development workflow
make dev          # Build and run

# Individual steps
make check        # Verify prerequisites
make whisper      # Build whisper.cpp framework
make build        # Build VoiceInk only
make run          # Launch built app
make clean        # Clean all artifacts
```

#### Manual Build

```bash
# 1. Build whisper.cpp
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh

# 2. Build VoiceInk
cd ../VoiceInk
# Add whisper.xcframework to Xcode project
# Cmd+B to build, Cmd+R to run
```

### CI/CD Workflow (GitHub Actions)

Trigger: Push to main/master or version tag (v*)

```
1. Checkout code
2. Setup Xcode (latest)
3. Run `make check`
4. Run `make whisper` (build framework)
5. Run `make build` (build app)
6. Create .zip archive
7. Upload artifact (30-day retention)
8. Create GitHub release (if version tag)
```

---

## Coding Conventions

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes | PascalCase | `WhisperState`, `AudioDeviceManager` |
| Protocols | PascalCase, capability-based | `TranscriptionService`, `TranscriptionModel` |
| Properties | camelCase | `isRecording`, `selectedModel` |
| @Published | camelCase | `@Published var recordingState` |
| Functions | camelCase, verb-leading | `startRecording()`, `transcribe()` |
| Enums | PascalCase | `RecordingState`, `ModelProvider` |
| Enum Cases | camelCase | `.idle`, `.recording`, `.transcribing` |
| Constants (UserDefaults keys) | Quoted strings | `"selectedHotkey1"`, `"isAIEnhancementEnabled"` |

### File Organization

#### Extension Pattern for Large Classes

When a class becomes too large (>500 lines), split it into extensions:

```
WhisperState.swift                      # Core class definition
WhisperState+LocalModelManager.swift    # Model loading logic
WhisperState+ModelManagement.swift      # Model switching
WhisperState+ModelQueries.swift         # Query methods
WhisperState+Parakeet.swift            # Parakeet-specific
WhisperState+UI.swift                  # UI coordination
```

#### View Organization

```
Views/
├── AI Models/          # Feature-grouped views
├── Dictionary/
├── Recorder/
├── Settings/
├── Common/             # Reusable components
└── Components/         # Small building blocks
```

#### Service Organization

```
Services/
├── TranscriptionService.swift          # Protocol
├── LocalTranscriptionService.swift     # Implementation
├── CloudTranscription/                 # Provider-specific
│   ├── GroqTranscriptionService.swift
│   └── ...
└── AIEnhancement/                      # AI-specific
    ├── AIEnhancementService.swift
    └── AIService.swift
```

### SwiftUI Patterns

#### State Management

```swift
@StateObject private var whisperState: WhisperState
@EnvironmentObject var whisperState: WhisperState
@AppStorage("selectedHotkey1") private var selectedHotkey1: String = ""
@Published var recordingState: RecordingState = .idle
@Environment(\.modelContext) private var modelContext
```

#### Threading

Always use `@MainActor` for UI-related classes:

```swift
@MainActor
class WhisperState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    // ...
}
```

#### Dependency Injection

Prefer protocol-based injection:

```swift
class AIEnhancementService: ObservableObject {
    private let aiService: AIService

    init(aiService: AIService = AIService()) {
        self.aiService = aiService
    }
}
```

### Documentation

- **Inline comments**: Minimal, used only for complex logic
- **Function names**: Self-documenting (prefer clear names over comments)
- **Protocol definitions**: Include parameter documentation
- **Public APIs**: Add doc comments for important methods

### Access Control

- Default to `internal` (Swift default)
- Use `private` for implementation details within a file
- Use `public` sparingly (mainly for frameworks)
- Heavy use of `@MainActor` for thread safety

### Error Handling

```swift
// Prefer async throws for asynchronous operations
func transcribe(audioURL: URL) async throws -> String {
    guard FileManager.default.fileExists(atPath: audioURL.path) else {
        throw TranscriptionError.fileNotFound
    }
    // ...
}

// Use Result type for services that might fail
enum TranscriptionError: Error {
    case fileNotFound
    case invalidAudioFormat
    case transcriptionFailed(String)
}
```

---

## Common Tasks

### Adding a New Cloud Transcription Provider

1. **Create provider service** in `Services/CloudTranscription/`:

```swift
import Foundation

class NewProviderTranscriptionService: ObservableObject {
    func transcribe(audioURL: URL, apiKey: String, model: String) async throws -> String {
        // Implementation
        let endpoint = "https://api.newprovider.com/v1/transcribe"
        // ... HTTP request logic
        return transcribedText
    }
}
```

2. **Add model definition** in `Models/PredefinedModels.swift`:

```swift
TranscriptionModelData(
    id: "newprovider-model",
    name: "NewProvider Model",
    provider: .cloud,
    requiresAPIKey: true,
    supportedLanguages: [...],
    maxFileSizeMB: 25
)
```

3. **Update CloudTranscriptionService.swift** to route to new provider:

```swift
case .newProvider:
    let service = NewProviderTranscriptionService()
    return try await service.transcribe(audioURL: audioURL, apiKey: apiKey, model: model.id)
```

4. **Add UI for API key** in `Views/AI Models/` settings.

5. **Test with sample audio files**.

### Adding a New AI Enhancement Prompt

1. **Create prompt template** in `Models/PredefinedPrompts.swift`:

```swift
CustomPrompt(
    name: "New Writing Style",
    systemMessage: "Transform the text to match X style...",
    isBuiltIn: true,
    category: .writing
)
```

2. **Add to default prompts** initialization.

3. **Test in AI enhancement settings**.

### Adding a New Hotkey

1. **Register in HotkeyManager.swift**:

```swift
@AppStorage("customHotkey") private var customHotkey: String = ""

KeyboardShortcuts.onKeyUp(for: .customAction) { [weak self] in
    self?.handleCustomAction()
}
```

2. **Add hotkey name** in `KeyboardShortcuts.Name` extension.

3. **Add UI** in Settings/Keyboard Shortcuts view.

### Adding a New Setting

1. **Add @AppStorage property** in relevant service/state class:

```swift
@AppStorage("newFeatureEnabled") private var newFeatureEnabled: Bool = false
```

2. **Add UI toggle** in `Views/Settings/`:

```swift
Toggle("Enable New Feature", isOn: $newFeatureEnabled)
```

3. **Use setting** in business logic:

```swift
if newFeatureEnabled {
    // Feature logic
}
```

### Modifying the Recording Pipeline

1. **Locate WhisperState.swift** and relevant methods:
   - `startRecording()` - Pre-recording setup
   - `stopRecording()` - Post-recording processing
   - `transcribe()` - Transcription pipeline

2. **Add processing step** in appropriate location:

```swift
func transcribe() async throws {
    recordingState = .transcribing

    // Existing transcription
    var text = try await transcriptionService.transcribe(...)

    // NEW: Add custom processing step
    text = customProcessingStep(text)

    // Existing post-processing
    text = wordReplacementService.applyReplacements(text)
    // ...
}
```

3. **Test thoroughly** with different audio inputs.

---

## Testing Strategy

### Current State

- **Test Coverage**: Minimal (stub tests only)
- **Test Frameworks**: Swift Testing framework
- **Test Targets**:
  - `VoiceInkTests/` - Unit tests
  - `VoiceInkUITests/` - UI tests

### Recommended Testing Approach

Given the current minimal test coverage, manual testing is critical:

#### Manual Testing Checklist

**Recording & Transcription**:
- [ ] Test all hotkey combinations
- [ ] Test push-to-talk functionality
- [ ] Test each transcription provider (local & cloud)
- [ ] Test with different audio qualities
- [ ] Test voice activity detection
- [ ] Test recording cancellation

**AI Enhancement**:
- [ ] Test each AI provider
- [ ] Test different prompts
- [ ] Test context gathering (clipboard, screen)
- [ ] Test with/without enhancement

**PowerMode**:
- [ ] Test app detection
- [ ] Test browser URL detection
- [ ] Test configuration switching
- [ ] Test with multiple configurations

**Settings & Configuration**:
- [ ] Test all settings persist correctly
- [ ] Test API key storage/retrieval
- [ ] Test model downloads
- [ ] Test keyboard shortcut conflicts

**UI**:
- [ ] Test all views render correctly
- [ ] Test navigation flows
- [ ] Test mini recorder positioning
- [ ] Test notch recorder (on supported Macs)

#### Unit Testing (Future Enhancement)

Priority areas for unit tests:

1. **TranscriptionService implementations**
   - Mock audio files
   - Test error handling
   - Test API responses

2. **WordReplacementService**
   - Test dictionary matching
   - Test replacement logic

3. **AIEnhancementService**
   - Test context gathering
   - Test prompt building
   - Mock AI responses

4. **PowerModeSessionManager**
   - Test app matching logic
   - Test URL pattern matching

### Testing Tools

```swift
// Example unit test structure
import Testing
@testable import VoiceInk

struct TranscriptionTests {
    @Test func testLocalTranscription() async throws {
        let service = LocalTranscriptionService()
        let audioURL = Bundle.main.url(forResource: "test", withExtension: "wav")!
        let result = try await service.transcribe(audioURL: audioURL, model: testModel)
        #expect(result.isEmpty == false)
    }
}
```

---

## Build & Deployment

### Build Requirements

- **macOS**: 14.0 or later
- **Xcode**: Latest version (15.0+)
- **Swift**: 5.9+
- **Git**: For dependency management
- **whisper.cpp**: External framework dependency

### Build Configurations

#### Debug (Development)

```bash
make dev
# Or in Xcode: Cmd+R with Debug scheme
```

- Code signing: Disabled
- Optimization: None
- Debugging symbols: Enabled
- Assertions: Enabled

#### Release (Production)

```bash
make build  # Uses Release configuration
# Or in Xcode: Product > Archive
```

- Code signing: Disabled (for open-source)
- Optimization: -O (full optimization)
- Debugging symbols: Stripped
- Assertions: Disabled

### Dependencies Management

All dependencies are managed via **Swift Package Manager** (SPM):

| Package | Repository | Purpose |
|---------|-----------|---------|
| KeyboardShortcuts | sindresorhus/KeyboardShortcuts | Global hotkeys |
| LaunchAtLogin | sindresorhus/LaunchAtLogin | Auto-start |
| Sparkle | sparkle-project/Sparkle | Auto-updates |
| MediaRemoteAdapter | ejbills/mediaremote-adapter | Media control |
| Zip | marmelroy/Zip | File compression |
| SelectedTextKit | tisfeng/SelectedTextKit | Text selection |
| FluidAudio | FluidInference/FluidAudio | Parakeet model |
| Atomics | apple/swift-atomics | Thread safety |

**External Framework**:
- **whisper.cpp**: Built separately, linked as XCFramework
  - Location: `~/VoiceInk-Dependencies/whisper.cpp/build-apple/whisper.xcframework`
  - Built via: `make whisper`

### App Entitlements

Required permissions (`VoiceInk.entitlements`):

```xml
<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Sandbox DISABLED - requires full system access -->

<key>com.apple.security.device.audio-input</key>
<true/>   <!-- Microphone access -->

<key>com.apple.security.device.camera</key>
<true/>   <!-- Screen recording for context -->

<key>com.apple.security.network.client</key>
<true/>   <!-- API calls -->

<key>com.apple.security.automation.apple-events</key>
<true/>   <!-- Control other apps -->

<key>com.apple.security.files.user-selected.read-only</key>
<true/>   <!-- File access -->

<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.yourteam.VoiceInk</string>
</array>  <!-- API key storage -->
```

### Deployment Checklist

Before creating a release:

1. **Update version** in project settings
2. **Update appcast.xml** with new version info
3. **Run full build**: `make clean && make all`
4. **Manual testing** of critical features
5. **Create git tag**: `git tag v1.x.x`
6. **Push tag**: `git push origin v1.x.x`
7. **GitHub Actions** will automatically build and create release
8. **Verify release** artifacts on GitHub

### Continuous Integration

**GitHub Actions Workflow** (`.github/workflows/build-and-release.yml`):

```yaml
Triggers:
- Push to main/master
- Version tags (v*)

Steps:
1. Checkout repository
2. Setup Xcode (latest)
3. Check prerequisites (make check)
4. Build whisper.cpp (make whisper)
5. Build VoiceInk (make build)
6. Create .zip archive
7. Upload artifact (30 days)
8. Create GitHub release (tags only)
```

**Artifact Outputs**:
- `VoiceInk.app.zip` - Application bundle
- Retained for 30 days
- Attached to GitHub releases for version tags

---

## Important Guidelines

### Before Making Changes

1. **Discuss first**: Open an issue to discuss significant changes before implementing
2. **Read CONTRIBUTING.md**: Understand the contribution workflow
3. **Check for duplicates**: Search existing issues/PRs
4. **Understand the architecture**: Review this document and key source files

### Development Best Practices

#### Code Quality

- **Follow Swift style guidelines**: Consistent with existing codebase
- **Write meaningful commit messages**: Describe what and why, not just what
- **Keep functions focused**: Single Responsibility Principle
- **Avoid premature optimization**: Clarity first, optimize when needed
- **Use descriptive names**: Prefer `isRecording` over `rec` or `flag`

#### SwiftUI Specifics

- **State management**: Use `@Published` for observable state changes
- **Avoid force unwrapping**: Use optional binding or guard statements
- **MainActor usage**: Always use `@MainActor` for UI-related classes
- **Environment objects**: Inject dependencies via `@EnvironmentObject`
- **Previews**: Add SwiftUI previews for new views when possible

#### Async/Await

- **Prefer async/await** over completion handlers
- **Handle cancellation**: Support Task cancellation where appropriate
- **Avoid blocking**: Never block the main thread
- **Error propagation**: Use `throws` for error handling in async functions

#### Memory Management

- **Avoid retain cycles**: Use `[weak self]` in closures
- **Clean up resources**: Implement proper deinitialization
- **Monitor memory**: Test for memory leaks with large operations

### Security Considerations

#### API Keys

- **Never commit API keys**: Always use secure storage (Keychain)
- **Validate input**: Sanitize user input before API calls
- **Rate limiting**: Implement rate limits for API calls
- **Error messages**: Don't expose sensitive information in errors

#### Privacy

- **Respect user privacy**: All transcription data should stay local by default
- **Screen capture**: Only capture when explicitly enabled
- **Clipboard access**: Only read when necessary
- **Data retention**: Support zero-retention modes

#### Permissions

- **Request permissions**: Properly request microphone and screen recording access
- **Explain usage**: Clear usage descriptions in Info.plist
- **Minimal permissions**: Only request what's necessary

### Performance Optimization

#### Audio Processing

- **Efficient formats**: Use 16kHz PCM for Whisper (optimal)
- **Batch processing**: Process audio in appropriate chunks
- **Background processing**: Use background queues for heavy operations
- **Resource management**: Unload models when not in use

#### UI Responsiveness

- **Async operations**: Keep all heavy work off main thread
- **Debouncing**: Debounce user input where appropriate
- **Lazy loading**: Load data only when needed
- **Efficient rendering**: Minimize SwiftUI view updates

### Debugging Tips

#### Common Issues

**whisper.cpp not found**:
```bash
make clean
make whisper
make build
```

**Xcode build fails**:
1. Clean build folder (Cmd+Shift+K)
2. Delete derived data
3. Restart Xcode

**Runtime crashes**:
- Check console logs for errors
- Verify all permissions are granted
- Test with Debug configuration
- Use Xcode's Memory Graph debugger

**Recording issues**:
- Check microphone permissions
- Verify audio device selection
- Test with different audio formats
- Check disk space for recordings

#### Debugging Tools

- **Xcode Debugger**: LLDB for breakpoints and inspection
- **Instruments**: Profile performance and memory
- **Console.app**: View system logs
- **Activity Monitor**: Check CPU and memory usage

### Code Review Guidelines

When submitting PRs:

1. **Self-review first**: Review your own changes before submitting
2. **Write clear PR descriptions**: Explain what, why, and how
3. **Keep changes focused**: One feature/fix per PR
4. **Update documentation**: Update relevant docs if needed
5. **Address feedback**: Respond to review comments promptly

### Versioning

- Follow **Semantic Versioning** (SemVer):
  - `MAJOR.MINOR.PATCH`
  - MAJOR: Breaking changes
  - MINOR: New features (backwards compatible)
  - PATCH: Bug fixes

### License Compliance

- **GPL v3.0**: All contributions are under GPL v3.0
- **Third-party licenses**: Respect dependency licenses
- **Attribution**: Credit original authors for significant code

---

## Key Files for AI Assistants

When working on VoiceInk, start by understanding these files:

### Essential Reading

1. **VoiceInk/VoiceInk.swift** - App initialization and setup
2. **VoiceInk/Whisper/WhisperState.swift** - Central orchestrator (most important)
3. **VoiceInk/Services/TranscriptionService.swift** - Service protocol architecture
4. **VoiceInk/Views/ContentView.swift** - Main UI structure
5. **Makefile** - Build automation
6. **BUILDING.md** - Build instructions
7. **CONTRIBUTING.md** - Contribution workflow

### Feature-Specific Files

**For transcription work**:
- `Services/LocalTranscriptionService.swift`
- `Services/CloudTranscription/` (all files)
- `Whisper/Recorder.swift`

**For AI enhancement**:
- `Services/AIEnhancement/AIEnhancementService.swift`
- `Services/AIEnhancement/AIService.swift`
- `Models/CustomPrompt.swift`

**For UI changes**:
- `Views/ContentView.swift`
- `Views/Recorder/MiniRecorderView.swift`
- `Views/Settings/` (all settings views)

**For PowerMode**:
- `PowerMode/PowerModeSessionManager.swift`
- `PowerMode/BrowserURLService.swift`

---

## Additional Resources

### External Documentation

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Project Resources

- **GitHub Repository**: [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)
- **Website**: [tryvoiceink.com](https://tryvoiceink.com)
- **Issue Tracker**: [GitHub Issues](https://github.com/Beingpax/VoiceInk/issues)

### Community

- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Pull Requests**: Contribute via PRs (discuss first!)

---

## Changelog

**2025-11-14** - Initial CLAUDE.md creation
- Comprehensive codebase analysis
- Architecture documentation
- Development workflow guides
- Coding conventions established

---

**For questions or clarifications about this document, please open an issue on GitHub.**
