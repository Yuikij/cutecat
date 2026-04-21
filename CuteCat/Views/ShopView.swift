import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var store: PetStore
    @State private var shopItems: [ShopItem] = []
    @State private var isLoading = true
    @State private var isClosed = false
    @State private var isFeeding = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CozyBackground()

                if isLoading {
                    loadingView
                } else if isClosed {
                    closedView
                } else {
                    itemListView
                }
            }
            .navigationTitle("小卖部")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关门") { dismiss() }
                        .foregroundStyle(CozyPalette.wood)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "bag.fill")
                            .font(.caption)
                        Text("背包: \(store.inventory.count)件")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(CozyPalette.plum)
                }
            }
        }
        .task {
            await loadShop()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(CozyPalette.moss)
            Text("老板正在摆摊…")
                .font(.subheadline)
                .foregroundStyle(CozyPalette.wood)
        }
    }

    private var closedView: some View {
        VStack(spacing: 16) {
            Text("🚪")
                .font(.system(size: 60))

            Text("打烊了")
                .font(.title2.weight(.bold))
                .foregroundStyle(CozyPalette.plum)

            Text("老板今天不太在状态，\n改天再来吧")
                .font(.subheadline)
                .foregroundStyle(CozyPalette.wood)
                .multilineTextAlignment(.center)

            Button("再敲敲门") {
                isLoading = true
                isClosed = false
                Task { await loadShop() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CozyPalette.moss)
            .padding(.top, 8)
        }
    }

    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(shopItems) { item in
                    shopItemCard(item)
                }

                if store.inventory.isEmpty == false {
                    inventorySection
                }
            }
            .padding(16)
        }
    }

    private func shopItemCard(_ item: ShopItem) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 32))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CozyPalette.plum)
                Text(item.desc)
                    .font(.caption)
                    .foregroundStyle(CozyPalette.wood)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                store.buyItem(item)
            } label: {
                Text("拿走")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(CozyPalette.moss)
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CozyPalette.card.opacity(0.9))
                .shadow(color: CozyPalette.shadow, radius: 4, y: 2)
        )
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("背包")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CozyPalette.plum)
                .padding(.top, 16)

            ForEach(store.inventory) { item in
                HStack(spacing: 12) {
                    Text(item.emoji)
                        .font(.system(size: 28))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CozyPalette.plum)
                        Text(item.desc)
                            .font(.caption)
                            .foregroundStyle(CozyPalette.wood)
                    }

                    Spacer()

                    Button {
                        guard !isFeeding else { return }
                        isFeeding = true
                        let feedItem = item
                        dismiss()
                        Task {
                            await store.feedItemToCat(feedItem)
                            isFeeding = false
                        }
                    } label: {
                        Text("投喂")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(CozyPalette.rose))
                    }
                    .disabled(isFeeding)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CozyPalette.cream.opacity(0.8))
                )
            }
        }
    }

    private func loadShop() async {
        defer { isLoading = false }

        guard store.modelRuntimeState == .ready else {
            isClosed = true
            return
        }

        if let items = await store.generateShopItems() {
            shopItems = items
            isClosed = false
        } else {
            isClosed = true
        }
    }
}
