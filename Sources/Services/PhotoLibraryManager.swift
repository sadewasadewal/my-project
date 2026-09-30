//
//  PhotoLibraryManager.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import Photos
import UIKit
import Combine

/// Utility managing PHPhotoLibrary permissions and camera roll persistence.
@MainActor
public final class PhotoLibraryManager: ObservableObject {
    public static let shared = PhotoLibraryManager()

    @Published public var isSaving: Bool = false
    @Published public var alertMessage: String?
    @Published public var showAlert: Bool = false
    @Published public var isSuccess: Bool = false

    private init() {}

    /// Requests photo library authorization and saves the given UIImage to the user's camera roll.
    public func saveToCameraRoll(image: UIImage) {
        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .authorized, .limited:
                    self.performSave(image: image)
                case .denied, .restricted:
                    self.isSaving = false
                    self.isSuccess = false
                    self.alertMessage = "Photo Library access was denied. Please enable 'Add Photos' access in iOS Settings to save your artwork."
                    self.showAlert = true
                    HapticManager.shared.notification(type: .warning)
                case .notDetermined:
                    self.isSaving = false
                    self.isSuccess = false
                    self.alertMessage = "Photo Library access was not determined."
                    self.showAlert = true
                @unknown default:
                    self.isSaving = false
                    self.isSuccess = false
                    self.alertMessage = "An unexpected error occurred while requesting photo permissions."
                    self.showAlert = true
                }
            }
        }
    }

    private func performSave(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if success {
                    self.isSuccess = true
                    self.alertMessage = "Artwork saved to Camera Roll successfully! ✨"
                    self.showAlert = true
                    HapticManager.shared.notification(type: .success)
                } else {
                    self.isSuccess = false
                    self.alertMessage = "Failed to save to Camera Roll: \(error?.localizedDescription ?? "Unknown error")"
                    self.showAlert = true
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
}
