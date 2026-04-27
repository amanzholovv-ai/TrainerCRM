import SwiftUI
import Firebase
import FirebaseAuth

final class AuthState: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUserId: String? = nil
    @Published var errorMessage: String = ""
    @Published var isLoading = false
    @Published var userEmail: String? = nil

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid
                self?.userEmail = user?.email
                self?.isLoggedIn = user != nil
            }
        }
    }

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func register(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    
    func logout() {
        try? Auth.auth().signOut()
        KeychainHelper.shared.delete(forKey: KeychainHelper.Key.savedEmail)
        UserDefaults.standard.set(false, forKey: "rememberMe")
    }

    // MARK: - Переаутентификация (нужна для смены email/пароля и удаления)

    private func reauthenticate(password: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            completion(NSError(domain: "AuthState", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"]))
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    // MARK: - Изменить email

    func updateEmail(newEmail: String, currentPassword: String,
                     completion: @escaping (String?) -> Void) {
        isLoading = true
        reauthenticate(password: currentPassword) { [weak self] error in
            if let error = error {
                self?.isLoading = false
                completion(error.localizedDescription)
                return
            }
            Auth.auth().currentUser?.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        completion(error.localizedDescription)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    // MARK: - Изменить пароль

    func updatePassword(currentPassword: String, newPassword: String,
                        completion: @escaping (String?) -> Void) {
        isLoading = true
        reauthenticate(password: currentPassword) { [weak self] error in
            if let error = error {
                self?.isLoading = false
                completion(error.localizedDescription)
                return
            }
            Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(error?.localizedDescription)
                }
            }
        }
    }

    // MARK: - Удалить аккаунт

    func deleteAccount(currentPassword: String,
                       completion: @escaping (String?) -> Void) {
        isLoading = true
        reauthenticate(password: currentPassword) { [weak self] error in
            if let error = error {
                self?.isLoading = false
                completion(error.localizedDescription)
                return
            }
            Auth.auth().currentUser?.delete { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        completion(error.localizedDescription)
                    } else {
                        self?.logout()
                        completion(nil)
                    }
                }
            }
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
