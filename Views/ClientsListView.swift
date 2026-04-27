import SwiftUI

struct ClientsListView: View {
    @EnvironmentObject var store: ClientStore
    @State private var showAddClient = false
    @State private var searchText = ""

    private var filteredClients: [Client] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return store.clients
        }
        let query = searchText.lowercased()
        return store.clients.filter {
            $0.name.lowercased().contains(query) ||
            $0.phone.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.clients.isEmpty {
                    // ── Нет ни одного клиента ─────────────────────────────
                    EmptyStateView(
                        icon: "person.2",
                        title: "Клиентов пока нет",
                        subtitle: "Добавьте первого клиента, чтобы начать работу",
                        actionTitle: "Добавить клиента"
                    ) {
                        showAddClient = true
                    }
                } else if filteredClients.isEmpty {
                    // ── Поиск ничего не нашёл ─────────────────────────────
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Ничего не найдено",
                        subtitle: "Попробуйте изменить запрос"
                    )
                } else {
                    List {
                        ForEach(filteredClients) { client in
                            if let binding = clientBinding(for: client.id) {
                                NavigationLink(destination: ClientDetailView(client: binding)) {
                                    ClientRowView(client: client)
                                }
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { filteredClients[$0].id }
                            let realIndices = ids.compactMap { id in
                                store.clients.firstIndex(where: { $0.id == id })
                            }
                            store.remove(at: IndexSet(realIndices))
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по имени или телефону")
            .navigationTitle("Клиенты")
            .toolbar {
                ToolbarItem(id: "clients-edit", placement: .topBarLeading) {
                    if !store.clients.isEmpty { EditButton() }
                }
                ToolbarItem(id: "clients-add", placement: .topBarTrailing) {
                    Button {
                        showAddClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClient) {
                AddClientView()
                    .environmentObject(store)
            }
        }
    }

    private func clientBinding(for id: UUID) -> Binding<Client>? {
        guard let idx = store.clients.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.clients[idx]
    }
}

// MARK: - ClientRowView

private struct ClientRowView: View {
    let client: Client

    private var initials: String {
        client.name
            .components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Аватар с инициалами
            ZStack {
                Circle()
                    .fill(client.color.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(client.color)
            }

            // Имя + телефон
            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(client.phone.isEmpty ? "Телефон не указан" : client.phone)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Статус абонемента + занятия
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(client.subscriptionStatus.swiftUIColor)
                        .frame(width: 7, height: 7)
                    Text(client.subscriptionStatus.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(client.subscriptionStatus.swiftUIColor)
                }
                if client.totalSessions > 0 {
                    Text("\(client.remainingSessions) из \(client.totalSessions)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
