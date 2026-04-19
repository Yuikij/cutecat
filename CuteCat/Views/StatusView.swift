import SwiftUI

struct StatusView: View {
    let state: PetState

    var body: some View {
        CozyPanel {
            VStack(spacing: 12) {
                Text("猫咪状态")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CozyPalette.plum)

                VStack(spacing: 8) {
                    statRow(icon: "heart.fill", label: "开心", value: state.happiness, tint: CozyPalette.rose)
                    statRow(icon: "fork.knife", label: "饥饿", value: state.hunger, tint: .orange)
                    statRow(icon: "cross.fill", label: "健康", value: state.health, tint: CozyPalette.moss)
                    statRow(icon: "sparkles", label: "干净", value: state.cleanliness, tint: CozyPalette.sky)
                    statRow(icon: "bolt.fill", label: "精力", value: state.energy, tint: .yellow)
                }

                HStack {
                    Label("年龄：\(state.age)", systemImage: "birthday.cake.fill")
                    Spacer()
                    if state.isDead {
                        Text("已去世")
                            .foregroundStyle(.red)
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
                .foregroundStyle(CozyPalette.wood)
            }
        }
        .padding(.horizontal, 20)
    }

    private func statRow(icon: String, label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(CozyPalette.plum)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(value) / 10.0)
                }
            }
            .frame(height: 8)

            Text("\(value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(CozyPalette.wood)
                .frame(width: 20, alignment: .trailing)
        }
    }
}
