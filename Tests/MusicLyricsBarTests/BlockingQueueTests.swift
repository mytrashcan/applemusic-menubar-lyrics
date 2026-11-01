import Foundation
import Testing
@testable import MusicLyricsBar

struct BlockingQueueTests {
    @Test func returnsResultsAndRethrowsErrors() async throws {
        let queue = BlockingQueue(label: "test", qos: .utility)
        #expect(try await queue.run { _ in 21 * 2 } == 42)
        await #expect(throws: CocoaError.self) {
            try await queue.run { _ in throw CocoaError(.fileNoSuchFile) }
        }
    }

    @Test func cancellationReachesRunningWorkAndSkipsUnstartedWork() async throws {
        let queue = BlockingQueue(label: "test", qos: .utility)
        let started = Semaphore()
        let task = Task {
            try await queue.run { isCancelled in
                started.signal()
                while !isCancelled() { Thread.sleep(forTimeInterval: 0.005) }
                return "stopped"
            }
        }
        await started.wait()
        task.cancel()
        #expect(try await task.value == "stopped")
        let unstarted = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await queue.run { _ in "never" }
        }
        unstarted.cancel()
        await #expect(throws: CancellationError.self) { try await unstarted.value }
    }
}

/// Minimal async signal for tests: the worker thread signals, the test awaits.
private final class Semaphore: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func signal() { semaphore.signal() }
    func wait() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { self.semaphore.wait(); continuation.resume() }
        }
    }
}
