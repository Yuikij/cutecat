import SwiftUI

struct CatDisplayView: View {
    let mood: CatMood
    let comment: String?
    let emoji: String
    var moodWord: String?
    var behavior: CatBehavior?
    var onTouch: ((Interaction) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var frameIndex: Int = 0
    @State private var touchHint: String?
    @State private var specialFrames: [String]?
    @State private var specialCountdown: Int = 0
    @State private var isPressed = false
    @State private var animationTask: Task<Void, Never>?
    @State private var specialResetTask: Task<Void, Never>?
    @State private var hintResetTask: Task<Void, Never>?

    init(
        mood: CatMood,
        comment: String?,
        emoji: String = "🐟",
        moodWord: String? = nil,
        behavior: CatBehavior? = nil,
        onTouch: ((Interaction) -> Void)? = nil
    ) {
        self.mood = mood
        self.comment = comment
        self.emoji = emoji
        self.moodWord = moodWord
        self.behavior = behavior
        self.onTouch = onTouch
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    stageBackdrop

                    accessoryLayer

                    Text(currentFrame)
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .minimumScaleFactor(0.78)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: catYOffset)
                        .scaleEffect(x: isPressed ? 0.97 : catScaleX, y: isPressed ? 1.03 : catScaleY, anchor: .bottom)
                        .rotationEffect(.degrees(catTilt))
                        .shadow(color: textColor.opacity(CozyPalette.isNight ? 0.35 : 0.14), radius: 6, y: 4)
                        .animation(frameAnimation, value: frameIndex)
                        .animation(pressAnimation, value: isPressed)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard canTouch else { return }
                            if !isPressed {
                                withAnimation(pressAnimation) {
                                    isPressed = true
                                }
                            }
                        }
                        .onEnded { value in
                            guard canTouch else {
                                isPressed = false
                                return
                            }

                            withAnimation(pressAnimation) {
                                isPressed = false
                            }

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
            .frame(minHeight: 166)

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
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: mood) { _, _ in
            resetAnimationState()
            startAnimation()
        }
        .onChange(of: behavior?.kind) { _, _ in
            specialFrames = nil
            specialCountdown = 0
            specialResetTask?.cancel()
            specialResetTask = nil
        }
    }

    private var activeFrames: [String] {
        specialFrames ?? CatFrames.frames(for: mood, behavior: behavior?.kind)
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

    private var canTouch: Bool {
        onTouch != nil && mood != .away
    }

    private var frameInterval: TimeInterval {
        switch mood {
        case .away:
            0
        case .playing, .happy, .eating, .headpat, .bellyUp:
            0.34
        case .sleeping:
            0.84
        case .sad, .sick, .disciplined, .shy, .thinking, .chatting:
            0.62
        default:
            0.48
        }
    }

    private var frameAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: min(frameInterval * 0.68, 0.28))
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72)
    }

    private var catYOffset: CGFloat {
        guard !reduceMotion else { return 0 }

        switch mood {
        case .happy, .playing, .headpat:
            return frameIndex.isMultiple(of: 2) ? -4 : 1
        case .eating, .bellyUp:
            return frameIndex.isMultiple(of: 2) ? 1 : -1
        case .sleeping:
            return frameIndex.isMultiple(of: 2) ? 1 : 0
        case .sad, .sick, .disciplined:
            return 3
        case .away:
            return 5
        default:
            return behaviorYOffset ?? (frameIndex.isMultiple(of: 2) ? -1 : 1)
        }
    }

    private var catScaleX: CGFloat {
        guard !reduceMotion else { return 1 }

        switch mood {
        case .playing, .happy, .headpat:
            return frameIndex.isMultiple(of: 2) ? 1.015 : 0.995
        case .sleeping:
            return 1.01
        case .sad, .sick:
            return 0.985
        default:
            return 1
        }
    }

    private var catScaleY: CGFloat {
        guard !reduceMotion else { return 1 }

        switch mood {
        case .playing, .happy, .headpat:
            return frameIndex.isMultiple(of: 2) ? 0.99 : 1.015
        case .sleeping:
            return frameIndex.isMultiple(of: 2) ? 0.99 : 1.005
        case .sad, .sick:
            return 0.99
        default:
            return 1
        }
    }

    private var catTilt: Double {
        guard !reduceMotion else { return 0 }

        switch mood {
        case .playing:
            return frameIndex.isMultiple(of: 2) ? -1.0 : 1.0
        case .shy, .bellyUp:
            return frameIndex.isMultiple(of: 2) ? -0.5 : 0.4
        default:
            return behaviorTilt ?? 0
        }
    }

    private var behaviorYOffset: CGFloat? {
        guard !reduceMotion, let kind = behavior?.kind else { return nil }

        switch kind {
        case .hiding, .sulking:
            return 4
        case .showingOff:
            return frameIndex.isMultiple(of: 2) ? -3 : 0
        case .searchingFood, .investigating:
            return frameIndex.isMultiple(of: 2) ? 1 : 3
        case .waiting, .writingDiary, .plotting:
            return frameIndex.isMultiple(of: 2) ? -1 : 0
        case .leaving:
            return frameIndex.isMultiple(of: 2) ? 2 : 4
        case .idle, .napping, .grooming, .guardingBelly:
            return nil
        }
    }

    private var behaviorTilt: Double? {
        guard !reduceMotion, let kind = behavior?.kind else { return nil }

        switch kind {
        case .investigating:
            return frameIndex.isMultiple(of: 2) ? -1.2 : 0.8
        case .searchingFood:
            return frameIndex.isMultiple(of: 2) ? 0.7 : -0.5
        case .showingOff:
            return frameIndex.isMultiple(of: 2) ? -1.0 : 1.0
        case .hiding, .sulking:
            return -0.4
        case .leaving:
            return frameIndex.isMultiple(of: 2) ? -0.8 : 0
        case .idle, .waiting, .napping, .grooming, .guardingBelly, .writingDiary, .plotting:
            return nil
        }
    }

    private var stageLineColor: Color {
        textColor.opacity(CozyPalette.isNight ? 0.22 : 0.14)
    }

    private var stageFillColor: Color {
        CozyPalette.isNight ? Color.white.opacity(0.045) : CozyPalette.peach.opacity(0.12)
    }

    private var windowSymbol: String {
        if CozyPalette.isNight || mood == .sleeping {
            return "🌙"
        }

        switch mood {
        case .sad, .sick:
            return "☁️"
        case .happy, .playing, .headpat:
            return "☀️"
        default:
            return "🌤️"
        }
    }

    private var stageAccessory: CatStageAccessory? {
        switch mood {
        case .eating, .hungry:
            return CatStageAccessory(symbol: "🍽️", side: .trailing, size: 28, lift: 0, tilt: -5)
        case .playing:
            return CatStageAccessory(symbol: "🧶", side: .leading, size: 30, lift: 2, tilt: -8)
        case .bathing:
            return CatStageAccessory(symbol: "🫧", side: .trailing, size: 30, lift: 16, tilt: 0)
        case .sleeping:
            return CatStageAccessory(symbol: "💤", side: .trailing, size: 28, lift: 30, tilt: 6)
        case .sick:
            return CatStageAccessory(symbol: "💊", side: .leading, size: 25, lift: 5, tilt: -10)
        case .thinking:
            return CatStageAccessory(symbol: "💭", side: .trailing, size: 27, lift: 34, tilt: 6)
        case .chatting:
            return CatStageAccessory(symbol: "💬", side: .trailing, size: 27, lift: 30, tilt: 5)
        case .bellyUp:
            return CatStageAccessory(symbol: "🐾", side: .leading, size: 26, lift: 0, tilt: -6)
        default:
            break
        }

        guard let behavior else { return nil }

        switch behavior.kind {
        case .waiting:
            return CatStageAccessory(symbol: "🫶", side: .trailing, size: 25, lift: 24, tilt: 5)
        case .hiding:
            return CatStageAccessory(symbol: "📦", side: .leading, size: 30, lift: 0, tilt: -3)
        case .searchingFood:
            return CatStageAccessory(symbol: "🍽️", side: .trailing, size: 28, lift: 0, tilt: -5)
        case .napping:
            return CatStageAccessory(symbol: "💤", side: .trailing, size: 28, lift: 30, tilt: 6)
        case .grooming:
            return CatStageAccessory(symbol: "🫧", side: .trailing, size: 30, lift: 16, tilt: 0)
        case .investigating:
            return CatStageAccessory(symbol: "🔍", side: .leading, size: 26, lift: 10, tilt: -8)
        case .guardingBelly:
            return CatStageAccessory(symbol: "🛡️", side: .leading, size: 26, lift: 8, tilt: -5)
        case .writingDiary:
            return CatStageAccessory(symbol: "📓", side: .trailing, size: 27, lift: 6, tilt: 6)
        case .showingOff:
            return CatStageAccessory(symbol: "✨", side: .trailing, size: 28, lift: 34, tilt: 8)
        case .sulking:
            return CatStageAccessory(symbol: "⋯", side: .leading, size: 30, lift: 28, tilt: -4)
        case .plotting:
            return CatStageAccessory(symbol: "💭", side: .trailing, size: 27, lift: 34, tilt: 6)
        case .leaving:
            return CatStageAccessory(symbol: "🚪", side: .leading, size: 29, lift: 0, tilt: 0)
        case .idle:
            return nil
        }
    }

    private var stageBackdrop: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    windowView
                        .padding(.leading, 24)

                    Spacer()
                }

                Spacer()
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Spacer()

                Capsule()
                    .fill(stageLineColor)
                    .frame(width: 116, height: 2)
                    .opacity(0.55)

                Capsule()
                    .fill(stageFillColor)
                    .frame(width: 214, height: 18)
                    .overlay(
                        Capsule()
                            .strokeBorder(stageLineColor.opacity(0.45), lineWidth: 0.8)
                    )
                    .shadow(color: textColor.opacity(CozyPalette.isNight ? 0.18 : 0.08), radius: 5, y: 3)
                    .padding(.bottom, 6)
            }
        }
        .allowsHitTesting(false)
    }

    private var windowView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(stageFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(stageLineColor, lineWidth: 1)
                )

            Rectangle()
                .fill(stageLineColor)
                .frame(width: 1)

            Rectangle()
                .fill(stageLineColor)
                .frame(height: 1)

            Text(windowSymbol)
                .font(.system(size: 12))
                .offset(x: 13, y: -8)
        }
        .frame(width: 54, height: 38)
    }

    @ViewBuilder
    private var accessoryLayer: some View {
        if let accessory = stageAccessory {
            VStack {
                Spacer()

                HStack {
                    if accessory.side == .trailing {
                        Spacer()
                    }

                    Text(accessory.symbol)
                        .font(.system(size: accessory.size))
                        .rotationEffect(.degrees(reduceMotion ? 0 : accessory.tilt))
                        .offset(y: reduceMotion ? 0 : -accessory.lift)
                        .shadow(color: textColor.opacity(CozyPalette.isNight ? 0.26 : 0.12), radius: 4, y: 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))

                    if accessory.side == .leading {
                        Spacer()
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 16)
            }
            .animation(frameAnimation, value: frameIndex)
            .allowsHitTesting(false)
        }
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = nil

        let interval = frameInterval
        guard interval > 0 else { return }

        animationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    frameIndex = (frameIndex + 1) % max(activeFrames.count, 1)

                    if specialFrames == nil && (mood == .neutral || mood == .happy) {
                        specialCountdown += 1
                        if specialCountdown >= 12 {
                            specialCountdown = 0
                            if let special = CatFrames.randomIdleSpecial() {
                                specialFrames = special
                                frameIndex = 0
                                scheduleSpecialReset(afterMilliseconds: special.count * 800)
                            }
                        }
                    }
                }
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        specialResetTask?.cancel()
        specialResetTask = nil
        hintResetTask?.cancel()
        hintResetTask = nil
    }

    private func resetAnimationState() {
        frameIndex = 0
        specialFrames = nil
        specialCountdown = 0
        touchHint = nil
        isPressed = false
        specialResetTask?.cancel()
        specialResetTask = nil
        hintResetTask?.cancel()
        hintResetTask = nil
    }

    private func scheduleSpecialReset(afterMilliseconds milliseconds: Int) {
        specialResetTask?.cancel()
        specialResetTask = Task {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                specialFrames = nil
                frameIndex = 0
            }
        }
    }

    private func clearHint() {
        hintResetTask?.cancel()
        hintResetTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    touchHint = nil
                }
            }
        }
    }
}

private enum CatStageSide: Equatable {
    case leading
    case trailing
}

private struct CatStageAccessory: Equatable {
    let symbol: String
    let side: CatStageSide
    let size: CGFloat
    let lift: CGFloat
    let tilt: Double
}
