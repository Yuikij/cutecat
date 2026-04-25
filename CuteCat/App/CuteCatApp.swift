import SwiftUI

@main
struct CuteCatApp: App {
    @UIApplicationDelegateAdaptor(CuteCatAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PetStore()

    private let tickTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let eventTimer = Timer.publish(every: 120, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .onReceive(refreshTimer) { _ in
                    store.tick()
                }
                .onReceive(tickTimer) { _ in
                    Task {
                        await store.llmTick()
                    }
                }
                .onReceive(eventTimer) { _ in
                    Task {
                        await store.tryTriggerEvent()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.tick()
                        store.checkDailyStreak()
                        Task {
                            await store.checkDailyBondMoment()
                            await store.tryTriggerEvent()
                        }
                    }
                }
        }
    }
}
