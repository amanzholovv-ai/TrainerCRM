import SwiftUI

struct ProfileView: View {
    @ObservedObject var authState: AuthState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Профиль тренера")
                        .font(.headline)
                }
                Section("Настройки") {
                    Label("Учётная запись", systemImage: "person.circle")
                    Label("Уведомления", systemImage: "bell")
                }
                Section {
                    Button("Выйти", role: .destructive) {
                        authState.logout()
                    }
                }
            }
            .navigationTitle("Профиль")
        }
    }
}
