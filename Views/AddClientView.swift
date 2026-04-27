import SwiftUI

struct AddClientView: View {
    @EnvironmentObject var store: ClientStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subManager = SubscriptionManager.shared

    @State private var name         = ""
    @State private var phone        = ""
    @State private var selectedHex  = "#6C63FF"
    @State private var showPermissionAlert  = false
    @State private var showUpgradeAlert     = false
    @State private var showSubscription     = false
    @FocusState private var focusedField: Field?

    enum Field { case name, phone }

    // MARK: - Colour palette

    private let colorPalette: [(name: String, hex: String)] = [
        ("Фиолетовый", "#6C63FF"),
        ("Розовый",    "#FF6584"),
        ("Зелёный",    "#43E97B"),
        ("Оранжевый",  "#F7971E"),
        ("Голубой",    "#38B2F8"),
        ("Красный",    "#FF4757"),
        ("Бирюзовый",  "#1DD1A1"),
        ("Жёлтый",     "#FFC312"),
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // ── 1. Поля ввода ──────────────────────────────────────────
                Section("Клиент") {
                    TextField("Имя", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .phone }

                    TextField("Номер телефона", text: $phone)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                }

                // ── 2. Импорт из контактов (отдельное действие) ────────────
                Section {
                    Button(action: openContactPicker) {
                        HStack(spacing: 14) {
                            // Иконка в тайлбоксе — Apple-style tinted icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            Text("Выбрать из контактов")
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Имя и телефон заполнятся автоматически")
                }

                // ── 3. Цвет метки (вторично) ───────────────────────────────
                Section("Цвет метки") {
                    // Превью
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill((Color(hex: selectedHex) ?? .accentColor).opacity(0.15))
                                .frame(width: 46, height: 46)
                            Circle()
                                .fill(Color(hex: selectedHex) ?? .accentColor)
                                .frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? "Имя клиента"
                                 : name)
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Так клиент выглядит в календаре")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.15), value: name)

                    // Палитра — 4 колонки, крупные области касания
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 8),
                        spacing: 6
                    ) {
                        ForEach(colorPalette, id: \.hex) { item in
                            colorSwatch(hex: item.hex)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Новый клиент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить") {
                        if subManager.canAddClient(currentCount: store.clients.count) {
                            saveClient()
                        } else {
                            showUpgradeAlert = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            // Auto-focus имени при открытии шита
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    focusedField = .name
                }
            }
            .alert("Доступ к контактам", isPresented: $showPermissionAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Разрешите доступ к контактам в настройках, чтобы импортировать клиентов.")
            }
            .alert("Лимит бесплатного тарифа", isPresented: $showUpgradeAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Перейти на Pro") {
                    showSubscription = true
                }
            } message: {
                Text("Бесплатный тариф позволяет добавить до \(SubscriptionManager.freeClientLimit) клиентов. Перейдите на Pro для неограниченного количества.")
            }
            .fullScreenCover(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }

    // MARK: - Color swatch

    private func colorSwatch(hex: String) -> some View {
        let isSelected = selectedHex == hex
        let color = Color(hex: hex) ?? .gray
        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .scaleEffect(isSelected ? 1.12 : 1.0)
                .shadow(
                    color: isSelected ? color.opacity(0.55) : .clear,
                    radius: isSelected ? 6 : 0
                )

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                selectedHex = hex
            }
        }
    }

    // MARK: - Save

    private func saveClient() {
        var newClient = Client(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone,
            colorHex: selectedHex,
            workouts: [],
            attendance: []
        )
        newClient.totalSessions = 0
        newClient.startDate = Date.distantPast
        newClient.endDate   = Date.distantPast
        store.addClient(newClient)
        dismiss()
    }

    // MARK: - Contacts

    private func openContactPicker() {
        ContactPermissionHelper.checkAndRequest { granted in
            guard granted else {
                showPermissionAlert = true
                return
            }
            ContactUIKitPicker.present { result in
                Task { @MainActor in
                    if let result {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            name  = result.name
                            phone = result.phone
                        }
                    }
                }
            }
        }
    }
}
