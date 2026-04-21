import Foundation
import LlamaSwift

enum LocalLlamaError: LocalizedError {
    case modelFileMissing
    case modelLoadFailed
    case vocabUnavailable
    case contextCreationFailed
    case samplerCreationFailed
    case tokenizeFailed
    case promptTooLong
    case decodeFailed
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .modelFileMissing:
            "没有找到模型文件。"
        case .modelLoadFailed:
            "模型加载失败。"
        case .vocabUnavailable:
            "模型词表初始化失败。"
        case .contextCreationFailed:
            "推理上下文创建失败。"
        case .samplerCreationFailed:
            "采样器初始化失败。"
        case .tokenizeFailed:
            "输入分词失败。"
        case .promptTooLong:
            "这段对话太长了，先稍微收一收再试。"
        case .decodeFailed:
            "生成回复时出错了。"
        case .emptyReply:
            "它想了想，但还没组织好要说的话。"
        }
    }
}

actor LocalLlamaSession {
    private static let bootstrap: Void = {
        llama_backend_init()
    }()

    private var model: OpaquePointer?
    private var vocab: OpaquePointer?
    private var loadedModelPath: String?

    private let maxContextTokens: Int = 1024
    private let maxReplyTokens: Int = 80

    func loadModel(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LocalLlamaError.modelFileMissing
        }

        _ = Self.bootstrap

        if loadedModelPath == path, model != nil, vocab != nil {
            return
        }

        if let model {
            llama_model_free(model)
        }

        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        #endif

        guard let loadedModel = path.withCString({ llama_model_load_from_file($0, modelParams) }) else {
            model = nil
            vocab = nil
            loadedModelPath = nil
            throw LocalLlamaError.modelLoadFailed
        }

        guard let loadedVocab = llama_model_get_vocab(loadedModel) else {
            llama_model_free(loadedModel)
            model = nil
            vocab = nil
            loadedModelPath = nil
            throw LocalLlamaError.vocabUnavailable
        }

        model = loadedModel
        vocab = loadedVocab
        loadedModelPath = path
    }

    func unload() {
        if let model {
            llama_model_free(model)
        }
        model = nil
        vocab = nil
        loadedModelPath = nil
    }

    func generateReply(systemPrompt: String, messages: [PetChatMessage], maxTokens: Int? = nil, temperature: Float? = nil) throws -> String {
        guard let model, let vocab else {
            throw LocalLlamaError.modelFileMissing
        }

        let replyLimit = maxTokens ?? maxReplyTokens
        let prompt = buildPrompt(systemPrompt: systemPrompt, messages: messages)
        let promptTokens = try tokenize(prompt, vocab: vocab, addBOS: true, special: true)
        print("🦙 [LLM] prompt=\(promptTokens.count) tokens, maxReply=\(replyLimit)")

        let requiredContext = max(1024, min(maxContextTokens, promptTokens.count + replyLimit + 32))
        guard promptTokens.count < requiredContext - 32 else {
            throw LocalLlamaError.promptTooLong
        }

        let threadCount = max(1, min(6, ProcessInfo.processInfo.processorCount - 1))

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(requiredContext)
        contextParams.n_batch = UInt32(max(promptTokens.count, 128))
        contextParams.n_threads = Int32(threadCount)
        contextParams.n_threads_batch = Int32(threadCount)

        guard let context = llama_init_from_model(model, contextParams) else {
            throw LocalLlamaError.contextCreationFailed
        }
        defer { llama_free(context) }

        let samplerParams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParams) else {
            throw LocalLlamaError.samplerCreationFailed
        }
        defer { llama_sampler_free(sampler) }

        let temp = temperature ?? 0.8
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temp))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        var batch = llama_batch_init(Int32(max(promptTokens.count, 1)), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(promptTokens.count)

        for (index, token) in promptTokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            if let seqID = batch.seq_id[index] {
                seqID[0] = 0
            }
            batch.logits[index] = 0
        }

        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }

        let t0 = CFAbsoluteTimeGetCurrent()

        guard llama_decode(context, batch) == 0 else {
            throw LocalLlamaError.decodeFailed
        }

        let prefillMs = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        print("🦙 [LLM] prefill \(prefillMs)ms")

        var output = ""
        var tokenPieceBuffer: [CChar] = []
        var currentPosition = Int32(promptTokens.count)
        var generatedTokens = 0

        for _ in 0..<replyLimit {
            let nextToken = llama_sampler_sample(sampler, context, batch.n_tokens - 1)

            if llama_vocab_is_eog(vocab, nextToken) {
                break
            }

            generatedTokens += 1
            if let piece = tokenToPiece(token: nextToken, vocab: vocab, buffer: &tokenPieceBuffer) {
                output += piece
            }

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = currentPosition
            batch.n_seq_id[0] = 1
            if let seqID = batch.seq_id[0] {
                seqID[0] = 0
            }
            batch.logits[0] = 1

            currentPosition += 1

            guard llama_decode(context, batch) == 0 else {
                throw LocalLlamaError.decodeFailed
            }
        }

        let totalMs = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        print("🦙 [LLM] done: \(generatedTokens) tokens in \(totalMs)ms → \"\(output.prefix(60))\"")

        let cleaned = cleanReply(output)
        guard cleaned.isEmpty == false else {
            throw LocalLlamaError.emptyReply
        }

        return cleaned
    }

    func generateInteractionReply(systemPrompt: String, userMessage: String, maxTokens: Int? = nil, temperature: Float? = nil) throws -> String {
        let messages = [
            PetChatMessage(id: UUID(), role: .user, text: userMessage, createdAt: .now)
        ]
        return try generateReply(systemPrompt: systemPrompt, messages: messages, maxTokens: maxTokens, temperature: temperature)
    }

    private func buildPrompt(systemPrompt: String, messages: [PetChatMessage]) -> String {
        var parts: [String] = [
            "<|im_start|>system\n\(sanitize(systemPrompt))<|im_end|>"
        ]

        let recentMessages = messages.suffix(4)
        for message in recentMessages {
            let role = message.role == .user ? "user" : "assistant"
            let text = String(sanitize(message.text).prefix(80))
            parts.append("<|im_start|>\(role)\n\(text)<|im_end|>")
        }

        parts.append("<|im_start|>assistant\n<think>\n\n</think>\n\n")
        return parts.joined(separator: "\n")
    }

    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(
        _ text: String,
        vocab: OpaquePointer,
        addBOS: Bool,
        special: Bool
    ) throws -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokenCount = utf8Count + (addBOS ? 1 : 0) + 32
        let pointer = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokenCount)
        defer { pointer.deallocate() }

        let tokenCount = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            pointer,
            Int32(maxTokenCount),
            addBOS,
            special
        )

        guard tokenCount > 0 else {
            throw LocalLlamaError.tokenizeFailed
        }

        return Array(UnsafeBufferPointer(start: pointer, count: Int(tokenCount)))
    }

    private func tokenToPiece(
        token: llama_token,
        vocab: OpaquePointer,
        buffer: inout [CChar]
    ) -> String? {
        var result = [CChar](repeating: 0, count: 16)
        let pieceLength = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)

        if pieceLength < 0 {
            let actualCount = -Int(pieceLength)
            result = [CChar](repeating: 0, count: actualCount)
            let check = llama_token_to_piece(vocab, token, &result, Int32(result.count), 0, false)
            guard check == actualCount else { return nil }
        } else {
            result.removeLast(result.count - Int(pieceLength))
        }

        if buffer.isEmpty, let utf8 = String(cString: result + [0], encoding: .utf8) {
            return utf8
        }

        buffer.append(contentsOf: result)
        let data = Data(buffer.map { UInt8(bitPattern: $0) })
        if let string = String(data: data, encoding: .utf8) {
            buffer = []
            return string
        }

        if buffer.count >= 4 {
            buffer = []
        }

        return nil
    }

    private func cleanReply(_ text: String) -> String {
        var result = text

        if let range = result.range(of: "<|im_end|>") {
            result = String(result[..<range.lowerBound])
        }

        while let start = result.range(of: "<think>"), let end = result.range(of: "</think>") {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }

        result = result
            .replacingOccurrences(of: "<|im_start|>assistant", with: "")
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")

        result = Self.stripActionNarration(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripActionNarration(_ text: String) -> String {
        var s = text
        let bracketPatterns = [
            "（[^）]{0,30}）",
            "\\([^)]{0,30}\\)",
        ]
        for pat in bracketPatterns {
            if let regex = try? NSRegularExpression(pattern: pat) {
                s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
            }
        }

        let prefixes = ["喵呜", "喵鸣", "喵呜喵呜", "汪汪"]
        for prefix in prefixes {
            while s.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
                for ch: Character in ["—", "～", "~", "！", "!", " ", "，", ",", "…", "\n"] {
                    while s.hasPrefix(String(ch)) { s = String(s.dropFirst()) }
                }
            }
        }

        s = s.split(separator: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty
            }
            .prefix(3)
            .joined(separator: "\n")

        return s
    }
}
