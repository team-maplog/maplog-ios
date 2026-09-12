import Foundation
import XCTest
@testable import Maplog

final class TourismResponseCacheTests: XCTestCase {
    func testTenRepeatedRequestsUseOneLoadUntilExpiry() async throws {
        let clock = CacheClock()
        let counter = CacheCounter()
        let cache = TourismResponseCache<String, Int>(capacity: 2, now: { clock.now })
        for _ in 0..<10 {
            let value = try await cache.value(for: "page", policy: .cached) { await counter.next() }
            XCTAssertEqual(value, 1)
        }
        clock.advance(599)
        let fresh = try await cache.value(for: "page", policy: .cached) { await counter.next() }
        XCTAssertEqual(fresh, 1)
        clock.advance(1)
        let expired = try await cache.value(for: "page", policy: .cached) { await counter.next() }
        XCTAssertEqual(expired, 2)
    }

    func testConcurrentRequestsSharePendingLoad() async throws {
        let cache = TourismResponseCache<String, Int>(capacity: 2)
        let counter = CacheCounter()
        let gate = CacheGate()
        let started = expectation(description: "shared loader started")
        let tasks = (0..<10).map { _ in Task {
            try await cache.value(for: "page", policy: .cached) {
                let value = await counter.next()
                started.fulfill()
                await gate.wait()
                return value
            }
        } }
        await fulfillment(of: [started], timeout: 2)
        await gate.open()
        for task in tasks { let value = try await task.value; XCTAssertEqual(value, 1) }
        let calls = await counter.count
        XCTAssertEqual(calls, 1)
    }

    func testReloadReplacesFreshValue() async throws {
        let cache = TourismResponseCache<String, Int>(capacity: 2)
        _ = try await cache.value(for: "page", policy: .cached) { 1 }
        let reloaded = try await cache.value(for: "page", policy: .reload) { 2 }
        let cached = try await cache.value(for: "page", policy: .cached) { 3 }
        XCTAssertEqual(reloaded, 2)
        XCTAssertEqual(cached, 2)
    }

    func testFailureIsNotCachedAndFailedReloadDoesNotExtendLifetime() async throws {
        let clock = CacheClock()
        let cache = TourismResponseCache<String, Int>(capacity: 2, now: { clock.now })
        do {
            _ = try await cache.value(for: "page", policy: .cached) { throw CacheTestError.failed }
            XCTFail("Failure must propagate")
        } catch CacheTestError.failed { }
        let recovered = try await cache.value(for: "page", policy: .cached) { 1 }
        XCTAssertEqual(recovered, 1)
        clock.advance(599)
        do {
            _ = try await cache.value(for: "page", policy: .reload) { throw CacheTestError.failed }
            XCTFail("Refresh failure must propagate")
        } catch CacheTestError.failed { }
        let retained = try await cache.value(for: "page", policy: .cached) { 2 }
        XCTAssertEqual(retained, 1)
        clock.advance(1)
        let expired = await cache.hasFreshValue(for: "page")
        XCTAssertFalse(expired)
    }

    func testKoreanMidnightInvalidatesFreshEntry() async throws {
        let clock = CacheClock(date: ISO8601DateFormatter().date(from: "2026-09-12T14:59:59Z")!)
        let cache = TourismResponseCache<String, Int>(capacity: 2, now: { clock.now })
        _ = try await cache.value(for: "page", policy: .cached) { 1 }
        clock.advance(2)
        let value = try await cache.value(for: "page", policy: .cached) { 2 }
        XCTAssertEqual(value, 2)
    }

    func testCapacityEvictsOldestEntry() async throws {
        let clock = CacheClock()
        let cache = TourismResponseCache<String, Int>(capacity: 2, now: { clock.now })
        for key in ["a", "b", "c"] {
            _ = try await cache.value(for: key, policy: .cached) { 1 }
            clock.advance(1)
        }
        let oldest = await cache.hasFreshValue(for: "a")
        let latest = await cache.hasFreshValue(for: "c")
        XCTAssertFalse(oldest)
        XCTAssertTrue(latest)
    }

    func testInvalidationPreventsLateRequestFromRepopulatingCache() async throws {
        for invalidateAll in [true, false] {
            let cache = TourismResponseCache<String, Int>(capacity: 2)
            let gate = CacheGate()
            let started = expectation(description: "loader started")
            let task = Task {
                try await cache.value(for: "page", policy: .cached) {
                    started.fulfill()
                    await gate.wait() // Simulates a loader that does not cooperate with cancellation.
                    return 1
                }
            }
            await fulfillment(of: [started], timeout: 2)
            if invalidateAll { await cache.invalidate() }
            else { await cache.invalidate { $0 == "page" } }
            let new = try await cache.value(for: "page", policy: .cached) { 2 }
            XCTAssertEqual(new, 2)
            await gate.open()
            do { _ = try await task.value; XCTFail("Invalidated result must not escape") }
            catch TourismRepositoryError.requestInvalidated { }
            let current = try await cache.value(for: "page", policy: .cached) { 3 }
            XCTAssertEqual(current, 2)
        }
    }

    func testCancellingOneWaiterDoesNotCancelSharedLoad() async throws {
        let cache = TourismResponseCache<String, Int>(capacity: 2)
        let gate = CacheGate()
        let started = expectation(description: "loader started")
        let first = Task {
            try await cache.value(for: "page", policy: .cached) {
                started.fulfill()
                await gate.wait()
                return 1
            }
        }
        await fulfillment(of: [started], timeout: 2)
        first.cancel()
        let second = Task { try await cache.value(for: "page", policy: .cached) { 99 } }
        await gate.open()
        do { _ = try await first.value; XCTFail("Cancelled waiter must throw") }
        catch is CancellationError { }
        let value = try await second.value
        XCTAssertEqual(value, 1)
    }
}

private enum CacheTestError: Error { case failed }
private actor CacheCounter {
    private(set) var count = 0
    func next() -> Int { count += 1; return count }
}
private actor CacheGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
private final class CacheClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(date: Date = Date(timeIntervalSince1970: 1_789_200_000)) { self.date = date }
    var now: Date { lock.lock(); defer { lock.unlock() }; return date }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; date.addTimeInterval(seconds) }
}
