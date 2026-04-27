import Foundation
import StoreKit
import SwiftUI

// MARK: - SubscriptionManager
// Управляет подпиской через StoreKit 2.
// Статус НЕ хранится в UserDefaults/@AppStorage — только в транзакциях App Store.
// Это делает обход подписки через редактирование UserDefaults невозможным.

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Состояние

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var activePlan: SubscriptionPlan = .free
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Product IDs (должны совпадать с App Store Connect)
    enum ProductID {
        static let monthly = "com.trainercrm.pro.monthly"   // $7 / месяц
        static let yearly  = "com.trainercrm.pro.yearly"    // $49.99 / год
    }

    enum SubscriptionPlan: String {
        case free    = "free"
        case monthly = "monthly"
        case yearly  = "yearly"
    }

    @Published private(set) var products: [Product] = []

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactionUpdates()
        Task { await refreshStatus() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Загрузка продуктов

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [ProductID.monthly, ProductID.yearly])
        } catch {
            errorMessage = "Не удалось загрузить тарифы: \(error.localizedDescription)"
        }
    }

    // MARK: - Покупка

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshStatus()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Покупка ожидает подтверждения"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Ошибка покупки: \(error.localizedDescription)"
        }
    }

    // MARK: - Восстановление покупок

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            errorMessage = "Ошибка восстановления: \(error.localizedDescription)"
        }
    }

    // MARK: - Проверка статуса (читает реальные транзакции App Store)

    func refreshStatus() async {
        var hasActive = false
        var plan: SubscriptionPlan = .free

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            if transaction.productID == ProductID.yearly {
                hasActive = true
                plan = .yearly
                break
            } else if transaction.productID == ProductID.monthly {
                hasActive = true
                plan = .monthly
            }
        }

        isSubscribed = hasActive
        activePlan   = plan
    }

    // MARK: - Фоновое отслеживание транзакций

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await refreshStatus()
            }
        }
    }

    // MARK: - Вспомогательные

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - Ограничения бесплатного тарифа

    /// До 3 клиентов на бесплатном тарифе
    static let freeClientLimit = 3

    func canAddClient(currentCount: Int) -> Bool {
        #if DEBUG
        return true
        #else
        return isSubscribed || currentCount < Self.freeClientLimit
        #endif
    }
}

// MARK: - Ошибки StoreKit

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Не удалось верифицировать покупку в App Store"
        }
    }
}
