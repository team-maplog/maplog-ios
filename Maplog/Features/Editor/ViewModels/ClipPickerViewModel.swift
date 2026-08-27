//
//  ClipPickerViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
// CameraCaptureViewModel  → 촬영·저장 담당
// ClipPickerViewModel     → 저장된 초안 목록 조회·선택 담당
// 저장된 영상 정보를 화면에 표시 가능한 정보로 번역하는 중간 관리자라고 생각

import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class ClipPickerViewModel: ObservableObject {
    @Published private(set) var state: ClipPickerState = .loading
    @Published private(set) var items: [ClipPickerItemViewData] = []
    @Published private(set) var selectedClipIDs: [UUID] = []
    @Published private(set) var isDeleting = false
    @Published private(set) var isImporting = false
    @Published private(set) var actionError: ErrorPresentation?
    @Published private(set) var compositionConfiguration: VideoCompositionConfiguration
    
    var selectedCount: Int {
        selectedClipIDs.count
    }
    
    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let photoLibraryVideoImportService: any PhotoLibraryVideoImporting
    private var draftsByID: [UUID: CaptureDraftClip] = [:]
//    클립 id
//    → 실제 영상 파일 URL·촬영 날짜·길이를 가진 CaptureDraftClip
    // [클립 id: 실제 클립 정보]
    
    private let initialSelectedClipIDs: [UUID]
    
    
    private let capturedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter
    }()
    
    init(
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        photoLibraryVideoImportService: any PhotoLibraryVideoImporting,
        initialSelectedClipIDs: [UUID] = [],
        initialCompositionConfiguration: VideoCompositionConfiguration = .init()
    ) {
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.photoLibraryVideoImportService = photoLibraryVideoImportService
        self.initialSelectedClipIDs = initialSelectedClipIDs
        self.compositionConfiguration = initialCompositionConfiguration
    }
    
    
//    1. 저장된 전체 클립 조회
//    2. 이전 편집 순서 [A, B, C]를 받음
//    3. 실제로 아직 존재하는 ID만 골라 [A, B, C] 선택 상태 복원
//    4. 화면에는 전체 클립을 표시
//    5. 썸네일 비동기 로드
    func load() async {
        state = .loading
        items = []
        selectedClipIDs = []
        draftsByID = [:]

        do {
            let fetchedDrafts = try await mediaDraftRepository
                .fetchDrafts()

            guard !Task.isCancelled else {
                return
            }

            let fetchedDraftIDs = Set(
                fetchedDrafts.map(\.id)
            )

            selectedClipIDs = initialSelectedClipIDs.filter {
                fetchedDraftIDs.contains($0)
            }

            for draft in fetchedDrafts {
                draftsByID[draft.id] = draft
            }

            items = fetchedDrafts.map { draft in
                makeItemViewData(from: draft)
            }

            state = items.isEmpty ? .empty : .content

            await loadThumbnails(for: fetchedDrafts)
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(
                ClipPickerErrorPolicy.presentation(for: error)
            )
        }
    }
    
    private func makeItemViewData(from draft: CaptureDraftClip) -> ClipPickerItemViewData {
        ClipPickerItemViewData(
                id: draft.id,
                thumbnailData: nil,
                capturedAtText: capturedAtFormatter.string(
                    from: draft.capturedAt
                ),
                durationText: durationText(for: draft)
            )
    }
    
    private func durationText(for draft: CaptureDraftClip) -> String {
        guard
            draft.mediaType == .video,
            let duration = draft.duration
        else {
            return "사진"
        }

        return "\(max(1, Int(duration.rounded())))s"
    }
    
    private func loadThumbnails(for drafts: [CaptureDraftClip]) async {
        for draft in drafts where draft.mediaType == .video {
            let thumbnailData = try? await videoThumbnailService
                .makeThumbnailData(for: draft.fileURL)
            
            guard !Task.isCancelled else {
                return
            }
            
            guard let index = items.firstIndex(where: { $0.id == draft.id }
            ) else {
                continue
            }
            
            items[index].thumbnailData = thumbnailData
        }
    }
    
    func retry() async {
        await load()
    }
    
    func toggleSelection(for id: UUID) {
        guard items.contains(where: { $0.id == id }) else {
            return
        }
        
//        A 탭 → [A]       → A에 1 표시
//        B 탭 → [A, B]    → A에 1, B에 2 표시
//        A 재탭 → [B]     → B가 1로 변경
        if let index = selectedClipIDs.firstIndex(of: id) { // firstIndex: 내가 찾는 값이 배열의 몇 번째 칸에 있는지
            selectedClipIDs.remove(at: index)
        } else if let maximumClipCount = compositionConfiguration.layout.maximumClipCount,
                  selectedClipIDs.count >= maximumClipCount {
            actionError = ErrorPresentation(
                message: "(compositionConfiguration.layout.title)은 클립 \(maximumClipCount)개로 만들 수 있어요.",
                recoveryAction: .none
            )
        } else {
            selectedClipIDs.append(id)
        }
    }

    func selectCompositionLayout(_ layout: VideoCompositionLayout) {
        compositionConfiguration.layout = layout

        if let maximumClipCount = layout.maximumClipCount,
           selectedClipIDs.count > maximumClipCount {
            selectedClipIDs = Array(selectedClipIDs.prefix(maximumClipCount))
        }
    }

    func selectSplitDirection(_ direction: VideoSplitDirection) {
        compositionConfiguration.splitDirection = direction
    }

    var hasValidCompositionSelection: Bool {
        switch compositionConfiguration.layout {
        case .single:
            return !selectedClipIDs.isEmpty
        case .splitTwo, .splitThree:
            return selectedClipIDs.count == compositionConfiguration.requiredClipCount
        }
    }

    func importVideos(
        from items: [PhotosPickerItem]
    ) async {
        guard !items.isEmpty, !isImporting else {
            return
        }

        isImporting = true
        actionError = nil

        defer {
            isImporting = false
        }

        do {
            let inputs = try await photoLibraryVideoImportService.makeDraftInputs(
                from: items
            )

            for input in inputs {
                _ = try await mediaDraftRepository.saveDraft(from: input)
            }

            await load()
        } catch is CancellationError {
            return
        } catch {
            actionError = ErrorPresentation(
                message: "갤러리 영상을 가져오지 못했어요. 다시 시도해 주세요.",
                recoveryAction: .retry
            )
        }
    }
    
    func selectionOrder(for id: UUID) -> Int? {
        guard let index = selectedClipIDs.firstIndex(of: id) else {
            return nil
        }
        
        return index + 1
    }
    
    // 순서가 반영된 실제 선택 클립만 돌려줌
    func selectedDrafts() -> [CaptureDraftClip] {
        selectedClipIDs.compactMap { selectedID in
            draftsByID[selectedID]
        }
    }
    
    func deleteSelectedDrafts() async {
        let idsToDelete = Set(selectedClipIDs) // 선택된 ID를 중복 없이 묶어둔 목록
        
        guard !idsToDelete.isEmpty, !isDeleting else {
            return
        }
        
        isDeleting = true
        actionError = nil
        
        defer {
            isDeleting = false
        }
        
        do {
            for id in idsToDelete {
                try await mediaDraftRepository.deleteDraft(id: id)
            }
            
            items.removeAll() { idsToDelete.contains($0.id)}
            
            for id in idsToDelete {
                draftsByID[id] = nil
            }
            
            selectedClipIDs.removeAll()
            state = items.isEmpty ? .empty : .content
        } catch {
            await load()
            actionError = ClipPickerErrorPolicy.deletionPresentation(for: error)
        }
    }
    
    func dismissActionError() {
        actionError = nil
    }
}


 
