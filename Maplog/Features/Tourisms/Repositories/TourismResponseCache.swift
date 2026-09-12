import Foundation

/// 관광 목록·상세의 정상 응답만 보관합니다. 이미지와 디스크 파일은 저장하지 않습니다.
actor TourismResponseCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private struct Request {
        let id: UUID
        let task: Task<Value, Error>
    }

    private let lifetime: TimeInterval
    private let capacity: Int
    private let now: @Sendable () -> Date
    private var entries: [Key: Entry] = [:]
    private var requests: [Key: Request] = [:]
    private var revision = UUID()
    private var day: Date?
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    init(lifetime: TimeInterval = 600, capacity: Int, now: @escaping @Sendable () -> Date = { Date() }) {
        precondition(lifetime > 0 && capacity > 0)
        self.lifetime = lifetime
        self.capacity = capacity
        self.now = now
    }

    func hasFreshValue(for key: Key) -> Bool {
        discardExpiredEntries()
        return entries[key] != nil
    }

    func value(
        for key: Key,
        policy: TourismFetchPolicy,
        load: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        discardExpiredEntries()
        if policy == .cached, let entry = entries[key] { return entry.value }

        let request: Request
        if let pending = requests[key] {
            // 새로고침도 이미 진행 중인 같은 요청은 공유합니다.
            request = pending
        } else {
            request = Request(id: UUID(), task: Task {
                let value = try await load()
                try Task.checkCancellation()
                return value
            })
            requests[key] = request
        }
        let requestedRevision = revision

        do {
            let value = try await request.task.value
            guard revision == requestedRevision, !request.task.isCancelled else { throw CancellationError() }
            if requests[key]?.id == request.id {
                requests[key] = nil
                entries[key] = Entry(value: value, storedAt: now())
                if entries.count > capacity,
                   let oldest = entries.min(by: { $0.value.storedAt < $1.value.storedAt })?.key {
                    entries[oldest] = nil
                }
            }
            // 한 화면의 취소가 다른 화면이 기다리는 공용 요청을 취소하지 않도록 합니다.
            try Task.checkCancellation()
            return value
        } catch {
            if requests[key]?.id == request.id { requests[key] = nil }
            try Task.checkCancellation()
            // 캐시 무효화는 화면 이탈과 다릅니다. 화면에 재시도 가능한 오류를 전달합니다.
            if revision != requestedRevision || request.task.isCancelled {
                throw TourismRepositoryError.requestInvalidated
            }
            throw error
        }
    }

    func invalidate() {
        revision = UUID()
        entries.removeAll()
        requests.values.forEach { $0.task.cancel() }
        requests.removeAll()
    }

    /// 새 첫 페이지와 오래된 다음 페이지를 섞지 않습니다.
    func invalidate(where matches: @Sendable (Key) -> Bool) {
        for key in entries.keys.filter(matches) { entries[key] = nil }
        for key in requests.keys.filter(matches) {
            requests[key]?.task.cancel()
            requests[key] = nil
        }
    }

    private func discardExpiredEntries() {
        let instant = now()
        let currentDay = calendar.startOfDay(for: instant)
        if let day, day != currentDay { invalidate() }
        day = currentDay
        entries = entries.filter {
            let age = instant.timeIntervalSince($0.value.storedAt)
            return age >= 0 && age < lifetime
        }
    }
}
