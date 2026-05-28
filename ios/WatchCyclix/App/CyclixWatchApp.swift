import SwiftUI

@main
struct CyclixWatchApp: App {
    @StateObject private var store = CyclixWatchStore()

    var body: some Scene {
        WindowGroup {
            CyclixRootView()
                .environmentObject(store)
        }
    }
}
