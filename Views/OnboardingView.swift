import SwiftUI

// MARK: - Onboarding entry point

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.strengthtraining.traditional",
            iconGradient: [.blue, .purple],
            title: "Coach Desk",
            subtitle: "Всё для тренера в одном месте.\nКлиенты, расписание, статистика — быстро и без бумаг.",
            items: nil
        ),
        OnboardingPage(
            icon: "person.text.rectangle.fill",
            iconGradient: [.teal, .blue],
            title: "Клиенты и абонементы",
            subtitle: "Добавляй клиентов, создавай абонементы и следи сколько занятий осталось.",
            items: [
                OnboardingItem(icon: "ticket.fill",    color: .teal,   text: "Абонемент автоматически создаёт расписание тренировок"),
                OnboardingItem(icon: "clock.badge.exclamationmark", color: .orange, text: "Напоминает когда у клиента заканчиваются занятия"),
                OnboardingItem(icon: "clock.arrow.circlepath", color: .blue, text: "История всех прошлых абонементов всегда под рукой"),
            ]
        ),
        OnboardingPage(
            icon: "calendar",
            iconGradient: [.purple, .pink],
            title: "Календарь",
            subtitle: "Недельный и месячный вид расписания. Тап на свободный слот — добавить тренировку.",
            items: [
                OnboardingItem(icon: "hand.tap.fill",        color: .blue,   text: "Тап на тренировку — изменить статус или время"),
                OnboardingItem(icon: "arrow.up.and.down",    color: .purple, text: "Перетащи тренировку чтобы перенести на другое время"),
                OnboardingItem(icon: "plus.circle.fill",     color: .green,  text: "Тап на пустое место — быстро добавить тренировку"),
            ]
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconGradient: [.green, .teal],
            title: "Статусы тренировок",
            subtitle: "Важно понимать чем отличаются статусы — от этого зависит учёт занятий.",
            items: [
                OnboardingItem(icon: "clock",                          color: .blue,   text: "Запланировано — тренировка ещё не прошла"),
                OnboardingItem(icon: "checkmark.circle.fill",          color: .green,  text: "Проведена — занятие прошло и списывается с абонемента"),
                OnboardingItem(icon: "exclamationmark.triangle.fill",  color: .orange, text: "Неявка — клиент не предупредил заранее. Тренировка считается проведённой и списывается"),
                OnboardingItem(icon: "xmark.circle.fill",              color: .red,    text: "Отмена — тренировка отменена заранее. Занятие НЕ списывается с абонемента"),
            ]
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom controls
                VStack(spacing: 20) {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == currentPage ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // Button
                    Button(action: advance) {
                        Text(currentPage == pages.count - 1 ? "Начать работу" : "Далее")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: currentPage == pages.count - 1
                                        ? [.green, .teal]
                                        : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)

                    // Skip
                    if currentPage < pages.count - 1 {
                        Button("Пропустить") { isPresented = false }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page layout

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: page.iconGradient.map { $0.opacity(0.25) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 120, height: 120)
                    Image(systemName: page.icon)
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: page.iconGradient,
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                // Texts
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(page.subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }

                // Items
                if let items = page.items {
                    VStack(spacing: 14) {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(items[i].color.opacity(0.18))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: items[i].icon)
                                        .font(.system(size: 17))
                                        .foregroundColor(items[i].color)
                                }
                                Text(items[i].text)
                                    .font(.subheadline)
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            isPresented = false
        }
    }
}

// MARK: - Models

private struct OnboardingPage {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let items: [OnboardingItem]?
}

private struct OnboardingItem {
    let icon: String
    let color: Color
    let text: String
}
