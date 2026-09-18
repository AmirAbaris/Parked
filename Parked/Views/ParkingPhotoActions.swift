import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ParkingPhotoActions: ViewModifier {
    @Binding var isShowingChoices: Bool
    let memoryID: UUID
    let hasPhoto: Bool
    let onSave: (Data?, UUID) -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailable = false
    @State private var isShowingPhotoError = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Aks-e park", isPresented: $isShowingChoices) {
                Button("Ba doorbin begir", systemImage: "camera") {
                    openCamera()
                }
                Button("Az Photos entekhab kon", systemImage: "photo.on.rectangle") {
                    selectedPhoto = nil
                    isShowingPhotoLibrary = true
                }
                if hasPhoto {
                    Button("Aks ro pak kon", systemImage: "trash", role: .destructive) {
                        onSave(nil, memoryID)
                    }
                }
                Button("Bikhial", role: .cancel) {}
            }
            .alert("Doorbin dar dastres nist", isPresented: $isShowingCameraUnavailable) {
                Button("Bashe", role: .cancel) {}
            } message: {
                Text("Mituni az Photos ye aks entekhab koni.")
            }
            .alert("Aks baz nashod", isPresented: $isShowingPhotoError) {
                Button("Bashe", role: .cancel) {}
            } message: {
                Text("Dobare talash kon ya ye aks-e dige entekhab kon.")
            }
            .photosPicker(
                isPresented: $isShowingPhotoLibrary,
                selection: $selectedPhoto,
                matching: .images
            )
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    saveImage(image)
                    isShowingCamera = false
                } onCancel: {
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                let targetMemoryID = memoryID
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let jpeg = image.jpegData(compressionQuality: 0.85) else {
                        isShowingPhotoError = true
                        return
                    }
                    guard !Task.isCancelled else { return }
                    onSave(jpeg, targetMemoryID)
                } catch {
                    guard !Task.isCancelled else { return }
                    isShowingPhotoError = true
                }
            }
    }

    private func saveImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            isShowingPhotoError = true
            return
        }
        onSave(data, memoryID)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            isShowingCameraUnavailable = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCamera = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    isShowingCamera = true
                } else {
                    isShowingCameraUnavailable = true
                }
            }
        case .denied, .restricted:
            isShowingCameraUnavailable = true
        @unknown default:
            isShowingCameraUnavailable = true
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onImagePicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
