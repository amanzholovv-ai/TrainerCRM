import SwiftUI

struct AddClientView: View {
    @EnvironmentObject var store: ClientStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var selectedHex = "#6C63FF"
    @State private var showPermissionAlert = false

    // Палитра цветов на выбор
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Новый клиент") {
                    TextField("Имя", text: $name)
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)

                    Button {
                        openContactPicker()
                    } label: {
                        Label("Импорт из контактов", systemImage: "person.crop.circle.badge.plus")
                    }
                }

                Section("Цвет в календаре") {
                    // Превью выбранного цвета
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedHex) ?? .accentColor)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .shadow(color: (Color(hex: selectedHex) ?? .accentColor).opacity(0.4), radius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Клиент" : name)
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Превью в календаре")
                                .font(.caption).foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    // Сетка цветов
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorPalette, id: \.hex) { item in
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: item.hex) ?? .gray)
                                        .frame(width: 44, height: 44)

                                    if selectedHex == item.hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundColor(.white)
                                    }
                                    
                                }
                                .onTapGesture { selectedHex = item.hex }

                                Text(item.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Добавить клиента")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        print("[AddClient] нажато «Сохранить» name=\(name), phone=\(phone)")
                        var newClient = Client(
                            name: name,
                            phone: phone,
                            colorHex: selectedHex,
                            workouts: [],
                            attendance: []
                        )
                        newClient.totalSessions = 0
                        newClient.startDate = Date.distantPast
                        newClient.endDate = Date.distantPast
                        store.addClient(newClient)
                        print("[AddClient] клиент добавлен в ClientStore, закрываем форму")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .listStyle(.insetGrouped)
            .alert("Доступ к контактам", isPresented: $showPermissionAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Разрешите доступ к контактам в настройках приложения для импорта клиентов.")
            }
    
        }
    }

    private func openContactPicker() {
        print("[AddClient] openContactPicker — UIKit ContactUIKitPicker (без SwiftUI sheet)")
        ContactPermissionHelper.checkAndRequest { granted in
            print("[AddClient] доступ к контактам: \(granted ? "разрешён" : "запрещён")")
            guard granted else {
                showPermissionAlert = true
                return
            }
            ContactUIKitPicker.present { result in
                Task { @MainActor in
                    print("[AddClient] колбэк пикера: \(result != nil ? "есть контакт" : "нет")")
                    if let result {
                        print("[AddClient] подставляем name=\(result.name) phone=\(result.phone)")
                        name = result.name
                        phone = result.phone
                    }
                    print("[AddClient] форма должна остаться открытой — сохранение только по «Сохранить»")
                }
            }
        }
    }
}

