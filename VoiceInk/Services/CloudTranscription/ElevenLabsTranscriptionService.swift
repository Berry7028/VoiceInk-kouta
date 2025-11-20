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