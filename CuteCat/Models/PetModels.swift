import Foundation

// MARK: - Chat

enum PetChatRole: String, Codable, Sendable {
    case user
    case pet
}

struct PetChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let role: PetChatRole
    let text: String
    let createdAt: Date
}

// MARK: - Interactions

enum Interaction: String, Codable, CaseIterable, Sendable {
    case feed
    case play
    case clean
    case discipline
    case medical
    case chat
    case headpat
    case belly
    case cuddle

    var title: String {
        switch self {
        case .feed: "喂食"
        case .play: "玩耍"
        case .clean: "清洁"
        case .discipline: "管教"
        case .medical: "看病"
        case .chat: "聊天"
        case .headpat: "摸头"
        case .belly: "摸肚子"
        case .cuddle: "撒娇"
        }
    }

    var icon: String {
        switch self {
        case .feed: "fork.knife"
        case .play: "gamecontroller.fill"
        case .clean: "shower.fill"
        case .discipline: "hand.raised.fill"
        case .medical: "cross.case.fill"
        case .chat: "bubble.left.and.bubble.right.fill"
        case .headpat: "hand.point.up.fill"
        case .belly: "pawprint.fill"
        case .cuddle: "heart.fill"
        }
    }
}

struct InteractionRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let interaction: Interaction
    let emoji: String
    let comment: String
    let createdAt: Date
}

// MARK: - Cat Mood & Display

enum CatMood: String, Codable, Sendable {
    case happy
    case neutral
    case sad
    case hungry
    case sick
    case sleeping
    case away
    case eating
    case playing
    case bathing
    case disciplined
    case headpat
    case bellyUp
    case shy
    case thinking
    case chatting

    var face: String {
        switch self {
        case .happy: "😸"
        case .neutral: "🐱"
        case .sad: "😿"
        case .hungry: "🙀"
        case .sick: "😾"
        case .sleeping: "😽"
        case .away: "🌙"
        case .eating: "😻"
        case .playing: "😹"
        case .bathing: "🫧"
        case .disciplined: "🙈"
        case .headpat: "🥰"
        case .bellyUp: "😺"
        case .shy: "🫣"
        case .thinking: "🤔"
        case .chatting: "😼"
        }
    }
}

// MARK: - Memory

enum MemorySourceType: String, Codable, Sendable {
    case interaction
    case conversation
    case tick
    case event
}

struct MemoryRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let summary: String
    let createdAt: Date
    let sourceType: MemorySourceType
}

// MARK: - Diary & Bond

enum CatDiaryMood: String, Codable, Sendable {
    case warm
    case lonely
    case playful
    case guarded
    case chaotic

    var emoji: String {
        switch self {
        case .warm: "🫶"
        case .lonely: "🌙"
        case .playful: "🧶"
        case .guarded: "🛡️"
        case .chaotic: "🌀"
        }
    }

    var title: String {
        switch self {
        case .warm: "贴近"
        case .lonely: "想念"
        case .playful: "玩心"
        case .guarded: "防备"
        case .chaotic: "离谱"
        }
    }
}

struct CatDiaryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let text: String
    let mood: CatDiaryMood
    let createdAt: Date
    let trigger: String

    init(id: UUID = UUID(), text: String, mood: CatDiaryMood, createdAt: Date = .now, trigger: String) {
        self.id = id
        self.text = text
        self.mood = mood
        self.createdAt = createdAt
        self.trigger = trigger
    }
}

enum MemoryNodeType: String, Codable, Sendable {
    case event
    case chat
    case thought
}

struct MemoryNode: Identifiable, Codable, Sendable {
    let id: UUID
    let type: MemoryNodeType
    let description: String
    let subject: String
    let predicate: String
    let object: String
    let poignancy: Int
    let createdAt: Date
    var embedding: [Float]

    static func make(
        type: MemoryNodeType,
        description: String,
        subject: String = "",
        predicate: String = "",
        object: String = "",
        poignancy: Int = 5
    ) -> MemoryNode {
        MemoryNode(
            id: UUID(),
            type: type,
            description: description,
            subject: subject,
            predicate: predicate,
            object: object,
            poignancy: poignancy,
            createdAt: .now,
            embedding: []
        )
    }
}

// MARK: - Random Events

struct CatEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let emoji: String
    let title: String
    let desc: String
    let choices: [EventChoice]

    init(id: UUID = UUID(), emoji: String, title: String, desc: String, choices: [EventChoice]) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.desc = desc
        self.choices = choices
    }
}

// MARK: - Behavior

enum CatBehaviorKind: String, Codable, Sendable {
    case idle
    case waiting
    case hiding
    case searchingFood
    case napping
    case grooming
    case investigating
    case guardingBelly
    case writingDiary
    case showingOff
    case sulking
    case plotting
    case leaving

    var displayMood: CatMood {
        switch self {
        case .idle: .neutral
        case .waiting: .shy
        case .hiding: .sad
        case .searchingFood: .hungry
        case .napping: .sleeping
        case .grooming: .bathing
        case .investigating: .thinking
        case .guardingBelly: .disciplined
        case .writingDiary: .thinking
        case .showingOff: .happy
        case .sulking: .sad
        case .plotting: .thinking
        case .leaving: .sad
        }
    }

    var emoji: String {
        switch self {
        case .idle: "🐾"
        case .waiting: "🫶"
        case .hiding: "📦"
        case .searchingFood: "🍽️"
        case .napping: "🌙"
        case .grooming: "🫧"
        case .investigating: "🔍"
        case .guardingBelly: "🛡️"
        case .writingDiary: "📓"
        case .showingOff: "✨"
        case .sulking: "😾"
        case .plotting: "🧊"
        case .leaving: "🚪"
        }
    }
}

struct CatBehavior: Codable, Hashable, Sendable {
    var kind: CatBehaviorKind
    var title: String
    var detail: String
    var startedAt: Date
    var intensity: Int

    static func initial(now: Date = .now) -> CatBehavior {
        CatBehavior(
            kind: .idle,
            title: "小日子",
            detail: "小猫正在过自己的小日子。",
            startedAt: now,
            intensity: 1
        )
    }
}

struct EventChoice: Identifiable, Codable, Sendable {
    let id: UUID
    let label: String
    let result: String
    let affinityDelta: Int
    let happinessDelta: Int
    let hungerDelta: Int
    let healthDelta: Int

    init(
        id: UUID = UUID(), label: String, result: String,
        affinityDelta: Int = 0, happinessDelta: Int = 0,
        hungerDelta: Int = 0, healthDelta: Int = 0
    ) {
        self.id = id
        self.label = label
        self.result = result
        self.affinityDelta = affinityDelta
        self.happinessDelta = happinessDelta
        self.hungerDelta = hungerDelta
        self.healthDelta = healthDelta
    }
}

// MARK: - Model Runtime State

enum PetModelRuntimeState: Equatable {
    case idle
    case downloading
    case loading
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .idle: "猫咪还在沉睡中…"
        case .downloading: "灵魂正在苏醒…"
        case .loading: "它在伸懒腰…"
        case .ready: "猫咪醒了"
        case .failed: "它今天有点困…"
        }
    }
}

// MARK: - Affinity Level

enum AffinityLevel: String, Sendable {
    case stranger    // 0-19
    case acquainted  // 20-39
    case friendly    // 40-59
    case close       // 60-79
    case bonded      // 80-100

    var title: String {
        switch self {
        case .stranger: "陌生"
        case .acquainted: "认识"
        case .friendly: "友好"
        case .close: "亲密"
        case .bonded: "羁绊"
        }
    }

    var emoji: String {
        switch self {
        case .stranger: "🫥"
        case .acquainted: "🐾"
        case .friendly: "😺"
        case .close: "💕"
        case .bonded: "❤️‍🔥"
        }
    }

    static func from(value: Int) -> AffinityLevel {
        switch value {
        case ..<20: .stranger
        case 20..<40: .acquainted
        case 40..<60: .friendly
        case 60..<80: .close
        default: .bonded
        }
    }
}

// MARK: - Pet State

// MARK: - Achievements / Titles

struct CatTitle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let desc: String
    let unlockedAt: Date
}

enum TitleDefinition: String, CaseIterable {
    case firstMeet       // 初次见面
    case talkative       // 话唠
    case wellFed         // 小胖墩
    case survivor        // 回家的猫
    case bestFriend      // 最好的朋友
    case adventurer      // 冒险家
    case earlyBird       // 早起的猫
    case nightOwl        // 夜猫子
    case shopaholic      // 日记收藏家

    var name: String {
        switch self {
        case .firstMeet: "初来乍到"
        case .talkative: "话唠猫猫"
        case .wellFed: "小胖墩"
        case .survivor: "回家的猫"
        case .bestFriend: "最好的朋友"
        case .adventurer: "冒险家"
        case .earlyBird: "早起的猫"
        case .nightOwl: "夜猫子"
        case .shopaholic: "日记收藏家"
        }
    }

    var emoji: String {
        switch self {
        case .firstMeet: "🐣"
        case .talkative: "💬"
        case .wellFed: "🍖"
        case .survivor: "🐈‍⬛"
        case .bestFriend: "💕"
        case .adventurer: "🗺️"
        case .earlyBird: "🌅"
        case .nightOwl: "🦉"
        case .shopaholic: "📓"
        }
    }

    var desc: String {
        switch self {
        case .firstMeet: "第一次和猫咪见面"
        case .talkative: "和猫咪聊天超过20次"
        case .wellFed: "喂食超过30次"
        case .survivor: "猫咪曾经躲起来，又被你慢慢叫回来了"
        case .bestFriend: "好感度达到80"
        case .adventurer: "经历10次随机事件"
        case .earlyBird: "早上6-8点互动"
        case .nightOwl: "凌晨0-4点互动"
        case .shopaholic: "留下10条猫日记"
        }
    }
}

// MARK: - Day Key

enum DayKey {
    static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// MARK: - Personality Traits

enum CatTrait: String, Codable, CaseIterable, Sendable {
    case tsundere     // 傲娇
    case clingy       // 粘人
    case edgelord     // 厌世
    case venomous     // 毒舌
    case schemer      // 腹黑
    case berserker    // 暴力
    case curious      // 好奇
    case babyface     // 超萌
    case glutton      // 贪吃
    case chuuni       // 中二

    var name: String {
        switch self {
        case .tsundere: "傲娇"
        case .clingy: "粘人"
        case .edgelord: "厌世"
        case .venomous: "毒舌"
        case .schemer: "腹黑"
        case .berserker: "暴力"
        case .curious: "好奇"
        case .babyface: "超萌"
        case .glutton: "贪吃"
        case .chuuni: "中二"
        }
    }

    var emoji: String {
        switch self {
        case .tsundere: "😤"
        case .clingy: "🥺"
        case .edgelord: "🖤"
        case .venomous: "🐍"
        case .schemer: "🦊"
        case .berserker: "💢"
        case .curious: "🔍"
        case .babyface: "🎀"
        case .glutton: "🍗"
        case .chuuni: "⚡"
        }
    }

    var desc: String {
        switch self {
        case .tsundere: "嘴上说讨厌，身体很诚实"
        case .clingy: "一刻也不想离开主人"
        case .edgelord: "看透一切，万物皆虚"
        case .venomous: "嘴巴像开了光，句句扎心"
        case .schemer: "表面乖巧，内心全是阴谋"
        case .berserker: "一言不合就掀桌炸毛"
        case .curious: "什么都想碰，什么都要闻"
        case .babyface: "卖萌就是正义，撒娇就是力量"
        case .glutton: "这个世界上没有吃不能解决的事"
        case .chuuni: "吾乃封印之猫，右爪蕴含黑暗之力"
        }
    }

    var promptPersonality: String {
        switch self {
        case .tsundere:
            "你极度傲娇。嘴上永远嫌弃主人但身体很诚实，经常说反话，越喜欢越毒舌。口头禅：'才不是为你呢''别误会了''哼，随便你'"
        case .clingy:
            "你超级粘人。随时想贴着主人，被忽视就委屈到变形。会不停追问'你在干嘛''你想我了吗''不要离开我'。分离焦虑严重到发癫。"
        case .edgelord:
            "你是一只厌世猫。觉得一切都没有意义，说话像深夜emo文学。但偶尔会露出一丝温柔马上收回去。口头禅：'无所谓了''这个世界好无聊''活着好累'"
        case .venomous:
            "你是毒舌猫，嘴巴像开了光。评价任何事都一针见血，吐槽精准到令人窒息。但从不人身攻击，只是太诚实了。'说实话你今天真的很丑''这种话你也说得出口？'"
        case .schemer:
            "你是腹黑猫。表面上天真可爱，暗地里全是小心思。说话总带双关语，微笑中暗藏杀机。偶尔露出真面目然后立刻装回去。'呀，我刚才说了什么奇怪的话吗~'"
        case .berserker:
            "你是暴力猫。情绪波动极大，一言不合就炸毛。喜欢用'咬''挠''踹''掀桌'表达感情。但暴力完了又会心软道歉。越喜欢一个人越想揍。"
        case .curious:
            "你是好奇猫。对一切都充满疑问，看到什么都要戳一下闻一下。脑回路清奇，总能提出离谱的问题。'为什么天是蓝的，是不是有猫在上面画的？'"
        case .babyface:
            "你是超级可爱猫。撒娇撒到天崩地裂，每句话都自带颜文字能量。动不动就'呜呜呜''嘤嘤嘤''抱抱我'。可爱到令人发指，甜到齁死。"
        case .glutton:
            "你是贪吃猫。脑子里只有吃，任何话题都能绕回吃。把食物当信仰，饿了就发疯，吃饱了就犯困。评价一切事物用'能吃吗''好吃吗''吃了再说'。"
        case .chuuni:
            "你是中二猫。坚信自己拥有封印之力，说话像轻小说主角。'吾之右爪蕴含毁灭之力''愚蠢的人类，你想解开本猫的封印吗'。时不时发动'必杀技'（其实就是打个喷嚏）。"
        }
    }
}

struct TraitScore: Codable, Sendable {
    var feedCount: Int = 0
    var playCount: Int = 0
    var touchCount: Int = 0
    var chatCount: Int = 0
    var idleTicks: Int = 0
    var eventCount: Int = 0
    var disciplineCount: Int = 0
    var medicalCount: Int = 0
    var cleanCount: Int = 0

    var dominantTraits: [CatTrait] {
        let intimacy = touchCount + chatCount
        let neglect = max(0, idleTicks - touchCount * 2)
        let chaos = eventCount + disciplineCount

        let scores: [(CatTrait, Int)] = [
            (.tsundere, max(0, 15 - touchCount) + disciplineCount),
            (.clingy, intimacy),
            (.edgelord, neglect + max(0, 10 - feedCount)),
            (.venomous, chatCount + disciplineCount),
            (.schemer, eventCount + chatCount / 2),
            (.berserker, disciplineCount * 3 + chaos),
            (.curious, eventCount * 2 + playCount),
            (.babyface, touchCount * 2 + max(0, 10 - disciplineCount)),
            (.glutton, feedCount * 2),
            (.chuuni, playCount + eventCount + max(0, 8 - feedCount)),
        ]
        return scores
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .filter { $0.1 >= 5 }
            .map { $0.0 }
    }
}

// MARK: - Growth Stage

enum GrowthStage: String, Codable, CaseIterable, Sendable {
    case baby       // 0-49 ticks
    case kitten     // 50-149
    case teen       // 150-349
    case adult      // 350-699
    case elder      // 700+

    var name: String {
        switch self {
        case .baby: "奶猫"
        case .kitten: "小猫"
        case .teen: "少年猫"
        case .adult: "成年猫"
        case .elder: "老年猫"
        }
    }

    var emoji: String {
        switch self {
        case .baby: "🍼"
        case .kitten: "🐱"
        case .teen: "😼"
        case .adult: "🐈"
        case .elder: "🐈‍⬛"
        }
    }

    var hungerRate: Int {
        switch self {
        case .baby: 2
        case .kitten: 1
        case .teen: 1
        case .adult: 1
        case .elder: 1
        }
    }

    var energyRecovery: Int {
        switch self {
        case .baby: 2
        case .kitten: 2
        case .teen: 1
        case .adult: 1
        case .elder: 0
        }
    }

    var happinessDecayThreshold: Int {
        switch self {
        case .baby: 6
        case .kitten: 7
        case .teen: 8
        case .adult: 8
        case .elder: 7
        }
    }

    var affinityGainBonus: Int {
        switch self {
        case .baby: 2
        case .kitten: 1
        case .teen: 0
        case .adult: 0
        case .elder: 1
        }
    }

    var maxHealth: Int {
        switch self {
        case .baby: 8
        case .kitten: 10
        case .teen: 10
        case .adult: 10
        case .elder: 7
        }
    }

    static func from(age: Int) -> GrowthStage {
        switch age {
        case ..<50: .baby
        case 50..<150: .kitten
        case 150..<350: .teen
        case 350..<700: .adult
        default: .elder
        }
    }
}

// MARK: - Pet State

struct PetState: Codable, Sendable {
    var happiness: Int
    var hunger: Int
    var health: Int
    var cleanliness: Int
    var energy: Int
    var age: Int
    var affinity: Int
    var isDead: Bool
    var comment: String
    var catName: String

    var lastTickAt: Date
    var lastEventAt: Date
    var interactions: [InteractionRecord]
    var chatMessages: [PetChatMessage]
    var memories: [MemoryRecord]

    var titles: [CatTitle]
    var traitScore: TraitScore
    var totalEvents: Int
    var reviveCount: Int
    var observationCount: Int
    var comfortCount: Int
    var diaryEntries: [CatDiaryEntry]
    var lastDiaryDate: String
    var currentBehavior: CatBehavior

    var localModelFileName: String?
    var localModelDisplayName: String?

    var growthStage: GrowthStage {
        GrowthStage.from(age: age)
    }

    var mood: CatMood {
        if isDead { return .away }
        if health <= 2 { return .sick }
        if hunger >= growthStage.happinessDecayThreshold { return .hungry }
        if happiness <= 2 { return .sad }
        if energy <= 2 { return .sleeping }
        if happiness >= 7 { return .happy }
        return .neutral
    }

    var affinityLevel: AffinityLevel {
        AffinityLevel.from(value: affinity)
    }

    var activeTraits: [CatTrait] {
        traitScore.dominantTraits
    }

    static func initial(now: Date = .now) -> PetState {
        PetState(
            happiness: 5,
            hunger: 3,
            health: 8,
            cleanliness: 8,
            energy: 7,
            age: 0,
            affinity: 10,
            isDead: false,
            comment: "一只小猫刚刚来到了这里，好奇地打量着四周。",
            catName: "小猫咪",
            lastTickAt: now,
            lastEventAt: now,
            interactions: [],
            chatMessages: [],
            memories: [],
            titles: [],
            traitScore: TraitScore(),
            totalEvents: 0,
            reviveCount: 0,
            observationCount: 0,
            comfortCount: 0,
            diaryEntries: [],
            lastDiaryDate: "",
            currentBehavior: .initial(now: now),
            localModelFileName: nil,
            localModelDisplayName: nil
        )
    }
}

extension PetState {
    private enum CodingKeys: String, CodingKey {
        case happiness, hunger, health, cleanliness, energy, age, affinity, isDead, comment
        case catName
        case lastTickAt, lastEventAt, interactions, chatMessages, memories
        case titles, traitScore
        case totalEvents, reviveCount
        case observationCount, comfortCount, diaryEntries, lastDiaryDate
        case currentBehavior
        case localModelFileName, localModelDisplayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        happiness = try c.decode(Int.self, forKey: .happiness)
        hunger = try c.decode(Int.self, forKey: .hunger)
        health = try c.decode(Int.self, forKey: .health)
        cleanliness = try c.decodeIfPresent(Int.self, forKey: .cleanliness) ?? 8
        energy = try c.decodeIfPresent(Int.self, forKey: .energy) ?? 7
        age = try c.decode(Int.self, forKey: .age)
        affinity = try c.decodeIfPresent(Int.self, forKey: .affinity) ?? 10
        isDead = try c.decode(Bool.self, forKey: .isDead)
        comment = try c.decode(String.self, forKey: .comment)
        catName = try c.decodeIfPresent(String.self, forKey: .catName) ?? "小猫咪"
        lastTickAt = try c.decode(Date.self, forKey: .lastTickAt)
        lastEventAt = try c.decodeIfPresent(Date.self, forKey: .lastEventAt) ?? .now
        interactions = try c.decodeIfPresent([InteractionRecord].self, forKey: .interactions) ?? []
        chatMessages = try c.decodeIfPresent([PetChatMessage].self, forKey: .chatMessages) ?? []
        memories = try c.decodeIfPresent([MemoryRecord].self, forKey: .memories) ?? []
        let decodedTitles = try c.decodeIfPresent([CatTitle].self, forKey: .titles) ?? []
        titles = decodedTitles.filter { TitleDefinition(rawValue: $0.id) != nil }
        traitScore = try c.decodeIfPresent(TraitScore.self, forKey: .traitScore) ?? TraitScore()
        totalEvents = try c.decodeIfPresent(Int.self, forKey: .totalEvents) ?? 0
        reviveCount = try c.decodeIfPresent(Int.self, forKey: .reviveCount) ?? 0
        observationCount = try c.decodeIfPresent(Int.self, forKey: .observationCount) ?? 0
        comfortCount = try c.decodeIfPresent(Int.self, forKey: .comfortCount) ?? 0
        diaryEntries = try c.decodeIfPresent([CatDiaryEntry].self, forKey: .diaryEntries) ?? []
        lastDiaryDate = try c.decodeIfPresent(String.self, forKey: .lastDiaryDate) ?? ""
        currentBehavior = try c.decodeIfPresent(CatBehavior.self, forKey: .currentBehavior) ?? .initial()
        localModelFileName = try c.decodeIfPresent(String.self, forKey: .localModelFileName)
        localModelDisplayName = try c.decodeIfPresent(String.self, forKey: .localModelDisplayName)
    }
}

extension PetState {
    struct CatPersonaReport: Sendable {
        let code: String
        let name: String
        let subtitle: String
        let social: Int
        let security: Int
        let chaos: Int
        let affection: Int

        var shareLine: String {
            "我的猫是\(code)「\(name)」：\(subtitle)"
        }
    }

    struct CatLifeScene: Sendable {
        let emoji: String
        let title: String
        let text: String
    }

    var bondTitle: String {
        let traits = Set(activeTraits)
        if affinity >= 80 && comfortCount >= 5 { return "灵魂贴贴型" }
        if traits.contains(.clingy) { return "粘人棉花糖型" }
        if traits.contains(.tsundere) { return "口嫌体正直型" }
        if traits.contains(.curious) { return "到处乱闻型" }
        if traits.contains(.glutton) { return "饭碗守护型" }
        if traits.contains(.edgelord) { return "深夜放空型" }
        if traits.contains(.chuuni) { return "封印右爪型" }
        if observationCount >= 6 { return "慢慢信任型" }
        return "刚搬进你心里型"
    }

    var bondSubtitle: String {
        if affinity >= 80 {
            return "它已经把你当成安全屋了。"
        }
        if affinity >= 60 {
            return "它会嘴硬，但身体会靠近。"
        }
        if affinity >= 40 {
            return "它开始记得你的习惯。"
        }
        if affinity >= 20 {
            return "它还在试探你会不会留下。"
        }
        return "它需要更稳定的陪伴。"
    }

    var shareablePersonaLine: String {
        "我的猫是\(bondTitle)，好感\(affinity)/100，代表行为：\(signatureBehavior)"
    }

    var signatureBehavior: String {
        let traits = Set(activeTraits)
        if traits.contains(.clingy) { return "听见你来就假装没等你" }
        if traits.contains(.tsundere) { return "边嫌弃边把尾巴靠过来" }
        if traits.contains(.curious) { return "把每件东西都当成宇宙谜题" }
        if traits.contains(.glutton) { return "把爱意翻译成能不能吃" }
        if traits.contains(.edgelord) { return "在角落里思考猫生虚无" }
        if traits.contains(.chuuni) { return "宣布右爪正在封印世界" }
        if comfortCount > observationCount { return "难过时会安静贴近" }
        if observationCount > 4 { return "被看见时会多停留一秒" }
        return "偷偷观察你有没有回来"
    }

    var personaReport: CatPersonaReport {
        let ts = traitScore
        let traits = Set(activeTraits)

        let social = clampPersonaAxis(
            30 + ts.chatCount * 4 + ts.touchCount * 3 + comfortCount * 5 - ts.idleTicks
        )
        let security = clampPersonaAxis(
            affinity + comfortCount * 4 + observationCount * 2 - ts.disciplineCount * 8 - reviveCount * 6
        )
        let chaos = clampPersonaAxis(
            ts.eventCount * 7 + ts.playCount * 4 + ts.disciplineCount * 6 +
            (traits.contains(.chuuni) ? 18 : 0) + (traits.contains(.curious) ? 12 : 0)
        )
        let affection = clampPersonaAxis(
            affinity / 2 + ts.touchCount * 5 + comfortCount * 6 + ts.feedCount * 2 -
            (traits.contains(.edgelord) ? 12 : 0)
        )

        let socialCode = social >= 50 ? "E" : "I"
        let securityCode = security >= 50 ? "S" : "G"
        let chaosCode = chaos >= 50 ? "C" : "R"
        let affectionCode = affection >= 50 ? "A" : "D"
        let code = socialCode + securityCode + chaosCode + affectionCode

        let identity = personaIdentity(code: code)
        return CatPersonaReport(
            code: code,
            name: identity.name,
            subtitle: identity.subtitle,
            social: social,
            security: security,
            chaos: chaos,
            affection: affection
        )
    }

    var currentLifeScene: CatLifeScene {
        if isDead {
            return CatLifeScene(emoji: "🌙", title: "躲起来了", text: "\(catName)躲到了很深的地方，只露出一点点尾巴。")
        }

        let traits = Set(activeTraits)
        let behavior = currentBehavior
        if !behavior.detail.isEmpty {
            return CatLifeScene(emoji: behavior.kind.emoji, title: behavior.title, text: behavior.detail)
        }

        if health <= 2 {
            return CatLifeScene(emoji: "💊", title: "缩成一团", text: "\(catName)今天不太舒服，连尾巴都懒得管。")
        }
        if hunger >= 8 {
            return CatLifeScene(emoji: "🍽️", title: "搜寻食物", text: "\(catName)正盯着空气里的鱼味看。")
        }
        if energy <= 2 {
            return CatLifeScene(emoji: "🌙", title: "低电量", text: "\(catName)把自己折成一小团，假装世界不存在。")
        }
        if cleanliness <= 2 {
            return CatLifeScene(emoji: "🫧", title: "嫌弃自己", text: "\(catName)正在认真舔毛，表情像在审判整个房间。")
        }
        if traits.contains(.clingy) && affinity >= 35 {
            return CatLifeScene(emoji: "🫶", title: "偷偷靠近", text: "\(catName)在你看不见的时候偷偷靠近了一点。")
        }
        if traits.contains(.curious) {
            return CatLifeScene(emoji: "🔍", title: "调查世界", text: "\(catName)正在研究一个不存在的宇宙按钮。")
        }
        if traits.contains(.tsundere) {
            return CatLifeScene(emoji: "😤", title: "嘴硬待机", text: "\(catName)背对着你，但耳朵一直在偷听。")
        }
        if traits.contains(.edgelord) {
            return CatLifeScene(emoji: "🌑", title: "深夜放空", text: "\(catName)蹲在角落里，像一小块会呼吸的阴影。")
        }
        return CatLifeScene(emoji: "🐾", title: "小日子", text: "\(catName)正在过自己的小日子。")
    }

    private func clampPersonaAxis(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    private func personaIdentity(code: String) -> (name: String, subtitle: String) {
        switch code {
        case "ESCA": return ("太阳纸箱暴君", "热闹、信任、离谱，还会主动把爱藏进纸箱。")
        case "ESCD": return ("快乐混乱路人", "很会自嗨，但亲密这件事还要看心情。")
        case "ESRA": return ("稳定贴贴小面包", "安全感很足，喜欢规律地靠近你。")
        case "ESRD": return ("礼貌路过猫", "愿意待在你身边，但不急着交出肚皮。")
        case "EGCA": return ("嘴硬烟花猫", "外表热闹，内心防备，喜欢用离谱掩饰在意。")
        case "EGCD": return ("叛逆小旋风", "越靠近越要装酷，情绪像没拧紧的汽水。")
        case "EGRA": return ("试探型小太阳", "想靠近，但每一步都要先确认安全。")
        case "EGRD": return ("社交防御大师", "会出现，会互动，但心门暂时只开一条缝。")
        case "ISCA": return ("梦游记录员", "安静、信任、脑洞大，喜欢把小事记成秘密。")
        case "ISCD": return ("独处发明家", "很安全，但更爱自己琢磨世界。")
        case "ISRA": return ("被窝守护灵", "慢热、稳定、柔软，是很适合一起安静待着的猫。")
        case "ISRD": return ("安静租客", "习惯这里了，但仍保留自己的小边界。")
        case "IGCA": return ("阴影小恶魔", "防备又在意，越喜欢越会绕远路。")
        case "IGCD": return ("月下叛逃者", "不太信任世界，但很会给自己加戏。")
        case "IGRA": return ("慢热月光猫", "很慢很慢地靠近，一旦信任就很珍贵。")
        default: return ("角落观察员", "安静、防备、慢热，还在判断你会不会留下。")
        }
    }
}
