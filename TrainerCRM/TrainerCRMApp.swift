import SwiftUI
import Firebase

@main
struct TrainerCRMApp: App {
    @StateObject private var store = ClientStore()
    @StateObject private var authState = AuthState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(authState)
                .preferredColorScheme(.dark)
                .onChange(of: authState.currentUserId) { _, userId in
                    if let userId = userId {
                        store.configure(userId: userId)
                    } else {
                        store.reset()
                    }
                }
        }
    }
}
