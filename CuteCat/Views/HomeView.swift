import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetStore
    @StateObject private var speech = SpeechService()
    @State private var showChat = false
    @State private var showStatus = false
    @State private var showShop = false
    @State private var showSettings = false
    @State private var showProfile = false

    var body: some View {
        ZStack {
            CozyBackground(weather: moodWeather)

            VStack(spacing: 0) {
                headerBar

                Spacer(minLength: 0)

                if let result = store.eventResult {
                    EventResultBanner(text: result)
                        .padding(.bottom, 8)
                }

                chatBubble

                catArea

                Spacer(minLength: 0)

                if showStatus {
                    StatusView(state: store.state)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 8)
                }

                modelStatusBadge
                    .padding(.bottom, 4)

                if store.state.isDead {
                    revivalArea
                        .padding(.bottom, 8)
                } else {
                    actionGrid
                        .padding(.bottom, 8)
                }

                voiceBar
                    .padding(.bottom, 8)
            }

            if let event = store.pendingEvent {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { }

                EventView(
                    event: event,
                    onChoice: { choice in
                        store.resolveEvent(choice: choice)
                    },
                    onDismiss: {
                        store.clearEvent()
                    }
                )
            }

            VStack {
                if let banner = store.growthBanner {
                    notificationBanner(text: banner, color: .green)
                }
                if let banner = store.streakBanner {
                    notificationBanner(text: banner, color: .orange)
                }
                if let title = store.newTitleBanner {
                    notificationBanner(text: "\(title.emoji) 解锁称号「\(title.name)」！", color: .purple)
                }
                if let treasure = store.newTreasureBanner {
                    notificationBanner(
                        text: "\(treasure.emoji) 发现宝物「\(treasure.name)」(\(treasure.rarity.label))！",
                        color: treasure.rarity == .legendary ? .orange : .blue
                    )
                }
                Spacer()
            }
            .padding(.top, 60)
            .animation(.spring(response: 0.4), value: store.growthBanner)
            .animation(.spring(response: 0.4), value: store.streakBanner)
            .animation(.spring(response: 0.4), value: store.newTitleBanner?.id)
            .animation(.spring(response: 0.4), value: store.newTreasureBanner?.id)
        }
        .sheet(isPresented: $showChat) {
            ChatView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showShop) {
            ShopView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showProfile) {
            CatProfileView()
                .environmentObject(store)
        }
        .animation(.easeInOut(duration: 0.3), value: showStatus)
        .animation(.easeInOut(duration: 0.3), value: store.currentMood)
        .animation(.easeInOut(duration: 0.3), value: store.pendingEvent != nil)
        .animation(.easeInOut(duration: 0.3), value: store.eventResult)
        .animation(.easeInOut(duration: 0.3), value: store.state.isDead)
        .onChange(of: speech.didFinishSpeaking) { _, finished in
            if finished {
                let msg = speech.transcript
                speech.didFinishSpeaking = false
                if !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await store.sendChatMessage(msg) }
                }
            }
        }
        .onChange(of: store.pendingSpeak) { _, text in
            guard let text, !text.isEmpty else { return }
            store.pendingSpeak = nil
            speech.speak(text, style: store.state.voiceStyle)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(store.catName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(headerTextColor)

                Spacer()

                HStack(spacing: 12) {
                    if speech.isSpeaking {
                        headerIcon("speaker.slash.fill") { speech.stopSpeaking() }
                    }
                    headerIcon("gearshape") { showSettings = true }
                    headerIcon("trophy") { showProfile = true }
                    headerIcon(showStatus ? "chart.bar.fill" : "chart.bar") { showStatus.toggle() }
                }
            }

            HStack(spacing: 0) {
                if store.state.isDead {
                    Text("\(store.catName)已经离开了…")
                        .font(.caption2)
                        .foregroundStyle(headerSubtextColor)
                } else {
                    statusPill(store.state.growthStage.emoji + store.state.growthStage.name)
                    statusPill(store.affinityLevel.emoji + " " + store.affinityLevel.title)

                    if !store.state.activeTraits.isEmpty {
                        ForEach(store.state.activeTraits, id: \.self) { trait in
                            statusPill(trait.emoji + trait.name)
                        }
                    }

                    statusPill(moodWeather.icon)
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func headerIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(headerTextColor.opacity(0.45))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(headerTextColor.opacity(0.06))
                )
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(headerSubtextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(headerTextColor.opacity(0.05))
            )
            .padding(.trailing, 4)
    }

    // MARK: - Cat Display

    private var catArea: some View {
        CatDisplayView(
            mood: store.currentMood,
            comment: nil,
            emoji: store.lastActionEmoji ?? "🐟",
            moodWord: store.catMoodWord
        ) { interaction in
            Task { await store.performInteraction(interaction) }
        }
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private var chatBubble: some View {
        let text = store.actionStatusText ?? store.state.comment
        if !text.isEmpty {
            MarqueeChatBubble(text: text)
                .frame(maxWidth: 320)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: text)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Voice Bar

    private let voiceActiveColor = Color(red: 0.95, green: 0.6, blue: 0.5)

    private var voiceBar: some View {
        HStack(spacing: 10) {
            Button {
                if speech.voiceModeActive {
                    speech.exitVoiceMode()
                } else {
                    speech.enterVoiceMode()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(speech.voiceModeActive
                            ? voiceActiveColor.opacity(0.18)
                            : CozyPalette.moss.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: speech.voiceModeActive ? "mic.fill" : "mic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(speech.voiceModeActive ? voiceActiveColor : CozyPalette.moss)
                }
            }
            .scaleEffect(speech.isListening ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speech.isListening)

            if speech.voiceModeActive {
                voiceModeStatus
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)

                Button {
                    speech.exitVoiceMode()
                } label: {
                    Text("结束")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(headerSubtextColor.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(CozyPalette.cardAdaptive.opacity(0.6))
                        )
                }
            } else if store.isGeneratingReply {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(CozyPalette.moss.opacity(0.6))
                    Text("🐾 \(store.catName)正在想…")
                        .font(.caption)
                        .foregroundStyle(headerSubtextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            } else {
                Text("点击麦克风和\(store.catName)说话")
                    .font(.caption)
                    .foregroundStyle(headerSubtextColor.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showChat = true
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16))
                        .foregroundStyle(headerTextColor.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(speech.voiceModeActive
                    ? voiceActiveColor.opacity(0.06)
                    : CozyPalette.cardAdaptive)
                .shadow(color: CozyPalette.shadowAdaptive, radius: 3, y: 1)
        )
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.25), value: speech.isListening)
        .animation(.easeInOut(duration: 0.25), value: speech.voiceModeActive)
        .animation(.easeInOut(duration: 0.25), value: store.isGeneratingReply)
    }

    @ViewBuilder
    private var voiceModeStatus: some View {
        if speech.isListening {
            VStack(alignment: .leading, spacing: 2) {
                Text(speech.transcript.isEmpty ? "正在听…" : speech.transcript)
                    .font(.subheadline)
                    .foregroundStyle(speech.transcript.isEmpty ? headerSubtextColor : headerTextColor)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    voiceDot
                    Text("语音对话中")
                        .font(.caption2)
                        .foregroundStyle(headerSubtextColor.opacity(0.5))
                }
            }
        } else if store.isGeneratingReply {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .tint(CozyPalette.moss.opacity(0.6))
                Text("🐾 \(store.catName)正在想…")
                    .font(.caption)
                    .foregroundStyle(headerSubtextColor)
            }
        } else if speech.isSpeaking {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(CozyPalette.moss)
                Text("\(store.catName)正在说话…")
                    .font(.caption)
                    .foregroundStyle(headerSubtextColor)
            }
        } else {
            HStack(spacing: 4) {
                voiceDot
                Text("等待你说话…")
                    .font(.caption)
                    .foregroundStyle(headerSubtextColor.opacity(0.6))
            }
        }
    }

    private var voiceDot: some View {
        Circle()
            .fill(voiceActiveColor)
            .frame(width: 6, height: 6)
            .opacity(speech.isListening ? 1 : 0.5)
    }

    // MARK: - Action Grid

    private var actionGrid: some View {
        HStack(spacing: 14) {
            CozyActionButton(title: "喂食", icon: "fork.knife", tint: .orange) {
                Task { await store.performInteraction(.feed) }
            }
            CozyActionButton(title: "玩耍", icon: "gamecontroller.fill", tint: CozyPalette.moss) {
                Task { await store.performInteraction(.play) }
            }
            CozyActionButton(title: "清洁", icon: "shower.fill", tint: CozyPalette.sky) {
                Task { await store.performInteraction(.clean) }
            }
            CozyActionButton(title: "管教", icon: "hand.raised.fill", tint: CozyPalette.wood) {
                Task { await store.performInteraction(.discipline) }
            }
            CozyActionButton(title: "看病", icon: "cross.case.fill", tint: CozyPalette.rose) {
                Task { await store.performInteraction(.medical) }
            }
            CozyActionButton(title: "小卖部", icon: "storefront.fill", tint: .purple) {
                showShop = true
            }
        }
        .padding(.horizontal, 16)
        .disabled(store.pendingEvent != nil)
    }

    // MARK: - Revival

    private var revivalArea: some View {
        VStack(spacing: 12) {
            Text("\(store.catName)已经离开了…")
                .font(.subheadline)
                .foregroundStyle(headerSubtextColor)

            Button {
                Task { await store.reviveCat() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20))
                    Text("再来一次")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(CozyPalette.moss)
                        .shadow(color: CozyPalette.shadowAdaptive, radius: 4, y: 2)
                )
            }
            .buttonStyle(SoftPressStyle())

            if store.state.affinity > 0 {
                Text("消耗 30 好感度")
                    .font(.caption2)
                    .foregroundStyle(headerSubtextColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Model Status Badge

    @ViewBuilder
    private var modelStatusBadge: some View {
        switch store.modelRuntimeState {
        case .ready, .idle:
            EmptyView()
        case .downloading:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("灵魂正在苏醒…")
                    .font(.caption2)
                    .foregroundStyle(headerSubtextColor)
            }
        case .failed(let msg):
            VStack(spacing: 6) {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(headerSubtextColor)
                Button("重试") {
                    Task { await store.reloadModel() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CozyPalette.moss)
            }
        }
    }

    // MARK: - Adaptive Colors

    private var isNightMode: Bool {
        CozyPalette.isNight
    }

    private var headerTextColor: Color {
        isNightMode ? CozyPalette.cream : CozyPalette.plum
    }

    private var headerSubtextColor: Color {
        isNightMode ? CozyPalette.cream.opacity(0.6) : CozyPalette.wood
    }

    private var moodWeather: WeatherCondition {
        let s = store.state
        if s.isDead { return .snow }
        if s.happiness == 0 && s.health <= 2 { return .rain }
        if s.happiness <= 1 { return .cloudy }
        if s.health <= 1 { return .fog }
        if s.happiness >= 7 && s.health >= 6 { return .clear }
        if s.energy <= 2 { return .fog }
        if s.hunger >= 9 { return .cloudy }
        return .clear
    }

    private func notificationBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color.gradient)
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
    }
}

// MARK: - Chat Bubble

struct MarqueeChatBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(CozyPalette.plum)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ChatBubbleShape()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: CozyPalette.plum.opacity(0.08), radius: 6, y: 2)
            )
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        let tailSize: CGFloat = 8
        var path = Path()

        let bodyRect = CGRect(x: rect.minX, y: tailSize, width: rect.width, height: rect.height - tailSize)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: radius, height: radius))

        let tailCenter = bodyRect.midX
        path.move(to: CGPoint(x: tailCenter - tailSize, y: bodyRect.maxY))
        path.addLine(to: CGPoint(x: tailCenter, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailCenter + tailSize, y: bodyRect.maxY))
        path.closeSubpath()

        return path
    }
}
