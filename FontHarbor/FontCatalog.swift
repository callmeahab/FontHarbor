// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum LibraryScope: Hashable, Sendable {
    case all, favorites, installed
    case source(FontSource)
    case collection(CuratedCollection)
    case custom(UUID)
}

/// Sort and build searchable text once, rather than on every keystroke or selection.
struct FontCatalog: Sendable {
    let fonts: [OpenFont]
    let byID: [OpenFont.ID: OpenFont]
    private let searchText: [OpenFont.ID: String]

    init(fonts: [OpenFont]) {
        var seen: Set<String> = []
        self.fonts = fonts.filter { seen.insert($0.id).inserted }
            .sorted { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
        byID = Dictionary(uniqueKeysWithValues: self.fonts.map { ($0.id, $0) })
        searchText = Dictionary(uniqueKeysWithValues: self.fonts.map { font in
            (font.id, Self.normalize(([font.family, font.designer, font.category.rawValue, font.source.rawValue] + font.tags).joined(separator: " ")))
        })
    }

    func filtered(query: String, scope: LibraryScope, category: FontCategory?, favorites: Set<String>, installed: Set<String>, customSources: [CustomFontSource]) -> [OpenFont] {
        let words = Self.normalize(query).split(whereSeparator: \.isWhitespace)
        let customIDs: Set<String>
        if case .custom(let id) = scope {
            customIDs = Set(customSources.first { $0.id == id }?.fontIDs ?? [])
        } else {
            customIDs = []
        }
        return fonts.filter { font in
            guard category == nil || font.category == category,
                  words.allSatisfy({ searchText[font.id]?.contains($0) == true }) else { return false }
            switch scope {
            case .all: return true
            case .favorites: return favorites.contains(font.id)
            case .installed: return installed.contains(font.id)
            case .source(let source): return font.source == source
            case .custom: return customIDs.contains(font.id)
            case .collection(let collection): return Self.matches(font, collection: collection)
            }
        }
    }

    static func matches(_ font: OpenFont, collection: CuratedCollection) -> Bool {
        switch collection {
        case .coding: font.category == .monospace || font.tags.contains { $0.localizedCaseInsensitiveContains("coding") }
        case .editorial: font.category == .serif
        case .friendlyUI: font.category == .sansSerif && !font.family.localizedCaseInsensitiveContains("condensed")
        case .variable: font.tags.contains { $0.localizedCaseInsensitiveContains("variable") }
        case .recent: font.source == .community
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
