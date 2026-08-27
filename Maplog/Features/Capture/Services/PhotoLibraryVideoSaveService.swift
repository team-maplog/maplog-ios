//
//  PhotoLibraryVideoSaveService.swift
//  Maplog
//

import Foundation
import Photos

protocol PhotoLibraryVideoSaving: Sendable {
    func saveVideo(at fileURL: URL) async throws
}

enum PhotoLibraryVideoSaveError: LocalizedError {
    case sourceFileNotFound
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound:
            return "저장할 완성 영상을 찾지 못했어요."
        case .permissionDenied:
            return "사진 앱에 저장하려면 사진 추가 권한이 필요해요."
        case .saveFailed:
            return "사진 앱에 영상을 저장하지 못했어요."
        }
    }
}

actor PhotoLibraryVideoSaveService: PhotoLibraryVideoSaving {
    private let photoLibrary: PHPhotoLibrary
    private let fileManager: FileManager

    init(
        photoLibrary: PHPhotoLibrary = .shared(),
        fileManager: FileManager = .default
    ) {
        self.photoLibrary = photoLibrary
        self.fileManager = fileManager
    }

    func saveVideo(at fileURL: URL) async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PhotoLibraryVideoSaveError.sourceFileNotFound
        }

        let authorizationStatus = await requestAddOnlyAuthorization()

        guard authorizationStatus == .authorized
            || authorizationStatus == .limited
        else {
            throw PhotoLibraryVideoSaveError.permissionDenied
        }

        do {
            try await photoLibrary.performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(
                    atFileURL: fileURL
                )
            }
        } catch {
            throw PhotoLibraryVideoSaveError.saveFailed
        }
    }

    private func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(
            for: .addOnly
        )

        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
