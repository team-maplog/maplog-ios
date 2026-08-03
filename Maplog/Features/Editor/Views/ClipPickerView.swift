//
//  ClipPickerView.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//
//ClipPickerFeatureView
//  └─ @StateObject로 ViewModel 생성·소유
//       └─ ClipPickerView
//            └─ .task에서 load()
//                 └─ Repository가 저장 초안 목록 반환
//                      └─ loading / content / empty / failed 화면 갱신


import SwiftUI

struct ClipPickerView: View {
    @ObservedObject var viewModel: ClipPickerViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isDeleteConfirmationPresented = false
    
    let allowsPermanentDeletion: Bool
    let confirmationTitle: (Int) -> String // 하단 버튼 문구를 상황에 따라 바꿈
    let onConfirmSelection: ([CaptureDraftClip]) -> Void // 선택 결과를 Feature에 전달하는 통로
    
    
    private let gridColumns = Array(
        repeating: GridItem(
            .flexible(),
            spacing: MaplogSpacing.xSmall),
        count: 3
    )
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("클립 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("클립 선택 닫기")
                    }
                    if allowsPermanentDeletion {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .destructive) {
                                isDeleteConfirmationPresented = true
                            } label: {
                                if viewModel.isDeleting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "trash")
                                }
                            }
                            .disabled(
                                viewModel.selectedCount == 0
                                || viewModel.isDeleting
                            )
                            .accessibilityLabel("선택한 클립 삭제")
                        }
                    }
                }
        }
        .confirmationDialog(
            "선택한 \(viewModel.selectedCount)개 클립을 삭제할까요?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedDrafts()
                }
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 클립은 복구할 수 없어요.")
        }
        .alert(
            "삭제하지 못했어요",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissActionError()
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.dismissActionError()
            }
        } message: {
            Text(viewModel.actionError?.message ?? "")
        }
        .task {
            await viewModel.load()
        }
    }
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("클립을 불러오는 중이에요")
            
        case .content:
            ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: MaplogSpacing.section
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: MaplogSpacing.xxSmall
                        ) {
                            Text(
                                viewModel.selectedCount == 0
                                ? "편집할 클립을 선택해 주세요"
                                : "\(viewModel.selectedCount)개 선택됨"
                            )
                            .font(MaplogFont.screenTitle)

                            Text("선택한 순서대로 영상을 이어 붙여요.")
                                .font(MaplogFont.callout)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(
                            columns: gridColumns,
                            spacing: MaplogSpacing.small
                        ) {
                            ForEach(viewModel.items) { item in
                                let selectionOrder = viewModel.selectionOrder(
                                    for: item.id
                                )

                                Button {
                                    viewModel.toggleSelection(for: item.id)
                                } label: {
                                    ClipPickerGridItemView(
                                        item: item,
                                        selectionOrder: selectionOrder
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "\(item.capturedAtText) 촬영 클립"
                                )
                                .accessibilityValue(
                                    selectionOrder.map {
                                        "\($0)번째로 선택됨"
                                    } ?? "선택되지 않음"
                                )
                            }
                        }
                    }
                    .padding(MaplogSpacing.page)
                }
            .safeAreaInset(edge: .bottom) {
                editorStartButton
            }
            
        case .empty:
            VStack(spacing: MaplogSpacing.medium) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.maplogLime)
                
                Text("저장한 클립이 없어요")
                    .font(.headline)
                
                Text("카메라에서 영상을 촬영하면\n이곳에서 이어 붙여 편집할 수 있어요.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
        case .failed(let presentation):
            VStack(spacing: MaplogSpacing.medium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                
                Text(presentation.message)
                    .multilineTextAlignment(.center)
                
                if presentation.recoveryAction == .retry {
                    Button("다시 시도") {
                        Task {
                            await viewModel.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(MaplogSpacing.xLarge)
        }
    }
    
    private var editorStartButton: some View {
        Button {
            let selectedDrafts = viewModel.selectedDrafts()

            guard !selectedDrafts.isEmpty else {
                return
            }

            onConfirmSelection(selectedDrafts)
        } label: {
            Text(
                        viewModel.selectedCount == 0
                        ? "편집할 클립을 선택해 주세요"
                        : confirmationTitle(viewModel.selectedCount)
                    )
                    .font(MaplogFont.button)
                    .foregroundStyle(
                        viewModel.selectedCount == 0
                        ? Color.maplogTextSecondary
                        : Color.maplogInk
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: MaplogSize.primaryButtonHeight)
                    .background(
                        viewModel.selectedCount == 0
                        ? Color.maplogSurfaceRaised
                        : Color.maplogLime,
                        in: Capsule()
                    )
        }
        .disabled(viewModel.selectedCount == 0)
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.vertical, MaplogSpacing.small)
        .background(.ultraThinMaterial)
    }
}
