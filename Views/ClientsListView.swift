import SwiftUI

struct ClientsListView: View {
    @EnvironmentObject var store: ClientStore
    @State private var showAddClient = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($store.clients) { $client in
                    NavigationLink(destination: ClientDetailView(client: $client)) {
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
                .onDelete { indexSet in
                    store.remove(at: indexSet)
                }
            }  // ← закрываем List здесь
            .navigationTitle("Клиенты")  // ← на List
            .toolbar {                    // ← на List
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
            .sheet(isPresented: $showAddClient) {  // ← на List
                AddClientView()
                    .environmentObject(store)
            }
        }
    }
}
