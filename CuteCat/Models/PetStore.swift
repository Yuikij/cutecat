import Foundation
import SwiftUI

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var state: PetState
    @Published private(set) var modelRuntimeState: PetModelRuntimeState = .idle
    @Published private(set) var isGeneratingReply = false

    @Published var displayMood: CatMood?
    @Published var actionStatusText: String?
    @Published var lastActionEmoji: String?

    @Published var pendingEvent: CatEvent?
    @Published var eventResult: String?
    @Published var pendingSpeak: String?
    @Published var catMoodWord: String?

    let memoryStore = CatMemoryStore()

    private let saveKey = "com.soukon.cutecat.save.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let llamaSession = LocalLlamaSession()
    private let bundledModelFileName = "Qwen3.5-0.8B-Q4_K_M.gguf"

    private let tickIntervalSeconds: TimeInterval = 300
    private let eventCooldownSeconds: TimeInterval = 600

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
            await memoryStore.bootstrap()
        }
    }

    // MARK: - Computed Properties

    var currentMood: CatMood {
        displayMood ?? state.mood
    }

    var canSendChat: Bool {
        modelRuntimeState == .ready && isGeneratingReply == false
    }

    var chatMessages: [PetChatMessage] {
        state.chatMessages
    }

    var affinityLevel: AffinityLevel {
        state.affinityLevel
    }

    var catName: String { state.catName }

    func renameCat(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.catName = trimmed
        save()
    }

    func setVoiceStyle(_ style: VoiceStyle) {
        state.voiceStyle = style
        save()
    }

    // MARK: - Interactions

    func performInteraction(_ interaction: Interaction) async {
        guard state.isDead == false else { return }
        guard isGeneratingReply == false else { return }

        switch interaction {
        case .feed:
            state.traitScore.feedCount += 1
            await handleFeed()
        case .play:
            state.traitScore.playCount += 1
            await handlePlay()
        case .clean:
            state.traitScore.cleanCount += 1
            await handleClean()
        case .discipline:
            state.traitScore.disciplineCount += 1
            await handleDiscipline()
        case .medical:
            state.traitScore.medicalCount += 1
            await handleMedical()
        case .chat:
            state.traitScore.chatCount += 1
            break
        case .headpat, .belly, .cuddle:
            state.traitScore.touchCount += 1
            if interaction == .headpat { await handleHeadpat() }
            else if interaction == .belly { await handleBelly() }
            else { await handleCuddle() }
        }
        maybeDropTreasure()
        checkAchievements()
    }

    private func handleFeed() async {
        if state.hunger <= 0 {
            displayMood = .eating
            actionStatusText = "猫咪已经吃饱了！"
            lastActionEmoji = "😫"
            adjustAffinity(-1)
            Task {
                try? await Task.sleep(for: .seconds(4))
                displayMood = nil
                actionStatusText = nil
                lastActionEmoji = nil
            }
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
                adjustAffinity(2)
                recordInteraction(.feed, emoji: emoji, comment: comment)
                addMemory("主人喂了猫咪：\(comment)", source: .interaction, poignancy: 4)
                showTemporaryStatus(mood: .eating, text: comment, emoji: emoji)
            } catch {
                state.hunger = max(0, state.hunger - 2)
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(1)
                let fallback = feedFallbackComment()
                recordInteraction(.feed, emoji: "🐟", comment: fallback)
                showTemporaryStatus(mood: .eating, text: fallback, emoji: "🐟")
            }

            isGeneratingReply = false
        } else {
            state.hunger = max(0, state.hunger - 2)
            state.happiness = min(10, state.happiness + 1)
            adjustAffinity(1)
            let fallback = feedFallbackComment()
            recordInteraction(.feed, emoji: "🐟", comment: fallback)
            showTemporaryStatus(mood: .eating, text: fallback, emoji: "🐟")
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
            showTemporaryStatus(mood: .playing, text: nil, emoji: "🧶")

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
                adjustAffinity(3)
                recordInteraction(.play, emoji: emoji, comment: comment)
                addMemory("主人和猫咪玩了：\(comment)", source: .interaction, poignancy: 6)
                showTemporaryStatus(mood: .playing, text: comment, emoji: emoji)
            } catch {
                state.happiness = min(10, state.happiness + 2)
                state.energy = max(0, state.energy - 2)
                adjustAffinity(2)
                let fallback = playFallbackComment()
                recordInteraction(.play, emoji: "🧶", comment: fallback)
                showTemporaryStatus(mood: .playing, text: fallback, emoji: "🧶")
            }

            isGeneratingReply = false
        } else {
            state.happiness = min(10, state.happiness + 2)
            state.energy = max(0, state.energy - 2)
            adjustAffinity(2)
            let fallback = playFallbackComment()
            recordInteraction(.play, emoji: "🧶", comment: fallback)
            showTemporaryStatus(mood: .playing, text: fallback, emoji: "🧶")
        }

        save()
    }

    private func handleClean() async {
        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .bathing, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: cleanPrompt(),
                    userMessage: "给猫咪洗澡"
                )
                let comment = reply.isEmpty ? "猫咪被洗得干干净净，甩了甩毛。" : reply

                state.cleanliness = min(10, state.cleanliness + 3)
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(1)
                recordInteraction(.clean, emoji: "🫧", comment: comment)
                addMemory("主人给猫咪洗了澡：\(comment)", source: .interaction, poignancy: 4)
                showTemporaryStatus(mood: .bathing, text: comment)
            } catch {
                state.cleanliness = min(10, state.cleanliness + 3)
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(1)
                let fallback = cleanFallbackComment()
                recordInteraction(.clean, emoji: "🫧", comment: fallback)
                showTemporaryStatus(mood: .bathing, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.cleanliness = min(10, state.cleanliness + 3)
            state.happiness = min(10, state.happiness + 1)
            adjustAffinity(1)
            let fallback = cleanFallbackComment()
            recordInteraction(.clean, emoji: "🫧", comment: fallback)
            showTemporaryStatus(mood: .bathing, text: fallback)
        }

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
                adjustAffinity(-3)
                recordInteraction(.discipline, emoji: "😾", comment: comment)
                addMemory("主人管教了猫咪：\(comment)", source: .interaction, poignancy: 7)
                showTemporaryStatus(mood: .disciplined, text: comment)
            } catch {
                state.happiness = max(0, state.happiness - 1)
                adjustAffinity(-2)
                let fallback = "猫咪低下了头，好像知道自己做错了。"
                recordInteraction(.discipline, emoji: "😾", comment: fallback)
                showTemporaryStatus(mood: .disciplined, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.happiness = max(0, state.happiness - 1)
            adjustAffinity(-2)
            let fallback = "猫咪低下了头，好像知道自己做错了。"
            recordInteraction(.discipline, emoji: "😾", comment: fallback)
            showTemporaryStatus(mood: .disciplined, text: fallback)
        }

        save()
    }

    private func handleMedical() async {
        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .sick, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: medicalPrompt(),
                    userMessage: "带猫咪看病"
                )
                let comment = reply.isEmpty ? "看了医生，猫咪的状态好了一些。" : reply

                state.health = min(10, state.health + 3)
                state.happiness = max(0, state.happiness - 1)
                adjustAffinity(1)
                recordInteraction(.medical, emoji: "💊", comment: comment)
                addMemory("主人带猫咪看了医生：\(comment)", source: .interaction, poignancy: 5)
                showTemporaryStatus(mood: .sick, text: comment)
            } catch {
                state.health = min(10, state.health + 3)
                state.happiness = max(0, state.happiness - 1)
                adjustAffinity(1)
                let fallback = medicalFallbackComment()
                recordInteraction(.medical, emoji: "💊", comment: fallback)
                showTemporaryStatus(mood: .sick, text: fallback)
            }

            isGeneratingReply = false
        } else {
            state.health = min(10, state.health + 3)
            state.happiness = max(0, state.happiness - 1)
            adjustAffinity(1)
            let fallback = medicalFallbackComment()
            recordInteraction(.medical, emoji: "💊", comment: fallback)
            showTemporaryStatus(mood: .sick, text: fallback)
        }

        save()
    }

    private func handleHeadpat() async {
        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .headpat, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: headpatPrompt(),
                    userMessage: "摸猫咪的头"
                )
                let comment = reply.isEmpty ? "猫咪眯起眼睛，发出了咕噜声。" : reply
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(state.affinity >= 40 ? 3 : 1)
                recordInteraction(.headpat, emoji: "✋", comment: comment)
                addMemory("主人摸了猫咪的头：\(comment)", source: .interaction, poignancy: 5)
                showTemporaryStatus(mood: .headpat, text: comment)
            } catch {
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(1)
                showTemporaryStatus(mood: .headpat, text: "猫咪歪了歪头，接受了你的抚摸。")
            }

            isGeneratingReply = false
        } else {
            state.happiness = min(10, state.happiness + 1)
            adjustAffinity(1)
            showTemporaryStatus(mood: .headpat, text: "猫咪歪了歪头，接受了你的抚摸。")
        }
        save()
    }

    private func handleBelly() async {
        let willBite = state.affinity < 40 && Bool.random()

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .bellyUp, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: bellyPrompt(willBite: willBite),
                    userMessage: "摸猫咪的肚子"
                )
                let comment = reply.isEmpty ? (willBite ? "猫咪咬了你一口！" : "猫咪露出了肚皮。") : reply

                if willBite {
                    state.happiness = max(0, state.happiness - 1)
                    adjustAffinity(-2)
                } else {
                    state.happiness = min(10, state.happiness + 2)
                    adjustAffinity(4)
                }
                recordInteraction(.belly, emoji: willBite ? "😾" : "🐾", comment: comment)
                addMemory("主人摸猫咪肚子：\(comment)", source: .interaction, poignancy: 5)
                showTemporaryStatus(mood: willBite ? .disciplined : .bellyUp, text: comment)
            } catch {
                if willBite {
                    adjustAffinity(-1)
                    showTemporaryStatus(mood: .disciplined, text: "猫咪翻了个身，然后咬了你一口！")
                } else {
                    adjustAffinity(2)
                    showTemporaryStatus(mood: .bellyUp, text: "猫咪翻过身，露出了毛茸茸的肚皮。")
                }
            }

            isGeneratingReply = false
        } else {
            if willBite {
                adjustAffinity(-1)
                showTemporaryStatus(mood: .disciplined, text: "猫咪翻了个身，然后咬了你一口！")
            } else {
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(2)
                showTemporaryStatus(mood: .bellyUp, text: "猫咪翻过身，露出了毛茸茸的肚皮。")
            }
        }
        save()
    }

    private func handleCuddle() async {
        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .shy, text: nil)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: cuddlePrompt(),
                    userMessage: "对猫咪撒娇"
                )
                let comment = reply.isEmpty ? "猫咪害羞地别过了头。" : reply
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(state.affinity >= 60 ? 3 : 1)
                recordInteraction(.cuddle, emoji: "💕", comment: comment)
                addMemory("主人对猫咪撒娇：\(comment)", source: .interaction, poignancy: 6)
                showTemporaryStatus(mood: .shy, text: comment)
            } catch {
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(1)
                showTemporaryStatus(mood: .shy, text: "猫咪害羞地别过了头。")
            }

            isGeneratingReply = false
        } else {
            state.happiness = min(10, state.happiness + 1)
            adjustAffinity(1)
            showTemporaryStatus(mood: .shy, text: "猫咪害羞地别过了头。")
        }
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
        adjustAffinity(1)
        save()

        isGeneratingReply = true
        displayMood = .thinking

        await prepareMemoryContext(for: trimmed)

        do {
            let reply = try await llamaSession.generateReply(
                systemPrompt: chatSystemPrompt(),
                messages: state.chatMessages
            )

            cachedMemoryContext = ""

            displayMood = .chatting
            state.chatMessages.append(
                PetChatMessage(id: UUID(), role: .pet, text: reply, createdAt: .now)
            )
            state.comment = reply
            pendingSpeak = reply
            trimChatHistory()
            consolidateMemoryIfNeeded()
            save()

            Task { await maybeReflect() }

            Task {
                try? await Task.sleep(for: .seconds(4))
                if displayMood == .chatting { displayMood = nil }
            }
        } catch LocalLlamaError.emptyReply {
            let fallback = defaultSoftReply()
            displayMood = .chatting
            state.chatMessages.append(
                PetChatMessage(id: UUID(), role: .pet, text: fallback, createdAt: .now)
            )
            state.comment = fallback
            save()

            Task {
                try? await Task.sleep(for: .seconds(4))
                if displayMood == .chatting { displayMood = nil }
            }
        } catch {
            displayMood = nil
            modelRuntimeState = .failed("它今天有点困，晚点再来找它吧。")
        }

        isGeneratingReply = false
    }

    // MARK: - Shop & Inventory

    var inventory: [ShopItem] {
        state.inventoryItems
    }

    func generateShopItems() async -> [ShopItem]? {
        guard modelRuntimeState == .ready else { return nil }

        let prompt = shopPrompt()
        let userMsg = "开门营业"
        print("🏪 [Shop] System Prompt:\n\(prompt)")
        print("🏪 [Shop] User Message: \(userMsg)")

        do {
            let reply = try await llamaSession.generateInteractionReply(
                systemPrompt: prompt,
                userMessage: userMsg,
                maxTokens: 256,
                temperature: 1.2
            )
            print("🏪 [Shop] LLM Raw Output:\n\(reply)")

            let items = parseShopJSON(reply)
            if let items {
                print("🏪 [Shop] Parsed \(items.count) items: \(items.map { "\($0.emoji)\($0.name)" })")
            } else {
                print("🏪 [Shop] Parse FAILED — showing 打烊了")
            }
            return items
        } catch {
            print("🏪 [Shop] LLM Error: \(error)")
            return nil
        }
    }

    func buyItem(_ item: ShopItem) {
        state.inventoryItems.append(item)
        state.totalShopBuys += 1
        if state.inventoryItems.count > 20 {
            state.inventoryItems.removeFirst()
        }
        checkAchievements()
        save()
    }

    func feedItemToCat(_ item: ShopItem) async {
        state.inventoryItems.removeAll { $0.id == item.id }

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            showTemporaryStatus(mood: .eating, text: nil, emoji: item.emoji)

            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: feedItemPrompt(item),
                    userMessage: "给猫咪喂\(item.emoji)\(item.name)",
                    maxTokens: 120,
                    temperature: 1.1
                )

                let parsed = parseFeedItemEffect(reply, item: item)
                state.hunger = max(0, min(10, state.hunger + parsed.hungerDelta))
                state.happiness = max(0, min(10, state.happiness + parsed.happinessDelta))
                state.energy = max(0, min(10, state.energy + parsed.energyDelta))
                state.health = max(0, min(state.growthStage.maxHealth, state.health + parsed.healthDelta))
                adjustAffinity(parsed.affinityDelta)
                recordInteraction(.feed, emoji: item.emoji, comment: parsed.comment)
                addMemory("猫咪吃了\(item.name)：\(parsed.comment)", source: .interaction, poignancy: 6)
                showTemporaryStatus(mood: parsed.mood, text: parsed.comment, emoji: item.emoji)
            } catch {
                applyDefaultFeedItem(item)
            }
            isGeneratingReply = false
        } else {
            applyDefaultFeedItem(item)
        }

        state.traitScore.feedCount += 1
        maybeDropTreasure()
        checkAchievements()
        save()
    }

    private func applyDefaultFeedItem(_ item: ShopItem) {
        state.hunger = max(0, state.hunger - Int.random(in: 2...4))
        state.happiness = min(10, state.happiness + 1)
        adjustAffinity(2)
        let comment = "猫咪吃了\(item.emoji)\(item.name)，看起来很满足！"
        recordInteraction(.feed, emoji: item.emoji, comment: comment)
        addMemory("猫咪吃了\(item.name)", source: .interaction, poignancy: 5)
        showTemporaryStatus(mood: .eating, text: comment, emoji: item.emoji)
    }

    private func feedItemPrompt(_ item: ShopItem) -> String {
        """
        你是猫猫\(state.catName)。\(traitHint) 主人给你喂了：\(item.emoji)\(item.name)（\(item.desc)）。
        用JSON回复你的反应：
        {"comment":"你说的话，纯对话1-2句，禁止括号动作描写","mood":"eating/happy/sick/excited","hunger":-2,"happiness":1,"energy":0,"health":0,"affinity":2}
        hunger/happiness/energy/health/affinity是增减值(-3到3)。只返回JSON。
        """
    }

    private struct FeedItemEffect {
        let comment: String
        let mood: CatMood
        let hungerDelta: Int
        let happinessDelta: Int
        let energyDelta: Int
        let healthDelta: Int
        let affinityDelta: Int
    }

    private func parseFeedItemEffect(_ text: String, item: ShopItem) -> FeedItemEffect {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8) else {
            return defaultFeedEffect(item)
        }

        struct RawEffect: Decodable {
            let comment: String?
            let mood: String?
            let hunger: Int?
            let happiness: Int?
            let energy: Int?
            let health: Int?
            let affinity: Int?
        }

        guard let raw = try? JSONDecoder().decode(RawEffect.self, from: data),
              let comment = raw.comment, !comment.isEmpty else {
            return defaultFeedEffect(item)
        }

        let parsedMood: CatMood = switch raw.mood {
        case "happy": .happy
        case "sick": .sick
        case "excited": .happy
        default: .eating
        }

        return FeedItemEffect(
            comment: comment,
            mood: parsedMood,
            hungerDelta: clampDelta(raw.hunger ?? -2),
            happinessDelta: clampDelta(raw.happiness ?? 1),
            energyDelta: clampDelta(raw.energy ?? 0),
            healthDelta: clampDelta(raw.health ?? 0),
            affinityDelta: clampDelta(raw.affinity ?? 2)
        )
    }

    private func defaultFeedEffect(_ item: ShopItem) -> FeedItemEffect {
        FeedItemEffect(
            comment: "猫咪吃了\(item.emoji)\(item.name)，看起来很满足！",
            mood: .eating,
            hungerDelta: -Int.random(in: 2...4),
            happinessDelta: 1,
            energyDelta: 0,
            healthDelta: 0,
            affinityDelta: 2
        )
    }

    private func clampDelta(_ v: Int) -> Int { max(-3, min(3, v)) }

    private func shopPrompt() -> String {
        """
        你是一个奇怪的小卖部老板，卖各种奇怪的猫咪食物。
        生成3个商品，用JSON数组返回。每个商品有name、emoji、desc字段。
        只返回JSON，不要其他文字。示例：
        [{"name":"星星饼干","emoji":"⭐","desc":"吃了会发光"}]
        """
    }

    private func parseShopJSON(_ text: String) -> [ShopItem]? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct RawItem: Decodable {
            let name: String?
            let emoji: String?
            let desc: String?
        }

        guard let rawItems = try? JSONDecoder().decode([RawItem].self, from: data) else {
            return nil
        }

        let items = rawItems.compactMap { raw -> ShopItem? in
            guard let name = raw.name, name.isEmpty == false else { return nil }
            return ShopItem(
                name: name,
                emoji: raw.emoji ?? "🎁",
                desc: raw.desc ?? "神秘的东西"
            )
        }

        return items.isEmpty ? nil : items
    }

    // MARK: - Random Events

    func tryTriggerEvent() async {
        guard state.isDead == false else { return }
        guard pendingEvent == nil else { return }
        guard modelRuntimeState == .ready else { return }
        guard isGeneratingReply == false else { return }

        let elapsed = Date.now.timeIntervalSince(state.lastEventAt)
        guard elapsed >= eventCooldownSeconds else { return }

        let roll = Int.random(in: 0..<100)
        guard roll < 30 else { return }

        isGeneratingReply = true

        do {
            let reply = try await llamaSession.generateInteractionReply(
                systemPrompt: eventPrompt(),
                userMessage: "触发一个随机事件",
                maxTokens: 320,
                temperature: 1.1
            )
            print("🎲 [Event] LLM Raw Output:\n\(reply)")

            if let event = parseEventJSON(reply) {
                print("🎲 [Event] Parsed: \(event.emoji) \(event.title) (\(event.choices.count) choices)")
                pendingEvent = event
                state.lastEventAt = .now
                save()
            }
        } catch {
            print("🎲 [Event] Error: \(error)")
        }

        isGeneratingReply = false
    }

    func resolveEvent(choice: EventChoice) {
        state.happiness = max(0, min(10, state.happiness + choice.happinessDelta))
        state.hunger = max(0, min(10, state.hunger + choice.hungerDelta))
        state.health = max(0, min(10, state.health + choice.healthDelta))
        adjustAffinity(choice.affinityDelta)

        state.totalEvents += 1
        state.traitScore.eventCount += 1

        addMemory("随机事件「\(pendingEvent?.title ?? "")」：选了\(choice.label)→\(choice.result)", source: .event, poignancy: 8)

        maybeDropTreasure()
        checkAchievements()
        save()
    }

    func dismissEvent() {
        pendingEvent = nil
        adjustAffinity(-1)
        save()
    }

    func clearEvent() {
        pendingEvent = nil
    }

    private func eventPrompt() -> String {
        """
        你是猫咪世界的抽象命运之轮。猫咪好感度\(state.affinity)/100。
        生成一个爆笑/抽象/离谱的随机事件，2个选项都要有意想不到的后果。
        用JSON返回，格式：
        {"emoji":"🌀","title":"事件名","desc":"场景描述","choices":[{"label":"具体的行动描述","result":"离谱的结果","affinity":2,"happiness":1,"hunger":0,"health":0},{"label":"另一个具体行动","result":"另一个离谱结果","affinity":-1,"happiness":-1,"hunger":0,"health":0}]}
        重要：label必须是具体的行动描述（如"一口吞掉""扔出窗外""假装没看见"），不要写"选项A/B"！
        affinity/happiness/hunger/health是增减值，范围-3到3。
        只返回JSON。中文。事件要抽象搞怪。
        """
    }

    private func parseEventJSON(_ text: String) -> CatEvent? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct RawEvent: Decodable {
            let emoji: String?
            let title: String?
            let desc: String?
            let choices: [RawChoice]?
        }

        struct RawChoice: Decodable {
            let label: String?
            let result: String?
            let affinity: Int?
            let happiness: Int?
            let hunger: Int?
            let health: Int?
        }

        guard let raw = try? JSONDecoder().decode(RawEvent.self, from: data),
              let title = raw.title, title.isEmpty == false,
              let rawChoices = raw.choices, rawChoices.count >= 2 else {
            return nil
        }

        let choices = rawChoices.prefix(3).compactMap { rc -> EventChoice? in
            guard let label = rc.label, label.isEmpty == false else { return nil }
            return EventChoice(
                label: label,
                result: rc.result ?? "发生了一些事情…",
                affinityDelta: max(-3, min(3, rc.affinity ?? 0)),
                happinessDelta: max(-3, min(3, rc.happiness ?? 0)),
                hungerDelta: max(-3, min(3, rc.hunger ?? 0)),
                healthDelta: max(-3, min(3, rc.health ?? 0))
            )
        }

        guard choices.count >= 2 else { return nil }

        return CatEvent(
            emoji: raw.emoji ?? "🎲",
            title: title,
            desc: raw.desc ?? "",
            choices: choices
        )
    }

    // MARK: - State Tick

    @Published var growthBanner: String?

    func tick(now: Date = .now) {
        guard state.isDead == false else { return }

        let elapsed = now.timeIntervalSince(state.lastTickAt)
        guard elapsed >= tickIntervalSeconds else { return }

        let ticksPassed = max(1, min(3, Int(elapsed / tickIntervalSeconds)))
        let stageBefore = state.growthStage

        for _ in 0..<ticksPassed {
            let stage = state.growthStage
            state.hunger = min(10, state.hunger + stage.hungerRate)
            state.energy = min(10, state.energy + stage.energyRecovery)
            state.cleanliness = max(0, state.cleanliness - 1)
            state.traitScore.idleTicks += 1

            if state.hunger >= stage.happinessDecayThreshold {
                state.happiness = max(0, state.happiness - 1)
                adjustAffinity(-1)
            }
            if state.cleanliness <= 2 {
                state.health = max(0, state.health - 1)
            }
            state.health = min(stage.maxHealth, state.health)

            if stage == .elder && Bool.random() && state.health > 3 {
                state.health = max(0, state.health - 1)
            }

            state.age += 1
        }

        let stageAfter = state.growthStage
        if stageBefore != stageAfter {
            growthBanner = "\(stageAfter.emoji) \(state.catName)长大了！现在是\(stageAfter.name)阶段"
            addMemory("\(state.catName)从\(stageBefore.name)成长为\(stageAfter.name)", source: .event, poignancy: 9)
            checkAchievements()
            Task {
                try? await Task.sleep(for: .seconds(5))
                growthBanner = nil
            }
        }

        if state.happiness <= 0 && state.health <= 0 && state.hunger >= 10 {
            state.isDead = true
            state.comment = "猫咪永远地睡着了…"
        }

        state.lastTickAt = now
        save()
    }

    func llmTick(now: Date = .now) async {
        tick(now: now)

        guard state.isDead == false else { return }
        guard modelRuntimeState == .ready else { return }
        guard isGeneratingReply == false else { return }
        guard actionStatusText == nil else { return }

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
        } catch {}

        isGeneratingReply = false

        await refreshMoodWord()
    }

    private static let quoteChars = CharacterSet(charactersIn: "\"\u{201C}\u{201D}\u{300C}\u{300D}\u{3002}")

    func refreshMoodWord() async {
        guard state.isDead == false else { return }
        guard modelRuntimeState == .ready else { return }
        guard isGeneratingReply == false else { return }

        do {
            let raw = try await llamaSession.generateInteractionReply(
                systemPrompt: moodWordPrompt(),
                userMessage: "现在的心情",
                maxTokens: 12,
                temperature: 1.2
            )
            let word = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: Self.quoteChars)
                .joined()
                .split(separator: "\n")
                .first
                .map(String.init) ?? ""
            if !word.isEmpty && word.count <= 6 {
                catMoodWord = word
            }
        } catch {}
    }

    // MARK: - Revival

    func reviveCat() async {
        guard state.isDead else { return }

        state.isDead = false
        state.happiness = 3
        state.hunger = 5
        state.health = 4
        state.cleanliness = 5
        state.energy = 4
        state.lastTickAt = .now
        state.lastEventAt = .now
        state.reviveCount += 1
        adjustAffinity(-30)
        checkAchievements()

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: "你是一只猫，刚刚从死亡中复活。描述你醒来的反应，1句中文，不超过25字。迷迷糊糊的。",
                    userMessage: "猫咪复活了"
                )
                state.comment = reply.isEmpty ? "猫咪迷迷糊糊地睁开了眼睛…好像做了一场很长的梦。" : reply
            } catch {
                state.comment = "猫咪迷迷糊糊地睁开了眼睛…好像做了一场很长的梦。"
            }
            isGeneratingReply = false
        } else {
            state.comment = "猫咪迷迷糊糊地睁开了眼睛…好像做了一场很长的梦。"
        }

        addMemory("猫咪死而复生了", source: .interaction, poignancy: 10)
        save()
    }

    // MARK: - Model Bootstrap

    func reloadModel() async {
        await bootstrapDefaultModel()
    }

    private func bootstrapDefaultModel() async {
        guard let bundledURL = bundledModelURL() else {
            modelRuntimeState = .failed("找不到内置模型文件。")
            return
        }

        modelRuntimeState = .loading
        do {
            try await llamaSession.loadModel(at: bundledURL.path)
            state.localModelFileName = bundledURL.lastPathComponent
            state.localModelDisplayName = "内置 \(bundledURL.lastPathComponent)"
            modelRuntimeState = .ready
            save()
        } catch {
            modelRuntimeState = .failed("模型加载失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Prompts

    private var cachedMemoryContext: String = ""

    private func chatSystemPrompt() -> String {
        let memoryContext: String
        if cachedMemoryContext.isEmpty {
            if state.memories.isEmpty {
                memoryContext = ""
            } else {
                let recent = state.memories.prefix(2).map { "• \($0.summary.prefix(40))" }.joined(separator: "\n")
                memoryContext = "\n记忆：\n\(recent)"
            }
        } else {
            memoryContext = cachedMemoryContext
        }

        let hasThoughtInMemory = memoryContext.contains("💭")
        let thoughtContext: String
        if hasThoughtInMemory {
            thoughtContext = ""
        } else {
            let thoughts = memoryStore.recentThoughts(limit: 1)
            thoughtContext = thoughts.isEmpty ? "" : "\n内心：\(thoughts[0].description.prefix(30))"
        }

        let traits = state.activeTraits
        let personalityBlock: String
        if traits.isEmpty {
            personalityBlock = "你有自己的想法，会发癫、会阴阳怪气、会突然撒娇、会无厘头。"
        } else {
            personalityBlock = traits.map(\.promptPersonality).joined(separator: "\n")
        }

        let stage = state.growthStage
        let stageHint: String = switch stage {
        case .baby: "你是只奶猫，说话奶声奶气，偶尔会打嗝。"
        case .kitten: "你是只小猫，好奇心爆棚，什么都想碰。"
        case .teen: "你是只中二少年猫，觉得自己很酷。"
        case .adult: "你是只成年猫，淡定但嘴毒。"
        case .elder: "你是只老猫，阅历丰富，偶尔念叨当年。"
        }

        let prompt = """
        你是\(state.catName)，住在手机里的猫猫。\(stageHint)不是AI助手。
        【核心性格】\(personalityBlock)
        成长阶段：\(stage.emoji)\(stage.name) 好感\(state.affinity)/100（\(state.affinityLevel.title)）心情\(state.happiness) 饱\(state.hunger) 精力\(state.energy)\(memoryContext)\(thoughtContext)
        风格：1-2句中文，可长可短。性格要极端鲜明！每句话都要能看出你的性格。纯对话，禁止括号动作描写如（摇尾巴）（歪头），禁止第三人称旁白。禁止"喵呜/喵鸣"开头。可用emoji。每次说不一样的话。
        """

        print("🐱 [Prompt] \(prompt)")
        return prompt
    }

    private func prepareMemoryContext(for query: String) async {
        let relevant = await memoryStore.retrieve(query: query, topK: 3)
        if relevant.isEmpty {
            cachedMemoryContext = ""
        } else {
            let lines = relevant.map { node in
                let typeIcon = switch node.type {
                case .event: "📌"
                case .chat: "💬"
                case .thought: "💭"
                }
                return "\(typeIcon) \(node.description.prefix(50))"
            }
            cachedMemoryContext = "\n记忆：\n" + lines.joined(separator: "\n")
        }
    }

    private let speechRule = "纯说话，禁止括号动作描写如（摇尾巴）（歪头）（蹭了蹭），禁止第三人称旁白。禁止喵呜/喵鸣开头。"

    private var traitHint: String {
        let traits = state.activeTraits
        if traits.isEmpty { return "你性格随机，可以发癫、阴阳怪气、撒娇。" }
        return traits.map(\.promptPersonality).joined(separator: " ")
    }

    private func feedPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人喂你吃的。1-2句回应。\(speechRule)"
    }

    private func playPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人找你玩。1-2句回应。\(speechRule)"
    }

    private func cleanPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人给你洗澡。1-2句回应。\(speechRule)"
    }

    private func disciplinePrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被主人训了。1-2句回应。\(speechRule)"
    }

    private func medicalPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被带去看医生了。1-2句回应。\(speechRule)"
    }

    private func headpatPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被摸头了。1-2句回应。\(speechRule)"
    }

    private func bellyPrompt(willBite: Bool) -> String {
        willBite
            ? "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 肚子被摸触发攻击！1-2句凶狠回应。\(speechRule)"
            : "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 肚子被摸了。1-2句回应。\(speechRule)"
    }

    private func cuddlePrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人对你撒娇。1-2句回应。\(speechRule)"
    }

    private func tickPrompt() -> String {
        "你是猫猫\(state.catName)。\(traitHint) 说你现在在干嘛，1-2句中文。\(speechRule)"
    }

    private func moodWordPrompt() -> String {
        let mood: String
        if state.happiness >= 8 { mood = "非常开心" }
        else if state.happiness >= 5 { mood = "心情不错" }
        else if state.happiness >= 3 { mood = "有点无聊" }
        else if state.happiness >= 1 { mood = "心情很差" }
        else { mood = "极度崩溃" }

        return """
        你是猫猫\(state.catName)。\(traitHint)你现在\(mood)，饱腹\(state.hunger)/10，精力\(state.energy)/10。
        输出猫肚子上显示的一小段话（2-5个字），可以是：
        - 吐槽主人（笨蛋、别碰、你丑）
        - 内心OS（想吃鱼、好无聊、在谋划）
        - 搞怪表情（>///<、=w=、>_<）
        - 情绪爆发（发疯！、救命！、哼！）
        - 猫咪行为（舔毛中、放空…、装死）
        - 傲娇台词（才不要、略略略、哈？）
        举例：别看！、想摸鱼、你谁啊、嘿嘿嘿、求投喂、在装死、闭嘴！、略略略、想开溜、太闲了
        只输出这段话本身，不要加引号和解释。
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

    private func cleanFallbackComment() -> String {
        [
            "猫咪被洗得干干净净，甩了甩毛。",
            "虽然不太情愿，但洗完澡舒服多了。",
            "猫咪舔了舔爪子，对自己的干净程度很满意。",
            "水花溅了一地，但猫咪看起来精神多了。"
        ].randomElement()!
    }

    private func medicalFallbackComment() -> String {
        [
            "看了医生，猫咪的状态好了一些。",
            "吃了药，虽然有点苦，但很快会好的。",
            "打了一针，猫咪委屈地叫了一声。"
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

    private func adjustAffinity(_ delta: Int) {
        let bonus = delta > 0 ? state.growthStage.affinityGainBonus : 0
        state.affinity = max(0, min(100, state.affinity + delta + bonus))
    }

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

    private func addMemory(_ summary: String, source: MemorySourceType, poignancy: Int = 5) {
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

        let nodeType: MemoryNodeType = switch source {
        case .conversation: .chat
        case .event: .event
        default: .event
        }

        Task {
            await memoryStore.addMemory(
                type: nodeType,
                description: summary,
                subject: state.catName,
                poignancy: poignancy
            )
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

        let userMessages = recentMessages.filter { $0.role == .user }
        let userContext = userMessages.last?.text.prefix(20) ?? ""

        let convCount = state.memories.filter { $0.sourceType == .conversation }.count
        if convCount < state.chatMessages.count / 8 {
            addMemory("主人说「\(userContext)」，猫咪回答：\(lastPet.text.prefix(40))", source: .conversation, poignancy: 6)
        }
    }

    private func maybeReflect() async {
        guard memoryStore.shouldReflect(), modelRuntimeState == .ready else { return }

        let essential = memoryStore.essentialMemories(topK: 5)
        guard !essential.isEmpty else { return }

        let summaries = essential.map { "• \($0.description.prefix(40))" }.joined(separator: "\n")
        let prompt = """
        你是猫猫\(state.catName)。用1句大白话说说最近的感受，要像猫一样直白，不要文艺不要哲学，20字内。
        最近发生的事：
        \(summaries)
        """

        do {
            let thought = try await llamaSession.generateInteractionReply(
                systemPrompt: prompt,
                userMessage: "反思一下最近的经历"
            )
            if !thought.isEmpty {
                await memoryStore.addMemory(
                    type: .thought,
                    description: thought,
                    subject: state.catName,
                    predicate: "thinks",
                    object: "",
                    poignancy: 8
                )
                print("🧠 [Reflect] \(thought)")
            }
        } catch {}
    }

    private var statusDismissTask: Task<Void, Never>?

    private func showTemporaryStatus(mood: CatMood, text: String?, emoji: String? = nil) {
        statusDismissTask?.cancel()

        displayMood = mood
        actionStatusText = text
        if let emoji { lastActionEmoji = emoji }
        if let text { pendingSpeak = text }

        guard text != nil else { return }

        let charCount = text?.count ?? 0
        let displaySeconds = max(8, Double(charCount) / 4.0 + 5.0)

        statusDismissTask = Task {
            try? await Task.sleep(for: .seconds(displaySeconds))
            guard !Task.isCancelled else { return }
            displayMood = nil
            actionStatusText = nil
            lastActionEmoji = nil
        }

        Task { await refreshMoodWord() }
    }

    private func extractEmoji(from text: String) -> String? {
        text.first { $0.unicodeScalars.allSatisfy { $0.properties.isEmoji && $0.value > 0x238C } }.map(String.init)
    }

    // MARK: - Daily Streak

    @Published var streakBanner: String?

    func checkDailyStreak() {
        guard !state.streak.checkedInToday else { return }
        state.streak.checkIn()

        let reward = state.streak.streakReward
        adjustAffinity(reward)
        state.happiness = min(10, state.happiness + 1)

        let day = state.streak.currentStreak
        streakBanner = "🔥 连续签到第\(day)天！好感+\(reward)"

        checkAchievements()
        save()

        Task {
            try? await Task.sleep(for: .seconds(4))
            streakBanner = nil
        }
    }

    // MARK: - Achievements

    @Published var newTitleBanner: CatTitle?

    private func checkAchievements() {
        let existing = Set(state.titles.map(\.id))
        var newlyUnlocked: [CatTitle] = []

        func tryUnlock(_ def: TitleDefinition) {
            guard !existing.contains(def.rawValue) else { return }
            let title = CatTitle(id: def.rawValue, name: def.name, emoji: def.emoji,
                                  desc: def.desc, unlockedAt: .now)
            state.titles.append(title)
            newlyUnlocked.append(title)
        }

        if state.age >= 0 { tryUnlock(.firstMeet) }
        if state.traitScore.chatCount >= 20 { tryUnlock(.talkative) }
        if state.traitScore.feedCount >= 30 { tryUnlock(.wellFed) }
        if state.reviveCount >= 1 { tryUnlock(.survivor) }
        if state.affinity >= 80 { tryUnlock(.bestFriend) }
        if state.totalEvents >= 10 { tryUnlock(.adventurer) }
        if state.treasures.count >= 5 { tryUnlock(.collector) }
        if state.totalShopBuys >= 10 { tryUnlock(.shopaholic) }

        let hour = Calendar.current.component(.hour, from: .now)
        if (6...7).contains(hour) { tryUnlock(.earlyBird) }
        if (0...3).contains(hour) { tryUnlock(.nightOwl) }

        if let first = newlyUnlocked.first {
            newTitleBanner = first
            Task {
                try? await Task.sleep(for: .seconds(4))
                newTitleBanner = nil
            }
        }
    }

    // MARK: - Treasures

    @Published var newTreasureBanner: Treasure?

    private static let treasurePool: [(String, String, TreasureRarity)] = [
        ("毛线球", "🧶", .common),
        ("小鱼干", "🐟", .common),
        ("蝴蝶结", "🎀", .common),
        ("铃铛", "🔔", .common),
        ("神秘羽毛", "🪶", .common),
        ("猫薄荷", "🌿", .common),
        ("月光石", "🌙", .rare),
        ("星星碎片", "⭐", .rare),
        ("彩虹水晶", "🌈", .rare),
        ("金鱼王冠", "👑", .rare),
        ("龙之逆鳞", "🐉", .legendary),
        ("时光沙漏", "⏳", .legendary),
        ("九命项链", "📿", .legendary),
    ]

    private func maybeDropTreasure() {
        let roll = Int.random(in: 0..<100)
        var threshold = 25
        if state.activeTraits.contains(.curious) { threshold += 15 }
        if state.activeTraits.contains(.glutton) { threshold += 5 }
        guard roll < threshold else { return }

        let weighted = Self.treasurePool.flatMap { item -> [(String, String, TreasureRarity)] in
            switch item.2 {
            case .common: Array(repeating: item, count: 5)
            case .rare: Array(repeating: item, count: 2)
            case .legendary: [item]
            }
        }

        guard let pick = weighted.randomElement() else { return }

        let ownedNames = Set(state.treasures.map(\.name))
        if ownedNames.contains(pick.0) && pick.2 != .common { return }

        let treasure = Treasure(name: pick.0, emoji: pick.1, rarity: pick.2)
        state.treasures.append(treasure)
        newTreasureBanner = treasure
        checkAchievements()

        Task {
            try? await Task.sleep(for: .seconds(4))
            newTreasureBanner = nil
        }
    }

    private func save() {
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func bundledModelURL() -> URL? {
        Bundle.main.url(forResource: "Qwen3.5-0.8B-Q4_K_M", withExtension: "gguf")
    }
}
