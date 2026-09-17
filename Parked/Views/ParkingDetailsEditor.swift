import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ParkingDetailsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ParkingDetailsDraft
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingPhotoChoices = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailable = false

    let onCancel: () -> Void
    let onSave: (ParkingDetailsDraft) -> Void

    init(
        initialDraft: ParkingDetailsDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ParkingDetailsDraft) -> Void
    ) {
        _draft = State(initialValue: initialDraft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aks-e park") {
                    if let photoData = draft.parkingPhotoData,
                       let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityLabel("Aks-e park entekhab shode")

                        Button("Aks ro avaz kon", systemImage: "arrow.triangle.2.circlepath") {
                            isShowingPhotoChoices = true
                        }

                        Button("Aks ro pak kon", systemImage: "trash", role: .destructive) {
                            selectedPhoto = nil
                            draft.parkingPhotoData = nil
                        }
                    } else {
                        Button("Aks ezafe kon", systemImage: "camera") {
                            isShowingPhotoChoices = true
                        }
                    }
                }

                Section {
                    TextField("Mesalan B2", text: $draft.floor)
                        .textContentType(.location)
                } header: {
                    Text("Tabaghe")
                }

                Section {
                    TextField("Mesalan Abi", text: $draft.section)
                } header: {
                    Text("Bakhsh")
                }

                Section {
                    TextField("Mesalan C-14", text: $draft.spot)
                } header: {
                    Text("Ja ya sotoon")
                }

                Section {
                    TextField("Mesalan kenare asansor", text: $draft.landmark)
                } header: {
                    Text("Neshone")
                }

                Section {
                    TextField("Har chizi ke komaket mikone", text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Yaddasht")
                } footer: {
                    Text("Hame-ye in joz'iyat ekhtiarian.")
                }
            }
            .navigationTitle("Joz'iyat-e park")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bikhial") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Aks ro chetor ezafe koni?", isPresented: $isShowingPhotoChoices) {
                Button("Ba doorbin begir", systemImage: "camera") {
                    openCamera()
                }

                Button("Az Photos entekhab kon", systemImage: "photo.on.rectangle") {
                    isShowingPhotoLibrary = true
                }

                Button("Bikhial", role: .cancel) {}
            }
            .alert("Doorbin dar dastres nist", isPresented: $isShowingCameraUnavailable) {
                Button("Bashe", role: .cancel) {}
            } message: {
                Text("Mituni az Photos ye aks entekhab koni.")
            }
            .photosPicker(
                isPresented: $isShowingPhotoLibrary,
                selection: $selectedPhoto,
                matching: .images
            )
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    draft.parkingPhotoData = image.jpegData(compressionQuality: 0.85)
                    isShowingCamera = false
                } onCancel: {
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto,
                      let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                draft.parkingPhotoData = image.jpegData(compressionQuality: 0.85)
            }
        }
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
