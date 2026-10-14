// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum FontSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case googleFonts = "Google Fonts"
    case fontshare = "Fontshare"
    case league = "The League"
    case adobe = "Adobe"
    case jetBrains = "JetBrains"
    case mozilla = "Mozilla"
    case nerdFonts = "Nerd Fonts"
    case community = "Community"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .googleFonts: "textformat.alt"
        case .fontshare: "square.grid.2x2"
        case .league: "flag.checkered"
        case .adobe: "character.book.closed.fill"
        case .jetBrains: "chevron.left.forwardslash.chevron.right"
        case .mozilla: "globe"
        case .nerdFonts: "terminal.fill"
        case .community: "person.3.fill"
        }
    }

    var tintName: String {
        switch self {
        case .googleFonts: "blue"
        case .fontshare: "purple"
        case .league: "orange"
        case .adobe: "red"
        case .jetBrains: "pink"
        case .mozilla: "indigo"
        case .nerdFonts: "green"
        case .community: "teal"
        }
    }
}

struct CustomFontSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var location: String
    var fontIDs: [String]
}

enum FontCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case sansSerif = "Sans Serif"
    case serif = "Serif"
    case monospace = "Monospace"
    case display = "Display"

    var id: String { rawValue }
}

struct OpenFont: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let family: String
    let designer: String
    let category: FontCategory
    let source: FontSource
    let license: String
    let description: String
    let tags: [String]
    let downloadURL: URL
    let repositoryURL: URL
    let fileName: String

    static let fallbackCatalog: [OpenFont] = [
        OpenFont(id: "inter", family: "Inter", designer: "Rasmus Andersson", category: .sansSerif, source: .googleFonts, license: "SIL Open Font License", description: "A carefully crafted typeface for computer screens.", tags: ["Variable", "UI", "Popular"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/rsms/inter")!, fileName: "Inter-Variable.ttf"),
        OpenFont(id: "montserrat", family: "Montserrat", designer: "Julieta Ulanovsky", category: .sansSerif, source: .googleFonts, license: "SIL Open Font License", description: "Geometric letterforms inspired by urban typography.", tags: ["Variable", "Geometric"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/JulietaUla/Montserrat")!, fileName: "Montserrat-Variable.ttf"),
        OpenFont(id: "lato", family: "Lato", designer: "Łukasz Dziedzic", category: .sansSerif, source: .googleFonts, license: "SIL Open Font License", description: "A warm, transparent sans serif family.", tags: ["Humanist", "Text"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/lato/Lato-Regular.ttf")!, repositoryURL: URL(string: "https://github.com/google/fonts/tree/main/ofl/lato")!, fileName: "Lato-Regular.ttf"),
        OpenFont(id: "playfair", family: "Playfair Display", designer: "Claus Eggers Sørensen", category: .serif, source: .googleFonts, license: "SIL Open Font License", description: "High-contrast display type with classical proportions.", tags: ["Variable", "Editorial"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/clauseggers/Playfair-Display")!, fileName: "PlayfairDisplay-Variable.ttf"),
        OpenFont(id: "oswald", family: "Oswald", designer: "Vernon Adams", category: .display, source: .googleFonts, license: "SIL Open Font License", description: "A modern reworking of the classic gothic style.", tags: ["Variable", "Condensed"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/google/fonts/tree/main/ofl/oswald")!, fileName: "Oswald-Variable.ttf"),
        OpenFont(id: "raleway", family: "Raleway", designer: "The League of Moveable Type", category: .sansSerif, source: .league, license: "SIL Open Font License", description: "An elegant sans serif with distinctive details.", tags: ["Variable", "Elegant"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/raleway/Raleway%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/theleagueof/raleway")!, fileName: "Raleway-Variable.ttf"),
        OpenFont(id: "source-serif", family: "Source Serif 4", designer: "Frank Griesshammer", category: .serif, source: .adobe, license: "SIL Open Font License", description: "Adobe's versatile serif for extended reading.", tags: ["Variable", "Editorial"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/SourceSerif4%5Bopsz,wght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/adobe-fonts/source-serif")!, fileName: "SourceSerif4-Variable.ttf"),
        OpenFont(id: "source-code", family: "Source Code Pro", designer: "Paul D. Hunt", category: .monospace, source: .adobe, license: "SIL Open Font License", description: "A coding face designed for legibility in interfaces.", tags: ["Variable", "Coding"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/sourcecodepro/SourceCodePro%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/adobe-fonts/source-code-pro")!, fileName: "SourceCodePro-Variable.ttf"),
        OpenFont(id: "jetbrains-mono", family: "JetBrains Mono", designer: "JetBrains", category: .monospace, source: .jetBrains, license: "SIL Open Font License", description: "A developer typeface with increased character height.", tags: ["Variable", "Coding", "Ligatures"], downloadURL: URL(string: "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/variable/JetBrainsMono%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/JetBrains/JetBrainsMono")!, fileName: "JetBrainsMono-Variable.ttf"),
        OpenFont(id: "fira-sans", family: "Fira Sans", designer: "Mozilla", category: .sansSerif, source: .mozilla, license: "SIL Open Font License", description: "Designed for the Firefox OS visual language.", tags: ["Humanist", "UI"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/firasans/FiraSans-Regular.ttf")!, repositoryURL: URL(string: "https://github.com/mozilla/Fira")!, fileName: "FiraSans-Regular.ttf"),
        OpenFont(id: "firacode", family: "Fira Code", designer: "Nikita Prokopov", category: .monospace, source: .googleFonts, license: "SIL Open Font License", description: "Monospaced programming font with ligatures.", tags: ["Variable", "Coding", "Ligatures"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/firacode/FiraCode%5Bwght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/tonsky/FiraCode")!, fileName: "FiraCode-Variable.ttf"),
        OpenFont(id: "archivo", family: "Archivo", designer: "Omnibus-Type", category: .sansSerif, source: .googleFonts, license: "SIL Open Font License", description: "A grotesque family built for print and digital use.", tags: ["Variable", "Grotesque"], downloadURL: URL(string: "https://raw.githubusercontent.com/google/fonts/main/ofl/archivo/Archivo%5Bwdth,wght%5D.ttf")!, repositoryURL: URL(string: "https://github.com/Omnibus-Type/Archivo")!, fileName: "Archivo-Variable.ttf")
    ]

    static let catalog: [OpenFont] = {
        guard let bundled = BundledFontIndex.load() else { return fallbackCatalog }
        let curatedFamilies = Set(fallbackCatalog.map { $0.family.lowercased() })
        return (fallbackCatalog + bundled.filter { !curatedFamilies.contains($0.family.lowercased()) })
            .sorted { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
    }()
}

struct FontIndexDocument: Codable, Sendable {
    struct SourceSummary: Codable, Sendable {
        let name: String
        let url: URL
        let count: Int
    }

    let schemaVersion: Int
    let generatedAt: String
    let sources: [SourceSummary]
    let fonts: [OpenFont]
}

enum BundledFontIndex {
    static func load(bundle: Bundle = .main) -> [OpenFont]? {
        guard let url = bundle.url(forResource: "FontIndex", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(FontIndexDocument.self, from: data),
              document.schemaVersion == 1,
              !document.fonts.isEmpty else {
            return nil
        }
        return document.fonts
    }
}
