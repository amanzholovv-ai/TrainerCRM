import SwiftUI

/// Утилита для корректной работы с нижним safe area в TabView.
/// Использует реальные значения системы вместо захардкоженных.
enum MainTabLayout { }

extension View {
    /// Добавляет корректный отступ снизу, равный системному safe area (home indicator).
    /// Использовать ТОЛЬКО при необходимости (например, кастомный скролл).
    func mainTabBottomSafeAreaInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            GeometryReader { geo in
                Color.clear
                    .frame(height: geo.safeAreaInsets.bottom)
                    .accessibilityHidden(true)
            }
        }
    }
}
