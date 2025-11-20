import Foundation
import os.log
import AVFoundation

/// ElevenLabs Scribe v2 Realtime WebSocket通信サービス
class ElevenLabsRealtimeService: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.example.VoiceInk", category: "ElevenLabsRealtimeService")

    private var webSocket: URLSessionWebSocketTask?
    private let apiKey: String
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    // コールバック
    var onPartialTranscript: ((String) async -> Void)?
    var onCommittedTranscript: ((String) async -> Void)?
    var onError: ((String) async -> Void)?
    var onSessionStarted: (() async -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - WebSocket接続

    func connect(model: String = "scribe_v2_realtime", language: String = "en") async throws {
        logger.info("Connecting to ElevenLabs Realtime API with model: \(model)")

        let queryParams = "model_id=\(model)&language_code=\(language)&commit_strategy=vad"
        guard let url = URL(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime?\(queryParams)") else {
            let error = "Invalid WebSocket URL"
            logger.error("Error: \(error)")
            await onError?(error)
            throw NSError(domain: "ElevenLabsRealtimeService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        isConnected = true
        reconnectAttempts = 0

        logger.info("WebSocket connection initiated")

        // メッセージ受信ループ開始
        await receiveMessages()
    }

    func disconnect() async {
        logger.info("Disconnecting from ElevenLabs Realtime API")
        isConnected = false

        if webSocket != nil {
            webSocket?.cancel(with: .goingAway, reason: nil)
            webSocket = nil
        }
    }

    // MARK: - 音声送信

    func sendAudioChunk(_ audioData: Data, sampleRate: Int = 16000) async {
        guard isConnected, let webSocket = webSocket else {
            logger.warning("WebSocket not connected, cannot send audio chunk")
            return
        }

        let audioBase64 = audioData.base64EncodedString()

        let message: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": audioBase64,
            "commit": false,
            "sample_rate": sampleRate
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

            let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    self?.logger.error("Error sending audio chunk: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Error serializing audio message: \(error.localizedDescription)")
        }
    }

    func commitAudio() async {
        guard isConnected, let webSocket = webSocket else {
            logger.warning("WebSocket not connected, cannot commit audio")
            return
        }

        let message: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": "",
            "commit": true,
            "sample_rate": 16000
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

            let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    self?.logger.error("Error committing audio: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Error serializing commit message: \(error.localizedDescription)")
        }
    }

    // MARK: - メッセージ受信

    private func receiveMessages() async {
        while isConnected, let webSocket = webSocket {
            do {
                let message = try await webSocket.receive()

                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    logger.warning("Received unknown message type")
                }
            } catch {
                logger.error("Error receiving message: \(error.localizedDescription)")
                isConnected = false

                // 再接続ロジック
                if self.reconnectAttempts < self.maxReconnectAttempts {
                    self.reconnectAttempts += 1
                    let delay = UInt64(pow(2.0, Double(self.reconnectAttempts - 1))) * 1_000_000_000 // exponential backoff
                    try? await Task.sleep(nanoseconds: delay)

                    self.logger.info("Attempting to reconnect... (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")
                    // 再接続は呼び出し側で処理
                    break
                } else {
                    let errorMsg = "Failed to maintain WebSocket connection after \(self.maxReconnectAttempts) attempts"
                    self.logger.error("Error: \(errorMsg)")
                    await self.onError?(errorMsg)
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else {
            logger.warning("Failed to convert message to data")
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let messageType = json["message_type"] as? String

                logger.debug("Received message type: \(messageType ?? "unknown")")

                switch messageType {
                case "session_started":
                    logger.info("WebSocket session started")
                    await onSessionStarted?()

                case "partial_transcript":
                    if let result = json["result"] as? [String: Any],
                       let transcript = result["transcript"] as? String {
                        logger.debug("Partial transcript: \(transcript)")
                        await onPartialTranscript?(transcript)
                    }

                case "committed_transcript":
                    if let result = json["result"] as? [String: Any],
                       let transcript = result["transcript"] as? String {
                        logger.info("Committed transcript: \(transcript)")
                        await onCommittedTranscript?(transcript)
                    }

                case "committed_transcript_with_timestamps":
                    if let result = json["result"] as? [String: Any],
                       let transcript = result["transcript"] as? String {
                        logger.info("Committed transcript with timestamps: \(transcript)")
                        await onCommittedTranscript?(transcript)
                    }

                case "error":
                    if let error = json["error"] as? String {
                        logger.error("API error: \(error)")
                        await onError?(error)
                    }

                case "auth_error":
                    let errorMsg = "Authentication failed - invalid API key"
                    logger.error("Auth error: \(errorMsg)")
                    await onError?(errorMsg)

                case "quota_exceeded_error":
                    let errorMsg = "API quota exceeded"
                    logger.error("Quota error: \(errorMsg)")
                    await onError?(errorMsg)

                default:
                    logger.debug("Received message type: \(messageType ?? "unknown")")
                }
            }
        } catch {
            logger.error("Error parsing JSON message: \(error.localizedDescription)")
        }
    }
}
