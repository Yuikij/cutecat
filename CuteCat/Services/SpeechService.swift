import Foundation
import AVFoundation
import Speech

@MainActor
final class SpeechService: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var didFinishSpeaking = false
    @Published var voiceModeActive = false

    private let audioWorker = AudioEngineWorker()
    private var silenceTask: Task<Void, Never>?

    private let silenceTimeout: TimeInterval = 1.8

    // MARK: - Voice Mode

    func enterVoiceMode() {
        voiceModeActive = true
        startListening()
    }

    func exitVoiceMode() {
        voiceModeActive = false
        stopListening()
    }

    // MARK: - STT

    func startListening() {
        guard !isListening else { return }

        isListening = true
        transcript = ""
        didFinishSpeaking = false
        silenceTask?.cancel()

        audioWorker.start { [weak self] partialText, finished in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let partialText {
                    self.transcript = partialText
                    self.resetSilenceTimer()
                }
                if finished {
                    self.silenceTask?.cancel()
                    if !self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.didFinishSpeaking = true
                    }
                    self.isListening = false
                }
            }
        }
    }

    func stopListening() {
        silenceTask?.cancel()
        audioWorker.stop()
        isListening = false
    }

    private func resetSilenceTimer() {
        silenceTask?.cancel()
        let currentTranscript = transcript
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(self?.silenceTimeout ?? 1.8) * 1000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.isListening && self.transcript == currentTranscript &&
                !currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.audioWorker.stop()
                self.isListening = false
                self.didFinishSpeaking = true
            }
        }
    }
}

private final class AudioEngineWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.cutecat.audioEngine")
    private var engine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func start(onUpdate: @Sendable @escaping (String?, Bool) -> Void) {
        queue.async { [self] in
            self.beginOnQueue(onUpdate: onUpdate)
        }
    }

    func stop() {
        queue.async { [self] in
            self.teardownOnQueue()
        }
    }

    private func beginOnQueue(onUpdate: @Sendable @escaping (String?, Bool) -> Void) {
        teardownOnQueue()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onUpdate(nil, true)
            return
        }

        SFSpeechRecognizer.requestAuthorization { [self] status in
            guard status == .authorized else {
                onUpdate(nil, true)
                return
            }
            AVAudioApplication.requestRecordPermission { [self] granted in
                guard granted else {
                    onUpdate(nil, true)
                    return
                }
                self.queue.async { [self] in
                    self.startEngineOnQueue(onUpdate: onUpdate)
                }
            }
        }
    }

    private func startEngineOnQueue(onUpdate: @Sendable @escaping (String?, Bool) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            onUpdate(nil, true)
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let eng = AVAudioEngine()
        self.engine = eng

        let inputNode = eng.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else {
            onUpdate(nil, true)
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }

        eng.prepare()
        do {
            try eng.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.engine = nil
            self.request = nil
            onUpdate(nil, true)
            return
        }

        recognitionTask = recognizer.recognitionTask(with: req) { [self] result, error in
            if let result {
                onUpdate(result.bestTranscription.formattedString, false)
            }
            if error != nil || (result?.isFinal ?? false) {
                self.queue.async { [self] in
                    self.teardownOnQueue()
                }
                onUpdate(nil, true)
            }
        }
    }

    private func teardownOnQueue() {
        recognitionTask?.cancel()
        recognitionTask = nil
        request?.endAudio()
        request = nil

        if let eng = engine {
            eng.stop()
            eng.inputNode.removeTap(onBus: 0)
        }
        engine = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
