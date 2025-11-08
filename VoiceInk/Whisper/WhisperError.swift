import Foundation

enum WhisperStateError: Error, Identifiable {
    case modelLoadFailed
    case transcriptionFailed
    case whisperCoreFailed
    case unzipFailed
    case unknownError
    
    var id: String { UUID().uuidString }
}

extension WhisperStateError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "文字起こしモデルの読み込みに失敗しました。"
        case .transcriptionFailed:
            return "音声の文字起こしに失敗しました。"
        case .whisperCoreFailed:
            return "コア文字起こしエンジンが失敗しました。"
        case .unzipFailed:
            return "ダウンロードしたCore MLモデルの解凍に失敗しました。"
        case .unknownError:
            return "不明なエラーが発生しました。"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelLoadFailed:
            return "別のモデルを選択するか、現在のモデルを再ダウンロードしてください。"
        case .transcriptionFailed:
            return "デフォルトモデルを確認して再試行してください。問題が解決しない場合は、別のモデルを試してください。"
        case .whisperCoreFailed:
            return "これは音声録音の問題またはシステムリソース不足が原因で発生する可能性があります。再試行するか、アプリを再起動してください。"
        case .unzipFailed:
            return "ダウンロードしたCore MLモデルアーカイブが破損している可能性があります。モデルを削除して再度ダウンロードしてください。利用可能なディスク容量を確認してください。"
        case .unknownError:
            return "アプリケーションを再起動してください。問題が解決しない場合は、サポートに連絡してください。"
        }
    }
} 