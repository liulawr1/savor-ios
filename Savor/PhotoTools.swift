import SwiftUI
import PhotosUI
import ImageIO
import AVFoundation

enum PhotoTools {
    static func compressed(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1536,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw SavorError.message("This photo could not be opened. Try a JPEG or another image.") }
        let image = UIImage(cgImage: thumbnail)
        for quality in [0.8, 0.6, 0.4] {
            if let result = image.jpegData(compressionQuality: quality), result.count <= 2_000_000 { return result }
        }
        throw SavorError.message("This photo is too large. Try a closer, smaller photo.")
    }

    static func load(_ item: PhotosPickerItem) async throws -> Data {
        guard let data = try await item.loadTransferable(type: Data.self) else { throw SavorError.message("The photo could not be loaded. It may still be downloading from iCloud.") }
        return try compressed(data)
    }

    static func cameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            defer { parent.dismiss() }
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) else {
                parent.onError("The camera photo could not be saved."); return
            }
            do { parent.onPhoto(try PhotoTools.compressed(data)) }
            catch { parent.onError(error.localizedDescription) }
        }
    }
}
