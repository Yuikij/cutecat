import Foundation
import SwiftUI

enum CatContextActionCommand: Hashable {
    case interaction(Interaction)
    case observe
    case comfort
    case giveSpace
}

struct CatContextAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let command: CatContextActionCommand
}

struct CareInsight {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private extension Interaction {
    var isIntrusive: Bool {
        switch self {
        case .play, .clean, .discipline, .headpat, .belly, .cuddle:
            true
        case .feed, .medical, .chat:
            false
        }
    }
}

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
        if state.isDead { return .away }
        return displayMood ?? state.currentBehavior.kind.displayMood
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

    var careInsight: CareInsight {
        if state.isDead {
            return CareInsight(
                icon: "moon.stars.fill",
                title: "躲起来了",
                detail: "不要重开，慢慢叫它回来。关系低谷需要耐心，不需要惩罚。",
                tint: CozyPalette.wood
            )
        }
        if state.health <= 2 {
            return CareInsight(
                icon: "cross.case.fill",
                title: "需要照顾身体",
                detail: "先看病，再陪它安静恢复；这时候玩闹收益很低。",
                tint: CozyPalette.rose
            )
        }
        if state.currentBehavior.kind == .guardingBelly || state.currentBehavior.kind == .sulking {
            return CareInsight(
                icon: "hand.raised.fill",
                title: "它在守边界",
                detail: "尊重一次，比强行靠近更容易让关系往前走。",
                tint: CozyPalette.wood
            )
        }
        if state.currentBehavior.kind == .hiding {
            return CareInsight(
                icon: "eye.slash.fill",
                title: "它需要安全感",
                detail: "距离、低声、食物都可以；别急着证明亲密。",
                tint: CozyPalette.wood
            )
        }
        if state.currentBehavior.kind == .writingDiary {
            return CareInsight(
                icon: "book.closed.fill",
                title: "它在整理心事",
                detail: "偷看会变成记忆，不偷看也会变成记忆。",
                tint: CozyPalette.moss
            )
        }
        if state.hunger >= 8 {
            return CareInsight(
                icon: "fork.knife",
                title: "它真的饿了",
                detail: "先处理饭碗，后面的亲密才会更自然。",
                tint: .orange
            )
        }
        if state.energy <= 2 {
            return CareInsight(
                icon: "moon.fill",
                title: "低电量",
                detail: "安静陪伴会比玩耍更有用。",
                tint: CozyPalette.wood
            )
        }
        if state.cleanliness <= 2 {
            return CareInsight(
                icon: "sparkles",
                title: "它有点嫌弃自己",
                detail: "清洁能改善状态，但太粗暴也会被记一笔。",
                tint: CozyPalette.sky
            )
        }
        if state.affinity < 25 {
            return CareInsight(
                icon: "pawprint.fill",
                title: "还在试探你",
                detail: "观察和稳定出现，比高频互动更能建立信任。",
                tint: CozyPalette.wood
            )
        }
        if state.affinity >= 70 {
            return CareInsight(
                icon: "heart.fill",
                title: "关系很稳",
                detail: "它会接受更多亲近，但仍然有自己的小脾气。",
                tint: CozyPalette.moss
            )
        }
        return CareInsight(
            icon: "leaf.fill",
            title: "一起过小日子",
            detail: "跟着它现在做的事选择，不用每次都把状态拉满。",
            tint: CozyPalette.moss
        )
    }

    var contextualActions: [CatContextAction] {
        guard state.isDead == false else { return [] }

        if state.health <= 2 {
            return [
                makeAction("看病", "cross.case.fill", CozyPalette.rose, .interaction(.medical)),
                makeAction("陪着", "heart.circle.fill", .purple, .comfort),
                makeAction("看看", "eye.fill", CozyPalette.wood, .observe),
            ]
        }

        if state.hunger >= 8 || state.currentBehavior.kind == .searchingFood {
            return [
                makeAction("喂点吃的", "fork.knife", .orange, .interaction(.feed)),
                makeAction("陪它找找", "magnifyingglass", CozyPalette.wood, .observe),
                makeAction("先等一下", "hourglass", CozyPalette.wood, .giveSpace),
            ]
        }

        if state.energy <= 2 || state.currentBehavior.kind == .napping {
            return [
                makeAction("不打扰", "moon.fill", CozyPalette.wood, .giveSpace),
                makeAction("轻轻陪着", "heart.circle.fill", .purple, .comfort),
                makeAction("整理一下", "shower.fill", CozyPalette.sky, .interaction(.clean)),
            ]
        }

        if state.cleanliness <= 2 || state.currentBehavior.kind == .grooming {
            return [
                makeAction("帮它清洁", "shower.fill", CozyPalette.sky, .interaction(.clean)),
                makeAction("假装没看", "eye.slash.fill", CozyPalette.wood, .giveSpace),
                makeAction("给点吃的", "fork.knife", .orange, .interaction(.feed)),
            ]
        }

        switch state.currentBehavior.kind {
        case .hiding:
            return [
                makeAction("留点距离", "eye.slash.fill", CozyPalette.wood, .giveSpace),
                makeAction("放低声音", "heart.circle.fill", .purple, .comfort),
                makeAction("拿食物哄", "fork.knife", .orange, .interaction(.feed)),
            ]
        case .guardingBelly, .sulking:
            return [
                makeAction("尊重边界", "hand.raised.fill", CozyPalette.wood, .giveSpace),
                makeAction("摸摸头", "hand.point.up.fill", CozyPalette.moss, .interaction(.headpat)),
                makeAction("冒险摸肚", "pawprint.fill", CozyPalette.rose, .interaction(.belly)),
            ]
        case .investigating, .plotting:
            return [
                makeAction("一起研究", "magnifyingglass", CozyPalette.wood, .observe),
                makeAction("逗它玩", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
                makeAction("突然抱抱", "heart.fill", .purple, .interaction(.cuddle)),
            ]
        case .writingDiary:
            return [
                makeAction("偷偷观察", "eye.fill", CozyPalette.wood, .observe),
                makeAction("不偷看", "eye.slash.fill", CozyPalette.wood, .giveSpace),
                makeAction("摸摸头", "hand.point.up.fill", CozyPalette.moss, .interaction(.headpat)),
            ]
        case .waiting:
            return [
                makeAction("靠近一点", "heart.fill", .purple, .interaction(.cuddle)),
                makeAction("摸摸头", "hand.point.up.fill", CozyPalette.moss, .interaction(.headpat)),
                makeAction("陪它玩", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
            ]
        case .showingOff:
            return [
                makeAction("认真看", "eye.fill", CozyPalette.wood, .observe),
                makeAction("陪它演", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
                makeAction("夸夸它", "heart.circle.fill", .purple, .comfort),
            ]
        default:
            if state.activeTraits.contains(.clingy) {
                return [
                    makeAction("抱一下", "heart.fill", .purple, .interaction(.cuddle)),
                    makeAction("摸摸头", "hand.point.up.fill", CozyPalette.moss, .interaction(.headpat)),
                    makeAction("陪它玩", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
                ]
            }
            if state.activeTraits.contains(.curious) {
                return [
                    makeAction("观察它", "eye.fill", CozyPalette.wood, .observe),
                    makeAction("丢玩具", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
                    makeAction("给点吃的", "fork.knife", .orange, .interaction(.feed)),
                ]
            }
            return [
                makeAction("观察", "eye.fill", CozyPalette.wood, .observe),
                makeAction("喂食", "fork.knife", .orange, .interaction(.feed)),
                makeAction("玩一会儿", "gamecontroller.fill", CozyPalette.moss, .interaction(.play)),
            ]
        }
    }

    func renameCat(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.catName = trimmed
        save()
    }

    private func makeAction(
        _ title: String,
        _ icon: String,
        _ tint: Color,
        _ command: CatContextActionCommand
    ) -> CatContextAction {
        CatContextAction(
            id: "\(title)-\(icon)",
            title: title,
            icon: icon,
            tint: tint,
            command: command
        )
    }

    // MARK: - Bond Loop

    func checkDailyBondMoment() async {
        guard state.isDead == false else { return }
        guard state.lastDiaryDate != DayKey.todayString else { return }

        let mood = diaryMoodForCurrentState()
        let seed = dailyDiarySeed()
        state.lastDiaryDate = DayKey.todayString
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

    func giveCatSpace() async {
        guard state.isDead == false else { return }
        guard isGeneratingReply == false else { return }

        state.observationCount += 1

        let boundaryMatters = state.currentBehavior.kind == .hiding ||
            state.currentBehavior.kind == .guardingBelly ||
            state.currentBehavior.kind == .sulking ||
            state.currentBehavior.kind == .writingDiary ||
            state.affinity < 35

        if boundaryMatters {
            state.happiness = min(10, state.happiness + 1)
            state.energy = min(10, state.energy + 1)
            adjustAffinity(state.affinity < 35 ? 3 : 2)
        } else {
            adjustAffinity(1)
        }

        let text = spaceLine(boundaryMatters: boundaryMatters)
        setBehavior(
            boundaryMatters ? .waiting : .idle,
            title: boundaryMatters ? "边界被尊重" : "安静同处",
            detail: text,
            intensity: boundaryMatters ? 2 : 1
        )
        recordInteraction(.chat, emoji: "🤫", comment: text)
        addMemory("主人没有打扰\(state.catName)：\(text)", source: .interaction, poignancy: boundaryMatters ? 7 : 4)
        showTemporaryStatus(mood: boundaryMatters ? .shy : .thinking, text: text, emoji: "🤫")

        if boundaryMatters && (state.observationCount == 1 || state.observationCount % 4 == 0) {
            await appendDiary(
                trigger: "边界被尊重",
                mood: .warm,
                fallback: "主人今天没有硬把我抱出来。我把这件事记在很里面的地方。"
            )
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
        if state.comfortCount >= 3 || state.observationCount >= 3 {
            return "主人又回来了。我没有马上过去，但耳朵先替我相信了一点。"
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

    private func spaceLine(boundaryMatters: Bool) -> String {
        if boundaryMatters {
            if state.currentBehavior.kind == .writingDiary {
                return "\(state.catName)用爪子压住日记本，确认你没有偷看后，耳朵松了一点。"
            }
            if state.activeTraits.contains(.tsundere) {
                return "\(state.catName)背对着你哼了一声，但尾巴尖没有再躲远。"
            }
            if state.activeTraits.contains(.edgelord) {
                return "\(state.catName)仍在角落里，但把影子旁边的位置留给了你。"
            }
            return "\(state.catName)发现你没有逼近，慢慢把自己从紧绷里放出来一点。"
        }

        if state.activeTraits.contains(.curious) {
            return "\(state.catName)把安静也当成玩具，偷偷研究你为什么不动。"
        }
        if state.affinity >= 60 {
            return "\(state.catName)和你待在同一片安静里，像这也是一种贴近。"
        }
        return "\(state.catName)没有被催促，只是在你附近继续过自己的小日子。"
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
            setBehavior(.hiding, title: "躲起来了", detail: "\(state.catName)躲到了很深的地方，只露出一点点尾巴。", intensity: 5)
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
        if maybeApplyInteractionFatigue(interaction) {
            return
        }
        if maybeRejectIntrusiveInteraction(interaction) {
            return
        }

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
        checkAchievements()
    }

    private func maybeApplyInteractionFatigue(_ interaction: Interaction) -> Bool {
        guard interaction != .medical else { return false }

        let recentSame = state.interactions
            .suffix(8)
            .filter {
                $0.interaction == interaction &&
                Date.now.timeIntervalSince($0.createdAt) < 150
            }
            .count
        guard recentSame >= 2 else { return false }

        if interaction == .feed && state.hunger >= 7 { return false }

        let text = fatigueLine(for: interaction)
        if interaction.isIntrusive {
            state.happiness = max(0, state.happiness - 1)
            adjustAffinity(-1)
        }
        recordInteraction(interaction, emoji: "⏳", comment: text)
        setBehavior(.sulking, title: "有点腻了", detail: text, intensity: 3)
        addMemory("主人连续做了很多次\(interaction.title)，\(state.catName)有点腻了：\(text)", source: .interaction, poignancy: 5)
        showTemporaryStatus(mood: interaction.isIntrusive ? .sad : .thinking, text: text, emoji: "⏳")
        save()
        return true
    }

    private func fatigueLine(for interaction: Interaction) -> String {
        switch interaction {
        case .feed:
            return "\(state.catName)闻了闻饭碗，表示爱不是把食物塞成小山。"
        case .play:
            return "\(state.catName)把玩具按住了：同一套把戏今天已经看穿。"
        case .clean:
            return "\(state.catName)后退半步，觉得自己不是一条毛巾。"
        case .discipline:
            return "\(state.catName)安静下来，但眼神把这件事折进了小本子。"
        case .chat:
            return "\(state.catName)眨了眨眼，像是暂时把人类语言放到一边。"
        case .headpat:
            return "\(state.catName)歪头躲开一点：喜欢也不能一直摸同一个地方。"
        case .belly:
            return "\(state.catName)把肚子收起来，明确表示那里不是公共区域。"
        case .cuddle:
            return "\(state.catName)轻轻推开你，想把亲密留到下一会儿。"
        case .medical:
            return "\(state.catName)配合完检查，决定今天到此为止。"
        }
    }

    private func maybeRejectIntrusiveInteraction(_ interaction: Interaction) -> Bool {
        guard interaction.isIntrusive else { return false }
        guard state.affinity < 85 else { return false }

        let behavior = state.currentBehavior.kind
        let isSensitiveMoment = behavior == .hiding ||
            behavior == .guardingBelly ||
            behavior == .sulking ||
            behavior == .napping ||
            behavior == .writingDiary
        guard isSensitiveMoment else { return false }

        var resistance = 35
        if behavior == .guardingBelly { resistance += 18 }
        if behavior == .hiding || behavior == .sulking { resistance += 14 }
        if behavior == .writingDiary { resistance += 10 }
        if state.activeTraits.contains(.tsundere) { resistance += 10 }
        if state.activeTraits.contains(.edgelord) { resistance += 8 }
        if state.activeTraits.contains(.clingy) { resistance -= 12 }
        if state.affinity >= 55 { resistance -= 18 }
        if state.affinity < 25 { resistance += 10 }
        if interaction == .belly { resistance += 18 }
        if interaction == .clean && state.cleanliness <= 2 { resistance -= 20 }

        let rejected = Int.random(in: 0..<100) < max(10, min(80, resistance))
        guard rejected else { return false }

        applyIntrusionRejection(interaction)
        return true
    }

    private func applyIntrusionRejection(_ interaction: Interaction) {
        let interruptedTitle = state.currentBehavior.title

        switch interaction {
        case .play:
            state.traitScore.playCount += 1
        case .clean:
            state.traitScore.cleanCount += 1
        case .discipline:
            state.traitScore.disciplineCount += 1
        case .medical:
            state.traitScore.medicalCount += 1
        case .headpat, .belly, .cuddle:
            state.traitScore.touchCount += 1
        case .feed:
            state.traitScore.feedCount += 1
        case .chat:
            state.traitScore.chatCount += 1
        }

        let text = intrusionRejectionLine(interaction)
        state.happiness = max(0, state.happiness - 1)
        adjustAffinity(interaction == .belly ? -2 : -1)
        setBehavior(.sulking, title: "被打扰了", detail: text, intensity: 4)
        recordInteraction(interaction, emoji: "…", comment: text)
        addMemory("主人在\(interruptedTitle)时打扰了\(state.catName)：\(text)", source: .interaction, poignancy: 7)
        showTemporaryStatus(mood: .sad, text: text, emoji: "…")
        checkAchievements()
        save()
    }

    private func intrusionRejectionLine(_ interaction: Interaction) -> String {
        if state.currentBehavior.kind == .writingDiary {
            return "\(state.catName)啪地合上日记本，今天暂时不想让你靠太近。"
        }
        if state.currentBehavior.kind == .napping {
            return "\(state.catName)困得把脸埋起来，只伸出尾巴尖表示抗议。"
        }
        if interaction == .belly {
            return "\(state.catName)立刻护住肚子：这里还不是你的领地。"
        }
        if state.activeTraits.contains(.tsundere) {
            return "\(state.catName)往旁边挪了一点，小声说：现在不准。"
        }
        if state.activeTraits.contains(.edgelord) {
            return "\(state.catName)缩回阴影里，像把门从里面轻轻关上。"
        }
        return "\(state.catName)没有生气，只是把距离重新摆回了自己舒服的位置。"
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
        state.traitScore.chatCount += 1
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
        let resultText = "\(pendingEvent?.emoji ?? "🐾") \(choice.result)"
        eventResult = resultText

        checkAchievements()
        save()

        Task {
            try? await Task.sleep(for: .seconds(8))
            if eventResult == resultText {
                eventResult = nil
            }
        }
    }

    func dismissEvent() {
        pendingEvent = nil
        adjustAffinity(-1)
        save()
    }

    func clearEvent() {
        pendingEvent = nil
        if eventResult == nil {
            refreshBehaviorFromState(reason: "event-cleared")
        }
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
            state.comment = "\(state.catName)躲起来了。它还在附近，只是现在不想回应。"
            setBehavior(.hiding, title: "躲起来了", detail: "\(state.catName)躲到了很深的地方，只露出一点点尾巴。", intensity: 5)
        } else {
            refreshBehaviorFromState(reason: "tick")
        }

        state.lastTickAt = now
        save()
    }

    func llmTick(now: Date = .now) async {
        tick(now: now)

        guard state.isDead == false else { return }
        await nudgeAutonomousMoment(force: true)
        await refreshMoodWord()
    }

    func nudgeAutonomousMoment(force: Bool = false) async {
        guard state.isDead == false else { return }
        guard pendingEvent == nil else { return }
        guard isGeneratingReply == false else { return }
        guard actionStatusText == nil else { return }

        let behaviorAge = Date.now.timeIntervalSince(state.currentBehavior.startedAt)
        if force == false {
            guard behaviorAge >= 90 else { return }
            guard Int.random(in: 0..<100) < 45 else { return }
        }

        let seed = autonomousMomentSeed()
        let detail: String

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: autonomousMomentPrompt(seed: seed),
                    userMessage: "让猫自己做一件小事",
                    maxTokens: 72,
                    temperature: 1.25
                )
                detail = cleanAutonomousLine(reply, fallback: seed.detail)
            } catch {
                detail = seed.detail
            }
            isGeneratingReply = false
        } else {
            detail = seed.detail
        }

        setBehavior(seed.kind, title: seed.title, detail: detail, intensity: seed.intensity)
        state.comment = detail
        addMemory("\(state.catName)自己做了件小事：\(detail)", source: .tick, poignancy: seed.poignancy)
        save()
    }

    private struct AutonomousMomentSeed {
        let kind: CatBehaviorKind
        let title: String
        let detail: String
        let intensity: Int
        let poignancy: Int
    }

    private func autonomousMomentSeed() -> AutonomousMomentSeed {
        let traits = Set(state.activeTraits)

        if state.health <= 2 {
            return AutonomousMomentSeed(
                kind: .hiding,
                title: "低声休息",
                detail: "\(state.catName)把自己收进角落，偶尔抬眼确认你还在。",
                intensity: 5,
                poignancy: 7
            )
        }
        if state.hunger >= 8 {
            return AutonomousMomentSeed(
                kind: .searchingFood,
                title: "寻找食物",
                detail: "\(state.catName)绕着饭碗走了三圈，像在举行一场严肃的召唤仪式。",
                intensity: 4,
                poignancy: 5
            )
        }
        if state.energy <= 2 {
            return AutonomousMomentSeed(
                kind: .napping,
                title: "半梦半醒",
                detail: "\(state.catName)睡到一半伸出一只爪子，好像梦里也在找你。",
                intensity: 3,
                poignancy: 5
            )
        }
        if state.cleanliness <= 2 {
            return AutonomousMomentSeed(
                kind: .grooming,
                title: "嫌弃自己",
                detail: "\(state.catName)认真舔毛，表情像刚刚发现世界不够干净。",
                intensity: 3,
                poignancy: 4
            )
        }
        if traits.contains(.clingy) && state.affinity >= 35 {
            return AutonomousMomentSeed(
                kind: .waiting,
                title: "偷偷等你",
                detail: "\(state.catName)坐在你常出现的地方，假装自己只是路过。",
                intensity: 2,
                poignancy: 7
            )
        }
        if traits.contains(.tsundere) && state.affinity < 75 {
            return AutonomousMomentSeed(
                kind: .guardingBelly,
                title: "嘴硬待机",
                detail: "\(state.catName)背对着你整理尾巴，但耳朵一直朝你这边转。",
                intensity: 2,
                poignancy: 6
            )
        }
        if traits.contains(.curious) {
            return AutonomousMomentSeed(
                kind: .investigating,
                title: "调查世界",
                detail: "\(state.catName)盯着墙角看了很久，仿佛那里刚刚通过一条秘密。",
                intensity: 2,
                poignancy: 5
            )
        }
        if traits.contains(.edgelord) {
            return AutonomousMomentSeed(
                kind: .hiding,
                title: "深夜放空",
                detail: "\(state.catName)把影子当成被子，安静地盖在自己身上。",
                intensity: 2,
                poignancy: 6
            )
        }
        if Bool.random() {
            return AutonomousMomentSeed(
                kind: .writingDiary,
                title: "写小日记",
                detail: "\(state.catName)用爪尖按着日记本，写下一个只有自己懂的句号。",
                intensity: 2,
                poignancy: 7
            )
        }
        return AutonomousMomentSeed(
            kind: .idle,
            title: "小日子",
            detail: "\(state.catName)在房间里慢慢走了一圈，确认这里还是它的小世界。",
            intensity: 1,
            poignancy: 4
        )
    }

    private func autonomousMomentPrompt(seed: AutonomousMomentSeed) -> String {
        """
        你是住在手机里的猫猫\(state.catName)，不是AI助手。
        任务：写一个“猫自己正在做什么”的可见小场景，中文1句，24-42字。
        风格：具体、有代入感、有一点猫脑回路；不要解释，不要对话，不要括号动作描写。
        小模型可以有一点怪，但必须像真实电子宠物在自己过日子。
        当前状态：好感\(state.affinity)/100，心情\(state.happiness)/10，饥饿\(state.hunger)/10，精力\(state.energy)/10，清洁\(state.cleanliness)/10
        当前猫格：\(state.bondTitle)，\(state.bondSubtitle)
        场景方向：\(seed.title)
        参考但不要照抄：\(seed.detail)
        只输出场景正文。
        """
    }

    private func cleanAutonomousLine(_ raw: String, fallback: String) -> String {
        let line = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .first
            .map(String.init) ?? ""
        let cleaned = line
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
        if cleaned.count < 8 || cleaned.count > 70 {
            return fallback
        }
        return cleaned
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

    // MARK: - Calling Back

    func callCatBack() async {
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
        adjustAffinity(-8)
        checkAchievements()

        if modelRuntimeState == .ready {
            isGeneratingReply = true
            do {
                let reply = try await llamaSession.generateInteractionReply(
                    systemPrompt: "你是一只猫，刚刚被主人从躲藏里慢慢叫回来。描述你回来时的反应，1句中文，不超过25字。别像任务奖励，要有一点别扭和依恋。",
                    userMessage: "主人耐心地把猫咪叫回来了"
                )
                state.comment = reply.isEmpty ? "\(state.catName)从暗处探出脑袋，装作只是路过。" : reply
            } catch {
                state.comment = "\(state.catName)从暗处探出脑袋，装作只是路过。"
            }
            isGeneratingReply = false
        } else {
            state.comment = "\(state.catName)从暗处探出脑袋，装作只是路过。"
        }

        addMemory("你把躲起来的\(state.catName)慢慢叫回来了", source: .interaction, poignancy: 10)
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
        \(iconicLineDirective(context: "chat"))
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

    private func iconicLineDirective(context: String) -> String {
        let traits = Set(state.activeTraits)
        let roll = Int.random(in: 0..<100)
        let isWarmContext = context == "feed" || context == "play" || context == "headpat" || context == "cuddle" || context == "chat"
        let isBoundaryContext = context == "discipline" || context == "clean" || context == "bellyBite"
        let stronglyAttached = state.affinity >= 70 || traits.contains(.clingy) || traits.contains(.babyface)
        let guarded = state.affinity <= 35 || state.happiness <= 2 || traits.contains(.tsundere) || traits.contains(.edgelord) || traits.contains(.venomous)
        let unhinged = traits.contains(.schemer) || traits.contains(.berserker) || traits.contains(.chuuni)

        let mode: String
        if isBoundaryContext && (guarded || roll < 72) {
            mode = "coldBoundary"
        } else if isWarmContext && stronglyAttached && roll < 48 {
            mode = "possessiveLove"
        } else if guarded && roll < 34 {
            mode = "coldBoundary"
        } else if unhinged && roll < 38 {
            mode = "catLogic"
        } else if traits.contains(.tsundere) && roll < 50 {
            mode = "loveHate"
        } else if roll < 16 {
            mode = "catLogic"
        } else {
            mode = "ordinary"
        }

        let base = """
        名场景能力：你可以输出强情绪、荒诞猫脑回路和反差台词，但必须像猫的即时真心话，不要解释设定，不要复述规则。
        安全边界：可以把“冰箱、纸箱、口袋、床底、日记本、门口”等当作猫脑回路的夸张比喻；不要写真实伤害、血腥、囚禁教程或威胁行动。
        原创要求：不要照抄任何示例句，不要模板化；每次都根据好感、心情、当前互动自己生成。
        """

        let modeRule: String
        switch mode {
        case "possessiveLove":
            modeRule = "本轮倾向：过度喜欢。可以把喜欢写到荒诞占有欲，比如想把主人藏好、保存好、随身带走；语气可以甜、疯、认真。"
        case "coldBoundary":
            modeRule = "本轮倾向：冷处理或嫌弃。可以表达拒绝互动、拉开距离、把主人排除在自己的小世界外；要有猫式矛盾，不能像仇恨宣言。"
        case "loveHate":
            modeRule = "本轮倾向：又爱又嫌弃。前半句嘴硬讨厌，后半句露出离不开主人的破绽。"
        case "catLogic":
            modeRule = "本轮倾向：离谱猫逻辑。把抽象关系物化成一个家用物品或小仪式，让玩家觉得想截图。"
        default:
            modeRule = "本轮倾向：日常但有性格。不要强行名场景，除非情绪自然冲上来。"
        }

        return base + "\n" + modeRule
    }

    private func feedPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人喂你吃的。\(iconicLineDirective(context: "feed")) 1-2句回应。\(speechRule)"
    }

    private func playPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人找你玩。\(iconicLineDirective(context: "play")) 1-2句回应。\(speechRule)"
    }

    private func cleanPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人给你洗澡。\(iconicLineDirective(context: "clean")) 1-2句回应。\(speechRule)"
    }

    private func disciplinePrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被主人训了。\(iconicLineDirective(context: "discipline")) 1-2句回应。\(speechRule)"
    }

    private func medicalPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被带去看医生了。\(iconicLineDirective(context: "medical")) 1-2句回应。\(speechRule)"
    }

    private func headpatPrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 被摸头了。\(iconicLineDirective(context: "headpat")) 1-2句回应。\(speechRule)"
    }

    private func bellyPrompt(willBite: Bool) -> String {
        willBite
            ? "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 肚子被摸触发攻击！\(iconicLineDirective(context: "bellyBite")) 1-2句凶狠回应。\(speechRule)"
            : "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 肚子被摸了。\(iconicLineDirective(context: "belly")) 1-2句回应。\(speechRule)"
    }

    private func cuddlePrompt() -> String {
        "你是猫猫\(state.catName)，好感\(state.affinity)/100。\(traitHint) 主人对你撒娇。\(iconicLineDirective(context: "cuddle")) 1-2句回应。\(speechRule)"
    }

    private func tickPrompt() -> String {
        "你是猫猫\(state.catName)。\(traitHint) 说你现在在干嘛，\(iconicLineDirective(context: "tick")) 1-2句中文。\(speechRule)"
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

    private func save() {
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func bundledModelURL() -> URL? {
        Bundle.main.url(forResource: "Qwen3.5-0.8B-Q4_K_M", withExtension: "gguf")
    }
}
