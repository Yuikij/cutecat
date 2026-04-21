import SwiftUI

struct CatDisplayView: View {
    let mood: CatMood
    let comment: String?
    let emoji: String
    var moodWord: String?
    var onTouch: ((Interaction) -> Void)?

    @State private var frameIndex: Int = 0
    @State private var touchHint: String?
    @State private var specialFrames: [String]?
    @State private var specialCountdown: Int = 0

    init(mood: CatMood, comment: String?, emoji: String = "🐟", moodWord: String? = nil, onTouch: ((Interaction) -> Void)? = nil) {
        self.mood = mood
        self.comment = comment
        self.emoji = emoji
        self.moodWord = moodWord
        self.onTouch = onTouch
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    Text(currentFrame)
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.15), value: frameIndex)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard onTouch != nil, mood != .dead else { return }
                            let ratio = value.location.y / geo.size.height
                            if ratio < 0.35 {
                                touchHint = "摸头 ✋"
                                onTouch?(.headpat)
                            } else if ratio > 0.65 {
                                touchHint = "摸肚子 🐾"
                                onTouch?(.belly)
                            } else {
                                touchHint = "撒娇 💕"
                                onTouch?(.cuddle)
                            }
                            clearHint()
                        }
                )
                .overlay(alignment: .bottom) {
                    if let hint = touchHint {
                        Text(hint)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(CozyPalette.textPrimary.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(CozyPalette.cardAdaptive)
                            )
                            .transition(.opacity.combined(with: .scale))
                            .offset(y: -4)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: touchHint)
            }
            .frame(minHeight: 140)

            if let comment {
                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(CozyPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onAppear {
            startAnimation()
        }
        .onChange(of: mood) { _, _ in
            frameIndex = 0
            specialFrames = nil
            specialCountdown = 0
            startAnimation()
        }
    }

    private var activeFrames: [String] {
        specialFrames ?? CatFrames.frames(for: mood)
    }

    private var currentFrame: String {
        guard activeFrames.isEmpty == false else { return "" }
        let frame = activeFrames[frameIndex % activeFrames.count]
        return CatFrames.replaceEmoji(in: frame, emoji: emoji, word: moodWord)
    }

    private var textColor: Color {
        let hour = Calendar.current.component(.hour, from: .now)
        return (hour >= 19 || hour < 6) ? CozyPalette.cream : CozyPalette.plum
    }

    private func startAnimation() {
        let interval: TimeInterval = mood == .dead ? 0 : 0.5
        guard interval > 0 else { return }

        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                await MainActor.run {
                    frameIndex = (frameIndex + 1) % max(activeFrames.count, 1)

                    if mood == .neutral || mood == .happy {
                        specialCountdown += 1
                        if specialCountdown >= 12 {
                            specialCountdown = 0
                            if let special = CatFrames.randomIdleSpecial() {
                                specialFrames = special
                                frameIndex = 0
                                Task {
                                    try? await Task.sleep(for: .milliseconds(special.count * 800))
                                    await MainActor.run {
                                        specialFrames = nil
                                        frameIndex = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearHint() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            touchHint = nil
        }
    }
}
