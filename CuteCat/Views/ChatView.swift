import SwiftUI
import Combine

struct ChatView: View {
    @EnvironmentObject private var store: PetStore
    @StateObject private var speech = SpeechService()
    @State private var draft = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatNavBar
            messagesList

            if store.modelRuntimeState != .ready {
                modelStateRow
            }

            composer
        }
        .background(CozyBackground())
        .ignoresSafeArea(.keyboard)
        .onReceive(keyboardHeightPublisher) { height in
            keyboardHeight = height
        }
        .onChange(of: speech.transcript) { _, newValue in
            draft = newValue
        }
    }

    // MARK: - Navigation Bar

    private var chatNavBar: some View {
        HStack {
            Text("猫咪")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CozyPalette.plum)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            CozyPalette.card.opacity(0.92)
                .shadow(color: CozyPalette.plum.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if store.chatMessages.isEmpty {
                        emptyState.padding(.top, 60)
                    } else {
                        Color.clear.frame(height: 8)

                        ForEach(store.chatMessages) { message in
                            messageBubble(message).id(message.id)
                        }

                        if store.isGeneratingReply {
                            typingBubble.id("typing")
                        }

                        Color.clear.frame(height: 4)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: store.chatMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: store.isGeneratingReply) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(CozyPalette.moss.opacity(0.5))
            Text("和猫咪打个招呼吧")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CozyPalette.plum.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    if speech.isListening {
                        speech.stopListening()
                    } else {
                        speech.startListening()
                    }
                } label: {
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 20))
                        .foregroundStyle(speech.isListening ? .red : CozyPalette.moss)
                        .frame(width: 32, height: 32)
                }

                TextField("想说点什么…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CozyPalette.moss.opacity(isInputFocused ? 0.3 : 0), lineWidth: 1)
                    )

                Button {
                    speech.stopListening()
                    let currentDraft = draft
                    draft = ""
                    Task {
                        await store.sendChatMessage(currentDraft)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.canSendChat == false
                                ? CozyPalette.plum.opacity(0.2)
                                : CozyPalette.moss
                        )
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.canSendChat == false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
        }
        .background(CozyPalette.card.opacity(0.95))
        .animation(.easeOut(duration: 0.22), value: keyboardHeight)
    }

    // MARK: - Model State Row

    private var modelStateRow: some View {
        HStack(spacing: 8) {
            Group {
                switch store.modelRuntimeState {
                case .loading:
                    ProgressView()
                        .tint(CozyPalette.moss)
                default:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(CozyPalette.wood)
                }
            }
            .frame(width: 14, height: 14)

            Text(modelStateLine)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CozyPalette.wood)
                .lineLimit(1)

            Spacer()

            if case .failed = store.modelRuntimeState {
                Button("重试") {
                    Task {
                        await store.reloadModel()
                    }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(CozyPalette.moss)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(CozyPalette.cream.opacity(0.9))
    }

    // MARK: - Bubbles

    private func messageBubble(_ message: PetChatMessage) -> some View {
        let isUser = message.role == .user

        return HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.body)
                .foregroundStyle(isUser ? .white : CozyPalette.plum)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? CozyPalette.moss : Color.white.opacity(0.92))
                )

            if isUser == false { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var typingBubble: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(CozyPalette.moss.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if store.isGeneratingReply {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let lastID = store.chatMessages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var modelStateLine: String {
        switch store.modelRuntimeState {
        case .loading:
            "灵魂正在苏醒…"
        case .failed:
            "它今天有点困…"
        default:
            "猫咪还在沉睡中…"
        }
    }

    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        return willChange
            .merge(with: willHide)
            .map { notification in
                guard
                    let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else {
                    return 0
                }
                let overlap = UIScreen.main.bounds.maxY - endFrame.minY
                return max(0, overlap)
            }
            .eraseToAnyPublisher()
    }
}
