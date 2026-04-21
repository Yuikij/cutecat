import Foundation
import AVFoundation
import Speech

@MainActor
final class SpeechService: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var isSpeaking = false
    @Published var didFinishSpeaking = false
    @Published var voiceModeActive = false

    private let synthesizer = AVSpeechSynthesizer()
    private let audioWorker = AudioEngineWorker()
    private var synthDelegate: SynthDelegate?
    private var silenceTask: Task<Void, Never>?

    private let silenceTimeout: TimeInterval = 1.8

    init() {
        synthDelegate = SynthDelegate { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isSpeaking = false
                if self.voiceModeActive {
                    try? await Task.sleep(for: .milliseconds(400))
                    if self.voiceModeActive && !self.isListening {
                        self.startListening()
                    }
                }
            }
        }
        synthesizer.delegate = synthDelegate
    }

    // MARK: - TTS

    func speak(_ text: String, style: VoiceStyle = .cute) {
        synthesizer.stopSpeaking(at: .immediate)

        let cleaned = Self.stripEmoji(text)
        guard !cleaned.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = style.rate
        utterance.pitchMultiplier = style.pitch

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private static func stripEmoji(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            let v = scalar.value
            if v <= 0x7E { return true }
            if (0x2E80...0x9FFF).contains(v) { return true }
            if (0xF900...0xFAFF).contains(v) { return true }
            if (0xFE30...0xFE4F).contains(v) { return true }
            if (0xFF00...0xFFEF).contains(v) { return true }
            if (0x20000...0x2A6DF).contains(v) { return true }
            if (0x2A700...0x2CEAF).contains(v) { return true }
            if (0x2CEB0...0x2EBEF).contains(v) { return true }
            if (0x30000...0x3134F).contains(v) { return true }
            if (0x3400...0x4DBF).contains(v) { return true }
            return false
        }
        .map { String($0) }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Voice Mode

    func enterVoiceMode() {
        voiceModeActive = true
        startListening()
    }

    func exitVoiceMode() {
        voiceModeActive = false
        stopSpeaking()
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

private final class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}
