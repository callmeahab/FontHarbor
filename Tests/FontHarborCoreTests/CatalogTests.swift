// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing
@testable import FontHarborCore

@MainActor
struct CatalogTests {
    @Test @MainActor func scopeSurvivesSearchAndCategoryChanges() {
        let fonts = OpenFont.fallbackCatalog
        let catalog = FontCatalog(fonts: fonts + [fonts[0]])
        let favorites: Set<String> = ["inter", "source-serif"]
        #expect(catalog.fonts.count == fonts.count)
        let result = catalog.filtered(query: "  INTER  UI ", scope: .favorites, category: .sansSerif,
                                      favorites: favorites, installed: [], customSources: [])
        #expect(result.map(\.id) == ["inter"])
        #expect(catalog.filtered(query: "", scope: .installed, category: nil,
                                favorites: favorites, installed: ["lato"], customSources: []).map(\.id) == ["lato"])
        #expect(catalog.filtered(query: "Łukasz", scope: .all, category: nil,
                                favorites: [], installed: [], customSources: []).map(\.id) == ["lato"])
    }

    @Test @MainActor func customSourceAndCollectionCountsUseSameMembership() {
        let fonts = OpenFont.fallbackCatalog
        let catalog = FontCatalog(fonts: fonts)
        let source = CustomFontSource(id: UUID(), name: "Two families", location: "example", fontIDs: ["inter", "lato"])
        let result = catalog.filtered(query: "lato", scope: .custom(source.id), category: nil,
                                      favorites: [], installed: [], customSources: [source])
        #expect(result.map(\.id) == ["lato"])
        for collection in CuratedCollection.allCases {
            let filtered = catalog.filtered(query: "", scope: .collection(collection), category: nil,
                                            favorites: [], installed: [], customSources: [])
            #expect(filtered.count == fonts.count { FontCatalog.matches($0, collection: collection) })
        }
        #expect(catalog.filtered(query: "", scope: .collection(.recent), category: nil,
                                favorites: [], installed: [], customSources: []).isEmpty)
    }

    @Test func variableAxesUseActualDefaultsAndClampValues() {
        let axis = FontVariationAxis(id: 1, name: "Weight", minimum: 300, maximum: 700, defaultValue: 450)
        var variation = VariationSettings()
        #expect(variation.value(for: axis) == 450)
        variation.values[axis.id] = 900
        #expect(variation.value(for: axis) == 700)
        variation.values[axis.id] = 100
        #expect(variation.value(for: axis) == 300)
    }

    @Test func repositoryURLsRejectWrongHostsAndCredentials() {
        #expect(GitHubRepositoryReference(input: "https://github.com/IBM/plex.git")?.name == "plex")
        #expect(GitHubRepositoryReference(input: "https://github.com/IBM/plex/tree/main")?.owner == "IBM")
        #expect(GitHubRepositoryReference(input: "http://github.com/IBM/plex") == nil)
        #expect(GitHubRepositoryReference(input: "https://github.com.evil.example/IBM/plex") == nil)
        #expect(GitHubRepositoryReference(input: "https://user:password@github.com/IBM/plex") == nil)
        #expect(GitHubRepositoryReference(input: "https://github.com/IBM") == nil)
    }

    @Test @MainActor func discoveryRejectsUnsafeURLsWithoutNetwork() async {
        let discovery = FontSourceDiscovery()
        await #expect(throws: SourceDiscoveryError.self) { try await discovery.discover("file:///tmp/Test.ttf") }
        await #expect(throws: SourceDiscoveryError.self) { try await discovery.discover("https://example.com/index.html") }
        let result = try? await discovery.discover("https://example.com/Test.ttf")
        #expect(result?.fonts.count == 1)
        #expect(result?.fonts.first?.license == "Check repository license")
    }
}
