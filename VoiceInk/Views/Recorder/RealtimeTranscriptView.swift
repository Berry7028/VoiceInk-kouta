import SwiftUI

/// リアルタイム文字起こしをチャット形式で表示するビュー
struct RealtimeTranscriptView: View {
    let transcripts: [RealtimeTranscriptMessage]
    let maxHeight: CGFloat = 150

    var body: some View {
        if transcripts.isEmpty {
            EmptyState()
        } else {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(transcripts) { message in
                            TranscriptBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: maxHeight)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .onChange(of: transcripts) { _, _ in
                    withAnimation {
                        scrollProxy.scrollTo(transcripts.last?.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    scrollProxy.scrollTo(transcripts.last?.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Subviews

struct TranscriptBubble: View {
    let message: RealtimeTranscriptMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .lineLimit(nil)
                    .textSelection(.enabled)

                Text(timeString(for: message.timestamp))
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(message.isPartial ? Color.gray.opacity(0.3) : Color.blue.opacity(0.15))
            .cornerRadius(8)

            Spacer()

            // ステータスインジケータ
            if message.isPartial {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("Waiting for transcription...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    let messages = [
        RealtimeTranscriptMessage(text: "Hello, this is", isPartial: true),
        RealtimeTranscriptMessage(text: "Hello, this is a test.", isPartial: false),
        RealtimeTranscriptMessage(text: "This is the", isPartial: true)
    ]

    RealtimeTranscriptView(transcripts: messages)
        .padding()
}
