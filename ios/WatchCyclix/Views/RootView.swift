import SwiftUI

struct CyclixRootView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                NavigationStack {
                    CyclixDashboardView()
                }
            } else {
                CyclixLoginView()
            }
        }
        .task {
            await store.bootstrapIfNeeded()
        }
        .alert(item: $store.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
    }
}
