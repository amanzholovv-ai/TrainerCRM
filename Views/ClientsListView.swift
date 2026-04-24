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
            List {
                ForEach(filteredClients) { client in
                    if let binding = clientBinding(for: client.id) {
                        NavigationLink(destination: ClientDetailView(client: binding)) {
                            HStack(alignment: .center, spacing: 8) {
                                Circle()
                                    .fill(client.subscriptionStatus == .expired ? Color.red : Color.green)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.name)
                                        .font(.headline)
                                    Text(client.phone)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { filteredClients[$0].id }
                    ids.forEach { id in
                        if let realIndex = store.clients.firstIndex(where: { $0.id == id }) {
                            store.remove(at: IndexSet([realIndex]))
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по имени или телефону")
            .navigationTitle("Клиенты")
            .toolbar {
                ToolbarItem(id: "clients-edit", placement: .topBarLeading) {
                    EditButton()
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
