// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing
@testable import FontHarborCore

@MainActor
struct LibraryTests {
    @Test func favoriteFilteringStaysActiveAndSelectionRecovers() {
        let library = FontLibrary(defaults: MemoryDefaults(), storageRoot: scratch(), fonts: OpenFont.fallbackCatalog)
        let inter = library.allFonts.first { $0.id == "inter" }!
        library.toggleFavorite(inter)
        library.selectScope(.favorites)
        library.searchText = "nothing matches"
        #expect(library.visibleFonts.isEmpty)
        #expect(library.selectedFont == nil)
        library.searchText = "inter"
        #expect(library.visibleFonts.map(\.id) == ["inter"])
        #expect(library.selectedFont?.id == "inter")
        #expect(library.scopeTitle == "Favorites")
        library.toggleFavorite(inter)
        #expect(library.visibleFonts.isEmpty)
    }

    @Test func removingOneSourceKeepsFontsUsedByAnother() throws {
        let defaults = MemoryDefaults()
        let original = OpenFont.fallbackCatalog[0]
        let custom = OpenFont(id: "custom-shared", family: original.family, designer: original.designer,
                              category: original.category, source: .community, license: original.license,
                              description: original.description, tags: original.tags, downloadURL: original.downloadURL,
                              repositoryURL: original.repositoryURL, fileName: original.fileName)
        let first = CustomFontSource(id: UUID(), name: "First", location: "first", fontIDs: [custom.id])
        let second = CustomFontSource(id: UUID(), name: "Second", location: "second", fontIDs: [custom.id])
        defaults.set(try JSONEncoder().encode([first, second]), forKey: "customFontSources")
        defaults.set(try JSONEncoder().encode([custom]), forKey: "customFonts")
        let library = FontLibrary(defaults: defaults, storageRoot: scratch(), fonts: [])
        library.selectScope(.custom(first.id))
        library.removeSource(first)
        #expect(library.allFonts.map(\.id) == [custom.id])
        #expect(library.selectedScope == .all)
        library.removeSource(second)
        #expect(library.allFonts.isEmpty)
        let reloaded = FontLibrary(defaults: defaults, storageRoot: scratch(), fonts: [])
        #expect(reloaded.allFonts.isEmpty)
    }

    @Test func failedInstallDoesNotClaimSuccessOrLeaveActiveDownload() async {
        let font = OpenFont(id: "bad", family: "Invalid", designer: "", category: .sansSerif, source: .community,
                            license: "Unknown", description: "", tags: [], downloadURL: URL(string: "http://example.com/test.ttf")!,
                            repositoryURL: URL(string: "https://example.com")!, fileName: "test.ttf")
        let library = FontLibrary(defaults: MemoryDefaults(), storageRoot: scratch(), fonts: [font])
        await library.install(font)
        #expect(library.installedFontIDs.isEmpty)
        #expect(library.activeDownloadIDs.isEmpty)
        #expect(library.errorMessage != nil)
        await library.preparePreview(font)
        #expect(library.previewErrors[font.id] != nil)
        #expect(library.previewDownloadIDs.isEmpty)
    }

    private func scratch() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "FontHarborTests-" + UUID().uuidString)
    }
}

// Persist between library instances without touching the user's preferences.
private final class MemoryDefaults: UserDefaults, @unchecked Sendable {
    private var values: [String: Any] = [:]
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func data(forKey key: String) -> Data? { values[key] as? Data }
}
