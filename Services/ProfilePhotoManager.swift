import UIKit

// MARK: - ProfilePhotoManager
// Хранит фото профиля тренера в Documents директории, а не в UserDefaults.
// UserDefaults не предназначен для больших бинарных данных — тормозит запуск приложения.

final class ProfilePhotoManager: ObservableObject {
    static let shared = ProfilePhotoManager()

    @Published private(set) var image: UIImage?

    private let fileName = "profile_photo.jpg"

    private var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    private init() {
        load()
    }

    // MARK: - Загрузка

    func load() {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data)
        else {
            image = nil
            return
        }
        image = img
    }

    // MARK: - Сохранение

    func save(_ uiImage: UIImage) {
        guard let url = fileURL,
              let data = uiImage.jpegData(compressionQuality: 0.75)
        else { return }
        try? data.write(to: url, options: .atomic)
        DispatchQueue.main.async {
            self.image = uiImage
        }
    }

    // MARK: - Удаление

    func delete() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.async {
            self.image = nil
        }
    }
}
