import Foundation
import os

/// Runs synchronous work that may block for a long time (Apple Events, SQLite, cold file opens)
/// on a dedicated thread, so the Swift concurrency cooperative pool keeps making progress.
///
/// Cancelling the awaiting task flips the `isCancelled` flag handed to the work. That cannot
/// interrupt a blocked system call, but work that polls the flag stops at its next check and the
/// caller discards whatever a cancelled call eventually returns.
struct BlockingQueue: Sendable {
    private let queue: DispatchQueue

    init(label: String, qos: DispatchQoS) {
        queue = DispatchQueue(label: label, qos: qos)
    }

    func run<T: Sendable>(
        _ work: @escaping @Sendable (_ isCancelled: @escaping @Sendable () -> Bool) throws -> T
    ) async throws -> T {
        let cancelled = OSAllocatedUnfairLock(initialState: false)
        let isCancelled: @Sendable () -> Bool = { cancelled.withLock { $0 } }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    continuation.resume(with: Result { try work(isCancelled) })
                }
            }
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
    }
}
