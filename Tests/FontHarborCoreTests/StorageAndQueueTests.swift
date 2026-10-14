// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing
@testable import FontHarborCore

@MainActor
struct StorageAndQueueTests {
    private func font(id: String) -> OpenFont {
        OpenFont(id: id, family: "Example", designer: "Example", category: .sansSerif, source: .community,
                 license: "Unknown", description: "", tags: [], downloadURL: URL(string: "https://example.com/Regular.ttf")!,
                 repositoryURL: URL(string: "https://example.com")!, fileName: "../../Regular.ttf")
    }

    @Test func filenamesCannotCollideOrEscapeStorage() {
        let first = FontFileIdentity.fileName(for: font(id: "A/B"))
        let second = FontFileIdentity.fileName(for: font(id: "A-B"))
        let third = FontFileIdentity.fileName(for: font(id: "a/b"))
        #expect(Set([first, second, third]).count == 3)
        #expect(!first.contains("/"))
        #expect(first.count == 68)
    }

    @Test func invalidFontFilesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let invalid = root.appending(path: "not-a-font.ttf")
        try Data("<html>upstream error</html>".utf8).write(to: invalid)
        #expect(throws: FontLibraryError.self) { try FontFileIdentity.validate(invalid) }
    }

    @Test func validCachedFontIsReusedByConcurrentConsumers() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let candidate = font(id: "cache-test")
        let cached = root.appendingPathComponent(FontFileIdentity.fileName(for: candidate))
        // Use an OS-provided font as a fixture; never redistribute proprietary font files.
        let systemFont = URL(filePath: "/System/Library/Fonts/Supplemental/Arial.ttf")
        try FileManager.default.copyItem(at: systemFont, to: cached)
        let store = FontDownloadStore(directory: root)
        async let first = store.url(for: candidate)
        async let second = store.url(for: candidate)
        let result = try await (first, second)
        #expect(result.0 == cached && result.1 == cached)
    }

    @Test func queueLimitsConcurrencyAndRecoversAfterCancellation() async throws {
        let queue = PreviewDownloadQueue(maxConcurrent: 2)
        let probe = ConcurrencyProbe()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 {
                group.addTask {
                    try await queue.acquire()
                    await probe.enter()
                    try await Task.sleep(for: .milliseconds(2))
                    await probe.leave()
                    await queue.release()
                }
            }
            try await group.waitForAll()
        }
        #expect(await probe.peak <= 2)
        try await queue.acquire()
        try await queue.acquire()
        let waiting = Task { try await queue.acquire() }
        await Task.yield()
        waiting.cancel()
        await #expect(throws: CancellationError.self) { try await waiting.value }
        await queue.release()
        await queue.release()
        // A cancelled waiter must neither steal nor leak a permit.
        try await queue.acquire()
        try await queue.acquire()
        await queue.release()
        await queue.release()
    }
}

private actor ConcurrencyProbe {
    var active = 0
    var peak = 0
    func enter() { active += 1; peak = max(peak, active) }
    func leave() { active -= 1 }
}
