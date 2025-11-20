import Foundation
import AVFoundation
import CoreAudio
import os

@MainActor
class Recorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "Recorder")
    private let deviceManager = AudioDeviceManager.shared
    private var deviceObserver: NSObjectProtocol?
    private var isReconfiguring = false
    private let mediaController = MediaController.shared
    private let playbackController = PlaybackController.shared
    @Published var audioMeter = AudioMeter(averagePower: 0, peakPower: 0)
    private var audioLevelCheckTask: Task<Void, Never>?
    private var audioMeterUpdateTask: Task<Void, Never>?
    private var hasDetectedAudioInCurrentSession = false

    // Realtime streaming support
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioStreamTask: Task<Void, Never>?
    var onAudioChunk: ((Data) -> Void)?
    
    enum RecorderError: Error {
        case couldNotStartRecording
    }
    
    override init() {
        super.init()
        setupDeviceChangeObserver()
    }
    
    private func setupDeviceChangeObserver() {
        deviceObserver = AudioDeviceConfiguration.createDeviceChangeObserver { [weak self] in
            Task {
                await self?.handleDeviceChange()
            }
        }
    }
    
    private func handleDeviceChange() async {
        guard !isReconfiguring else { return }
        isReconfiguring = true
        
        if recorder != nil {
            let currentURL = recorder?.url
            stopRecording()
            
            if let url = currentURL {
                do {
                    try await startRecording(toOutputFile: url)
                } catch {
                    logger.error("❌ Failed to restart recording after device change: \(error.localizedDescription)")
                }
            }
        }
        isReconfiguring = false
    }
    
    private func configureAudioSession(with deviceID: AudioDeviceID) async throws {
        try AudioDeviceConfiguration.setDefaultInputDevice(deviceID)
    }
    
    func startRecording(toOutputFile url: URL, enableRealtimeStreaming: Bool = false) async throws {
        deviceManager.isRecordingActive = true

        let currentDeviceID = deviceManager.getCurrentDevice()
        let lastDeviceID = UserDefaults.standard.string(forKey: "lastUsedMicrophoneDeviceID")

        if String(currentDeviceID) != lastDeviceID {
            if let deviceName = deviceManager.availableDevices.first(where: { $0.id == currentDeviceID })?.name {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: "Using: \(deviceName)",
                        type: .info
                    )
                }
            }
        }
        UserDefaults.standard.set(String(currentDeviceID), forKey: "lastUsedMicrophoneDeviceID")

        hasDetectedAudioInCurrentSession = false

        let deviceID = deviceManager.getCurrentDevice()
        if deviceID != 0 {
            do {
                try await configureAudioSession(with: deviceID)
            } catch {
                logger.warning("⚠️ Failed to configure audio session for device \(deviceID), attempting to continue: \(error.localizedDescription)")
            }
        }

        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: recordSettings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true

            if recorder?.record() == false {
                logger.error("❌ Could not start recording")
                throw RecorderError.couldNotStartRecording
            }

            Task { [weak self] in
                guard let self = self else { return }
                await self.playbackController.pauseMedia()
                _ = await self.mediaController.muteSystemAudio()
            }

            // Realtime streaming setup
            if enableRealtimeStreaming {
                setupRealtimeStreaming()
            }

            audioLevelCheckTask?.cancel()
            audioMeterUpdateTask?.cancel()

            audioMeterUpdateTask = Task {
                while recorder != nil && !Task.isCancelled {
                    updateAudioMeter()
                    try? await Task.sleep(nanoseconds: 33_000_000)
                }
            }

            audioLevelCheckTask = Task {
                let notificationChecks: [TimeInterval] = [5.0, 12.0]

                for delay in notificationChecks {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    if Task.isCancelled { return }

                    if self.hasDetectedAudioInCurrentSession {
                        return
                    }

                    await MainActor.run {
                        NotificationManager.shared.showNotification(
                            title: "No Audio Detected",
                            type: .warning
                        )
                    }
                }
            }

        } catch {
            logger.error("Failed to create audio recorder: \(error.localizedDescription)")
            stopRecording()
            throw RecorderError.couldNotStartRecording
        }
    }

    // MARK: - Realtime Streaming

    private func setupRealtimeStreaming() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        self.inputNode = inputNode

        let inputFormat = inputNode.outputFormat(forBus: 0)!

        let chunkerFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!

        audioEngine?.attach(AVAudioUnitVarispeed(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_FormatConverter,
            componentSubType: kAudioUnitSubType_AUConverter,
            componentManufacturer: kAudioUnitManufacture_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )))

        inputNode.installTap(onBus: 0, bufferSize: 16000, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, targetFormat: chunkerFormat)
        }

        do {
            try audioEngine?.start()
            logger.info("✅ Realtime audio streaming started")
        } catch {
            logger.error("❌ Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

        let audioBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: buffer.frameLength)!

        do {
            let converter = AVAudioConverter(from: buffer.format, to: targetFormat)!
            var error: NSError?
            _ = converter.convert(to: audioBuffer, error: &error)

            if let error = error {
                logger.error("❌ Audio conversion error: \(error.localizedDescription)")
                return
            }

            let audioData = audioBuffer.int16ChannelData!.pointee
            let dataBytes = Data(bytes: audioData, count: Int(audioBuffer.frameLength) * 2)

            onAudioChunk?(dataBytes)
        } catch {
            logger.error("❌ Error processing audio buffer: \(error.localizedDescription)")
        }
    }

    private func stopRealtimeStreaming() {
        audioStreamTask?.cancel()
        audioStreamTask = nil

        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }

        do {
            try audioEngine?.stop()
            audioEngine = nil
            logger.info("✅ Realtime audio streaming stopped")
        } catch {
            logger.error("❌ Error stopping audio engine: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioLevelCheckTask?.cancel()
        audioMeterUpdateTask?.cancel()
        stopRealtimeStreaming()
        recorder?.stop()
        recorder = nil
        audioMeter = AudioMeter(averagePower: 0, peakPower: 0)

        Task {
            await mediaController.unmuteSystemAudio()
            try? await Task.sleep(nanoseconds: 100_000_000)
            await playbackController.resumeMedia()
        }
        deviceManager.isRecordingActive = false
    }

    private func updateAudioMeter() {
        guard let recorder = recorder else { return }
        recorder.updateMeters()
        
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        let minVisibleDb: Float = -60.0 
        let maxVisibleDb: Float = 0.0

        let normalizedAverage: Float
        if averagePower < minVisibleDb {
            normalizedAverage = 0.0
        } else if averagePower >= maxVisibleDb {
            normalizedAverage = 1.0
        } else {
            normalizedAverage = (averagePower - minVisibleDb) / (maxVisibleDb - minVisibleDb)
        }
        
        let normalizedPeak: Float
        if peakPower < minVisibleDb {
            normalizedPeak = 0.0
        } else if peakPower >= maxVisibleDb {
            normalizedPeak = 1.0
        } else {
            normalizedPeak = (peakPower - minVisibleDb) / (maxVisibleDb - minVisibleDb)
        }
        
        let newAudioMeter = AudioMeter(averagePower: Double(normalizedAverage), peakPower: Double(normalizedPeak))

        if !hasDetectedAudioInCurrentSession && newAudioMeter.averagePower > 0.01 {
            hasDetectedAudioInCurrentSession = true
        }
        
        audioMeter = newAudioMeter
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("❌ Recording finished unsuccessfully - file may be corrupted or empty")
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "Recording failed - audio file corrupted",
                    type: .error
                )
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            logger.error("❌ Recording encode error during session: \(error.localizedDescription)")
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "Recording error: \(error.localizedDescription)",
                    type: .error
                )
            }
        }
    }
    
    deinit {
        audioLevelCheckTask?.cancel()
        audioMeterUpdateTask?.cancel()
        if let observer = deviceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

struct AudioMeter: Equatable {
    let averagePower: Double
    let peakPower: Double
}