import Foundation
import UniformTypeIdentifiers

protocol LogVideoUploadFileBuilding: Sendable {
    func makeMultipartFile(from videoURL: URL, boundary: String) async throws -> URL
}

/// 영상 본문은 작은 청크로 디스크에 기록한다. 큰 파일의 전체 Data를 만들지 않는다.
actor LogVideoUploadFileBuilder: LogVideoUploadFileBuilding {
    private let temporaryDirectory: URL
    private let fileManager: FileManager

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory,
         fileManager: FileManager = .default) {
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
    }

    func makeMultipartFile(from videoURL: URL, boundary: String) async throws -> URL {
        try Task.checkCancellation()
        let input = try FileHandle(forReadingFrom: videoURL)
        defer { try? input.close() }
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let bodyURL = temporaryDirectory.appendingPathComponent("maplog-upload-\(UUID().uuidString).multipart")
        guard fileManager.createFile(atPath: bodyURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        do {
            let output = try FileHandle(forWritingTo: bodyURL)
            defer { try? output.close() }
            // 파일명은 multipart 헤더의 따옴표·줄 경계를 바꾸지 못하게 한다.
            let filename = videoURL.lastPathComponent
                .replacingOccurrences(of: "\r", with: "_")
                .replacingOccurrences(of: "\n", with: "_")
                .replacingOccurrences(of: "\"", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
            let mimeType = UTType(filenameExtension: videoURL.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            let header = "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
                + "Content-Type: \(mimeType)\r\n\r\n"
            try output.write(contentsOf: Data(header.utf8))
            while true {
                try Task.checkCancellation()
                guard let chunk = try input.read(upToCount: 64 * 1_024), !chunk.isEmpty else { break }
                try output.write(contentsOf: chunk)
            }
            try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
            try Task.checkCancellation()
            return bodyURL
        } catch {
            try? fileManager.removeItem(at: bodyURL)
            throw error
        }
    }
}
