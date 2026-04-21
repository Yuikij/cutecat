import SwiftUI

struct CatProfileView: View {
    @EnvironmentObject private var store: PetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    growthSection
                    streakSection
                    traitsSection
                    titlesSection
                    treasuresSection
                }
                .padding()
            }
            .background(CozyPalette.isNight
                ? Color(red: 0.08, green: 0.06, blue: 0.14)
                : Color(red: 0.96, green: 0.95, blue: 0.93))
            .navigationTitle("\(store.catName)的档案")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Growth

    private var growthSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(store.state.growthStage.emoji) 成长")
                    .font(.headline)
                Spacer()
                Text("年龄 \(store.state.age)")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            }

            HStack(spacing: 12) {
                ForEach(Array(GrowthStage.allCases.enumerated()), id: \.element) { idx, stage in
                    VStack(spacing: 4) {
                        Text(stage.emoji)
                            .font(.title2)
                            .opacity(store.state.growthStage == stage ? 1 : 0.3)
                        Text(stage.name)
                            .font(.caption2)
                            .foregroundStyle(store.state.growthStage == stage
                                ? CozyPalette.textPrimary
                                : CozyPalette.textSecondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    if idx < GrowthStage.allCases.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(CozyPalette.textSecondary.opacity(0.3))
                    }
                }
            }

            let stage = store.state.growthStage
            VStack(alignment: .leading, spacing: 4) {
                Text(stageDescription(stage))
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .profileCard()
    }

    private func stageDescription(_ stage: GrowthStage) -> String {
        switch stage {
        case .baby: "奶猫阶段：饥饿值增长快×2，但好感增长有额外加成+2！需要更多照顾。"
        case .kitten: "小猫阶段：精力恢复快，好感增长+1，最活泼好动的时期！"
        case .teen: "少年阶段：性格逐渐成型，开始有自己的脾气。"
        case .adult: "成年阶段：各项属性平衡稳定，最独立的时期。"
        case .elder: "老年阶段：精力不再恢复，健康上限降低到7，但好感增长+1，更珍惜陪伴。"
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🔥 签到")
                    .font(.headline)
                Spacer()
                if store.state.streak.checkedInToday {
                    Text("今日已签到 ✓")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 16) {
                streakStat("连续", "\(store.state.streak.currentStreak)天")
                streakStat("最长", "\(store.state.streak.longestStreak)天")
                streakStat("累计", "\(store.state.streak.totalCheckIns)次")
            }

            if !store.state.streak.checkedInToday {
                Button {
                    store.checkDailyStreak()
                } label: {
                    Text("签到领取奖励")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                }
            }
        }
        .profileCard()
    }

    private func streakStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(CozyPalette.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(CozyPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Traits

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🐾 性格特征")
                .font(.headline)

            let active = Set(store.state.activeTraits)

            if active.isEmpty {
                Text("还在观察中…多互动才能发现猫咪的性格哦")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            }

            let allScores = traitScoresForDisplay()

            ForEach(allScores, id: \.trait) { item in
                let isActive = active.contains(item.trait)
                HStack(spacing: 10) {
                    Text(item.trait.emoji)
                        .font(.title3)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.trait.name)
                                .font(.subheadline.weight(isActive ? .bold : .medium))
                                .foregroundStyle(isActive ? CozyPalette.textPrimary : CozyPalette.textSecondary)
                            if isActive {
                                Text("当前性格")
                                    .font(.system(size: 9).weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(traitColor(item.trait)))
                            }
                            Spacer()
                            Text("\(item.score)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(CozyPalette.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(traitColor(item.trait).opacity(0.12))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(traitColor(item.trait).opacity(isActive ? 1 : 0.4))
                                    .frame(width: geo.size.width * min(1, CGFloat(item.score) / 30.0))
                            }
                        }
                        .frame(height: 4)

                        Text(item.trait.desc)
                            .font(.caption2)
                            .foregroundStyle(CozyPalette.textSecondary.opacity(isActive ? 0.8 : 0.5))
                    }
                }
                .padding(.vertical, 2)
                .opacity(isActive ? 1 : 0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileCard()
    }

    private struct TraitDisplay: Identifiable {
        var id: String { trait.rawValue }
        let trait: CatTrait
        let score: Int
    }

    private func traitScoresForDisplay() -> [TraitDisplay] {
        let ts = store.state.traitScore
        let intimacy = ts.touchCount + ts.chatCount
        let neglect = max(0, ts.idleTicks - ts.touchCount * 2)
        let chaos = ts.eventCount + ts.disciplineCount

        let scores: [(CatTrait, Int)] = [
            (.tsundere, max(0, 15 - ts.touchCount) + ts.disciplineCount),
            (.clingy, intimacy),
            (.edgelord, neglect + max(0, 10 - ts.feedCount)),
            (.venomous, ts.chatCount + ts.disciplineCount),
            (.schemer, ts.eventCount + ts.chatCount / 2),
            (.berserker, ts.disciplineCount * 3 + chaos),
            (.curious, ts.eventCount * 2 + ts.playCount),
            (.babyface, ts.touchCount * 2 + max(0, 10 - ts.disciplineCount)),
            (.glutton, ts.feedCount * 2),
            (.chuuni, ts.playCount + ts.eventCount + max(0, 8 - ts.feedCount)),
        ]

        return scores
            .sorted { $0.1 > $1.1 }
            .map { TraitDisplay(trait: $0.0, score: $0.1) }
    }

    private func traitColor(_ trait: CatTrait) -> Color {
        switch trait {
        case .tsundere: .pink
        case .clingy: .purple
        case .edgelord: .gray
        case .venomous: .green
        case .schemer: .orange
        case .berserker: .red
        case .curious: .blue
        case .babyface: .pink
        case .glutton: .orange
        case .chuuni: .indigo
        }
    }

    // MARK: - Titles

    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🏅 称号")
                    .font(.headline)
                Spacer()
                Text("\(store.state.titles.count)/\(TitleDefinition.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            }

            let all = TitleDefinition.allCases
            let unlocked = Set(store.state.titles.map(\.id))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(all, id: \.rawValue) { def in
                    let isUnlocked = unlocked.contains(def.rawValue)
                    titleBadge(def: def, unlocked: isUnlocked)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileCard()
    }

    private func titleBadge(def: TitleDefinition, unlocked: Bool) -> some View {
        VStack(spacing: 4) {
            Text(unlocked ? def.emoji : "🔒")
                .font(.title2)
            Text(unlocked ? def.name : "???")
                .font(.caption.weight(.medium))
                .foregroundStyle(unlocked ? CozyPalette.textPrimary : CozyPalette.textSecondary.opacity(0.5))
            if unlocked {
                Text(def.desc)
                    .font(.caption2)
                    .foregroundStyle(CozyPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(unlocked
                    ? CozyPalette.cardAdaptive
                    : CozyPalette.cardAdaptive.opacity(0.3))
        )
        .opacity(unlocked ? 1 : 0.6)
    }

    // MARK: - Treasures

    private var treasuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💎 宝物收藏")
                    .font(.headline)
                Spacer()
                Text("\(store.state.treasures.count)件")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            }

            if store.state.treasures.isEmpty {
                Text("还没有宝物…多和猫咪互动，它会给你带回宝物的！")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.textSecondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ], spacing: 8) {
                    ForEach(store.state.treasures) { treasure in
                        treasureCell(treasure)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileCard()
    }

    private func treasureCell(_ treasure: Treasure) -> some View {
        VStack(spacing: 4) {
            Text(treasure.emoji)
                .font(.title)
            Text(treasure.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CozyPalette.textPrimary)
            Text(treasure.rarity.label)
                .font(.system(size: 9))
                .foregroundStyle(rarityColor(treasure.rarity))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CozyPalette.cardAdaptive)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(rarityColor(treasure.rarity).opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func rarityColor(_ rarity: TreasureRarity) -> Color {
        switch rarity {
        case .common: .gray
        case .rare: .purple
        case .legendary: .orange
        }
    }
}

private extension View {
    func profileCard() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CozyPalette.isNight
                        ? Color(red: 0.15, green: 0.13, blue: 0.22).opacity(0.9)
                        : .white.opacity(0.8))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
    }
}
