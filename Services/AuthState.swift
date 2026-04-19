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
        UserDefaults.standard.removeObject(forKey: "savedEmail")
        UserDefaults.standard.removeObject(forKey: "rememberMe")
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
