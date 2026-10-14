// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import CoreText
import Foundation
import Observation

@MainActor
@Observable
final class FontLibrary {
    private(set) var allFonts: [OpenFont] = OpenFont.catalog
    private(set) var visibleFonts: [OpenFont] = OpenFont.catalog
    var customSources: [CustomFontSource] = []
    var searchText = "" { didSet { updateVisibleFonts() } }
    var selectedScope: LibraryScope = .all { didSet { updateVisibleFonts() } }
    var selectedCategory: FontCategory? { didSet { updateVisibleFonts() } }
    var browserLayout: BrowserLayout = .list { didSet { defaults.set(browserLayout.rawValue, forKey: "browserLayout") } }
    var selectedFontID: OpenFont.ID? = OpenFont.catalog.first?.id
    var installedFontIDs: Set<OpenFont.ID> = []
    var favoriteFontIDs: Set<OpenFont.ID> = []
    var comparedFontIDs: [OpenFont.ID] = []
    var activeDownloadIDs: Set<OpenFont.ID> = []
    var previewDownloadIDs: Set<OpenFont.ID> = []
    var previewErrors: [OpenFont.ID: String] = [:]
    private(set) var sourceCounts: [FontSource: Int] = [:]
    private(set) var collectionCounts: [CuratedCollection: Int] = [:]
    var runtimeInfo: [OpenFont.ID: FontRuntimeInfo] = [:]
    var isDiscovering = false
    var isRecommending = false
    var lastDiscoveryUsedAppleIntelligence = false
    var errorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var catalog = FontCatalog(fonts: OpenFont.catalog)
    @ObservationIgnored private var previewConsumers: [String: Int] = [:]
    @ObservationIgnored private var repositoryDates: [URL: Date] = [:]
    @ObservationIgnored private var checkedRepositories: Set<URL> = []
    private let fileManager = FileManager.default
    private let favoritesKey = "favoriteFontIDs"
    private let installedKey = "installedFontIDs"
    private let customSourcesKey = "customFontSources"
    private let customFontsKey = "customFonts"
    private let discovery = FontSourceDiscovery()
    private let downloadStore: FontDownloadStore
    private let storageDirectory: URL

    init(defaults: UserDefaults = .standard, storageRoot: URL? = nil, fonts: [OpenFont]? = nil) {
        self.defaults = defaults
        allFonts = fonts ?? OpenFont.catalog
        let identifier = Bundle.main.bundleIdentifier ?? "FontHarbor"
        storageDirectory = storageRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: identifier).appending(path: "Fonts")
        let cache = storageRoot?.appending(path: "Cache") ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: identifier).appending(path: "FontPreviews")
        downloadStore = FontDownloadStore(directory: cache)
        favoriteFontIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        installedFontIDs = Set(defaults.stringArray(forKey: installedKey) ?? [])
        if let sourceData = defaults.data(forKey: customSourcesKey),
           let decodedSources = try? JSONDecoder().decode([CustomFontSource].self, from: sourceData) {
            customSources = decodedSources
        }
        if let fontData = defaults.data(forKey: customFontsKey),
           let decodedFonts = try? JSONDecoder().decode([OpenFont].self, from: fontData) {
            allFonts.append(contentsOf: decodedFonts)
            visibleFonts = allFonts
        }
        browserLayout = BrowserLayout(rawValue: defaults.string(forKey: "browserLayout") ?? "") ?? .list
        rebuildCatalog()
        reactivateInstalledFonts()
        updateVisibleFonts()
    }

    var selectedFont: OpenFont? {
        guard let selectedFontID else { return nil }
        return catalog.byID[selectedFontID]
    }

    var comparedFonts: [OpenFont] {
        comparedFontIDs.compactMap { catalog.byID[$0] }
    }

    var appleIntelligenceStatus: AppleIntelligenceStatus {
        FontSourceDiscovery.appleIntelligenceStatus
    }

    func previewName(for font: OpenFont) -> String {
        runtimeInfo[font.id]?.previewName ?? font.family
    }

    func swiftUIFont(for font: OpenFont, size: CGFloat, variation: VariationSettings) -> NSFont? {
        let name = previewName(for: font)
        guard let baseFont = NSFont(name: name, size: size) ?? NSFontManager.shared.font(withFamily: name, traits: [], weight: 5, size: size) else {
            return nil
        }
        let values = Dictionary(uniqueKeysWithValues: (runtimeInfo[font.id]?.axes ?? []).map { axis in
            (NSNumber(value: axis.id), NSNumber(value: variation.value(for: axis)))
        })
        let descriptor = baseFont.fontDescriptor.addingAttributes([.variation: values])
        return NSFont(descriptor: descriptor, size: size) ?? baseFont
    }

    var scopeTitle: String {
        switch selectedScope {
        case .all: "All Fonts"
        case .favorites: "Favorites"
        case .installed: "Installed"
        case .source(let source): source.rawValue
        case .collection(let collection): collection.rawValue
        case .custom(let id): customSources.first { $0.id == id }?.name ?? "My Source"
        }
    }

    func selectScope(_ scope: LibraryScope) {
        selectedCategory = nil
        selectedScope = scope
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }

    func canCompare(_ font: OpenFont) -> Bool {
        comparedFontIDs.contains(font.id) || comparedFontIDs.count < 4
    }

    func toggleComparison(_ font: OpenFont) {
        if let index = comparedFontIDs.firstIndex(of: font.id) {
            comparedFontIDs.remove(at: index)
        } else if comparedFontIDs.count < 4 {
            comparedFontIDs.append(font.id)
        }
    }

    func recommend(for request: String) async -> OpenFont? {
        guard !isRecommending else { return nil }
        isRecommending = true
        defer { isRecommending = false }

        do {
            let family = try await discovery.recommendFont(
                for: request,
                candidates: randomizedRecommendationCandidates
            )
            let recommended = allFonts.first {
                $0.family.localizedCaseInsensitiveCompare(family) == .orderedSame
            } ?? heuristicRecommendation(for: request)
            reveal(recommended)
            selectedFontID = recommended?.id
            return recommended
        } catch {
            let fallback = heuristicRecommendation(for: request)
            reveal(fallback)
            selectedFontID = fallback?.id
            return fallback
        }
    }

    func preloadPreviews(_ fonts: [OpenFont], limit: Int = 24) async {
        let candidates = fonts.lazy
            .filter { self.runtimeInfo[$0.id] == nil }
            .prefix(limit)

        await withTaskGroup(of: Void.self) { group in
            for font in candidates {
                group.addTask { await self.preparePreview(font) }
            }
        }
    }

    func preparePreview(_ font: OpenFont) async {
        guard runtimeInfo[font.id] == nil else { return }
        previewConsumers[font.id, default: 0] += 1
        previewDownloadIDs.insert(font.id)
        previewErrors[font.id] = nil
        defer {
            previewConsumers[font.id, default: 1] -= 1
            if previewConsumers[font.id] == 0 {
                previewConsumers[font.id] = nil
                previewDownloadIDs.remove(font.id)
            }
        }
        do {
            let url = try await downloadStore.url(for: font)
            try Task.checkCancellation()
            guard runtimeInfo[font.id] == nil else { return }
            try register(url, scope: .process)
            runtimeInfo[font.id] = inspectFont(at: url, fallbackName: font.family)
        } catch {
            guard !isCancellation(error) else { return }
            previewErrors[font.id] = error.localizedDescription
        }
    }

    func prepareRepositoryMetadata(_ font: OpenFont) async {
        guard let repository = repositoryAPIURL(for: font) else { return }
        if let date = repositoryDates[repository], var info = runtimeInfo[font.id] {
            info.repositoryUpdatedAt = date
            runtimeInfo[font.id] = info
            return
        }
        guard runtimeInfo[font.id] != nil, checkedRepositories.insert(repository).inserted else { return }
        guard let updatedAt = await repositoryUpdateDate(at: repository) else { return }
        repositoryDates[repository] = updatedAt
        if var info = runtimeInfo[font.id] {
            info.repositoryUpdatedAt = updatedAt
            runtimeInfo[font.id] = info
        }
    }

    func addSource(_ request: String) async -> Bool {
        guard !isDiscovering else { return false }
        isDiscovering = true
        defer { isDiscovering = false }
        do {
            let result = try await discovery.discover(request)
            let existingIDs = Set(allFonts.map(\.id))
            let newFonts = result.fonts.filter { !existingIDs.contains($0.id) }
            allFonts.append(contentsOf: newFonts)
            if !customSources.contains(where: { $0.location == result.source.location }) {
                customSources.append(result.source)
            }
            lastDiscoveryUsedAppleIntelligence = result.usedAppleIntelligence
            persistCustomCatalog()
            rebuildCatalog()
            clearFilters()
            selectScope(.custom(customSources.first { $0.location == result.source.location }?.id ?? result.source.id))
            selectedFontID = newFonts.first?.id ?? result.fonts.first?.id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeSource(_ source: CustomFontSource) {
        customSources.removeAll { $0.id == source.id }
        let retainedIDs = Set(customSources.flatMap(\.fontIDs)).union(installedFontIDs)
        let removedIDs = Set(source.fontIDs).subtracting(retainedIDs)
        allFonts.removeAll { removedIDs.contains($0.id) }
        favoriteFontIDs.subtract(removedIDs)
        comparedFontIDs.removeAll { removedIDs.contains($0) }
        defaults.set(Array(favoriteFontIDs), forKey: favoritesKey)
        persistCustomCatalog()
        rebuildCatalog()
        if selectedScope == .custom(source.id) { selectScope(.all) }
        updateVisibleFonts()
    }

    func toggleFavorite(_ font: OpenFont) {
        if favoriteFontIDs.contains(font.id) {
            favoriteFontIDs.remove(font.id)
        } else {
            favoriteFontIDs.insert(font.id)
        }
        defaults.set(Array(favoriteFontIDs), forKey: favoritesKey)
        updateVisibleFonts()
    }

    func install(_ font: OpenFont) async {
        guard !activeDownloadIDs.contains(font.id), !installedFontIDs.contains(font.id) else { return }
        activeDownloadIDs.insert(font.id)
        defer { activeDownloadIDs.remove(font.id) }
        var createdURL: URL?
        do {
            let cached = try await downloadStore.url(for: font)
            let destination = try destinationURL(for: font)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: cached, to: destination)
                createdURL = destination
            }
            try FontFileIdentity.validate(destination)
            try register(destination, scope: .user)
            installedFontIDs.insert(font.id)
            defaults.set(Array(installedFontIDs), forKey: installedKey)
            updateVisibleFonts()
        } catch {
            if let createdURL { try? fileManager.removeItem(at: createdURL) }
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ font: OpenFont) {
        do {
            let destination = try destinationURL(for: font)
            if fileManager.fileExists(atPath: destination.path) {
                var unmanagedError: Unmanaged<CFError>?
                let removed = CTFontManagerUnregisterFontsForURL(destination as CFURL, .user, &unmanagedError)
                if !removed, let error = unmanagedError?.takeRetainedValue(),
                   CFErrorGetCode(error) != CTFontManagerError.notRegistered.rawValue {
                    throw FontLibraryError.registrationFailed(error.localizedDescription)
                }
                try fileManager.removeItem(at: destination)
            }
            installedFontIDs.remove(font.id)
            defaults.set(Array(installedFontIDs), forKey: installedKey)
            persistCustomCatalog()
            updateVisibleFonts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register(_ url: URL, scope: CTFontManagerScope) throws {
        var unmanagedError: Unmanaged<CFError>?
        let succeeded = CTFontManagerRegisterFontsForURL(url as CFURL, scope, &unmanagedError)
        if !succeeded {
            guard let error = unmanagedError?.takeRetainedValue() else {
                throw FontLibraryError.registrationFailed("Core Text did not provide an error.")
            }
            if CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue {
                throw FontLibraryError.registrationFailed(error.localizedDescription)
            }
        }
    }

    private func rebuildCatalog() {
        catalog = FontCatalog(fonts: allFonts)
        allFonts = catalog.fonts
        sourceCounts = Dictionary(grouping: allFonts, by: \.source).mapValues(\.count)
        collectionCounts = Dictionary(uniqueKeysWithValues: CuratedCollection.allCases.map { collection in
            (collection, allFonts.count { FontCatalog.matches($0, collection: collection) })
        })
        favoriteFontIDs.formIntersection(Set(allFonts.map(\.id)))
    }

    private func updateVisibleFonts() {
        visibleFonts = catalog.filtered(query: searchText, scope: selectedScope, category: selectedCategory,
                                        favorites: favoriteFontIDs, installed: installedFontIDs, customSources: customSources)
        if selectedFontID == nil || !visibleFonts.contains(where: { $0.id == selectedFontID }) {
            selectedFontID = visibleFonts.first?.id
        }
    }

    private func reveal(_ font: OpenFont?) {
        guard let font, !visibleFonts.contains(where: { $0.id == font.id }) else { return }
        clearFilters()
        selectScope(.all)
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as NSError).code == NSURLErrorCancelled
    }

    private var randomizedRecommendationCandidates: [OpenFont] {
        let favorites = allFonts.filter { favoriteFontIDs.contains($0.id) }.prefix(8)
        let curated = OpenFont.fallbackCatalog.compactMap { catalog.byID[$0.id] }
        let balanced = FontCategory.allCases.flatMap { category in allFonts.filter { $0.category == category }.prefix(6) }
        let popular = allFonts.filter { $0.tags.contains("Popular") }
        var seen: Set<String> = []
        let candidates = (Array(favorites) + curated + balanced + popular)
            .filter { seen.insert($0.id).inserted }
        let alternatives = candidates.filter { $0.id != selectedFontID }
        return (alternatives.isEmpty ? candidates : alternatives).shuffled()
    }

    private func heuristicRecommendation(for request: String) -> OpenFont? {
        let query = request.lowercased()
        let category: FontCategory
        if query.contains("code") || query.contains("mono") {
            category = .monospace
        } else if query.contains("luxury") || query.contains("editorial") || query.contains("serif") {
            category = .serif
        } else if query.contains("poster") || query.contains("bold") {
            category = .display
        } else {
            category = .sansSerif
        }

        let matches = allFonts.filter { $0.category == category }
        let alternatives = matches.filter { $0.id != selectedFontID }
        return (alternatives.isEmpty ? matches : alternatives).randomElement()
    }

    private func destinationURL(for font: OpenFont) throws -> URL {
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        return storageDirectory.appendingPathComponent(FontFileIdentity.fileName(for: font))
    }

    private func inspectFont(at url: URL, fallbackName: String) -> FontRuntimeInfo {
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
        let descriptor = descriptors.first
        let postScriptName = descriptor
            .flatMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
            ?? fallbackName
        let ctFont = CTFontCreateWithName(postScriptName as CFString, 16, nil)
        let characterSet = CTFontCopyCharacterSet(ctFont) as CharacterSet
        let axesData = CTFontCopyVariationAxes(ctFont) as? [[CFString: Any]] ?? []
        let axes = axesData.compactMap { axis -> FontVariationAxis? in
            guard let id = axis[kCTFontVariationAxisIdentifierKey] as? NSNumber,
                  let minimum = axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber,
                  let maximum = axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber,
                  let defaultValue = axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber else { return nil }
            return FontVariationAxis(id: id.uint32Value, name: axis[kCTFontVariationAxisNameKey] as? String ?? "Axis",
                                     minimum: minimum.doubleValue, maximum: maximum.doubleValue, defaultValue: defaultValue.doubleValue)
        }
        let scriptSamples: [(String, UnicodeScalar)] = [
            ("Latin", "A"), ("Cyrillic", "Ж"), ("Greek", "Ω"), ("Arabic", "ش"),
            ("Hebrew", "א"), ("Devanagari", "क"), ("CJK", "漢"), ("Japanese", "あ")
        ].compactMap { name, string in
            guard let scalar = string.unicodeScalars.first else { return nil }
            return (name, scalar)
        }
        let scripts = scriptSamples.filter { characterSet.contains($0.1) }.map(\.0)
        let sample = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?@&$%#ΩЖéßæø"
        let glyphs = sample.map(String.init).filter {
            guard let scalar = $0.unicodeScalars.first else { return false }
            return characterSet.contains(scalar)
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return FontRuntimeInfo(
            previewName: postScriptName,
            fileSize: size,
            format: url.pathExtension.uppercased(),
            styleCount: max(descriptors.count, 1),
            axes: axes,
            scripts: scripts,
            glyphs: glyphs,
            repositoryUpdatedAt: nil
        )
    }

    private func repositoryAPIURL(for font: OpenFont) -> URL? {
        guard font.repositoryURL.host()?.lowercased() == "github.com" else { return nil }
        let parts = font.repositoryURL.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        return URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])")
    }

    private func repositoryUpdateDate(at url: URL) async -> Date? {
        var request = URLRequest(url: url)
        request.setValue("FontHarbor/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(RepositoryUpdate.self, from: data) else { return nil }
        return ISO8601DateFormatter().date(from: payload.pushedAt)
    }

    private func reactivateInstalledFonts() {
        for font in allFonts where installedFontIDs.contains(font.id) {
            do {
                let url = try destinationURL(for: font)
                // Migrate the prototype's filename-based storage without overwriting a font.
                if !fileManager.fileExists(atPath: url.path),
                   URL(filePath: font.fileName).lastPathComponent == font.fileName {
                    let legacy = storageDirectory.appendingPathComponent(font.fileName)
                    if fileManager.fileExists(atPath: legacy.path) {
                        try FontFileIdentity.validate(legacy)
                        try fileManager.moveItem(at: legacy, to: url)
                    }
                }
                guard fileManager.fileExists(atPath: url.path) else {
                    installedFontIDs.remove(font.id)
                    continue
                }
                try register(url, scope: .user)
                runtimeInfo[font.id] = inspectFont(at: url, fallbackName: font.family)
            } catch {
                installedFontIDs.remove(font.id)
                errorMessage = "Could not restore \(font.family): \(error.localizedDescription)"
            }
        }
        defaults.set(Array(installedFontIDs), forKey: installedKey)
    }

    private func persistCustomCatalog() {
        let customIDs = Set(customSources.flatMap(\.fontIDs)).union(installedFontIDs)
        let customFonts = allFonts.filter { $0.source == .community && customIDs.contains($0.id) }
        defaults.set(try? JSONEncoder().encode(customSources), forKey: customSourcesKey)
        defaults.set(try? JSONEncoder().encode(customFonts), forKey: customFontsKey)
    }
}

private struct RepositoryUpdate: Decodable {
    let pushedAt: String

    enum CodingKeys: String, CodingKey {
        case pushedAt = "pushed_at"
    }
}

enum FontLibraryError: LocalizedError {
    case downloadFailed
    case invalidFont
    case insecureURL
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            "The font download could not be completed."
        case .invalidFont:
            "The downloaded file is not a supported font, or exceeds 100 MB."
        case .insecureURL:
            "Font downloads require an HTTPS URL."
        case .registrationFailed(let message):
            "The font downloaded, but registration failed: \(message)"
        }
    }
}
