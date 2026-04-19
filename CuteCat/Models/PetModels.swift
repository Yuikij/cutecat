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

    var title: String {
        switch self {
        case .feed: "喂食"
        case .play: "玩耍"
        case .clean: "清洁"
        case .discipline: "管教"
        case .medical: "看病"
        case .chat: "聊天"
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
        }
    }
}

// MARK: - Memory

enum MemorySourceType: String, Codable, Sendable {
    case interaction
    case conversation
    case tick
}

struct MemoryRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let summary: String
    let createdAt: Date
    let sourceType: MemorySourceType
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

// MARK: - Pet State

struct PetState: Codable, Sendable {
    var happiness: Int      // 0-10, higher = happier
    var hunger: Int          // 0-10, higher = hungrier (bad)
    var health: Int          // 0-10, higher = healthier
    var cleanliness: Int     // 0-10, higher = cleaner
    var energy: Int          // 0-10, higher = more energetic
    var age: Int             // increments each tick
    var isDead: Bool
    var comment: String      // LLM-generated status comment

    var lastTickAt: Date
    var interactions: [InteractionRecord]
    var chatMessages: [PetChatMessage]
    var memories: [MemoryRecord]

    var localModelFileName: String?
    var localModelDisplayName: String?

    var mood: CatMood {
        if isDead { return .dead }
        if health <= 2 { return .sick }
        if hunger >= 8 { return .hungry }
        if happiness <= 2 { return .sad }
        if energy <= 2 { return .sleeping }
        if happiness >= 7 { return .happy }
        return .neutral
    }

    static func initial(now: Date = .now) -> PetState {
        PetState(
            happiness: 5,
            hunger: 3,
            health: 8,
            cleanliness: 8,
            energy: 7,
            age: 0,
            isDead: false,
            comment: "一只小猫刚刚来到了这里，好奇地打量着四周。",
            lastTickAt: now,
            interactions: [],
            chatMessages: [],
            memories: [],
            localModelFileName: nil,
            localModelDisplayName: nil
        )
    }
}

extension PetState {
    private enum CodingKeys: String, CodingKey {
        case happiness, hunger, health, cleanliness, energy, age, isDead, comment
        case lastTickAt, interactions, chatMessages, memories
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
        isDead = try c.decode(Bool.self, forKey: .isDead)
        comment = try c.decode(String.self, forKey: .comment)
        lastTickAt = try c.decode(Date.self, forKey: .lastTickAt)
        interactions = try c.decodeIfPresent([InteractionRecord].self, forKey: .interactions) ?? []
        chatMessages = try c.decodeIfPresent([PetChatMessage].self, forKey: .chatMessages) ?? []
        memories = try c.decodeIfPresent([MemoryRecord].self, forKey: .memories) ?? []
        localModelFileName = try c.decodeIfPresent(String.self, forKey: .localModelFileName)
        localModelDisplayName = try c.decodeIfPresent(String.self, forKey: .localModelDisplayName)
    }
}
