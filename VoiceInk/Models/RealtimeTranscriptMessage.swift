import Foundation

/// リアルタイム文字起こしのメッセージを表すモデル
struct RealtimeTranscriptMessage: Identifiable {
    let id: UUID
    let text: String
    let isPartial: Bool  // true = 部分結果, false = 確定結果
    let timestamp: Date

    init(text: String, isPartial: Bool = false, timestamp: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.isPartial = isPartial
        self.timestamp = timestamp
    }
}
