import SwiftUI

struct StatusView: View {
    let state: PetState

    var body: some View {
        CozyPanel {
            VStack(spacing: 12) {
                Text("猫咪状态")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CozyPalette.textPrimary)

                VStack(spacing: 8) {
                    statRow(icon: "heart.fill", label: "开心", value: state.happiness, max: 10, tint: CozyPalette.rose)
                    statRow(icon: "fork.knife", label: "饥饿", value: state.hunger, max: 10, tint: .orange)
                    statRow(icon: "cross.fill", label: "健康", value: state.health, max: 10, tint: CozyPalette.moss)
                    statRow(icon: "sparkles", label: "干净", value: state.cleanliness, max: 10, tint: CozyPalette.sky)
                    statRow(icon: "bolt.fill", label: "精力", value: state.energy, max: 10, tint: .yellow)

                    Divider().opacity(0.3)

                    statRow(
                        icon: "heart.circle.fill", label: "好感",
                        value: state.affinity, max: 100,
                        tint: Color(red: 0.9, green: 0.3, blue: 0.5),
                        suffix: state.affinityLevel.emoji
                    )
                }

                HStack {
                    Label("\(state.growthStage.emoji) \(state.growthStage.name)", systemImage: "birthday.cake.fill")
                    Spacer()
                    Text("年龄 \(state.age)")
                    Spacer()
                    Text("\(state.affinityLevel.emoji) \(state.affinityLevel.title)")
                }
                .font(.caption)
                .foregroundStyle(CozyPalette.textSecondary)

                if state.growthStage == .baby {
                    Text("🍼 奶猫容易饿，多喂食哦！好感增长+2")
                        .font(.caption2)
                        .foregroundStyle(CozyPalette.moss)
                } else if state.growthStage == .elder {
                    Text("🐈‍⬛ 老猫体力恢复慢，健康上限降低，多关心它")
                        .font(.caption2)
                        .foregroundStyle(CozyPalette.rose)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func statRow(
        icon: String, label: String,
        value: Int, max: Int,
        tint: Color, suffix: String? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(CozyPalette.textPrimary)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(max))
                }
            }
            .frame(height: 8)

            HStack(spacing: 2) {
                Text("\(value)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CozyPalette.textSecondary)
                if let suffix {
                    Text(suffix)
                        .font(.caption2)
                }
            }
            .frame(width: 36, alignment: .trailing)
        }
    }
}
