import Foundation
import LlamaSwift

actor EmbeddingSession {
    private static let bootstrap: Void = {
        llama_backend_init()
    }()

    private var model: OpaquePointer?
    private var vocab: OpaquePointer?
    private var embeddingDim: Int = 0

    func loadModel(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }

        _ = Self.bootstrap

        if model != nil { return }

        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        #endif

        guard let loaded = path.withCString({ llama_model_load_from_file($0, modelParams) }) else {
            return
        }

        guard let loadedVocab = llama_model_get_vocab(loaded) else {
            llama_model_free(loaded)
            return
        }

        model = loaded
        vocab = loadedVocab
        embeddingDim = Int(llama_model_n_embd(loaded))
    }

    var isLoaded: Bool { model != nil }

    func embed(_ text: String) -> [Float] {
        guard let model, let vocab else { return [] }
        guard embeddingDim > 0 else { return [] }

        let tokens = tokenize(text, vocab: vocab)
        guard !tokens.isEmpty else { return [] }

        let threadCount = max(1, min(4, ProcessInfo.processInfo.processorCount - 1))

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(min(512, tokens.count + 16))
        contextParams.n_batch = UInt32(min(512, max(tokens.count, 64)))
        contextParams.n_threads = Int32(threadCount)
        contextParams.n_threads_batch = Int32(threadCount)
        contextParams.embeddings = true

        guard let context = llama_init_from_model(model, contextParams) else {
            return []
        }
        defer { llama_free(context) }

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(tokens.count)
        for (i, token) in tokens.enumerated() {
            batch.token[i] = token
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            if let seqID = batch.seq_id[i] {
                seqID[0] = 0
            }
            batch.logits[i] = 0
        }
        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }

        guard llama_decode(context, batch) == 0 else {
            return []
        }

        guard let embPtr = llama_get_embeddings_seq(context, 0) else {
            return []
        }

        var vec = Array(UnsafeBufferPointer(start: embPtr, count: embeddingDim))
        normalize(&vec)
        return vec
    }

    private func normalize(_ vec: inout [Float]) {
        let norm = sqrt(vec.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return }
        for i in vec.indices { vec[i] /= norm }
    }

    private func tokenize(_ text: String, vocab: OpaquePointer) -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokenCount = utf8Count + 33
        let pointer = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokenCount)
        defer { pointer.deallocate() }

        let count = llama_tokenize(vocab, text, Int32(utf8Count), pointer, Int32(maxTokenCount), true, true)
        guard count > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: pointer, count: Int(count)))
    }
}
