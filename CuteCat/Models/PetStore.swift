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
    @Published var diaryBanner: CatDiaryEntry?
    @Published var bondChangeBanner: String?

    let memoryStore = CatMemoryStore()

    private let saveKey = "com.soukon.cutecat.save.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let llamaSession = LocalLlamaSession()
    private let bundledModelFileName = "Qwen3.5-0.8B-Q4_K_M.gguf"

    private let tickIntervalSeconds: TimeInterval = 300
    private let eventCooldownSeconds: TimeInterval = 600

    private enum UserEmotionSignal: String {
        case tired
        case lonely
        case sad
        case anxious
        case angry
        case happy

        var title: String {
            switch self {
            case .tired: "很累"
            case .lonely: "有点孤单"
            case .sad: "不太好受"
            case .anxious: "有点焦虑"
            case .angry: "有点生气"
            case .happy: "有一点开心"
            }
        }

        var diaryMood: CatDiaryMood {
            switch self {
            case .happy: .playful
            case .angry, .anxious: .guarded
            case .tired, .lonely, .sad: .warm
            }
        }
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: saveKey),
           let loaded = try? decoder.decode(PetState.self, from: data) {
            state = loaded
        } else {
            state = PetState.initial()
        }
        refreshBehaviorFromState(reason: "init")

        Task {
            await bootstrapDefaultModel()
            await memoryStore.bootstrap()
        }
    }

    // MARK: - Computed Properties

    var currentMood: CatMood {
        if state.isDead { return .dead }
        displayMood ?? state.currentBehavior.kind.displayMood
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

    var latestDiary: CatDiaryEntry? {
        state.diaryEntries.first
    }

    var lifePulseText: String {
        let scene = state.currentLifeScene
        return "\(scene.emoji) \(scene.text)"
    }

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

    // MARK: - Bond Loop

    func checkDailyBondMoment() async {
        guard state.isDead == false else { return }
        guard state.lastDiaryDate != DailyStreak.todayString else { return }

        let mood = diaryMoodForCurrentState()
        let seed = dailyDiarySeed()
        state.lastDiaryDate = DailyStreak.todayString
        setBehavior(.writingDiary, title: "写日记", detail: "\(state.catName)把今天折成一句很短的话，藏进日记里。", intensity: 2)
        await appendDiary(trigger: "今日醒来", mood: mood, fallback: seed)
        adjustAffinity(1)
        checkAchievements()
        save()
    }

    func observeCat() async {
        guard state.isDead == false else { return }
        guard isGeneratingReply == false else { return }

        state.observationCount += 1
        let accepted = observationAccepted()
        if accepted {
            state.happiness = min(10, state.happiness + 1)
            adjustAffinity(state.observationCount % 3 == 0 ? 2 : 1)
        } else {
            adjustAffinity(1)
        }

        let text = observationLine(accepted: accepted)
        setBehavior(
            accepted ? .waiting : .hiding,
            title: accepted ? "被看见" : "保持距离",
            detail: text,
            intensity: accepted ? 2 : 3
        )
        recordInteraction(.chat, emoji: "👀", comment: text)
        addMemory("主人安静观察了\(state.catName)：\(text)", source: .interaction, poignancy: 5)
        showTemporaryStatus(mood: .thinking, text: text, emoji: "👀")

        if state.observationCount == 1 || state.observationCount % 4 == 0 {
            let mood: CatDiaryMood = accepted ? .warm : .guarded
            let fallback = accepted
                ? "今天主人没有急着让我表演，只是看着我。我多停留了一小会儿。"
                : "主人一直看着我。我没有躲太远，但也没有马上靠过去。"
            await appendDiary(trigger: "被主人看见", mood: mood, fallback: fallback)
        }

        checkAchievements()
        save()
    }

    func comfortCat() async {
        guard state.isDead == false else { return }
        guard isGeneratingReply == false else { return }

        state.comfortCount += 1
        let accepted = comfortAccepted()
        if accepted {
            state.happiness = min(10, state.happiness + 2)
            state.energy = min(10, state.energy + 1)
            adjustAffinity(3)
        } else {
            state.happiness = max(0, state.happiness - 1)
            adjustAffinity(-1)
        }

        let text = comfortLine(accepted: accepted)
        setBehavior(
            accepted ? .waiting : .sulking,
            title: accepted ? "接受陪伴" : "拒绝靠近",
            detail: text,
            intensity: accepted ? 3 : 4
        )
        recordInteraction(.cuddle, emoji: "🫶", comment: text)
        addMemory("主人陪了陪\(state.catName)：\(text)", source: .interaction, poignancy: 7)
        showTemporaryStatus(mood: accepted ? .shy : .disciplined, text: text, emoji: "🫶")

        if state.comfortCount == 1 || state.comfortCount % 3 == 0 {
            let mood: CatDiaryMood = accepted ? .warm : .guarded
            let fallback = accepted
                ? "主人靠近的时候，我没有立刻躲开。也许这里是安全的。"
                : "主人想安慰我，但我今天还不想被碰。信任不能催。"
            await appendDiary(trigger: "被安抚", mood: mood, fallback: fallback)
        }

        checkAchievements()
        save()
    }

    private func appendDiary(trigger: String, mood: CatDiaryMood, fallback: String) async {
        let text: String
        if modelRuntimeState == .ready && isGeneratingReply == false {
            isGeneratingReply = true
            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: diaryPrompt(trigger: trigger, fallback: fallback),
                    userMessage: "写一条猫日记",
                    maxTokens: 48,
                    temperature: 1.0
                )
                text = cleanDiaryLine(reply, fallback: fallback)
            } catch {
                text = fallback
            }
            isGeneratingReply = false
        } else {
            text = fallback
        }

        let entry = CatDiaryEntry(text: text, mood: mood, trigger: trigger)
        state.diaryEntries.insert(entry, at: 0)
        if state.diaryEntries.count > 30 {
            state.diaryEntries = Array(state.diaryEntries.prefix(30))
        }
        diaryBanner = entry
        addMemory("猫日记：\(text)", source: .event, poignancy: 8)

        Task {
            try? await Task.sleep(for: .seconds(5))
            if diaryBanner?.id == entry.id {
                diaryBanner = nil
            }
        }
    }

    private func diaryMoodForCurrentState() -> CatDiaryMood {
        if state.happiness <= 2 || state.energy <= 2 { return .lonely }
        if state.hunger >= 8 { return .chaotic }
        if state.affinity >= 60 || state.comfortCount >= 3 { return .warm }
        if state.activeTraits.contains(.curious) || state.activeTraits.contains(.chuuni) { return .playful }
        if state.activeTraits.contains(.tsundere) || state.activeTraits.contains(.edgelord) { return .guarded }
        return .playful
    }

    private func dailyDiarySeed() -> String {
        if state.streak.currentStreak >= 3 {
            return "主人又回来了。连续几天都是这样。我开始有点相信门会被推开。"
        }
        if state.hunger >= 8 {
            return "今天醒来第一件事：想吃。第二件事：继续想吃。"
        }
        if state.energy <= 2 {
            return "我今天把自己收得很小。小一点，就不容易被孤单发现。"
        }
        if state.affinity >= 70 {
            return "主人来的时候，我假装刚好路过。其实我等了很久。"
        }
        if state.activeTraits.contains(.curious) {
            return "我发现墙角有一个秘密。它可能只是灰，但我决定尊重它。"
        }
        return "今天我在这里醒来。房间很安静，但主人留下的气味还在。"
    }

    private func observationAccepted() -> Bool {
        if state.affinity >= 35 { return true }
        if state.activeTraits.contains(.clingy) || state.activeTraits.contains(.babyface) { return true }
        if state.activeTraits.contains(.tsundere) || state.activeTraits.contains(.edgelord) { return state.observationCount.isMultiple(of: 3) }
        return state.observationCount.isMultiple(of: 2)
    }

    private func comfortAccepted() -> Bool {
        if state.affinity >= 55 { return true }
        if state.happiness <= 2 && state.affinity >= 25 { return true }
        if state.activeTraits.contains(.clingy) { return state.affinity >= 20 }
        if state.activeTraits.contains(.tsundere) || state.activeTraits.contains(.edgelord) { return state.affinity >= 45 && state.comfortCount.isMultiple(of: 2) }
        return state.affinity >= 35
    }

    private func observationLine(accepted: Bool) -> String {
        if accepted == false {
            if state.activeTraits.contains(.tsundere) {
                return "\(state.catName)发现你在看它，故意转过身，只留给你一个耳朵。"
            }
            if state.activeTraits.contains(.edgelord) {
                return "\(state.catName)看了你一眼，又把自己塞回阴影里。"
            }
            return "\(state.catName)注意到你了，但还在判断你是不是安全。"
        }
        if state.activeTraits.contains(.tsundere) {
            return "\(state.catName)装作没发现你在看它，但尾巴尖轻轻晃了一下。"
        }
        if state.activeTraits.contains(.curious) {
            return "\(state.catName)把你的目光当成新玩具，认真研究了三秒。"
        }
        if state.energy <= 2 {
            return "\(state.catName)困得睁不开眼，但还是往你这边挪了一点。"
        }
        if state.affinity >= 60 {
            return "\(state.catName)没有说话，只是在你附近安心地待着。"
        }
        return "\(state.catName)停下手里的小动作，确认你还在。"
    }

    private func comfortLine(accepted: Bool) -> String {
        if accepted == false {
            if state.activeTraits.contains(.tsundere) {
                return "\(state.catName)躲开了一点，小声嘀咕：现在才来，谁稀罕。"
            }
            if state.activeTraits.contains(.edgelord) {
                return "\(state.catName)没有接受安抚，只把尾巴收得更紧。"
            }
            return "\(state.catName)今天还不想被安慰。它需要一点距离。"
        }
        if state.happiness <= 2 {
            return "\(state.catName)慢慢贴近你，像把今天的难过放轻了一点。"
        }
        if state.activeTraits.contains(.tsundere) {
            return "\(state.catName)小声哼了一下，但没有躲开你的安抚。"
        }
        if state.activeTraits.contains(.clingy) {
            return "\(state.catName)立刻靠过来，好像终于等到这一刻。"
        }
        if state.affinity >= 70 {
            return "\(state.catName)把额头轻轻抵过来，这是它的小小信任。"
        }
        return "\(state.catName)安静了一会儿，呼吸慢慢变软。"
    }

    private func diaryPrompt(trigger: String, fallback: String) -> String {
        """
        你是住在手机里的猫猫\(state.catName)，不是AI助手。
        写一条猫日记，中文1句，18-36字。治愈但有猫味，像一只孤独但慢慢信任主人的小猫。
        重要：不要一味讨好主人。好感低时可以防备、嘴硬、保持距离；好感高时才更柔软。
        触发：\(trigger)
        性格：\(state.bondTitle)，\(state.bondSubtitle)
        好感：\(state.affinity)/100
        参考但不要照抄：\(fallback)
        禁止解释，禁止括号动作描写，禁止“喵呜/喵鸣”开头，只输出日记正文。
        """
    }

    private func cleanDiaryLine(_ raw: String, fallback: String) -> String {
        let line = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""
        let cleaned = line
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
        if cleaned.isEmpty || cleaned.count > 60 {
            return fallback
        }
        return cleaned
    }

    private func classifyUserEmotion(in text: String) async -> UserEmotionSignal? {
        guard modelRuntimeState == .ready else {
            return keywordEmotionSignal(in: text)
        }

        do {
            let raw = try await llamaSession.generateInteractionReply(
                systemPrompt: emotionClassifierPrompt(),
                userMessage: String(text.prefix(240)),
                maxTokens: 12,
                temperature: 0.1
            )
            return parseEmotionSignal(raw) ?? keywordEmotionSignal(in: text)
        } catch {
            return keywordEmotionSignal(in: text)
        }
    }

    private func emotionClassifierPrompt() -> String {
        """
        判断用户这句话主要表达的情绪。只输出一个英文标签：
        tired 疲惫没力气
        lonely 孤独寂寞
        sad 难过委屈低落
        anxious 焦虑压力不安
        angry 生气烦躁
        happy 开心顺利
        none 没有明显情绪
        不要解释，不要标点，只输出标签。
        """
    }

    private func parseEmotionSignal(_ raw: String) -> UserEmotionSignal? {
        let normalized = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains("none") { return nil }
        if normalized.contains("tired") { return .tired }
        if normalized.contains("lonely") { return .lonely }
        if normalized.contains("sad") { return .sad }
        if normalized.contains("anxious") { return .anxious }
        if normalized.contains("angry") { return .angry }
        if normalized.contains("happy") { return .happy }
        return nil
    }

    private func keywordEmotionSignal(in text: String) -> UserEmotionSignal? {
        let lowered = text.lowercased()
        let tired = ["累", "疲惫", "困", "撑不住", "不想动", "burnout"]
        let lonely = ["孤独", "寂寞", "没人", "一个人", "空空"]
        let sad = ["难过", "伤心", "委屈", "想哭", "崩溃"]
        let anxious = ["焦虑", "压力", "慌", "不安", "害怕", "紧张"]
        let angry = ["生气", "烦", "火大", "气死", "讨厌"]
        let happy = ["开心", "高兴", "顺利", "太好了", "快乐"]

        if tired.contains(where: { lowered.contains($0) }) { return .tired }
        if lonely.contains(where: { lowered.contains($0) }) { return .lonely }
        if sad.contains(where: { lowered.contains($0) }) { return .sad }
        if anxious.contains(where: { lowered.contains($0) }) { return .anxious }
        if angry.contains(where: { lowered.contains($0) }) { return .angry }
        if happy.contains(where: { lowered.contains($0) }) { return .happy }
        return nil
    }

    private func heardEmotionFallback(_ emotion: UserEmotionSignal, guarded: Bool) -> String {
        if guarded {
            switch emotion {
            case .happy:
                return "主人今天\(emotion.title)。我听见了，但我只偷偷开心一点点。"
            case .angry, .anxious:
                return "主人今天\(emotion.title)。我不敢太近，只把耳朵转过去听着。"
            default:
                return "主人今天\(emotion.title)。我听见了，但还不确定该不该靠近。"
            }
        }

        switch emotion {
        case .happy:
            return "主人今天\(emotion.title)。我假装不在意，其实尾巴已经先开心了。"
        case .angry:
            return "主人今天\(emotion.title)。我不懂人类的火，但我可以陪它慢慢熄掉。"
        case .anxious:
            return "主人今天\(emotion.title)。我趴近一点，不说话也算帮忙。"
        default:
            return "主人今天\(emotion.title)。我不太会安慰人，但我可以待在这里。"
        }
    }

    private func setBehavior(_ kind: CatBehaviorKind, title: String, detail: String, intensity: Int = 1) {
        state.currentBehavior = CatBehavior(
            kind: kind,
            title: title,
            detail: detail,
            startedAt: .now,
            intensity: max(1, min(5, intensity))
        )
    }

    private func refreshBehaviorFromState(reason: String = "") {
        guard state.isDead == false else {
            setBehavior(.idle, title: "长睡", detail: "\(state.catName)安静地睡着了。")
            return
        }

        let traits = Set(state.activeTraits)

        if state.health <= 2 {
            setBehavior(.hiding, title: "缩成一团", detail: "\(state.catName)今天不太舒服，连尾巴都懒得管。", intensity: 5)
        } else if state.hunger >= 8 {
            setBehavior(.searchingFood, title: "搜寻食物", detail: "\(state.catName)正盯着空气里的鱼味看。", intensity: 4)
        } else if state.energy <= 2 {
            setBehavior(.napping, title: "低电量", detail: "\(state.catName)把自己折成一小团，假装世界不存在。", intensity: 3)
        } else if state.cleanliness <= 2 {
            setBehavior(.grooming, title: "嫌弃自己", detail: "\(state.catName)正在认真舔毛，表情像在审判整个房间。", intensity: 3)
        } else if traits.contains(.curious) && Bool.random() {
            setBehavior(.investigating, title: "调查世界", detail: "\(state.catName)正在研究一个不存在的宇宙按钮。", intensity: 2)
        } else if traits.contains(.tsundere) && state.affinity < 70 {
            setBehavior(.guardingBelly, title: "嘴硬待机", detail: "\(state.catName)背对着你，但耳朵一直在偷听。", intensity: 2)
        } else if traits.contains(.clingy) && state.affinity >= 35 {
            setBehavior(.waiting, title: "偷偷靠近", detail: "\(state.catName)在你看不见的时候偷偷靠近了一点。", intensity: 2)
        } else if traits.contains(.edgelord) {
            setBehavior(.hiding, title: "深夜放空", detail: "\(state.catName)蹲在角落里，像一小块会呼吸的阴影。", intensity: 2)
        } else {
            setBehavior(.idle, title: "小日子", detail: "\(state.catName)正在过自己的小日子。", intensity: 1)
        }
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

        if let emotion = await classifyUserEmotion(in: trimmed) {
            let naturallyGuarded = state.activeTraits.contains(.tsundere) || state.activeTraits.contains(.edgelord)
            let guarded = state.affinity < 35 || (naturallyGuarded && state.affinity < 70)
            if guarded {
                state.observationCount += 1
                adjustAffinity(1)
            } else {
                state.comfortCount += 1
                state.happiness = min(10, state.happiness + 1)
                adjustAffinity(2)
            }
            addMemory("主人今天\(emotion.title)，\(state.catName)听见了", source: .conversation, poignancy: 8)
            setBehavior(
                guarded ? .guardingBelly : .waiting,
                title: guarded ? "听见但防备" : "安静陪着",
                detail: heardEmotionFallback(emotion, guarded: guarded),
                intensity: guarded ? 3 : 2
            )
            await appendDiary(
                trigger: "听见主人的心情",
                mood: guarded ? .guarded : emotion.diaryMood,
                fallback: heardEmotionFallback(emotion, guarded: guarded)
            )
            save()
        }

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
        guard isGeneratingReply == false else { return }
        guard modelRuntimeState == .ready else { return }

        let elapsed = Date.now.timeIntervalSince(state.lastEventAt)
        guard elapsed >= eventCooldownSeconds else { return }

        let roll = Int.random(in: 0..<100)
        guard roll < 30 else { return }

        isGeneratingReply = true
        do {
            let reply = try await llamaSession.generateInteractionReply(
                systemPrompt: sceneGeneratorPrompt(),
                userMessage: sceneGeneratorStatePayload(),
                maxTokens: 360,
                temperature: 1.15
            )
            if let event = parseGeneratedScene(reply) {
                pendingEvent = event
                state.lastEventAt = .now
                setBehavior(.showingOff, title: event.title, detail: event.desc, intensity: 3)
                save()
            }
        } catch {
            print("🎲 [Scene] generation failed: \(error)")
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
        setBehavior(.showingOff, title: choice.label, detail: choice.result, intensity: 3)

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
        refreshBehaviorFromState(reason: "event-cleared")
        save()
    }

    private func sceneGeneratorPrompt() -> String {
        """
        你是 CuteCat 的“名场景导演”，不是聊天助手。你的任务是根据猫的长期属性，发明一个玩家会想截图分享的猫猫事件。

        核心目标：爆款名场景 = 情绪真实 + 猫脑回路离谱 + 和当前养成状态强相关。
        不要写普通撒娇、普通饿了、普通陪伴、普通卖萌。不要写大道理。不要讨好玩家。

        创作方法：
        1. 先判断猫对主人的核心情绪：过度依恋、占有欲、防备、记仇、无聊、逃离、试探、愧疚、炫耀。
        2. 把这个情绪变成一个具体荒诞行动，而不是一句话。
        3. 行动必须像猫理解错了人类世界：把抽象关系物化成冰箱、门口、小包袱、纸箱、日记、闹钟、影子、饭碗等。
        4. 两个选项都要影响关系：一个尊重猫的边界，一个刺激猫的执念/防备/占有欲。

        输出严格 JSON，不要 Markdown，不要解释：
        {
          "emoji":"一个emoji",
          "title":"2-8个中文，像事件名",
          "desc":"中文1句，28-55字，必须是具体行动场景",
          "choices":[
            {"label":"具体行动，3-9字","result":"中文1句，20-45字","affinity":整数-3到3,"happiness":整数-3到3,"hunger":整数-3到3,"health":整数-3到3},
            {"label":"具体行动，3-9字","result":"中文1句，20-45字","affinity":整数-3到3,"happiness":整数-3到3,"hunger":整数-3到3,"health":整数-3到3}
          ]
        }

        质量标准：
        - title 不能是“随机事件/小猫事件/奇怪事件”。
        - desc 必须出现一个物品或地点。
        - result 必须体现猫的关系变化或边界感。
        - 不要照抄用户示例；要自己发明同等强度的新场景。
        """
    }

    private func sceneGeneratorStatePayload() -> String {
        let report = state.personaReport
        let traits = state.activeTraits.map(\.name).joined(separator: "、")
        let recentDiary = state.diaryEntries.prefix(3).map { "「\($0.text)」" }.joined(separator: " ")
        let recentInteractions = state.interactions.suffix(5).map { $0.interaction.title }.joined(separator: "、")

        return """
        猫名：\(state.catName)
        猫格：\(report.code) \(report.name) / \(report.subtitle)
        当前行为：\(state.currentBehavior.title) / \(state.currentBehavior.detail)
        好感：\(state.affinity)/100（\(state.affinityLevel.title)）
        心情：\(state.happiness)/10，饥饿：\(state.hunger)/10，健康：\(state.health)/10，精力：\(state.energy)/10，清洁：\(state.cleanliness)/10
        性格特征：\(traits.isEmpty ? "尚未定型" : traits)
        观察次数：\(state.observationCount)，陪伴次数：\(state.comfortCount)，被管教次数：\(state.traitScore.disciplineCount)，闲置次数：\(state.traitScore.idleTicks)
        最近互动：\(recentInteractions.isEmpty ? "无" : recentInteractions)
        最近日记：\(recentDiary.isEmpty ? "无" : recentDiary)
        请生成一个只属于这只猫当前状态的名场景。
        """
    }

    private func parseGeneratedScene(_ text: String) -> CatEvent? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct RawScene: Decodable {
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

        guard let raw = try? JSONDecoder().decode(RawScene.self, from: data),
              let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              let desc = raw.desc?.trimmingCharacters(in: .whitespacesAndNewlines),
              title.count >= 2,
              title.count <= 12,
              desc.count >= 18,
              let rawChoices = raw.choices,
              rawChoices.count >= 2 else {
            return nil
        }

        let bannedTitles = ["随机事件", "小猫事件", "奇怪事件", "猫咪事件"]
        guard !bannedTitles.contains(title) else { return nil }

        let choices = rawChoices.prefix(2).compactMap { rawChoice -> EventChoice? in
            guard let label = rawChoice.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let result = rawChoice.result?.trimmingCharacters(in: .whitespacesAndNewlines),
                  label.count >= 2,
                  result.count >= 8 else {
                return nil
            }

            return EventChoice(
                label: String(label.prefix(12)),
                result: String(result.prefix(60)),
                affinityDelta: clampEventDelta(rawChoice.affinity ?? 0),
                happinessDelta: clampEventDelta(rawChoice.happiness ?? 0),
                hungerDelta: clampEventDelta(rawChoice.hunger ?? 0),
                healthDelta: clampEventDelta(rawChoice.health ?? 0)
            )
        }

        guard choices.count == 2 else { return nil }
        return CatEvent(
            emoji: raw.emoji?.isEmpty == false ? raw.emoji! : "🐾",
            title: title,
            desc: String(desc.prefix(70)),
            choices: choices
        )
    }

    private func clampEventDelta(_ value: Int) -> Int {
        max(-3, min(3, value))
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
            setBehavior(.idle, title: "长睡", detail: "猫咪永远地睡着了…", intensity: 5)
        } else {
            refreshBehaviorFromState(reason: "tick")
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
        let before = state.affinity
        let bonus = delta > 0 ? state.growthStage.affinityGainBonus : 0
        let actualDelta = delta + bonus
        state.affinity = max(0, min(100, state.affinity + actualDelta))
        let changed = state.affinity - before
        showBondChange(delta: changed)
    }

    private func showBondChange(delta: Int) {
        guard delta != 0 else { return }
        let direction = delta > 0 ? "更靠近了一点" : "更防备了一点"
        let sign = delta > 0 ? "+" : ""
        bondChangeBanner = "\(state.affinityLevel.emoji) \(state.catName)\(direction)  好感\(sign)\(delta)"

        Task {
            try? await Task.sleep(for: .seconds(4))
            bondChangeBanner = nil
        }
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
        if state.diaryEntries.count >= 10 { tryUnlock(.shopaholic) }

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
