import Foundation
import os.log

class ElevenLabsTranscriptionService {
    private let logger = Logger(subsystem: "com.example.VoiceInk", category: "ElevenLabsTranscriptionService")

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        let config = try getAPIConfig(for: model)

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")

        let body = try createElevenLabsRequestBody(audioURL: audioURL, modelName: config.modelName, boundary: boundary)

        logger.info("Starting ElevenLabs transcription with model: \(config.modelName)")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid HTTP response received")
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        logger.debug("ElevenLabs API response status: \(httpResponse.statusCode)")

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            logger.error("ElevenLabs API error: \(errorMessage)")
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            logger.info("Transcription successful, text length: \(transcriptionResponse.text.count)")
            return transcriptionResponse.text
        } catch {
            logger.error("Failed to decode transcription response")
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func getAPIConfig(for model: any TranscriptionModel) throws -> APIConfig {
        guard let apiKey = UserDefaults.standard.string(forKey: "ElevenLabsAPIKey"), !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        guard let apiURL = URL(string: "https://api.elevenlabs.io/v1/speech-to-text") else {
            throw NSError(domain: "ElevenLabsTranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        return APIConfig(url: apiURL, apiKey: apiKey, modelName: model.name)
    }

    private func createElevenLabsRequestBody(audioURL: URL, modelName: String, boundary: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        // Add file field
        appendFormField(to: &body, name: "file", filename: audioURL.lastPathComponent, data: audioData, boundary: boundary, contentType: "audio/wav")

        // Add model_id field
        appendFormField(to: &body, name: "model_id", value: modelName, boundary: boundary)

        // Add tag_audio_events field
        appendFormField(to: &body, name: "tag_audio_events", value: "false", boundary: boundary)

        // Add temperature field
        appendFormField(to: &body, name: "temperature", value: "0", boundary: boundary)

        // Add language_code field if specified
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
        if selectedLanguage != "auto", !selectedLanguage.isEmpty {
            appendFormField(to: &body, name: "language_code", value: selectedLanguage, boundary: boundary)
        }

        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private func appendFormField(to body: inout Data, name: String, filename: String, data: Data, boundary: String, contentType: String) {
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(data)
        body.append(crlf.data(using: .utf8)!)
    }

    private func appendFormField(to body: inout Data, name: String, value: String, boundary: String) {
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(value.data(using: .utf8)!)
        body.append(crlf.data(using: .utf8)!)
    }

    private struct APIConfig {
        let url: URL
        let apiKey: String
        let modelName: String
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
        let x_groq: GroqMetadata?

        struct GroqMetadata: Decodable {
            let id: String?
        }
    }
}

final class ElevenLabsRealtimeTranscriptionService: RealtimeTranscriptionServiceProtocol {
    private let logger = Logger(subsystem: "com.example.VoiceInk", category: "ElevenLabsRealtimeTranscriptionService")
    private let urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    private var audioFileURL: URL?
    private var streamReadOffset: UInt64 = 0
    private let chunkSize: UInt64 = 6_400 // ~200ms of 16 kHz mono PCM
    private let sampleRate: Int = 16_000
    private let transcriptQueue = DispatchQueue(label: "com.prakashjoshipax.voiceink.realtime.transcript", attributes: .concurrent)
    private let controlQueue = DispatchQueue(label: "com.prakashjoshipax.voiceink.realtime.control")
    private var committedTextStorage: String = ""
    private var partialTextStorage: String = ""
    private var _shouldStopStreaming: Bool = false
    private var lastTranscriptUpdate: Date = Date()

    var onTextUpdate: ((String) -> Void)?
    var onConnectionStateChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    init(urlSession: URLSession = URLSession(configuration: .default)) {
        self.urlSession = urlSession
    }

    var isSessionActive: Bool {
        webSocketTask != nil
    }

    func startSession(audioFileURL: URL, modelName: String?) async throws {
        guard webSocketTask == nil else { return }
        guard let apiKey = UserDefaults.standard.string(forKey: "ElevenLabsAPIKey"), !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }

        resetTranscriptStorage()
        self.audioFileURL = audioFileURL
        streamReadOffset = 0
        shouldStopStreaming = false

        let normalizedModel = Self.normalizedModelName(modelName ?? "realtime_trans")
        guard let url = URL(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=\(normalizedModel)") else {
            throw CloudTranscriptionError.apiRequestFailed(statusCode: -1, message: "Invalid ElevenLabs realtime endpoint")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let task = urlSession.webSocketTask(with: request)
        webSocketTask = task

        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStateChange?(true)
        }

        task.resume()

        receiveTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.listenForMessages()
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        startStreamingLoop()
    }

    func finishSession() async -> String {
        guard webSocketTask != nil else {
            let text = finalTranscript()
            resetState(clearTranscripts: true)
            return text
        }

        shouldStopStreaming = true
        if let streamingTask {
            await streamingTask.value
        }
        streamingTask = nil

        await sendFinalCommit()
        await waitForTranscriptStability(idleTime: 0.35, timeout: 2.0)

        closeConnection()
        let text = finalTranscript()
        resetState(clearTranscripts: true)
        return text
    }

    func cancelSession() async {
        guard webSocketTask != nil else {
            resetState(clearTranscripts: true)
            return
        }

        streamingTask?.cancel()
        streamingTask = nil
        shouldStopStreaming = false
        closeConnection()
        resetState(clearTranscripts: true)
    }

    func finalTranscript() -> String {
        transcriptQueue.sync {
            combinedTranscriptLocked()
        }
    }

    // MARK: - Streaming

    private func startStreamingLoop() {
        guard let url = audioFileURL else { return }
        streamingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.performStreamingLoop(audioURL: url)
        }
    }

    private func performStreamingLoop(audioURL: URL) async {
        var handle: FileHandle?
        defer { try? handle?.close() }

        do {
            while !FileManager.default.fileExists(atPath: audioURL.path) && !Task.isCancelled {
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            guard !Task.isCancelled else { return }
            handle = try FileHandle(forReadingFrom: audioURL)
            var headerSkipped = false

            while !Task.isCancelled {
                if shouldStopStreaming {
                    let currentSize = try fileSize(of: audioURL)
                    if currentSize <= streamReadOffset {
                        break
                    }
                }

                let fileSize = try fileSize(of: audioURL)
                if !headerSkipped {
                    if fileSize <= 44 {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        continue
                    }
                    streamReadOffset = 44
                    headerSkipped = true
                }

                if fileSize > streamReadOffset {
                    let available = fileSize - streamReadOffset
                    let bytesToRead = Int(min(available, chunkSize))
                    try handle?.seek(toOffset: streamReadOffset)
                    if let chunk = handle?.readData(ofLength: bytesToRead), !chunk.isEmpty {
                        streamReadOffset += UInt64(chunk.count)
                        await sendChunk(chunk, commit: false)
                    }
                } else {
                    try await Task.sleep(nanoseconds: 80_000_000)
                }
            }
        } catch {
            logger.error("Realtime streaming error: \(error.localizedDescription)")
        }
    }

    private func listenForMessages() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .data(let data):
                    handleMessageData(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        handleMessageData(data)
                    }
                @unknown default:
                    break
                }
            } catch {
                logger.error("Realtime websocket receive failed: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError?("Realtime connection closed")
                }
                streamingTask?.cancel()
                streamingTask = nil
                shouldStopStreaming = false

                receiveTask?.cancel()
                receiveTask = nil
                webSocketTask?.cancel(with: .goingAway, reason: nil)
                webSocketTask = nil
                DispatchQueue.main.async { [weak self] in
                    self?.onConnectionStateChange?(false)
                }
                break
            }
        }
    }

    // MARK: - Message Handling

    private func handleMessageData(_ data: Data) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let payload = jsonObject as? [String: Any],
              let type = payload["message_type"] as? String else {
            return
        }

        switch type {
        case "session_started":
            logger.debug("Realtime session started")
        case "partial_transcript":
            let text = (payload["text"] as? String) ?? ""
            updatePartialText(text)
        case "committed_transcript", "committed_transcript_with_timestamps":
            appendCommittedText(textFromPayload(payload))
        case "input_error", "error":
            let message = (payload["text"] as? String)
                ?? (payload["error"] as? String)
                ?? "Unknown realtime error"
            DispatchQueue.main.async { [weak self] in
                self?.onError?(message)
            }
        default:
            break
        }
    }

    private func textFromPayload(_ payload: [String: Any]) -> String {
        if let text = payload["text"] as? String {
            return text
        }
        if let words = payload["words"] as? [[String: Any]] {
            return words.compactMap { $0["text"] as? String }.joined(separator: "")
        }
        return ""
    }

    private func appendCommittedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        transcriptQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            if self.committedTextStorage.isEmpty {
                self.committedTextStorage = trimmed
            } else if self.committedTextStorage.hasSuffix(" ") {
                self.committedTextStorage += trimmed
            } else {
                self.committedTextStorage += " \(trimmed)"
            }
            self.partialTextStorage = ""
            let combined = self.combinedTranscriptLocked()
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?(combined)
            }
            self.markTranscriptUpdate()
        }
    }

    private func updatePartialText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.partialTextStorage = trimmed
            let combined = self.combinedTranscriptLocked()
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?(combined)
            }
            self.markTranscriptUpdate()
        }
    }

    private func combinedTranscriptLocked() -> String {
        let committed = committedTextStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = partialTextStorage.trimmingCharacters(in: .whitespacesAndNewlines)

        if committed.isEmpty {
            return partial
        }

        if partial.isEmpty {
            return committed
        }

        return "\(committed) \(partial)"
    }

    // MARK: - Helpers

    private func sendChunk(_ data: Data, commit: Bool) async {
        guard let task = webSocketTask else { return }
        var payload: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": data.isEmpty ? "" : data.base64EncodedString(),
            "commit": commit,
            "sample_rate": sampleRate
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try await task.send(.string(jsonString))
            }
        } catch {
            logger.error("Failed to send realtime chunk: \(error.localizedDescription)")
        }
    }

    private func sendFinalCommit() async {
        await sendChunk(Data(), commit: true)
    }

    private func fileSize(of url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }

    private func resetTranscriptStorage() {
        transcriptQueue.async(flags: .barrier) { [weak self] in
            self?.committedTextStorage = ""
            self?.partialTextStorage = ""
        }
    }

    private func resetState(clearTranscripts: Bool) {
        audioFileURL = nil
        streamReadOffset = 0
        shouldStopStreaming = false
        controlQueue.sync { lastTranscriptUpdate = Date() }
        if clearTranscripts {
            resetTranscriptStorage()
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?("")
            }
        }
    }

    private func closeConnection() {
        guard webSocketTask != nil else { return }
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStateChange?(false)
        }
    }

    private var shouldStopStreaming: Bool {
        get { controlQueue.sync { _shouldStopStreaming } }
        set { controlQueue.sync { _shouldStopStreaming = newValue } }
    }

    private func markTranscriptUpdate() {
        controlQueue.sync {
            lastTranscriptUpdate = Date()
        }
    }

    private func waitForTranscriptStability(idleTime: TimeInterval, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let idleDuration = controlQueue.sync { Date().timeIntervalSince(lastTranscriptUpdate) }
            if idleDuration >= idleTime {
                break
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private static func normalizedModelName(_ modelName: String) -> String {
        if modelName == "realtime_trans" {
            return "scribe_v2_realtime"
        }
        return modelName
    }
}
