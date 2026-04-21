import Foundation

@MainActor
final class CatMemoryStore: ObservableObject {
    @Published private(set) var nodes: [MemoryNode] = []
    @Published private(set) var isReady = false

    private let embedder = EmbeddingSession()
    private let saveURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let recencyWeight: Float = 1.0
    private let importanceWeight: Float = 1.0
    private let relevanceWeight: Float = 1.0

    private let reflectionThreshold: Int = 30

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        saveURL = docs.appendingPathComponent("cat_memories.json")
        loadFromDisk()
    }

    func bootstrap() async {
        guard let url = Bundle.main.url(forResource: "bge-small-zh-v1.5-q4_k_m", withExtension: "gguf") else {
            print("🧠 [Memory] Embedding model not found in bundle")
            return
        }
        try? await embedder.loadModel(at: url.path)
        isReady = await embedder.isLoaded
        if isReady {
            print("🧠 [Memory] Embedding model loaded, \(nodes.count) memories")
        }
    }

    // MARK: - Write

    func addMemory(
        type: MemoryNodeType,
        description: String,
        subject: String = "",
        predicate: String = "",
        object: String = "",
        poignancy: Int = 5
    ) async {
        var node = MemoryNode.make(
            type: type,
            description: description,
            subject: subject,
            predicate: predicate,
            object: object,
            poignancy: min(10, max(1, poignancy))
        )

        if isReady {
            node.embedding = await embedder.embed(description)
        }

        nodes.insert(node, at: 0)
        trimIfNeeded()
        saveToDisk()
    }

    // MARK: - Read (Retrieval)

    func retrieve(query: String, topK: Int = 5) async -> [MemoryNode] {
        guard !nodes.isEmpty else { return [] }

        let queryVec: [Float]
        if isReady {
            queryVec = await embedder.embed(query)
        } else {
            queryVec = []
        }

        let now = Date.now
        var scored: [(node: MemoryNode, score: Float)] = []

        for node in nodes {
            let recency = recencyScore(node.createdAt, now: now)
            let importance = Float(node.poignancy) / 10.0
            let relevance: Float
            if !queryVec.isEmpty && !node.embedding.isEmpty {
                relevance = cosineSimilarity(queryVec, node.embedding)
            } else {
                relevance = keywordOverlap(query, node.description)
            }

            let total = recencyWeight * recency + importanceWeight * importance + relevanceWeight * relevance
            scored.append((node, total))
        }

        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(topK).map { $0.node })
    }

    func essentialMemories(topK: Int = 5) -> [MemoryNode] {
        let sorted = nodes.sorted { $0.poignancy > $1.poignancy }
        return Array(sorted.prefix(topK))
    }

    func recentThoughts(limit: Int = 3) -> [MemoryNode] {
        return Array(nodes.filter { $0.type == .thought }.prefix(limit))
    }

    // MARK: - Reflection

    func shouldReflect() -> Bool {
        let recentNodes = nodes.prefix(10)
        let totalPoignancy = recentNodes.reduce(0) { $0 + $1.poignancy }
        let hasRecentThought = nodes.prefix(5).contains { $0.type == .thought }
        return totalPoignancy >= reflectionThreshold && !hasRecentThought
    }

    // MARK: - KG Query (simple SPO search)

    func queryRelations(subject: String) -> [MemoryNode] {
        nodes.filter {
            !$0.subject.isEmpty && $0.subject.localizedCaseInsensitiveContains(subject)
        }
    }

    // MARK: - Scoring Helpers

    private func recencyScore(_ date: Date, now: Date) -> Float {
        let hours = Float(now.timeIntervalSince(date) / 3600)
        return exp(-0.02 * hours)
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        for i in a.indices { dot += a[i] * b[i] }
        return max(0, dot)
    }

    private func keywordOverlap(_ query: String, _ text: String) -> Float {
        let queryChars = Set(query)
        let textChars = Set(text)
        let overlap = queryChars.intersection(textChars).count
        let total = max(queryChars.count, 1)
        return Float(overlap) / Float(total) * 0.5
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try encoder.encode(nodes)
            try data.write(to: saveURL, options: .atomic)
        } catch {}
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: saveURL),
              let loaded = try? decoder.decode([MemoryNode].self, from: data) else { return }
        nodes = loaded
    }

    private func trimIfNeeded() {
        let maxNodes = 200
        if nodes.count > maxNodes {
            let sorted = nodes.sorted {
                Float($0.poignancy) * recencyScore($0.createdAt, now: .now) >
                Float($1.poignancy) * recencyScore($1.createdAt, now: .now)
            }
            nodes = Array(sorted.prefix(maxNodes))
        }
    }
}
