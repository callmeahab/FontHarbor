// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

actor PreviewDownloadQueue {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var availablePermits: Int
    private var waiters: [Waiter] = []

    init(maxConcurrent: Int) {
        precondition(maxConcurrent > 0)
        availablePermits = maxConcurrent
    }

    func acquire() async throws {
        try Task.checkCancellation()
        if availablePermits > 0 {
            availablePermits -= 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
        // Cancellation can race with a released permit; return that permit before throwing.
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    func release() {
        if !waiters.isEmpty {
            waiters.removeFirst().continuation.resume()
        } else {
            availablePermits += 1
        }
    }

    private func cancel(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
