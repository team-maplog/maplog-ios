import Foundation

/// 게시글 본문에 쓴 `#해시태그`를 로그 생성 API의 `tags` 계약으로 바꿉니다.
/// 화면은 본문 텍스트만 관리하고, `#` 제거·중복 제거·제한 검사는 이 모델이 맡습니다.
struct LogCustomTagParseResult: Equatable, Sendable {
    let tags: [String]
    let containsOverLengthTag: Bool

    var validationMessage: String? {
        if containsOverLengthTag {
            return "해시태그는 30자 이내로 입력해 주세요."
        }

        if tags.count > LogCustomTagParser.maximumTagCount {
            return "해시태그는 최대 \(LogCustomTagParser.maximumTagCount)개까지 입력할 수 있어요."
        }

        return nil
    }
}

enum LogCustomTagParser {
    static let maximumTagCount = 10
    static let maximumTagLength = 30

    static func parse(
        caption: String
    ) -> LogCustomTagParseResult {
        let candidates = hashtagCandidates(in: caption)

        var uniqueTags: [String] = []
        var seenTags = Set<String>()
        var containsOverLengthTag = false

        for candidate in candidates {
            if candidate.tag.count > maximumTagLength {
                containsOverLengthTag = true
                continue
            }

            if seenTags.insert(candidate.tag).inserted {
                uniqueTags.append(candidate.tag)
            }
        }

        return LogCustomTagParseResult(
            tags: uniqueTags,
            containsOverLengthTag: containsOverLengthTag
        )
    }

    /// 입력창에서도 parser와 동일한 기준으로 해시태그만 색칠할 수 있게
    /// `#`을 포함한 문자열 범위를 제공합니다.
    static func hashtagRanges(
        in caption: String
    ) -> [NSRange] {
        hashtagCandidates(in: caption).map(\.range)
    }

    private static func hashtagCandidates(
        in caption: String
    ) -> [HashtagCandidate] {
        var candidates: [HashtagCandidate] = []
        var currentTag = ""
        var isReadingTag = false
        var tagStartIndex: String.Index?

        func appendCurrentTag(
            endingAt endIndex: String.Index
        ) {
            guard
                !currentTag.isEmpty,
                let currentTagStartIndex = tagStartIndex
            else {
                return
            }

            candidates.append(
                HashtagCandidate(
                    tag: currentTag,
                    range: NSRange(
                        currentTagStartIndex..<endIndex,
                        in: caption
                    )
                )
            )
            currentTag = ""
            tagStartIndex = nil
        }

        for index in caption.indices {
            let character = caption[index]

            if character == "#" {
                if isReadingTag {
                    appendCurrentTag(endingAt: index)
                }

                isReadingTag = true
                tagStartIndex = index
                continue
            }

            guard isReadingTag else {
                continue
            }

            if isHashtagCharacter(character) {
                currentTag.append(character)
            } else {
                appendCurrentTag(endingAt: index)
                isReadingTag = false
                tagStartIndex = nil
            }
        }

        if isReadingTag {
            appendCurrentTag(endingAt: caption.endIndex)
        }

        return candidates
    }

    private static func isHashtagCharacter(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar.value == 95 // _
        }
    }
}

private struct HashtagCandidate {
    let tag: String
    let range: NSRange
}
