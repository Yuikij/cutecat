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
    case dead
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
        case .dead: "🪦"
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

// MARK: - Shop

struct ShopItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let emoji: String
    let desc: String

    init(id: UUID = UUID(), name: String, emoji: String, desc: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.desc = desc
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

// MARK: - Voice Style

enum VoiceStyle: String, Codable, CaseIterable, Sendable {
    case cute
    case baby
    case hyper
    case cool
    case gremlin
    case elder
    case robot
    case demon

    var title: String {
        switch self {
        case .cute: "软萌"
        case .baby: "奶音"
        case .hyper: "鸡血"
        case .cool: "高冷"
        case .gremlin: "小恶魔"
        case .elder: "老妖怪"
        case .robot: "电音"
        case .demon: "深渊"
        }
    }

    var emoji: String {
        switch self {
        case .cute: "🥰"
        case .baby: "👶"
        case .hyper: "⚡"
        case .cool: "🧊"
        case .gremlin: "😈"
        case .elder: "👴"
        case .robot: "🤖"
        case .demon: "👹"
        }
    }

    var desc: String {
        switch self {
        case .cute: "甜到齁死的撒娇音"
        case .baby: "奶声奶气小不点"
        case .hyper: "语速暴走兴奋猫"
        case .cool: "慢悠悠爱理不理"
        case .gremlin: "尖锐又快的坏笑"
        case .elder: "颤巍巍老猫念经"
        case .robot: "机器人电音猫"
        case .demon: "来自深渊的低吟"
        }
    }

    var rate: Float {
        switch self {
        case .cute: 0.52
        case .baby: 0.60
        case .hyper: 0.65
        case .cool: 0.35
        case .gremlin: 0.62
        case .elder: 0.30
        case .robot: 0.42
        case .demon: 0.32
        }
    }

    var pitch: Float {
        switch self {
        case .cute: 1.45
        case .baby: 1.7
        case .hyper: 1.55
        case .cool: 0.85
        case .gremlin: 1.8
        case .elder: 0.65
        case .robot: 0.5
        case .demon: 0.5
        }
    }
}

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
    case survivor        // 九命怪猫
    case bestFriend      // 最好的朋友
    case adventurer      // 冒险家
    case collector       // 收藏家
    case earlyBird       // 早起的猫
    case nightOwl        // 夜猫子
    case shopaholic      // 购物狂

    var name: String {
        switch self {
        case .firstMeet: "初来乍到"
        case .talkative: "话唠猫猫"
        case .wellFed: "小胖墩"
        case .survivor: "九命怪猫"
        case .bestFriend: "最好的朋友"
        case .adventurer: "冒险家"
        case .collector: "收藏家"
        case .earlyBird: "早起的猫"
        case .nightOwl: "夜猫子"
        case .shopaholic: "购物狂"
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
        case .collector: "💎"
        case .earlyBird: "🌅"
        case .nightOwl: "🦉"
        case .shopaholic: "🛍️"
        }
    }

    var desc: String {
        switch self {
        case .firstMeet: "第一次和猫咪见面"
        case .talkative: "和猫咪聊天超过20次"
        case .wellFed: "喂食超过30次"
        case .survivor: "猫咪死而复生"
        case .bestFriend: "好感度达到80"
        case .adventurer: "经历10次随机事件"
        case .collector: "收集5个宝物"
        case .earlyBird: "早上6-8点互动"
        case .nightOwl: "凌晨0-4点互动"
        case .shopaholic: "在小卖部购买10次"
        }
    }
}

// MARK: - Daily Streak

struct DailyStreak: Codable, Sendable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCheckInDate: String
    var totalCheckIns: Int

    static func initial() -> DailyStreak {
        DailyStreak(currentStreak: 0, longestStreak: 0, lastCheckInDate: "", totalCheckIns: 0)
    }

    static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    static var yesterdayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
    }

    var checkedInToday: Bool {
        lastCheckInDate == Self.todayString
    }

    mutating func checkIn() {
        let today = Self.todayString
        guard lastCheckInDate != today else { return }

        if lastCheckInDate == Self.yesterdayString {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)
        totalCheckIns += 1
        lastCheckInDate = today
    }

    var streakReward: Int {
        switch currentStreak {
        case 1: 1
        case 2: 2
        case 3: 3
        case 4...6: 4
        case 7...: 5
        default: 1
        }
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

// MARK: - Treasures

struct Treasure: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let emoji: String
    let rarity: TreasureRarity
    let foundAt: Date

    init(id: UUID = UUID(), name: String, emoji: String, rarity: TreasureRarity = .common) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.rarity = rarity
        self.foundAt = .now
    }
}

enum TreasureRarity: String, Codable, Sendable {
    case common
    case rare
    case legendary

    var label: String {
        switch self {
        case .common: "普通"
        case .rare: "稀有"
        case .legendary: "传说"
        }
    }

    var color: String {
        switch self {
        case .common: "gray"
        case .rare: "purple"
        case .legendary: "gold"
        }
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
    var voiceStyle: VoiceStyle

    var lastTickAt: Date
    var lastEventAt: Date
    var interactions: [InteractionRecord]
    var chatMessages: [PetChatMessage]
    var memories: [MemoryRecord]

    var inventoryItems: [ShopItem]
    var titles: [CatTitle]
    var streak: DailyStreak
    var traitScore: TraitScore
    var treasures: [Treasure]
    var totalShopBuys: Int
    var totalEvents: Int
    var reviveCount: Int

    var localModelFileName: String?
    var localModelDisplayName: String?

    var growthStage: GrowthStage {
        GrowthStage.from(age: age)
    }

    var mood: CatMood {
        if isDead { return .dead }
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
            voiceStyle: .cute,
            lastTickAt: now,
            lastEventAt: now,
            interactions: [],
            chatMessages: [],
            memories: [],
            inventoryItems: [],
            titles: [],
            streak: .initial(),
            traitScore: TraitScore(),
            treasures: [],
            totalShopBuys: 0,
            totalEvents: 0,
            reviveCount: 0,
            localModelFileName: nil,
            localModelDisplayName: nil
        )
    }
}

extension PetState {
    private enum CodingKeys: String, CodingKey {
        case happiness, hunger, health, cleanliness, energy, age, affinity, isDead, comment
        case catName, voiceStyle
        case lastTickAt, lastEventAt, interactions, chatMessages, memories, inventoryItems
        case titles, streak, traitScore, treasures
        case totalShopBuys, totalEvents, reviveCount
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
        voiceStyle = try c.decodeIfPresent(VoiceStyle.self, forKey: .voiceStyle) ?? .cute
        lastTickAt = try c.decode(Date.self, forKey: .lastTickAt)
        lastEventAt = try c.decodeIfPresent(Date.self, forKey: .lastEventAt) ?? .now
        interactions = try c.decodeIfPresent([InteractionRecord].self, forKey: .interactions) ?? []
        chatMessages = try c.decodeIfPresent([PetChatMessage].self, forKey: .chatMessages) ?? []
        memories = try c.decodeIfPresent([MemoryRecord].self, forKey: .memories) ?? []
        inventoryItems = try c.decodeIfPresent([ShopItem].self, forKey: .inventoryItems) ?? []
        titles = try c.decodeIfPresent([CatTitle].self, forKey: .titles) ?? []
        streak = try c.decodeIfPresent(DailyStreak.self, forKey: .streak) ?? .initial()
        traitScore = try c.decodeIfPresent(TraitScore.self, forKey: .traitScore) ?? TraitScore()
        treasures = try c.decodeIfPresent([Treasure].self, forKey: .treasures) ?? []
        totalShopBuys = try c.decodeIfPresent(Int.self, forKey: .totalShopBuys) ?? 0
        totalEvents = try c.decodeIfPresent(Int.self, forKey: .totalEvents) ?? 0
        reviveCount = try c.decodeIfPresent(Int.self, forKey: .reviveCount) ?? 0
        localModelFileName = try c.decodeIfPresent(String.self, forKey: .localModelFileName)
        localModelDisplayName = try c.decodeIfPresent(String.self, forKey: .localModelDisplayName)
    }
}
