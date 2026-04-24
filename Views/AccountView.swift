import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showPrivacyPolicy = false

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

                Section("О приложении") {
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Label("Политика конфиденциальности", systemImage: "lock.shield")
                    }
                    .foregroundColor(.primary)
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
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }
}

// MARK: - Политика конфиденциальности

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    private let url = URL(string: "https://amanzholovv-ai.github.io/trainercrm-privacy/")!

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

// MARK: - WebView (WKWebView обёртка)

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
