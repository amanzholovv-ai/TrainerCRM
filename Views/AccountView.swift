import SwiftUI
import PhotosUI
import WebKit
import UserNotifications

// MARK: - AccountView (Профиль)

struct AccountView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showPrivacyPolicy = false
    @State private var showOnboarding    = false

    var body: some View {
        NavigationStack {
            List {

                // ── 1. Шапка: аватар + email ──────────────────────────────
                Section {
                    AccountHeaderRow()
                }

                // ── 2. Профиль + Аккаунт + Уведомления + Подписка ────────
                Section {
                    NavigationLink(destination: ProfileEditView()) {
                        Label("Профиль", systemImage: "person.text.rectangle")
                    }
                    NavigationLink(destination: AccountSettingsView()) {
                        Label("Аккаунт", systemImage: "gearshape")
                    }
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Уведомления", systemImage: "bell.fill")
                    }
                    NavigationLink(destination: SubscriptionView()) {
                        Label("Управление подпиской", systemImage: "crown")
                    }
                }

                // ── 3. Поддержка + О приложении ──────────────────────────
                Section("Поддержка") {
                    Link(destination: URL(string: "https://t.me/coachdesk01") ?? URL(string: "https://t.me")!) {
                        HStack {
                            Label("Написать в поддержку", systemImage: "paperplane.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section("О приложении") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Как работает приложение", systemImage: "questionmark.circle")
                    }
                    .foregroundColor(.primary)

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Label("Политика конфиденциальности", systemImage: "lock.shield")
                    }
                    .foregroundColor(.primary)
                }

                // ── 4. Выход ──────────────────────────────────────────────
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
            .navigationTitle("Профиль")
            .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
        }
    }
}

// MARK: - Шапка: аватар + email

private struct AccountHeaderRow: View {
    @EnvironmentObject var authState: AuthState
    @ObservedObject private var photoManager = ProfilePhotoManager.shared
    @AppStorage("profile_name") private var profileName = ""

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let img = photoManager.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(profileName.isEmpty ? "Тренер" : profileName)
                    .font(.headline)
                Text(authState.userEmail ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ProfileEditView

struct ProfileEditView: View {
    @ObservedObject private var photoManager = ProfilePhotoManager.shared
    @AppStorage("profile_name")       private var name         = ""
    @AppStorage("profile_bio")        private var bio          = ""
    @AppStorage("profile_instagram")  private var instagram    = ""
    @AppStorage("profile_gender")     private var genderRaw    = ""
    @AppStorage("profile_birthday")   private var birthdayTS   = Double(0)

    @State private var photoItem: PhotosPickerItem?

    private var birthday: Binding<Date> {
        Binding(
            get: { birthdayTS == 0 ? defaultBirthday : Date(timeIntervalSince1970: birthdayTS) },
            set: { birthdayTS = $0.timeIntervalSince1970 }
        )
    }

    private var defaultBirthday: Date {
        Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    }

    private let genderOptions = ["Мужской", "Женский", "Другой"]

    var body: some View {
        List {

            // ── Фото ──────────────────────────────────────────────────────
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let img = photoManager.image {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())

                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }
                            .offset(x: 4, y: 4)
                        }
                    }
                    .onChange(of: photoItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                ProfilePhotoManager.shared.save(img)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // ── Основные данные ───────────────────────────────────────────
            Section("Основное") {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    TextField("Имя", text: $name)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                        .padding(.top, 8)
                    TextField("Коротко о себе", text: $bio, axis: .vertical)
                        .lineLimit(2...5)
                }
            }

            // ── Соцсети ───────────────────────────────────────────────────
            Section("Соцсети") {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.pink)
                        .frame(width: 20)
                    HStack(spacing: 2) {
                        Text("@")
                            .foregroundColor(.secondary)
                        TextField("instagram", text: $instagram)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.twitter)
                    }
                }
            }

            // ── Личное ───────────────────────────────────────────────────
            Section("Личное") {
                HStack(spacing: 12) {
                    Image(systemName: "figure.stand")
                        .foregroundColor(.teal)
                        .frame(width: 20)
                    Picker("Пол", selection: $genderRaw) {
                        Text("Не указан").tag("")
                        ForEach(genderOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    DatePicker(
                        "День рождения",
                        selection: birthday,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
                .onAppear {
                    if birthdayTS == 0 { birthdayTS = defaultBirthday.timeIntervalSince1970 }
                }
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @EnvironmentObject var store: ClientStore

    @AppStorage("notifications_enabled")       private var enabled       = false
    @AppStorage("notifications_minutesBefore") private var minutesBefore = 60

    @State private var permissionDenied  = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private let options: [(minutes: Int, label: String)] = [
        (15,   "За 15 минут"),
        (30,   "За 30 минут"),
        (60,   "За 1 час"),
        (120,  "За 2 часа"),
        (180,  "За 3 часа"),
        (1440, "За день"),
    ]

    var body: some View {
        List {
            // ── Тоггл ─────────────────────────────────────────────────────
            Section {
                Toggle(isOn: $enabled) {
                    Label("Напоминания о тренировках", systemImage: "bell.badge.fill")
                }
                .onChange(of: enabled) { _, newValue in
                    if newValue {
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                NotificationManager.shared.rescheduleAll(clients: store.clients)
                            } else {
                                enabled = false
                                permissionDenied = true
                            }
                        }
                    } else {
                        NotificationManager.shared.cancelAll()
                    }
                }
                // Если системно запрещено — показываем плашку
                if authStatus == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Уведомления отключены")
                                .font(.caption.bold())
                            Text("Разрешите в настройках iPhone")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Открыть") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption.bold())
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Уведомление придёт перед каждой запланированной тренировкой.")
            }

            // ── Время напоминания (только когда включено) ─────────────────
            if enabled && authStatus != .denied {
                Section("Предупреждать") {
                    ForEach(options, id: \.minutes) { option in
                        Button {
                            minutesBefore = option.minutes
                            NotificationManager.shared.rescheduleAll(clients: store.clients)
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundColor(.primary)
                                Spacer()
                                if minutesBefore == option.minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            NotificationManager.shared.checkStatus { status in
                authStatus = status
                // Если включено в настройках, но разрешение отозвали — выключаем
                if status == .denied && enabled {
                    enabled = false
                }
            }
        }
        .alert("Нет доступа к уведомлениям", isPresented: $permissionDenied) {
            Button("Отмена", role: .cancel) {}
            Button("Открыть настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Разрешите уведомления в настройках iPhone, чтобы получать напоминания о тренировках.")
        }
    }
}

// MARK: - AccountSettingsView

struct AccountSettingsView: View {
    @EnvironmentObject var authState: AuthState

    // Sheet control
    @State private var activeSheet: AccountSheet?

    // Shared fields
    @State private var currentPassword = ""
    @State private var newEmail        = ""
    @State private var newPassword     = ""
    @State private var confirmPassword = ""

    // Feedback
    @State private var errorMessage    = ""
    @State private var successMessage  = ""
    @State private var showResult      = false

    enum AccountSheet: Identifiable {
        case email, password, delete
        var id: Int { hashValue }
    }

    var body: some View {
        List {
            // ── Email ─────────────────────────────────────────────────────
            Section("Электронная почта") {
                LabeledContent("Текущая почта") {
                    Text(authState.userEmail ?? "—")
                        .foregroundColor(.secondary)
                }
                Button {
                    resetFields()
                    activeSheet = .email
                } label: {
                    Label("Изменить почту", systemImage: "envelope.badge")
                }
            }

            // ── Пароль ────────────────────────────────────────────────────
            Section("Пароль") {
                Button {
                    resetFields()
                    activeSheet = .password
                } label: {
                    Label("Изменить пароль", systemImage: "lock.rotation")
                }
            }

            // ── Опасная зона ──────────────────────────────────────────────
            Section {
                Button(role: .destructive) {
                    resetFields()
                    activeSheet = .delete
                } label: {
                    Label("Удалить аккаунт", systemImage: "trash")
                }
            } header: {
                Text("Опасная зона")
            } footer: {
                Text("Удаление аккаунта необратимо. Все данные будут удалены.")
            }
        }
        .navigationTitle("Аккаунт")
        .navigationBarTitleDisplayMode(.large)

        // ── Sheets ────────────────────────────────────────────────────────
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .email:    changeEmailSheet
            case .password: changePasswordSheet
            case .delete:   deleteAccountSheet
            }
        }

        // ── Результат ─────────────────────────────────────────────────────
        .alert(errorMessage.isEmpty ? "Готово" : "Ошибка",
               isPresented: $showResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage.isEmpty ? successMessage : errorMessage)
        }
    }

    // MARK: - Change Email Sheet

    private var changeEmailSheet: some View {
        NavigationStack {
            Form {
                Section("Новая почта") {
                    TextField("Новый email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    SecureField("Текущий пароль", text: $currentPassword)
                } header: {
                    Text("Подтверждение")
                } footer: {
                    Text("На новый адрес придёт письмо для подтверждения.")
                }
            }
            .navigationTitle("Изменить почту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { activeSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if authState.isLoading {
                        ProgressView()
                    } else {
                        Button("Отправить") { submitEmailChange() }
                            .fontWeight(.semibold)
                            .disabled(newEmail.isEmpty || currentPassword.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Change Password Sheet

    private var changePasswordSheet: some View {
        NavigationStack {
            Form {
                Section("Текущий пароль") {
                    SecureField("Введите текущий пароль", text: $currentPassword)
                }
                Section {
                    SecureField("Новый пароль", text: $newPassword)
                    SecureField("Повторите новый пароль", text: $confirmPassword)
                } header: {
                    Text("Новый пароль")
                } footer: {
                    Text("Минимум 6 символов.")
                }
            }
            .navigationTitle("Изменить пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { activeSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if authState.isLoading {
                        ProgressView()
                    } else {
                        Button("Сохранить") { submitPasswordChange() }
                            .fontWeight(.semibold)
                            .disabled(currentPassword.isEmpty || newPassword.count < 6 || newPassword != confirmPassword)
                    }
                }
            }
        }
    }

    // MARK: - Delete Account Sheet

    private var deleteAccountSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Это действие нельзя отменить")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Все данные вашего аккаунта будут удалены безвозвратно.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    SecureField("Введите пароль для подтверждения", text: $currentPassword)
                } header: {
                    Text("Подтверждение")
                }
            }
            .navigationTitle("Удаление аккаунта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { activeSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if authState.isLoading {
                        ProgressView()
                    } else {
                        Button("Удалить", role: .destructive) { submitDeleteAccount() }
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .disabled(currentPassword.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func submitEmailChange() {
        authState.updateEmail(newEmail: newEmail, currentPassword: currentPassword) { error in
            activeSheet = nil
            if let error = error {
                errorMessage = error
                successMessage = ""
            } else {
                errorMessage = ""
                successMessage = "Письмо с подтверждением отправлено на \(newEmail)"
            }
            showResult = true
        }
    }

    private func submitPasswordChange() {
        guard newPassword == confirmPassword else {
            errorMessage = "Пароли не совпадают"
            successMessage = ""
            showResult = true
            return
        }
        authState.updatePassword(currentPassword: currentPassword, newPassword: newPassword) { error in
            activeSheet = nil
            if let error = error {
                errorMessage = error
                successMessage = ""
            } else {
                errorMessage = ""
                successMessage = "Пароль успешно изменён"
            }
            showResult = true
        }
    }

    private func submitDeleteAccount() {
        authState.deleteAccount(currentPassword: currentPassword) { error in
            if let error = error {
                activeSheet = nil
                errorMessage = error
                successMessage = ""
                showResult = true
            }
            // При успехе authState.logout() вызывается внутри deleteAccount —
            // приложение само вернётся на экран входа
        }
    }

    private func resetFields() {
        currentPassword = ""
        newEmail        = ""
        newPassword     = ""
        confirmPassword = ""
        errorMessage    = ""
        successMessage  = ""
    }
}

// MARK: - SubscriptionView

struct SubscriptionView: View {

    enum Plan { case free, monthly, yearly }

    @ObservedObject private var subManager = SubscriptionManager.shared
    @State private var selectedPlan: Plan = .yearly

    private var isSubscribed: Bool { subManager.isSubscribed }

    private var activePlan: Plan {
        switch subManager.activePlan {
        case .monthly: return .monthly
        case .yearly:  return .yearly
        case .free:    return .free
        }
    }

    private let proFeatures: [(icon: String, color: Color, text: String)] = [
        ("person.2.fill",            .blue,   "Неограниченное количество клиентов"),
        ("calendar.badge.plus",      .purple, "Полный доступ к календарю"),
        ("ticket.fill",              .teal,   "Абонементы и история занятий"),
        ("chart.bar.fill",           .orange, "Статистика доходов и загрузки"),
        ("bell.badge.fill",          .red,    "Напоминания об истекающих абонементах"),
        ("icloud.and.arrow.up.fill", .cyan,   "Синхронизация между устройствами"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Шапка ─────────────────────────────────────────────────
                VStack(spacing: 10) {
                    ZStack {
                        Circle()

                            .fill(LinearGradient(
                                colors: [.yellow.opacity(0.25), .orange.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top, endPoint: .bottom))
                    }
                    Text("Coach Desk Pro")
                        .font(.title2.bold())
                    Text("Выберите подходящий тариф")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // ── Тариф: Бесплатный ─────────────────────────────────────
                freePlanCard
                    .padding(.horizontal)

                // ── Переключатель Месяц / Год ─────────────────────────────
                HStack(spacing: 0) {
                    planToggleTab(title: "Месяц", plan: .monthly)
                    planToggleTab(title: "Год", plan: .yearly, badge: "−40%")
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)

                // ── Карточка Pro ───────────────────────────────────────────
                proPlanCard
                    .padding(.horizontal)

                // ── Кнопка подписки ────────────────────────────────────────
                if subManager.isLoading && subManager.products.isEmpty {
                    ProgressView("Загрузка тарифов...")
                        .padding()
                }

                if !isSubscribed {
                    Button {
                        Task {
                            let targetId = selectedPlan == .yearly
                                ? SubscriptionManager.ProductID.yearly
                                : SubscriptionManager.ProductID.monthly
                            if let product = subManager.products.first(where: { $0.id == targetId }) {
                                await subManager.purchase(product)
                            } else {
                                // Продукты ещё не загружены — загружаем и повторяем
                                await subManager.loadProducts()
                                if let product = subManager.products.first(where: { $0.id == targetId }) {
                                    await subManager.purchase(product)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if subManager.isLoading {
                                ProgressView().tint(.primary)
                            } else {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.primary.opacity(0.8))
                                Text(selectedPlan == .yearly
                                     ? "Оформить подписку — $49.99 / год"
                                     : "Оформить подписку — $7 / месяц")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary.opacity(0.85))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                    }
                    .disabled(subManager.isLoading)
                    .padding(.horizontal)

                    Button {
                        Task { await subManager.restorePurchases() }
                    } label: {
                        Text("Восстановить покупки")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Отменить подписку можно в любой момент")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                } else {
                    // Активная подписка
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text(activePlan == .yearly ? "Годовая подписка активна" : "Месячная подписка активна")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)

                    Button {
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Управление подпиской → Apple ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .underline()
                    }
                }

                if let err = subManager.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                subManager.errorMessage = nil
                            }
                        }
                }

                // ── Футер ──────────────────────────────────────────────────
                VStack(spacing: 6) {
                    Divider()
                    if let privacyURL = URL(string: "https://amanzholovv-ai.github.io/trainercrm-privacy/") {
                        Link("Политика конфиденциальности", destination: privacyURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Подписка продлевается автоматически. Списание происходит через App Store.")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
        }
        .navigationTitle("Подписка")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            if subManager.products.isEmpty {
                await subManager.loadProducts()
            }
        }
    }

    // MARK: - Free Plan Card

    private var freePlanCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Бесплатно")
                            .font(.headline)
                        Text("7 дней пробный период")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    Text("До 3 клиентов навсегда")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("$0")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.blue)
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))

            Divider()

            VStack(spacing: 0) {
                freeFeatureRow(icon: "person.fill", color: .blue,
                               text: "До 3 клиентов", included: true)
                Divider().padding(.leading, 52)
                freeFeatureRow(icon: "calendar", color: .purple,
                               text: "Базовый календарь", included: true)
                Divider().padding(.leading, 52)
                freeFeatureRow(icon: "ticket.fill", color: .teal,
                               text: "Абонементы и история", included: false)
                Divider().padding(.leading, 52)
                freeFeatureRow(icon: "chart.bar.fill", color: .orange,
                               text: "Статистика доходов", included: false)
                Divider().padding(.leading, 52)
                freeFeatureRow(icon: "icloud.and.arrow.up.fill", color: .cyan,
                               text: "Синхронизация", included: false)
            }
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1.5))
    }

    @ViewBuilder
    private func freeFeatureRow(icon: String, color: Color, text: String, included: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((included ? color : Color.gray).opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(included ? color : .gray)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(included ? .primary : .secondary)
            Spacer()
            Image(systemName: included ? "checkmark" : "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(included ? .green : Color(.tertiaryLabel))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Plan Toggle Tab

    @ViewBuilder
    private func planToggleTab(title: String, plan: Plan, badge: String? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedPlan == plan ? .white : .secondary)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedPlan == plan
                            ? Color.white.opacity(0.25)
                            : Color.green.opacity(0.15))
                        .foregroundColor(selectedPlan == plan ? .white : .green)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                selectedPlan == plan
                    ? LinearGradient(colors: [.yellow, .orange],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.clear, Color.clear],
                                     startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro Plan Card

    private var proPlanCard: some View {
        VStack(spacing: 0) {
            // Хедер
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Все функции")
                        .font(.headline)
                    Text(selectedPlan == .yearly ? "Годовая подписка" : "Ежемесячная подписка")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if selectedPlan == .yearly {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$84")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(.tertiaryLabel))
                                .strikethrough(true, color: Color(.tertiaryLabel))
                            Text("$49.99")
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading, endPoint: .trailing))
                        }
                        HStack(spacing: 4) {
                            Text("в год")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("скидка 40%")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text("$7")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading, endPoint: .trailing))
                        Text("в месяц")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Список функций
            VStack(spacing: 0) {
                ForEach(proFeatures.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(proFeatures[i].color.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: proFeatures[i].icon)
                                .font(.system(size: 15))
                                .foregroundColor(proFeatures[i].color)
                        }
                        Text(proFeatures[i].text)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                    if i < proFeatures.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: [.yellow.opacity(0.6), .orange.opacity(0.4)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.5))
    }
}

// MARK: - Политика конфиденциальности

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    private let url = URL(string: "https://amanzholovv-ai.github.io/trainercrm-privacy/") ?? URL(string: "https://apple.com")!

    var body: some View {
        NavigationStack {
            WebView(url: url)
                .navigationTitle("Политика конфиденциальности")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - WebView

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.load(URLRequest(url: url))
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
