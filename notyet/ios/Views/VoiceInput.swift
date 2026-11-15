// Target membership: app only.
// Live speech-to-text for the mic button in Search.
// REQUIRED Info.plist keys on the app target, or the app crashes when the mic is tapped:
//   NSMicrophoneUsageDescription       "Ask about products with your voice."
//   NSSpeechRecognitionUsageDescription "Turn your voice into a product search."
import AVFoundation
import Foundation
import Speech

@MainActor
final class VoiceInput: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    // Why the mic didn't start, in words that say what to do. Nil when it's fine.
    @Published var problem: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        if isListening { stop() } else { Task { await start() } }
    }

    func start() async {
        guard await Self.speechAllowed(), await AVAudioApplication.requestRecordPermission() else {
            problem = "Allow Microphone and Speech Recognition in Settings."
            return
        }
        guard recognizer?.isAvailable == true else {
            problem = "Voice isn't available right now. Type instead."
            return
        }
        problem = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
                             block: Self.tapBlock(for: request))
            engine.prepare()
            try engine.start()

            transcript = ""
            isListening = true
            task = recognizer?.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self))
        } catch {
            stop()
            problem = "Couldn't start the mic. Try again."
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // These are built outside the main actor on purpose: the audio and speech callbacks
    // run on background threads, and closures made on the main actor would trap there.
    nonisolated private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated private static func tapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func resultHandler(for owner: VoiceInput) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let done = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                if let text { owner.transcript = text }
                if done { owner.stop() }
            }
        }
    }
}
