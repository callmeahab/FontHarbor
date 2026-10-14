// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum BrowserLayout: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }
}

enum CuratedCollection: String, CaseIterable, Identifiable, Sendable {
    case coding = "Great for Coding"
    case editorial = "Editorial Serifs"
    case friendlyUI = "Friendly UI"
    case variable = "Variable Fonts"
    case recent = "Recently Discovered"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .editorial: "newspaper"
        case .friendlyUI: "macwindow"
        case .variable: "slider.horizontal.3"
        case .recent: "sparkles"
        }
    }
}

enum PreviewPreset: String, CaseIterable, Identifiable {
    case headline = "Headline"
    case article = "Article"
    case interface = "Interface"
    case code = "Code"
    case poster = "Poster"
    case resume = "Résumé"

    var id: String { rawValue }

    var text: String {
        switch self {
        case .headline: "Ideas deserve beautiful voices."
        case .article: "Typography gives written language a durable visual form. The best text faces disappear into the act of reading."
        case .interface: "Create project   Share   Export"
        case .code: "let harbor = FontLibrary()\nawait harbor.preparePreview(font)"
        case .poster: "OPEN\nTYPE\nFOREVER"
        case .resume: "ALEX MORGAN\nProduct Designer · Belgrade\nExperience  Selected Work  Education"
        }
    }

    var suggestedSize: Double {
        switch self {
        case .headline: 58
        case .article: 25
        case .interface: 22
        case .code: 20
        case .poster: 72
        case .resume: 24
        }
    }
}

enum SpecimenTheme: String, CaseIterable, Identifiable {
    case paper = "Paper"
    case midnight = "Midnight"
    case ink = "Ink"
    case cobalt = "Cobalt"

    var id: String { rawValue }
}

struct FontVariationAxis: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
    let minimum: Double
    let maximum: Double
    let defaultValue: Double
}

struct VariationSettings: Equatable, Sendable {
    var values: [UInt32: Double] = [:]

    func value(for axis: FontVariationAxis) -> Double {
        min(max(values[axis.id] ?? axis.defaultValue, axis.minimum), axis.maximum)
    }
}

struct FontRuntimeInfo: Equatable, Sendable {
    var previewName: String
    var fileSize: Int64
    var format: String
    var styleCount: Int
    var axes: [FontVariationAxis]
    var scripts: [String]
    var glyphs: [String]
    var repositoryUpdatedAt: Date?
}
