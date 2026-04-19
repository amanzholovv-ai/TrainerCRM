import Contacts

enum ContactPermissionHelper {
    static func checkAndRequest(completion: @escaping (Bool) -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            completion(true)
        case .limited:
            // iOS 18+: частичный доступ — для выбора контакта достаточно
            completion(true)
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(false)
            }
        @unknown default:
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
