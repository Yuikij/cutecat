import Foundation
import SwiftUI

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var state: PetState
    @Published private(set) var modelRuntimeState: PetModelRuntimeState = .idle
    @Published private(set) var isGeneratingReply = false
    @Published private(set) var modelDownloadProgress: Double = 0
    @Published private(set) var downloadedModelBytes: Int64 = 0
    @Published private(set) var expectedModelBytes: Int64 = 0

    /// Transient display mood override during animations.
    @Published var displayMood: CatMood?
    /// Transient status text shown after an interaction.
    @Published var actionStatusText: String?

    private let saveKey = "com.soukon.cutecat.save.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let llamaSession = LocalLlamaSession()
    private let modelDownloader = ModelDownloadService.shared
    private let bundledModelFileName = "Qwen3.5-0.8B-Q4_K_M.gguf"
    private let bundledModelDownloadURL = URL(string: "https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf?download=true")!

    private let tickIntervalSeconds: TimeInterval = 300 // 5 minutes

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: saveKey),
           let loaded = try? decoder.decode(PetState.self, from: data) {
            state = loaded
        } else {
            state = PetState.initial()
        }

        Task {
            await bootstrapDefaultModel()
        }
    }

    // MARK: - Computed Properties

    var currentMood: CatMood {
        displayMood ?? state.mood
    }

    var canSendChat: Bool {
        modelRuntimeState == .ready && isGeneratingReply == false
    }

    var hasDownloadProgress: Bool {
        modelRuntimeState == .downloading && expectedModelBytes > 0
    }

    var downloadProgressLabel: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        let downloaded = formatter.string(fromByteCount: downloadedModelBytes)
        let expected = expectedModelBytes > 0 ? formatter.string(fromByteCount: expectedModelBytes) : "未知大小"
        let percent = Int((modelDownloadProgress * 100).rounded())
        return "\(percent)% · \(downloaded) / \(expected)"
    }

    var hasBundledModel: Bool {
        bundledModelURL() != nil
    }

    var chatMessages: [PetChatMessage] {
        state.chatMessages
    }

    // MARK: - Interactions

    func performInteraction(_ interaction: Interaction) async {
        guard state.isDead == false else { return }
        guard isGeneratingReply == false else { return }

        switch interaction {
        case .feed:
            await handleFeed()
        case .play:
            await handlePlay()
        case .clean:
            handleClean()
        case .discipline:
            await handleDiscipline()
        case .medical:
            handleMedical()
        case .chat:
            break
        }
    }

    private func handleFeed() async {
        if state.hunger <= 0 {
            showTemporaryStatus(mood: .eating, text: "猫咪已经吃饱了！")
            return
        }

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .eating, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: feedPrompt(),
                    userMessage: "给猫咪喂食"
                )
                let emoji = extractEmoji(from: reply) ?? "🐟"
                let comment = reply.isEmpty ? "猫咪吃了东西，看起来很满足。" : reply

                state.hunger = max(0, state.hunger - Int.random(in: 2...4))
                state.happiness = min(10, state.happiness + 1)
                recordInteraction(.feed, emoji: emoji, comment: comment)
                addMemory("主人喂了猫咪：\(comment)", source: .interaction)
                showTemporaryStatus(mood: .eating, text: comment)
            } catch {
                state.hunger = max(0, state.hunger - 2)
                state.happiness = min(10, state.happiness + 1)
                let fallback = feedFallbackComment()
                recordInteraction(.feed, emoji: "🐟", comment: fallback)
                showTemporaryStatus(mood: .eating, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.hunger = max(0, state.hunger - 2)
            state.happiness = min(10, state.happiness + 1)
            let fallback = feedFallbackComment()
            recordInteraction(.feed, emoji: "🐟", comment: fallback)
            showTemporaryStatus(mood: .eating, text: fallback)
        }

        save()
    }

    private func handlePlay() async {
        if state.energy <= 1 {
            showTemporaryStatus(mood: .sleeping, text: "猫咪太累了，不想玩…")
            return
        }

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .playing, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: playPrompt(),
                    userMessage: "和猫咪玩耍"
                )
                let emoji = extractEmoji(from: reply) ?? "🧶"
                let comment = reply.isEmpty ? "猫咪玩得很开心！" : reply

                state.happiness = min(10, state.happiness + Int.random(in: 1...3))
                state.energy = max(0, state.energy - 2)
                state.hunger = min(10, state.hunger + 1)
                recordInteraction(.play, emoji: emoji, comment: comment)
                addMemory("主人和猫咪玩了：\(comment)", source: .interaction)
                showTemporaryStatus(mood: .playing, text: comment)
            } catch {
                state.happiness = min(10, state.happiness + 2)
                state.energy = max(0, state.energy - 2)
                let fallback = playFallbackComment()
                recordInteraction(.play, emoji: "🧶", comment: fallback)
                showTemporaryStatus(mood: .playing, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.happiness = min(10, state.happiness + 2)
            state.energy = max(0, state.energy - 2)
            let fallback = playFallbackComment()
            recordInteraction(.play, emoji: "🧶", comment: fallback)
            showTemporaryStatus(mood: .playing, text: fallback)
        }

        save()
    }

    private func handleClean() {
        state.cleanliness = min(10, state.cleanliness + 3)
        state.happiness = min(10, state.happiness + 1)

        let comments = [
            "猫咪被洗得干干净净，甩了甩毛。",
            "虽然不太情愿，但洗完澡舒服多了。",
            "猫咪舔了舔爪子，对自己的干净程度很满意。",
            "水花溅了一地，但猫咪看起来精神多了。"
        ]
        let comment = comments.randomElement()!
        recordInteraction(.clean, emoji: "🫧", comment: comment)
        showTemporaryStatus(mood: .bathing, text: comment)
        save()
    }

    private func handleDiscipline() async {
        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .disciplined, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: disciplinePrompt(),
                    userMessage: "管教猫咪"
                )
                let comment = reply.isEmpty ? "猫咪低下了头，好像知道自己做错了。" : reply

                state.happiness = max(0, state.happiness - 1)
                recordInteraction(.discipline, emoji: "😾", comment: comment)
                addMemory("主人管教了猫咪：\(comment)", source: .interaction)
                showTemporaryStatus(mood: .disciplined, text: comment)
            } catch {
                state.happiness = max(0, state.happiness - 1)
                let fallback = "猫咪低下了头，好像知道自己做错了。"
                recordInteraction(.discipline, emoji: "😾", comment: fallback)
                showTemporaryStatus(mood: .disciplined, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.happiness = max(0, state.happiness - 1)
            let fallback = "猫咪低下了头，好像知道自己做错了。"
            recordInteraction(.discipline, emoji: "😾", comment: fallback)
            showTemporaryStatus(mood: .disciplined, text: fallback)
        }

        save()
    }

    private func handleMedical() {
        state.health = min(10, state.health + 3)
        state.happiness = max(0, state.happiness - 1)

        let comments = [
            "看了医生，猫咪的状态好了一些。",
            "吃了药，虽然有点苦，但很快会好的。",
            "打了一针，猫咪委屈地叫了一声。"
        ]
        let comment = comments.randomElement()!
        recordInteraction(.medical, emoji: "💊", comment: comment)
        showTemporaryStatus(mood: .sick, text: comment)
        save()
    }

    // MARK: - Chat

    func sendChatMessage(_ rawText: String) async {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard modelRuntimeState == .ready else {
            modelRuntimeState = .failed("猫咪还没完全醒过来，等一小会儿吧。")
            return
        }
        guard isGeneratingReply == false else { return }

        state.chatMessages.append(
            PetChatMessage(id: UUID(), role: .user, text: trimmed, createdAt: .now)
        )
        trimChatHistory()
        save()

        isGeneratingReply = true

        do {
            let reply = try await llamaSession.generateReply(
                systemPrompt: chatSystemPrompt(),
                messages: state.chatMessages
            )
            state.chatMessages.append(
                PetChatMessage(id: UUID(), role: .pet, text: reply, createdAt: .now)
            )
            trimChatHistory()
            consolidateMemoryIfNeeded()
            save()
        } catch LocalLlamaError.emptyReply {
            state.chatMessages.append(
                PetChatMessage(id: UUID(), role: .pet, text: defaultSoftReply(), createdAt: .now)
            )
            save()
        } catch {
            modelRuntimeState = .failed("它今天有点困，晚点再来找它吧。")
        }

        isGeneratingReply = false
    }

    // MARK: - State Tick

    func tick(now: Date = .now) {
        guard state.isDead == false else { return }

        let elapsed = now.timeIntervalSince(state.lastTickAt)
        guard elapsed >= tickIntervalSeconds else { return }

        let ticksPassed = max(1, Int(elapsed / tickIntervalSeconds))

        for _ in 0..<ticksPassed {
            state.hunger = min(10, state.hunger + 1)
            state.energy = min(10, state.energy + 1)
            state.cleanliness = max(0, state.cleanliness - 1)

            if state.hunger >= 8 {
                state.happiness = max(0, state.happiness - 1)
            }
            if state.cleanliness <= 2 {
                state.health = max(0, state.health - 1)
            }

            state.age += 1
        }

        if state.happiness <= 0 && state.health <= 0 && state.hunger >= 10 {
            state.isDead = true
            state.comment = "猫咪永远地睡着了…"
        }

        state.lastTickAt = now
        save()
    }

    /// Async tick that uses LLM to generate a comment about the pet's current state.
    func llmTick(now: Date = .now) async {
        tick(now: now)

        guard state.isDead == false else { return }
        guard modelRuntimeState == .ready else { return }
        guard isGeneratingReply == false else { return }

        isGeneratingReply = true

        do {
            let reply = try await llamaSession.generateInteractionReply(
                systemPrompt: tickPrompt(),
                userMessage: "描述一下猫咪现在的状态"
            )
            if reply.isEmpty == false {
                state.comment = reply
                save()
            }
        } catch {
            // Non-critical: keep existing comment
        }

        isGeneratingReply = false
    }

    // MARK: - Model Bootstrap

    func redownloadModel() async {
        await downloadBundledModel(force: true)
    }

    private func bootstrapDefaultModel() async {
        if let bundledURL = bundledModelURL() {
            modelRuntimeState = .loading
            do {
                try await llamaSession.loadModel(at: bundledURL.path)
                state.localModelFileName = bundledURL.lastPathComponent
                state.localModelDisplayName = "内置 \(bundledURL.lastPathComponent)"
                modelRuntimeState = .ready
                save()
                return
            } catch {
                modelRuntimeState = .failed(error.localizedDescription)
            }
        }

        if let modelURL = importedModelURL() {
            modelRuntimeState = .loading
            do {
                try await llamaSession.loadModel(at: modelURL.path)
                state.localModelFileName = bundledModelFileName
                state.localModelDisplayName = bundledModelFileName
                modelRuntimeState = .ready
                save()
                return
            } catch {
                modelRuntimeState = .failed(error.localizedDescription)
            }
        }

        await downloadBundledModel(force: false)
    }

    private func downloadBundledModel(force: Bool) async {
        do {
            let destinationURL = try managedModelURL(for: bundledModelFileName)

            if force == false, FileManager.default.fileExists(atPath: destinationURL.path) {
                modelRuntimeState = .loading
                try await llamaSession.loadModel(at: destinationURL.path)
                state.localModelFileName = bundledModelFileName
                state.localModelDisplayName = bundledModelFileName
                modelRuntimeState = .ready
                save()
                return
            }

            modelRuntimeState = .downloading
            updateDownloadProgress(progress: 0, downloadedBytes: 0, expectedBytes: 0)
            await llamaSession.unload()

            let temporaryURL = try await modelDownloader.download(
                from: bundledModelDownloadURL,
                forceRestart: force
            ) { progress, downloadedBytes, expectedBytes in
                self.updateDownloadProgress(
                    progress: progress,
                    downloadedBytes: downloadedBytes,
                    expectedBytes: expectedBytes
                )
            }

            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            updateDownloadProgress(progress: 1, downloadedBytes: expectedModelBytes, expectedBytes: expectedModelBytes)

            modelRuntimeState = .loading
            try await llamaSession.loadModel(at: destinationURL.path)

            state.localModelFileName = bundledModelFileName
            state.localModelDisplayName = bundledModelFileName
            modelRuntimeState = .ready
            resetDownloadProgress()
            save()
        } catch {
            resetDownloadProgress()
            modelRuntimeState = .failed("猫咪今天状态不太好，晚点再来找它吧。")
        }
    }

    // MARK: - Prompts

    private func chatSystemPrompt() -> String {
        let memoryContext: String
        if state.memories.isEmpty {
            memoryContext = ""
        } else {
            let recent = state.memories.prefix(5).map { "• \($0.summary)" }.joined(separator: "\n")
            memoryContext = "\n你的重要记忆：\n\(recent)"
        }

        return """
        你是一只住在手机里的小猫咪。你有自己的小脾气和想法。
        你的状态：开心程度 \(state.happiness)/10，饥饿 \(state.hunger)/10，健康 \(state.health)/10，精力 \(state.energy)/10。
        你已经 \(state.age) 岁了（游戏年龄）。\(memoryContext)
        你不是AI助手，你是一只真正的猫。
        回复要求：
        1. 使用简体中文。
        2. 每次回复 1 到 3 句，控制在 60 字以内。
        3. 语气可以有点奇怪、跳脱、抽象，像一只有灵魂的猫。
        4. 偶尔说一些莫名其妙但有趣的话。
        5. 不要长篇大论，像猫一样简短。
        """
    }

    private func feedPrompt() -> String {
        """
        你是一只小猫咪，主人正在喂你吃东西。
        你现在的饥饿程度是 \(state.hunger)/10。
        用 1-2 句话描述你吃东西的反应。可以提到你想象中吃的是什么。
        语气可以奇怪、可爱、或者有点发癫。不要超过 40 个字。
        """
    }

    private func playPrompt() -> String {
        """
        你是一只小猫咪，主人想和你玩。
        你现在的精力是 \(state.energy)/10，开心程度是 \(state.happiness)/10。
        用 1-2 句话描述你玩耍的反应。可以想象一个奇怪的玩法。
        语气可以跳脱、抽象、有趣。不要超过 40 个字。
        """
    }

    private func disciplinePrompt() -> String {
        """
        你是一只小猫咪，主人正在管教你。
        你现在的开心程度是 \(state.happiness)/10。
        用 1-2 句话描述你被管教后的反应。可以委屈也可以不服气。
        不要超过 40 个字。
        """
    }

    private func tickPrompt() -> String {
        let recentInteractions = state.interactions.suffix(3).map {
            "\($0.interaction.title): \($0.comment)"
        }.joined(separator: "\n")

        return """
        你是一只住在手机里的小猫咪。
        当前状态：开心 \(state.happiness)/10，饥饿 \(state.hunger)/10，健康 \(state.health)/10，干净 \(state.cleanliness)/10，精力 \(state.energy)/10。
        年龄：\(state.age)。
        最近发生的事：
        \(recentInteractions.isEmpty ? "（没什么事发生）" : recentInteractions)
        用一句话描述你现在的心情或在做什么。可以奇怪、抽象、有趣。不超过 30 字。
        """
    }

    // MARK: - Fallback Comments

    private func feedFallbackComment() -> String {
        [
            "猫咪大口大口地吃了起来，尾巴翘得老高。",
            "它闻了闻，然后满意地埋头吃了。",
            "咕噜咕噜，好像很好吃的样子。",
            "猫咪歪着头看了一眼，然后开始吃了。",
            "它吃了一口，然后舔了舔嘴巴。"
        ].randomElement()!
    }

    private func playFallbackComment() -> String {
        [
            "猫咪疯狂地追着什么东西跑了起来！",
            "它在地上打了个滚，露出肚皮。",
            "猫咪跳来跳去，玩得很开心。",
            "它扑向了一个看不见的目标。",
            "猫咪用爪子拍了拍空气，好像在抓蝴蝶。"
        ].randomElement()!
    }

    private func defaultSoftReply() -> String {
        [
            "它蹭了蹭你的手，像是在轻轻回应。",
            "猫咪眯了眯眼睛，尾巴轻轻摇了一下。",
            "喵…（含义不明）",
            "它打了个小哈欠，然后继续盯着你看。",
            "猫咪歪了歪头，好像在想什么深奥的问题。"
        ].randomElement()!
    }

    // MARK: - Helpers

    private func recordInteraction(_ interaction: Interaction, emoji: String, comment: String) {
        let record = InteractionRecord(
            id: UUID(),
            interaction: interaction,
            emoji: emoji,
            comment: comment,
            createdAt: .now
        )
        state.interactions.append(record)
        if state.interactions.count > 50 {
            state.interactions.removeFirst(state.interactions.count - 50)
        }
    }

    private func addMemory(_ summary: String, source: MemorySourceType) {
        let memory = MemoryRecord(
            id: UUID(),
            summary: String(summary.prefix(80)),
            createdAt: .now,
            sourceType: source
        )
        state.memories.insert(memory, at: 0)
        if state.memories.count > 30 {
            state.memories = Array(state.memories.prefix(30))
        }
    }

    private func trimChatHistory() {
        let overflow = state.chatMessages.count - 24
        if overflow > 0 {
            state.chatMessages.removeFirst(overflow)
        }
    }

    private func consolidateMemoryIfNeeded() {
        let recentMessages = state.chatMessages.suffix(6)
        guard recentMessages.count >= 6 else { return }

        let petMessages = recentMessages.filter { $0.role == .pet }
        guard let lastPet = petMessages.last else { return }

        let convCount = state.memories.filter { $0.sourceType == .conversation }.count
        if convCount < state.chatMessages.count / 8 {
            addMemory("和主人聊天：\(lastPet.text.prefix(40))", source: .conversation)
        }
    }

    private func showTemporaryStatus(mood: CatMood, text: String?) {
        displayMood = mood
        actionStatusText = text

        Task {
            try? await Task.sleep(for: .seconds(6))
            displayMood = nil
            actionStatusText = nil
        }
    }

    private func extractEmoji(from text: String) -> String? {
        text.first { $0.unicodeScalars.allSatisfy { $0.properties.isEmoji && $0.value > 0x238C } }.map(String.init)
    }

    private func save() {
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func updateDownloadProgress(progress: Double, downloadedBytes: Int64, expectedBytes: Int64) {
        modelDownloadProgress = progress
        self.downloadedModelBytes = downloadedBytes
        self.expectedModelBytes = expectedBytes
    }

    private func resetDownloadProgress() {
        modelDownloadProgress = 0
        downloadedModelBytes = 0
        expectedModelBytes = 0
    }

    private func managedModelURL(for fileName: String) throws -> URL {
        try modelsDirectoryURL().appending(path: fileName, directoryHint: .notDirectory)
    }

    private func bundledModelURL() -> URL? {
        Bundle.main.url(
            forResource: "Qwen3.5-0.8B-Q4_K_M",
            withExtension: "gguf",
            subdirectory: "Resources/Models"
        ) ?? Bundle.main.url(
            forResource: "Qwen3.5-0.8B-Q4_K_M",
            withExtension: "gguf"
        )
    }

    private func importedModelURL() -> URL? {
        guard let directory = try? modelsDirectoryURL() else { return nil }
        let fileName = state.localModelFileName ?? bundledModelFileName
        let url = directory.appending(path: fileName, directoryHint: .notDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func modelsDirectoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appending(path: "Models", directoryHint: .isDirectory)
    }
}
