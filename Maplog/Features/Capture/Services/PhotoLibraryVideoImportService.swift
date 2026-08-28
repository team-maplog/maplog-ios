//
//  PhotoLibraryVideoImportService.swift
//  Maplog
//

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

protocol PhotoLibraryVideoImporting: Sendable {
    func makeDraftInputs(
        from items: [PhotosPickerItem]
    ) async throws -> [CaptureDraftClipInput]
}

enum PhotoLibraryVideoImportError: LocalizedError {
    case noVideoSelected
    case unsupportedVideo
    case unableToReadDuration

    var errorDescription: String? {
        switch self {
        case .noVideoSelected:
            return "가져올 영상을 선택해 주세요."
        case .unsupportedVideo:
            return "이 영상을 가져오지 못했어요. 다른 영상을 선택해 주세요."
        case .unableToReadDuration:
            return "영상 길이를 확인하지 못했어요."
        }
    }
}

actor PhotoLibraryVideoImportService: PhotoLibraryVideoImporting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeDraftInputs(
        from items: [PhotosPickerItem]
    ) async throws -> [CaptureDraftClipInput] {
        guard !items.isEmpty else {
            throw PhotoLibraryVideoImportError.noVideoSelected
        }

        var inputs: [CaptureDraftClipInput] = []

        for item in items {
            guard let importedVideo = try await item.loadTransferable(
                type: ImportedVideoFile.self
            ) else {
                throw PhotoLibraryVideoImportError.unsupportedVideo
            }

            let asset = AVURLAsset(url: importedVideo.fileURL)
            let duration = try await asset.load(.duration)

            guard duration.seconds.isFinite, duration.seconds > 0 else {
                try? fileManager.removeItem(at: importedVideo.fileURL)
                throw PhotoLibraryVideoImportError.unableToReadDuration
            }

            inputs.append(
                CaptureDraftClipInput(
                    temporaryFileURL: importedVideo.fileURL,
                    mediaType: .video,
                    capturedAt: Date(),
                    duration: duration.seconds,
                    location: nil,
                    timestampStyle: .none
                )
            )
        }

        return inputs
    }
}

private struct ImportedVideoFile: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let sourceURL = received.file
            let fileExtension = sourceURL.pathExtension.isEmpty
                ? "mov"
                : sourceURL.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            try FileManager.default.copyItem(
                at: sourceURL,
                to: destinationURL
            )

            return ImportedVideoFile(fileURL: destinationURL)
        }
    }
}
