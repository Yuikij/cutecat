import SwiftUI

struct EventView: View {
    let event: CatEvent
    let onChoice: (EventChoice) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var chosenResult: EventChoice?

    var body: some View {
        VStack(spacing: 16) {
            Text(event.emoji)
                .font(.system(size: 48))

            Text(event.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(CozyPalette.textPrimary)

            if chosenResult == nil, event.desc.isEmpty == false {
                Text(event.desc)
                    .font(.subheadline)
                    .foregroundStyle(CozyPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if let chosen = chosenResult {
                resultView(chosen)
            } else {
                choicesView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CozyPalette.isNight
                    ? Color(red: 0.18, green: 0.16, blue: 0.26).opacity(0.95)
                    : CozyPalette.card.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .padding(.horizontal, 24)
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var choicesView: some View {
        VStack(spacing: 10) {
            ForEach(event.choices) { choice in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        chosenResult = choice
                    }
                    onChoice(choice)
                } label: {
                    HStack {
                        Text(choice.label)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(CozyPalette.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CozyPalette.cardAdaptive)
                    )
                    .foregroundStyle(CozyPalette.textPrimary)
                }
                .buttonStyle(SoftPressStyle())
            }

            Button("忽略") {
                onDismiss()
            }
            .font(.caption)
            .foregroundStyle(CozyPalette.textSecondary)
            .padding(.top, 4)
        }
    }

    private func resultView(_ choice: EventChoice) -> some View {
        VStack(spacing: 14) {
            Text("你选择了「\(choice.label)」")
                .font(.caption)
                .foregroundStyle(CozyPalette.textSecondary)

            Text(choice.result)
                .font(.subheadline)
                .foregroundStyle(CozyPalette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                if choice.affinityDelta != 0 {
                    statBadge(icon: choice.affinityDelta > 0 ? "❤️" : "💔",
                              label: "好感", value: choice.affinityDelta)
                }
                if choice.happinessDelta != 0 {
                    statBadge(icon: "😊", label: "心情", value: choice.happinessDelta)
                }
                if choice.healthDelta != 0 {
                    statBadge(icon: "💊", label: "健康", value: choice.healthDelta)
                }
                if choice.hungerDelta != 0 {
                    statBadge(icon: "🍖", label: "饥饿", value: choice.hungerDelta)
                }
            }

            Button {
                onDismiss()
            } label: {
                Text("好的")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CozyPalette.moss.gradient)
                    )
            }
            .padding(.top, 4)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func statBadge(icon: String, label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.title3)
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(value > 0 ? CozyPalette.moss : CozyPalette.rose)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(CozyPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CozyPalette.cardAdaptive)
        )
    }
}

struct EventResultBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(CozyPalette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(CozyPalette.cardAdaptive)
                    .shadow(color: CozyPalette.shadowAdaptive, radius: 4, y: 2)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
    }
}
