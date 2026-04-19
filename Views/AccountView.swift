import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authState: AuthState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Тренер")
                                .font(.headline)
                            Text(authState.userEmail ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        authState.logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                    }
                }
            }
            .navigationTitle("Аккаунт")
        }
    }
}
