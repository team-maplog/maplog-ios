//
//  FileMediaDraftRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
// 카메라가 방금 만든 임시 영상 파일을, 앱이 나중에도 꺼내 쓸 수 있는 초안 파일로 옮기고 목록을 관리

//카메라가 만든 임시 파일
///tmp/recording.mov
//        ↓
//FileMediaDraftRepository
//        ↓
//Application Support/MediaDrafts/
//├── 1A2B3C.mov 실제 영상
//└── drafts.json 언제 찍었는지·몇 초인지·장소가 어디인지 같은 목록 정보


//CaptureDraftClip: 앱이 사용하는 Domain Model
//MediaDraftClipRecord: drafts.json에만 저장되는 내부 DTO
//.mov 파일: Application Support/MediaDrafts에 저장
//drafts.json: 파일 이름, 장소, 시간, 길이 등 클립 목록 정보 저장
//actor: 동시에 저장·삭제가 발생해도 파일 목록이 꼬이지 않도록 한 번에 하나씩 처리

//CaptureDraftClipInput은 카메라가 막 만든 임시 파일 정보다.
//FileMediaDraftRepository는 임시 영상을 앱 내부 폴더로 옮기고 목록도 저장한다.
//CaptureDraftClip은 저장이 끝나서 편집 화면이 사용할 결과물이다.



import Foundation

actor FileMediaDraftRepository: MediaDraftRepository {
    private let fileManager: FileManager // 폴더 생성, 파일 이동·삭제를 수행하는 Apple 도구
    private let storageDirectory: URL // 실제 영상들을 모아두는 폴더 주소
    private let indexFileURL: URL // 클립 목록 JSON 파일의 주소
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        storageDirectory = applicationSupportURL.appendingPathComponent("MediaDrafts", isDirectory: true) // Application Support는 앱 전용 저장 공간 .../Application Support/MediaDrafts/ 주소를 저장
        
        indexFileURL = storageDirectory.appendingPathComponent("drafts.json")
    }
    
    // 임시 파일을 초안으로 저장, 카메라 Service가 준 CaptureDraftClipInput을 받아서, 저장이 끝난 CaptureDraftClip을 돌려줌
    func saveDraft(from input: CaptureDraftClipInput) async throws -> CaptureDraftClip {
        guard fileManager.fileExists(atPath: input.temporaryFileURL.path) else { // 임시 파일이 실제 존재하는지 확인
            throw MediaDraftRepositoryError.sourceFileNotFound
        }
        try createStorageDirectoryIfNeeded() // 영상 폴더 생성
        
        let draftID = UUID() // 앱 내부용 고유 파일 이름 만들기 임시 파일: /tmp/recording.mov, 저장 파일: Application Support/MediaDrafts/A1B2.mov
        let destinationFileURL = makeDestinationFileURL(for: input, id: draftID)
        
        try fileManager.moveItem(at: input.temporaryFileURL, to: destinationFileURL) // 실제 영상 파일 이동
        
        let draft = CaptureDraftClip( // 앱이 사용하는 Domain Model, 방금 저장된 클립을 앱이 이해하는 CaptureDraftClip으로 표현
            id: draftID,
            mediaType: input.mediaType,
            fileURL: destinationFileURL,
            capturedAt: input.capturedAt,
            duration: input.duration,
            location: input.location,
            timestampStyle: input.timestampStyle
        )
        
        do { // 영상 목록 JSON에 정보 추가, 파일 목록도 함께 저장함(어떤 파일이 언제 찍힌 건지 알 수 없기 때문에)
            var records = try loadRecords()
            records.append(MediaDraftClipRecord(draft: draft))
            try writeRecords(records)
            
            return draft
        } catch { // do-catch는 JSON 저장 실패 시 방금 옮긴 영상 파일도 다시 지워서, 영상만 남고 목록에는 없는 고아 파일이 생기는 것을 줄이는 처리야.
            try? fileManager.removeItem(at: destinationFileURL)
            throw error
        }
    }
    
    // 편집 화면에서 클립 목록 조회
    func fetchDrafts() async throws -> [CaptureDraftClip] {
        try createStorageDirectoryIfNeeded()
        
        let records = try loadRecords()
        
        let availableRecords = records.filter { record in
            let fileURL = storageDirectory.appendingPathComponent(record.fileName)
            
            return fileManager.fileExists(atPath: fileURL.path)
        }
        
        if availableRecords.count != records.count {
            try writeRecords(availableRecords)
        }
        
        return try availableRecords
            .map { try $0.makeDraft(in: storageDirectory) }
            .sorted { $0.capturedAt > $1.capturedAt } // 최신 촬영순으로 정렬해 반환
    }
    
    // 영상과 목록을 함께 삭제
    func deleteDraft(id: UUID) async throws {
        try createStorageDirectoryIfNeeded()
        
        var records = try loadRecords()
        
        guard let index = records.firstIndex(where: { $0.id == id}) else {
            throw MediaDraftRepositoryError.draftNotFound
        }
        
        let record = records.remove(at: index)
        let fileURL = storageDirectory.appendingPathComponent(record.fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try writeRecords(records)
    }
    
    private func createStorageDirectoryIfNeeded() throws {
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
    
    private func loadRecords() throws -> [MediaDraftClipRecord] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: indexFileURL)
        
        return try JSONDecoder().decode([MediaDraftClipRecord].self, from: data)
    }

    private func writeRecords(_ records: [MediaDraftClipRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(records)
        
        try data.write(to: indexFileURL, options: .atomic)
    }
    
    private func makeDestinationFileURL(for input: CaptureDraftClipInput, id: UUID) -> URL {
        let fallbackExtension = input.mediaType == .video ? "mov" : "jpg"
        
        let fileExtension = input.temporaryFileURL.pathExtension.isEmpty ? fallbackExtension : input.temporaryFileURL.pathExtension
        
        return storageDirectory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension(fileExtension)
    }
}

private struct MediaDraftClipRecord: Codable { // drafts.json에만 저장되는 내부 DTO, 디스크에 JSON으로 저장하기 쉬운 형태
        let id: UUID
        let mediaType: String
        let fileName: String
        let capturedAt: Date
        let duration: TimeInterval?
        let latitude: Double?
        let longitude: Double?
        let placeName: String?
        let timestampStyle: String

    init(draft: CaptureDraftClip) {
        id = draft.id
        mediaType = draft.mediaType.rawValue
        fileName = draft.fileURL.lastPathComponent
        capturedAt = draft.capturedAt
        duration = draft.duration
        latitude = draft.location?.latitude
        longitude = draft.location?.longitude
        placeName = draft.location?.placeName
        timestampStyle = draft.timestampStyle.rawValue
    }
    
    func makeDraft(in storageDirectory: URL) throws -> CaptureDraftClip {
        guard
            let mediaType = CaptureMediaType(rawValue: mediaType),
            let timestampStyle = CaptureTimestampStyle(rawValue: timestampStyle)
        else {
            throw MediaDraftRepositoryError.invalidStoredRecord
        }
        let location: CaptureLocation?
        
        if let latitude, let longitude {
            location = CaptureLocation(latitude: latitude, longitude: longitude, placeName: placeName)
        } else {
            location = nil
        }
        
        return CaptureDraftClip( // 앱이 사용하는 Domain Model
            id: id,
            mediaType: mediaType,
            fileURL: storageDirectory.appendingPathComponent(fileName),
            capturedAt: capturedAt,
            duration: duration,
            location: location,
            timestampStyle: timestampStyle
        )
    }
}
