import SwiftUI
import Contacts
import ContactsUI

struct ContactPickResult {
    let name: String
    let phone: String
}

struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (ContactPickResult?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (ContactPickResult?) -> Void

        init(onPick: @escaping (ContactPickResult?) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            print("[ContactPicker] didSelect contact — вызов onPick (не dismiss SwiftUI вручную)")
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let formatted = Self.formatPhone(phone)
            onPick(ContactPickResult(name: name.isEmpty ? "Контакт" : name, phone: formatted))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            print("[ContactPicker] пользователь отменил выбор")
            onPick(nil)
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
}
