import SwiftUI

struct CatDisplayView: View {
    let mood: CatMood
    let comment: String?
    @State private var bounceOffset: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(mood.face)
                .font(.system(size: 100))
                .offset(y: bounceOffset)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .easeInOut(duration: idleAnimationDuration)
                    .repeatForever(autoreverses: true),
                    value: bounceOffset
                )
                .animation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true),
                    value: rotation
                )
                .onAppear {
                    bounceOffset = -8
                    rotation = moodRotation
                }
                .onChange(of: mood) { _, newMood in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        bounceOffset = -20
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeInOut(duration: idleAnimationDuration).repeatForever(autoreverses: true)) {
                            bounceOffset = -8
                        }
                    }
                    rotation = moodRotation(for: newMood)
                }

            if let comment {
                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(CozyPalette.wood)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var idleAnimationDuration: Double {
        switch mood {
        case .sleeping: 3.0
        case .happy, .playing: 0.8
        case .eating: 0.6
        case .dead: 0
        default: 1.5
        }
    }

    private var moodRotation: Double {
        moodRotation(for: mood)
    }

    private func moodRotation(for mood: CatMood) -> Double {
        switch mood {
        case .playing: 5
        case .eating: 3
        case .disciplined: -3
        default: 0
        }
    }
}
