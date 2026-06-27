import Foundation
import AVFoundation
import Speech

protocol VoiceRecognitionServiceProtocol {
    func requestAuthorization() async -> Bool
    func transcribeOnce() async throws -> String
}

enum VoiceRecognitionError: Error {
    case speechUnavailable
    case microphoneUnavailable
    case noSpeechDetected
}

final class VoiceRecognitionService: VoiceRecognitionServiceProtocol {
    private let locale = Locale(identifier: "zh_CN")

    func requestAuthorization() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechAuthorized && microphoneAuthorized
    }

    func transcribeOnce() async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw VoiceRecognitionError.speechUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let audioEngine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            let stateLock = NSLock()
            var didResume = false
            var latestTranscript = ""
            var tapInstalled = false
            var recognitionTask: SFSpeechRecognitionTask?

            func setLatestTranscript(_ transcript: String) {
                stateLock.lock()
                latestTranscript = transcript
                stateLock.unlock()
            }

            func currentTranscript() -> String {
                stateLock.lock()
                let transcript = latestTranscript
                stateLock.unlock()
                return transcript
            }

            func finish(with result: Result<String, Error>) {
                stateLock.lock()
                let shouldFinish = !didResume
                didResume = true
                stateLock.unlock()

                guard shouldFinish else { return }
                recognitionTask?.cancel()
                request.endAudio()
                if audioEngine.isRunning {
                    audioEngine.stop()
                }
                if tapInstalled {
                    audioEngine.inputNode.removeTap(onBus: 0)
                }
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                continuation.resume(with: result)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    setLatestTranscript(result.bestTranscription.formattedString)
                    if result.isFinal {
                        finish(with: .success(currentTranscript()))
                    }
                }

                if let error {
                    finish(with: .failure(error))
                }
            }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)

                let inputNode = audioEngine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                guard format.sampleRate > 0 else {
                    finish(with: .failure(VoiceRecognitionError.microphoneUnavailable))
                    return
                }

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }
                tapInstalled = true

                audioEngine.prepare()
                try audioEngine.start()

                Task {
                    try? await Task.sleep(nanoseconds: 4_500_000_000)
                    let transcript = currentTranscript()
                    if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        finish(with: .failure(VoiceRecognitionError.noSpeechDetected))
                    } else {
                        finish(with: .success(transcript))
                    }
                }
            } catch {
                finish(with: .failure(error))
            }
        }
    }
}
