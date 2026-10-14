// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import CoreText
import CryptoKit
import Foundation

enum FontFileIdentity {
    /// Hash the full identity: punctuation, case and identical filenames must not collide.
    nonisolated static func fileName(for font: OpenFont) -> String {
        let digest = SHA256.hash(data: Data(font.id.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = font.downloadURL.pathExtension.lowercased()
        return digest + "." + (["ttf", "otf", "ttc", "otc"].contains(ext) ? ext : "font")
    }

    nonisolated static func validate(_ url: URL) throws {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else { throw FontLibraryError.invalidFont }
    }
}

/// Owns disk I/O and shares one cancellable, bounded download between previews and installs.
actor FontDownloadStore {
    private struct Flight {
        let task: Task<URL, Error>
        var consumers: Set<UUID>
    }
    private let directory: URL
    private let session: URLSession
    private let queue = PreviewDownloadQueue(maxConcurrent: 4)
    private var flights: [String: Flight] = [:]

    init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
    }

    func url(for font: OpenFont) async throws -> URL {
        let consumer = UUID()
        let task: Task<URL, Error>
        if var flight = flights[font.id] {
            flight.consumers.insert(consumer)
            flights[font.id] = flight
            task = flight.task
        } else {
            task = Task { try await self.download(font) }
            flights[font.id] = Flight(task: task, consumers: [consumer])
        }
        defer { release(font.id, consumer: consumer) }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            Task { await self.release(font.id, consumer: consumer) }
        }
    }

    private func release(_ id: String, consumer: UUID) {
        guard var flight = flights[id], flight.consumers.remove(consumer) != nil else { return }
        if flight.consumers.isEmpty {
            flight.task.cancel()
            flights[id] = nil
        } else {
            flights[id] = flight
        }
    }

    private func download(_ font: OpenFont) async throws -> URL {
        guard font.downloadURL.scheme?.lowercased() == "https" else { throw FontLibraryError.insecureURL }
        try await queue.acquire()
        do {
            try Task.checkCancellation()
            let result = try await fetch(font)
            await queue.release()
            return result
        } catch {
            await queue.release()
            throw error
        }
    }

    private func fetch(_ font: OpenFont) async throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(FontFileIdentity.fileName(for: font))
        if manager.fileExists(atPath: destination.path) {
            do {
                try FontFileIdentity.validate(destination)
                return destination
            } catch {
                try manager.removeItem(at: destination)
            }
        }
        var request = URLRequest(url: font.downloadURL)
        request.timeoutInterval = 60
        let (temporary, response) = try await session.download(for: request)
        defer { try? manager.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              http.url?.scheme?.lowercased() == "https" else { throw FontLibraryError.downloadFailed }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 100 * 1024 * 1024 else { throw FontLibraryError.invalidFont }
        try FontFileIdentity.validate(temporary)
        try manager.moveItem(at: temporary, to: destination)
        return destination
    }
}
