import ContactsUI
import UIKit

/// Показывает `CNContactPickerViewController` через UIKit поверх текущего top-most VC,
/// без SwiftUI `.sheet` / `.fullScreenCover`, чтобы не закрывался родительский sheet (`AddClientView`).
enum ContactUIKitPicker {

    private final class DelegateProxy: NSObject, CNContactPickerDelegate {
        private let onDone: (ContactPickResult?) -> Void

        init(onDone: @escaping (ContactPickResult?) -> Void) {
            self.onDone = onDone
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            print("[ContactUIKitPicker] didSelect — UIKit presentation")
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let raw = contact.phoneNumbers.first?.value.stringValue ?? ""
            let formatted = Self.formatPhone(raw)
            let result = ContactPickResult(name: name.isEmpty ? "Контакт" : name, phone: formatted)
            finish(result)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            print("[ContactUIKitPicker] отмена")
            finish(nil)
        }

        private func finish(_ result: ContactPickResult?) {
            DispatchQueue.main.async { [onDone] in
                onDone(result)
            }
        }

        private static func formatPhone(_ phone: String) -> String {
            phone
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static var associationKey: UInt8 = 0

    static func present(completion: @escaping (ContactPickResult?) -> Void) {
        let run: () -> Void = {
            guard let host = topMostViewController() else {
                print("[ContactUIKitPicker] нет UIViewController — отмена")
                completion(nil)
                return
            }

            let picker = CNContactPickerViewController()
            let delegate = DelegateProxy { result in
                completion(result)
            }
            picker.delegate = delegate
            picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")

            objc_setAssociatedObject(
                picker,
                &associationKey,
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            print("[ContactUIKitPicker] present(from: \(type(of: host)))")
            host.present(picker, animated: true)
        }

        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    private static func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = {
            if let base { return base }
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else {
                return UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first(where: { $0.isKeyWindow })?
                    .rootViewController
            }
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            return window?.rootViewController
        }()

        if let nav = root as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return root
    }
}
