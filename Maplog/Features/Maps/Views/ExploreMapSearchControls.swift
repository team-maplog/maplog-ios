//
//  ExploreMapSearchControls.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import SwiftUI

struct ExploreMapSearchControls: View {
    @Binding private var query: String
    @FocusState.Binding private var isSearchFieldFocused: Bool

    private let selectedScope: ExploreMapSearchScope
    private let markerCount: (ExploreMapSearchScope) -> Int
    private let onSelectScope: (ExploreMapSearchScope) -> Void
    private let onClearSearch: () -> Void

    init(
        query: Binding<String>,
        isSearchFieldFocused: FocusState<Bool>.Binding,
        selectedScope: ExploreMapSearchScope,
        markerCount: @escaping (ExploreMapSearchScope) -> Int,
        onSelectScope: @escaping (ExploreMapSearchScope) -> Void,
        onClearSearch: @escaping () -> Void
    ) {
        _query = query
        _isSearchFieldFocused = isSearchFieldFocused
        self.selectedScope = selectedScope
        self.markerCount = markerCount
        self.onSelectScope = onSelectScope
        self.onClearSearch = onClearSearch
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.maplogMuted)

                TextField(
                    "이 지도에서 장소·맵로그 검색",
                    text: $query
                )
                .font(.subheadline)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)

                if !query.isEmpty {
                    Button(
                        action: onClearSearch
                    ) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.maplogMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                .regularMaterial,
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 8) {
                    ForEach(ExploreMapSearchScope.allCases) {
                        scope in
                        ExploreMapSearchScopeChip(
                            title: scope.title,
                            count: markerCount(scope),
                            isSelected: selectedScope == scope
                        ) {
                            onSelectScope(scope)
                        }
                    }
                }
            }
        }
    }
}

private struct ExploreMapSearchScopeChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(
            action: action
        ) {
            Text("\(title) \(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.maplogInk
                        : Color.maplogMuted
                )
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    isSelected
                        ? Color.maplogLime
                        : Color.white.opacity(0.92),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(count)개")
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
    }
}
