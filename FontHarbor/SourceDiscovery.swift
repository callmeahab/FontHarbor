// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import FoundationModels

@Generable(description: "A concise GitHub repository search for open-source fonts")
struct FontSearchPlan {
    @Guide(description: "GitHub search terms only, without explanations")
    var query: String
}

@Generable(description: "A font family recommendation from a supplied catalog")
struct FontRecommendation {
    @Guide(description: "The exact family name from the supplied catalog")
    var family: String
}

struct SourceDiscoveryResult: Sendable {
    let source: CustomFontSource
    let fonts: [OpenFont]
    let usedAppleIntelligence: Bool
}

@MainActor
final class FontSourceDiscovery {
    private let decoder = JSONDecoder()

    func discover(_ input: String) async throws -> SourceDiscoveryResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SourceDiscoveryError.emptyRequest }

        if let url = URL(string: trimmed), url.scheme != nil {
            guard url.scheme?.lowercased() == "https", url.host() != nil,
                  url.user == nil, url.password == nil else { throw SourceDiscoveryError.invalidURL }
            if GitHubRepositoryReference(input: trimmed) == nil,
               !["ttf", "otf", "ttc", "otc"].contains(url.pathExtension.lowercased()) {
                throw SourceDiscoveryError.unsupportedURL
            }
        }
        if let url = URL(string: trimmed), url.scheme == "https", GitHubRepositoryReference(input: trimmed) == nil, ["ttf", "otf", "ttc", "otc"].contains(url.pathExtension.lowercased()) {
            let font = makeFont(
                path: url.lastPathComponent,
                downloadURL: url,
                repositoryURL: url.deletingLastPathComponent(),
                sourceName: url.host() ?? "Custom source"
            )
            return SourceDiscoveryResult(
                source: CustomFontSource(id: UUID(), name: url.host() ?? "Custom source", location: trimmed, fontIDs: [font.id]),
                fonts: [font],
                usedAppleIntelligence: false
            )
        }

        if let repository = GitHubRepositoryReference(input: trimmed) {
            let fonts = try await fonts(in: repository)
            guard !fonts.isEmpty else { throw SourceDiscoveryError.noFontsFound }
            return SourceDiscoveryResult(
                source: CustomFontSource(id: UUID(), name: repository.name, location: trimmed, fontIDs: fonts.map(\.id)),
                fonts: fonts,
                usedAppleIntelligence: false
            )
        }

        let plan = await searchPlan(for: trimmed)
        let repositories = try await searchRepositories(matching: plan.query)
        var discovered: [OpenFont] = []
        var names: [String] = []

        for repository in repositories.prefix(3) {
            let fonts = (try? await fonts(in: repository)) ?? []
            if !fonts.isEmpty {
                discovered.append(contentsOf: fonts.prefix(12))
                names.append(repository.name)
            }
        }

        let uniqueFonts = Array(Dictionary(grouping: discovered, by: \.id).compactMap(\.value.first))
            .sorted { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
        guard !uniqueFonts.isEmpty else { throw SourceDiscoveryError.noFontsFound }

        let sourceName = names.isEmpty ? plan.query : names.joined(separator: ", ")
        return SourceDiscoveryResult(
            source: CustomFontSource(id: UUID(), name: sourceName, location: trimmed, fontIDs: uniqueFonts.map(\.id)),
            fonts: uniqueFonts,
            usedAppleIntelligence: plan.usedAppleIntelligence
        )
    }

    func recommendFont(for request: String, candidates: [OpenFont]) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw SourceDiscoveryError.intelligenceUnavailable
        }
        let catalog = candidates.prefix(80).map {
            "\($0.family) — \($0.category.rawValue), \($0.tags.joined(separator: ", "))"
        }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            Recommend exactly one family from the supplied font catalog for the creative brief. Return its family name exactly as written. Consider tone, medium, readability, and category. Prefer an unexpected but defensible choice, and vary the choice when several families fit equally well.
            """)
        let options = GenerationOptions(
            samplingMode: .random(probabilityThreshold: 0.9),
            temperature: 0.9,
            maximumResponseTokens: 80
        )
        let response = try await session.respond(
            to: "Creative brief: \(request)\n\nFont catalog:\n\(catalog)",
            generating: FontRecommendation.self,
            options: options
        )
        return response.content.family
    }

    static var appleIntelligenceStatus: AppleIntelligenceStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case .unavailable(.deviceNotEligible):
            .unavailable("This Mac does not support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            .unavailable("Apple Intelligence is turned off.")
        case .unavailable(.modelNotReady):
            .unavailable("Apple Intelligence is still preparing its on-device model.")
        case .unavailable:
            .unavailable("Apple Intelligence is currently unavailable.")
        }
    }

    private func searchPlan(for request: String) async -> (query: String, usedAppleIntelligence: Bool) {
        guard SystemLanguageModel.default.isAvailable else {
            return ("\(request) font in:name,description,readme", false)
        }

        do {
            let session = LanguageModelSession(instructions: """
                Convert the request into short GitHub search terms that locate repositories containing downloadable, open-source font files. Preserve family, style, language, and use-case words. Do not invent repository names.
                """)
            let response = try await session.respond(
                to: request,
                generating: FontSearchPlan.self
            )
            return ("\(response.content.query) font in:name,description,readme", true)
        } catch {
            return ("\(request) font in:name,description,readme", false)
        }
    }

    private func searchRepositories(matching query: String) async throws -> [GitHubRepositoryReference] {
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "per_page", value: "5")
        ]
        let response: RepositorySearchResponse = try await githubRequest(components.url!)
        return response.items.map {
            GitHubRepositoryReference(owner: $0.owner.login, name: $0.name, defaultBranch: $0.defaultBranch)
        }
    }

    private func fonts(in repository: GitHubRepositoryReference) async throws -> [OpenFont] {
        // Fetch metadata even for search results: the default branch alone loses license information.
        let metadata: RepositoryMetadata = try await githubRequest(
            URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)")!
        )
        let branch = metadata.defaultBranch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%"))) ?? metadata.defaultBranch

        let tree: RepositoryTree = try await githubRequest(
            URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)/git/trees/\(branch)?recursive=1")!
        )

        guard !tree.truncated else { throw SourceDiscoveryError.truncatedRepository }

        let candidates = tree.tree
            .filter { item in
                guard item.type == "blob" else { return false }
                return ["ttf", "otf", "ttc", "otc"].contains(URL(filePath: item.path).pathExtension.lowercased())
                    && !item.path.localizedCaseInsensitiveContains("webfont")
            }
            .sorted { lhs, rhs in
                fontPathScore(lhs.path) > fontPathScore(rhs.path)
            }
            .prefix(24)

        let repositoryURL = URL(string: "https://github.com/\(repository.owner)/\(repository.name)")!
        return candidates.compactMap { item in
            let encodedPath = Self.encodePath(item.path)
            guard let downloadURL = URL(
                string: "https://raw.githubusercontent.com/\(repository.owner)/\(repository.name)/\(tree.sha)/\(encodedPath)"
            ) else { return nil }
            return makeFont(
                path: item.path,
                downloadURL: downloadURL,
                repositoryURL: repositoryURL,
                sourceName: metadata.fullName,
                license: metadata.license?.spdxID
            )
        }
    }

    private func makeFont(
        path: String,
        downloadURL: URL,
        repositoryURL: URL,
        sourceName: String,
        license: String? = nil
    ) -> OpenFont {
        let fileName = URL(filePath: path).lastPathComponent
        let rawName = URL(filePath: fileName).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let family = rawName
            .replacingOccurrences(of: "Variable", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Regular", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "VF", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Wght", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Wdth", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Opsz", with: "", options: .caseInsensitive)
            .split(separator: " ")
            .filter { !["bold", "italic", "light", "medium", "semibold", "thin", "black"].contains($0.lowercased()) }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        let finalFamily = family.isEmpty ? rawName : family
        let category: FontCategory = {
            let lowercased = path.lowercased()
            if lowercased.contains("mono") || lowercased.contains("code") { return .monospace }
            if lowercased.contains("serif") && !lowercased.contains("sans") { return .serif }
            if lowercased.contains("display") || lowercased.contains("decorative") { return .display }
            return .sansSerif
        }()

        return OpenFont(
            id: "community-\(sourceName)-\(path)",
            family: finalFamily,
            designer: sourceName,
            category: category,
            source: .community,
            license: (license == nil || license == "NOASSERTION") ? "Check repository license" : license!,
            description: "Discovered from \(sourceName). Review the repository license before installing.",
            tags: path.lowercased().contains("variable") || path.contains("[") ? ["Community", "Variable"] : ["Community"],
            downloadURL: downloadURL,
            repositoryURL: repositoryURL,
            fileName: fileName
        )
    }

    private func fontPathScore(_ path: String) -> Int {
        let lowercased = path.lowercased()
        var score = 0
        if lowercased.contains("variable") || lowercased.contains("[") { score += 10 }
        if lowercased.contains("regular") { score += 6 }
        if lowercased.contains("/fonts/") { score += 3 }
        if lowercased.contains("static") { score -= 2 }
        if lowercased.contains("italic") { score -= 1 }
        return score
    }

    private static func encodePath(_ path: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%"))
        return path.split(separator: "/", omittingEmptySubsequences: false).map {
            String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0)
        }.joined(separator: "/")
    }

    private func githubRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("FontHarbor/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SourceDiscoveryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 || (httpResponse.statusCode == 403 && httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0") {
                throw SourceDiscoveryError.rateLimited
            }
            throw SourceDiscoveryError.githubStatus(httpResponse.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

enum AppleIntelligenceStatus: Equatable, Sendable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .available: "Apple Intelligence available"
        case .unavailable(let reason): reason
        }
    }
}

enum SourceDiscoveryError: LocalizedError {
    case emptyRequest
    case invalidURL
    case unsupportedURL
    case truncatedRepository
    case invalidResponse
    case noFontsFound
    case rateLimited
    case githubStatus(Int)
    case intelligenceUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Use an HTTPS URL without embedded credentials."
        case .unsupportedURL: "Use a GitHub repository URL or a direct .ttf, .otf, .ttc, or .otc URL."
        case .truncatedRepository: "This repository is too large to inspect completely. Paste a direct font URL instead."
        case .emptyRequest: "Enter a GitHub repository, direct font URL, or a description."
        case .invalidResponse: "The source returned an invalid response."
        case .noFontsFound: "No installable .ttf, .otf, .ttc, or .otc files were found."
        case .rateLimited: "GitHub's anonymous API limit was reached. Try again later."
        case .githubStatus(let status): "GitHub returned HTTP status \(status)."
        case .intelligenceUnavailable: "Apple Intelligence is unavailable."
        }
    }
}

struct GitHubRepositoryReference: Sendable {
    let owner: String
    let name: String
    let defaultBranch: String?

    init(owner: String, name: String, defaultBranch: String? = nil) {
        self.owner = owner
        self.name = name
        self.defaultBranch = defaultBranch
    }

    init?(input: String) {
        guard let url = URL(string: input), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              let host = url.host()?.lowercased(),
              host == "github.com" || host == "www.github.com" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2 else { return nil }
        let repositoryName = components[1].hasSuffix(".git") ? String(components[1].dropLast(4)) : components[1]
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard !repositoryName.isEmpty,
              components[0].unicodeScalars.allSatisfy({ allowed.contains($0) }),
              repositoryName.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              ![".", ".."].contains(components[0]), ![".", ".."].contains(repositoryName) else { return nil }
        owner = components[0]
        name = repositoryName
        defaultBranch = nil
    }
}

private struct RepositorySearchResponse: Decodable, Sendable {
    let items: [RepositorySearchItem]
}

private struct RepositorySearchItem: Decodable, Sendable {
    let name: String
    let owner: RepositoryOwner
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case name, owner
        case defaultBranch = "default_branch"
    }
}

private struct RepositoryOwner: Decodable, Sendable {
    let login: String
}

private struct RepositoryMetadata: Decodable, Sendable {
    let name: String
    let fullName: String
    let defaultBranch: String
    let license: RepositoryLicense?

    enum CodingKeys: String, CodingKey {
        case name, license
        case fullName = "full_name"
        case defaultBranch = "default_branch"
    }
}

private struct RepositoryLicense: Decodable, Sendable {
    let spdxID: String

    enum CodingKeys: String, CodingKey {
        case spdxID = "spdx_id"
    }
}

private struct RepositoryTree: Decodable, Sendable {
    let sha: String
    let truncated: Bool
    let tree: [RepositoryTreeItem]
}

private struct RepositoryTreeItem: Decodable, Sendable {
    let path: String
    let type: String
}
