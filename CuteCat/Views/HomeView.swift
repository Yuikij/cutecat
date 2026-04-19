import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetStore
    @State private var showChat = false
    @State private var showStatus = false

    var body: some View {
        ZStack {
            CozyBackground()

            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(spacing: 20) {
                        catArea
                        if showStatus {
                            StatusView(state: store.state)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        actionGrid
                        modelStatusBadge
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView()
                .environmentObject(store)
        }
        .animation(.easeInOut(duration: 0.3), value: showStatus)
        .animation(.easeInOut(duration: 0.3), value: store.currentMood)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CuteCat")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(CozyPalette.plum)
                Text(store.state.isDead ? "猫咪已经离开了…" : store.modelRuntimeState.title)
                    .font(.caption)
                    .foregroundStyle(CozyPalette.wood)
            }

            Spacer()

            Button {
                showStatus.toggle()
            } label: {
                Image(systemName: showStatus ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 20))
                    .foregroundStyle(CozyPalette.plum.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CozyPalette.card.opacity(0.85))
    }

    // MARK: - Cat Display

    private var catArea: some View {
        CatDisplayView(
            mood: store.currentMood,
            comment: store.actionStatusText ?? store.state.comment
        )
        .padding(.top, 8)
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 16) {
            statPill(icon: "heart.fill", value: store.state.happiness, tint: CozyPalette.rose)
            statPill(icon: "fork.knife", value: store.state.hunger, tint: .orange)
            statPill(icon: "cross.fill", value: store.state.health, tint: CozyPalette.moss)
            statPill(icon: "sparkles", value: store.state.cleanliness, tint: CozyPalette.sky)
            statPill(icon: "bolt.fill", value: store.state.energy, tint: .yellow)
        }
        .padding(.horizontal, 20)
    }

    private func statPill(icon: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(CozyPalette.plum)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(CozyPalette.card.opacity(0.8))
                .shadow(color: CozyPalette.shadow, radius: 2, y: 1)
        )
    }

    // MARK: - Action Grid

    private var actionGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CozyActionButton(title: "喂食", icon: "fork.knife", tint: .orange) {
                    Task { await store.performInteraction(.feed) }
                }
                CozyActionButton(title: "玩耍", icon: "gamecontroller.fill", tint: CozyPalette.moss) {
                    Task { await store.performInteraction(.play) }
                }
                CozyActionButton(title: "清洁", icon: "shower.fill", tint: CozyPalette.sky) {
                    Task { await store.performInteraction(.clean) }
                }
            }

            HStack(spacing: 12) {
                CozyActionButton(title: "管教", icon: "hand.raised.fill", tint: CozyPalette.wood) {
                    Task { await store.performInteraction(.discipline) }
                }
                CozyActionButton(title: "看病", icon: "cross.case.fill", tint: CozyPalette.rose) {
                    Task { await store.performInteraction(.medical) }
                }
                CozyActionButton(title: "聊天", icon: "bubble.left.and.bubble.right.fill", tint: CozyPalette.blush) {
                    showChat = true
                }
            }
        }
        .padding(.horizontal, 20)
        .disabled(store.state.isDead)
        .opacity(store.state.isDead ? 0.5 : 1)
    }

    // MARK: - Model Status Badge

    @ViewBuilder
    private var modelStatusBadge: some View {
        switch store.modelRuntimeState {
        case .ready:
            EmptyView()
        case .downloading:
            HStack(spacing: 8) {
                ProgressView(value: store.modelDownloadProgress)
                    .progressViewStyle(.linear)
                    .tint(CozyPalette.moss)
                    .frame(maxWidth: 160)

                Text(store.hasDownloadProgress ? store.downloadProgressLabel : "下载中…")
                    .font(.caption2)
                    .foregroundStyle(CozyPalette.wood)
            }
            .padding(.horizontal, 20)
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("加载模型中…")
                    .font(.caption2)
                    .foregroundStyle(CozyPalette.wood)
            }
        case .failed(let msg):
            VStack(spacing: 6) {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(CozyPalette.wood)
                Button("重试") {
                    Task { await store.redownloadModel() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CozyPalette.moss)
            }
        case .idle:
            EmptyView()
        }
    }
}
