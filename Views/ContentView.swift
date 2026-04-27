import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var store: ClientStore

    // MARK: - Login / Register fields
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @AppStorage("rememberMe") private var rememberMe = false
    @State private var isRegistering = false
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotSent = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        if authState.isLoggedIn {
            mainTabView
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                // Планируем уведомления как только Firestore прислал первый снапшот
                .onChange(of: store.isLoadingClients) { _, isLoading in
                    if !isLoading {
                        NotificationManager.shared.rescheduleAll(clients: store.clients)
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
                    hasSeenOnboarding = true
                }) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        } else {
            loginView
        }
    }

    // MARK: - Main Tab View
    var mainTabView: some View {
        TabView {
            CalendarContainerView()
                .tabItem { Label("Календарь", systemImage: "calendar") }

            ClientsListView()
                .tabItem { Label("Клиенты", systemImage: "person.2.fill") }

            StatsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar.fill") }

            AccountView()
                .tabItem { Label("Профиль", systemImage: "person.circle.fill") }
        }
        // Показываем системный алерт, если ClientStore зарепортил ошибку Firestore.
        .alert(
            "Ошибка синхронизации",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { newValue in
                    if !newValue { store.clearLastError() }
                }
            ),
            presenting: store.lastError
        ) { _ in
            Button("Понятно", role: .cancel) {
                store.clearLastError()
            }
        } message: { errorText in
            Text(errorText)
        }
    }

    // MARK: - Login / Register View
    var loginView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.13, green: 0.13, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                            )

                        Text("Coach Desk")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        Text(isRegistering ? "Создайте аккаунт" : "Добро пожаловать")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)

                    // Fields card
                    VStack(spacing: 16) {
                        fieldView(icon: "envelope.fill", placeholder: "Email", text: $email, keyboard: .emailAddress)

                        fieldView(icon: "lock.fill", placeholder: "Пароль", text: $password, isSecure: true, revealBinding: $showPassword)

                        if isRegistering {
                            fieldView(icon: "lock.fill", placeholder: "Повторите пароль", text: $confirmPassword, isSecure: true, revealBinding: $showConfirmPassword)
                        }

                        if !authState.errorMessage.isEmpty {
                            Text(authState.errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if !isRegistering {
                            Toggle(isOn: $rememberMe) {
                                Text("Запомнить меня")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            .tint(.blue)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal)

                    // Primary action button
                    Button {
                        primaryAction()
                    } label: {
                        Group {
                            if authState.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegistering ? "Зарегистрироваться" : "Войти")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .disabled(authState.isLoading)

                    // Secondary links
                    VStack(spacing: 14) {
                        if !isRegistering {
                            Button("Забыли пароль?") {
                                forgotEmail = email
                                forgotSent = false
                                authState.errorMessage = ""
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }

                        Button {
                            withAnimation {
                                isRegistering.toggle()
                                authState.errorMessage = ""
                                password = ""
                                confirmPassword = ""
                            }
                        } label: {
                            Text(isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onAppear {
            if rememberMe, let saved = KeychainHelper.shared.get(forKey: KeychainHelper.Key.savedEmail) {
                email = saved
            }
        }
    }

    // MARK: - Forgot Password Sheet
    var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: forgotSent ? "checkmark.circle.fill" : "key.fill")
                        .font(.system(size: 52))
                        .foregroundColor(forgotSent ? .green : .blue)
                        .padding(.top, 20)

                    Text(forgotSent ? "Письмо отправлено!" : "Восстановление пароля")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    if forgotSent {
                        Text("Проверьте почту \(forgotEmail) и следуйте инструкциям.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            fieldView(icon: "envelope.fill", placeholder: "Ваш Email", text: $forgotEmail, keyboard: .emailAddress)
                                .padding(.horizontal)

                            if !authState.errorMessage.isEmpty {
                                Text(authState.errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }

                            Button {
                                authState.resetPassword(email: forgotEmail) { success in
                                    if success { forgotSent = true }
                                }
                            } label: {
                                Text("Отправить")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal)
                            .disabled(authState.isLoading)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        showForgotPassword = false
                        authState.errorMessage = ""
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Helpers
    @ViewBuilder
    func fieldView(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool = false, keyboard: UIKeyboardType = .default, revealBinding: Binding<Bool>? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            if isSecure {
                if let reveal = revealBinding, reveal.wrappedValue {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let reveal = revealBinding {
                    Button {
                        reveal.wrappedValue.toggle()
                    } label: {
                        Image(systemName: reveal.wrappedValue ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(reveal.wrappedValue ? "Скрыть пароль" : "Показать пароль")
                }
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }

    func primaryAction() {
        authState.errorMessage = ""
        if isRegistering {
            guard password == confirmPassword else {
                authState.errorMessage = "Пароли не совпадают"
                return
            }
            guard password.count >= 6 else {
                authState.errorMessage = "Пароль минимум 6 символов"
                return
            }
            authState.register(email: email, password: password)
        } else {
            if rememberMe {
                KeychainHelper.shared.set(email, forKey: KeychainHelper.Key.savedEmail)
            } else {
                KeychainHelper.shared.delete(forKey: KeychainHelper.Key.savedEmail)
            }
            authState.login(email: email, password: password)
        }
    }
}
