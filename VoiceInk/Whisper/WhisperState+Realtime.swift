import Foundation

/// WhisperStateのリアルタイム文字起こし機能拡張
extension WhisperState {

    // MARK: - Realtime Transcription Setup

    func setupRealtimeTranscription() async {
        guard let model = currentTranscriptionModel as? CloudModel,
              model.provider == .elevenLabs,
              model.name.contains("scribe_v2_realtime") else {
            logger.info("Current model is not ElevenLabs Scribe v2 Realtime, skipping realtime setup")
            return
        }

        guard let apiKey = UserDefaults.standard.string(forKey: "ElevenLabsAPIKey"), !apiKey.isEmpty else {
            logger.error("ElevenLabs API key not configured")
            miniRecorderError = "ElevenLabs API key not configured"
            return
        }

        logger.info("Setting up realtime transcription with Scribe v2")

        realtimeService = ElevenLabsRealtimeService(apiKey: apiKey)

        // Set up callbacks
        realtimeService?.onSessionStarted = { [weak self] in
            await MainActor.run {
                self?.isRealtimeTranscribing = true
                self?.logger.info("Realtime transcription session started")
            }
        }

        realtimeService?.onPartialTranscript = { [weak self] text in
            await MainActor.run {
                self?.updateRealtimeTranscript(text: text, isPartial: true)
            }
        }

        realtimeService?.onCommittedTranscript = { [weak self] text in
            await MainActor.run {
                self?.updateRealtimeTranscript(text: text, isPartial: false)
                self?.committedTextBuffer.append(text)
            }
        }

        realtimeService?.onError = { [weak self] errorMessage in
            await MainActor.run {
                self?.logger.error("Realtime transcription error: \(errorMessage)")
                self?.miniRecorderError = errorMessage
                self?.isRealtimeTranscribing = false
            }
        }

        // Connect to WebSocket
        do {
            let language = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
            try await realtimeService?.connect(model: "scribe_v2_realtime", language: language)
        } catch {
            logger.error("Failed to connect to realtime service: \(error.localizedDescription)")
            miniRecorderError = "Connection failed"
            isRealtimeTranscribing = false
        }
    }

    func startRealtimeAudioStreaming() {
        guard realtimeService != nil else {
            logger.warning("Realtime service not initialized")
            return
        }

        logger.info("Starting realtime audio streaming")

        // Set up audio chunk callback in Recorder
        recorder.onAudioChunk = { [weak self] audioData in
            Task {
                await self?.realtimeService?.sendAudioChunk(audioData, sampleRate: 16000)
            }
        }
    }

    func stopRealtimeAudioStreaming() {
        logger.info("Stopping realtime audio streaming")
        recorder.onAudioChunk = nil
    }

    func finalizeRealtimeTranscription() async -> String {
        logger.info("Finalizing realtime transcription")

        // Commit any remaining audio
        await realtimeService?.commitAudio()

        // Give some time for final results
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Generate final text from committed messages
        let finalText = committedTextBuffer.joined(separator: " ")
        committedTextBuffer.removeAll()
        realtimeTranscripts.removeAll()

        // Disconnect from WebSocket
        await realtimeService?.disconnect()
        realtimeService = nil

        isRealtimeTranscribing = false

        logger.info("Final text: \(finalText)")
        return finalText
    }

    // MARK: - Helper Methods

    private func updateRealtimeTranscript(text: String, isPartial: Bool) {
        let message = RealtimeTranscriptMessage(text: text, isPartial: isPartial)

        if isPartial {
            // Keep only the latest partial result
            if let lastIndex = realtimeTranscripts.lastIndex(where: { $0.isPartial }) {
                realtimeTranscripts[lastIndex] = message
            } else {
                realtimeTranscripts.append(message)
            }
        } else {
            // Add committed result
            realtimeTranscripts.append(message)
        }

        logger.debug("Updated realtime transcript: \(text) (partial: \(isPartial))")
    }

    func clearRealtimeTranscripts() {
        realtimeTranscripts.removeAll()
        committedTextBuffer.removeAll()
        isRealtimeTranscribing = false
        logger.info("Cleared realtime transcripts")
    }
}
