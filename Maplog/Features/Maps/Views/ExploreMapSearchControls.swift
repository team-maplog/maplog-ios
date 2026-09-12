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

    private let selectedFilter: ExploreMapFilter
    private let onSelectFilter: (ExploreMapFilter) -> Void
    private let onClearSearch: () -> Void

    init(
        query: Binding<String>,
        isSearchFieldFocused: FocusState<Bool>.Binding,
        selectedFilter: ExploreMapFilter,
        onSelectFilter: @escaping (ExploreMapFilter) -> Void,
        onClearSearch: @escaping () -> Void
    ) {
        _query = query
        _isSearchFieldFocused = isSearchFieldFocused
        self.selectedFilter = selectedFilter
        self.onSelectFilter = onSelectFilter
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
                    ForEach(ExploreMapFilter.allCases) { filter in
                        ExploreMapFilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            onSelectFilter(filter)
                        }
                    }
                }
            }
        }
    }
}

private struct ExploreMapFilterChip: View {
    let filter: ExploreMapFilter
    let isSelected: Bool
    let action: () -> Void

    private var iconName: String {
        switch filter {
        case .all:
            return "square.grid.2x2.fill"
        case .maplog:
            return "play.rectangle.fill"
        default:
            return TourismMapMarkerAppearance.style(
                for: filter.tourismRequestCategory
            )
            .symbolName
        }
    }

    private var tint: Color {
        switch filter {
        case .all:
            return Color.maplogTextPrimary
        case .maplog:
            return Color(uiColor: TourismMapMarkerAppearance.style(for: .natureTourism).color)
        default:
            return Color(
                uiColor: TourismMapMarkerAppearance.style(
                    for: filter.tourismRequestCategory
                )
                .color
            )
        }
    }

    var body: some View {
        Button(
            action: action
        ) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.caption2.weight(.bold))

                Text(filter.title)
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.maplogTextPrimary
                        : Color.maplogTextSecondary
                )
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    isSelected
                        ? Color.clear
                        : Color.white.opacity(0.92),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            tint.opacity(isSelected ? 1 : 0.22),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.title) 필터")
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
    }
}
