import Foundation

protocol VoiceRecognitionServiceProtocol {
    func requestAuthorization() async -> Bool
    func transcribeOnce() async throws -> String
}

struct VoiceRecognitionService: VoiceRecognitionServiceProtocol {
    func requestAuthorization() async -> Bool {
        true
    }

    func transcribeOnce() async throws -> String {
        ""
    }
}
