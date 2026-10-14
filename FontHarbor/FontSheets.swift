// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

// MARK: - Comparison & intelligence

struct ComparisonView: View {
    let library: FontLibrary
    @Binding var isPresented: Bool
    @State private var text = "Compare voices, rhythm, and texture."
    @State private var size = 44.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Font Comparison").font(.title.bold())
                    Text("Pin two to four families from the browser.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Comparison text", text: $text).frame(maxWidth: 360)
                Slider(value: $size, in: 18...76).frame(width: 140).accessibilityLabel("Comparison font size")
                Button("Done") { isPresented = false }.keyboardShortcut(.defaultAction)
            }
            .padding(22)
            Divider()

            if library.comparedFonts.isEmpty {
                ContentUnavailableView("No Fonts Pinned", systemImage: "rectangle.stack", description: Text("Pin fonts from the list or grid first."))
            } else {
                HStack(spacing: 0) {
                    ForEach(library.comparedFonts) { font in
                        ComparisonColumn(font: font, library: library, text: text, size: size)
                        if font.id != library.comparedFonts.last?.id { Divider() }
                    }
                }
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

struct ComparisonColumn: View {
    let font: OpenFont
    let library: FontLibrary
    let text: String
    let size: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SourceArtwork(source: font.source, size: 38)
                VStack(alignment: .leading) {
                    Text(font.family).font(.headline)
                    Text(font.category.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    library.toggleComparison(font)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            ExactSpecimenText(text: text, font: font, size: size, library: library)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            Divider()
            ExactSpecimenText(text: "Aa Bb Cc 0123", font: font, size: 32, library: library)
            Spacer()
            Text(font.license).font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .task { await library.preparePreview(font) }
    }
}

struct SurpriseMeView: View {
    let library: FontLibrary
    @Binding var isPresented: Bool
    @State private var brief = "A quiet luxury skincare brand"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Surprise Me", systemImage: "sparkles")
                .font(.title.bold())
                .foregroundStyle(.purple)
            Text(library.appleIntelligenceStatus.isAvailable ? "Describe a project or mood. Apple Intelligence will choose a family from your catalog." : "Describe a project or mood. Font Harbor will suggest a family using its category and tags.")
                .foregroundStyle(.secondary)
            TextField("Creative brief", text: $brief, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            Label(library.appleIntelligenceStatus.message, systemImage: library.appleIntelligenceStatus.isAvailable ? "apple.intelligence" : "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    Task {
                        _ = await library.recommend(for: brief)
                        isPresented = false
                    }
                } label: {
                    if library.isRecommending {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Choose a Font", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || library.isRecommending)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 500)
    }
}

// MARK: - Source discovery

struct AddSourceView: View {
    let library: FontLibrary
    @Binding var isPresented: Bool
    @State private var request = ""
    @State private var discoveryError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AddSourceHeader(status: library.appleIntelligenceStatus)
            if let discoveryError {
                FontInlineStatus(message: discoveryError) { self.discoveryError = nil }
            }
            TextField("GitHub URL, direct font URL, or describe what you want", text: $request, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .onSubmit { discover() }
            VStack(alignment: .leading, spacing: 7) {
                Text("Examples").font(.headline)
                Text("https://github.com/IBM/plex")
                Text("A friendly variable serif for long-form reading")
                Text("Open-source monospace fonts with coding ligatures")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    discover()
                } label: {
                    if library.isDiscovering {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Find Fonts", systemImage: library.appleIntelligenceStatus.isAvailable ? "apple.intelligence" : "magnifyingglass")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || library.isDiscovering)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 540)
    }

    private func discover() {
        guard !library.isDiscovering else { return }
        let submittedRequest = request
        discoveryError = nil
        Task {
            if await library.addSource(submittedRequest) {
                isPresented = false
            } else {
                discoveryError = library.errorMessage
                library.errorMessage = nil
            }
        }
    }
}

struct AddSourceHeader: View {
    let status: AppleIntelligenceStatus

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: status.isAvailable ? "apple.intelligence" : "text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(status.isAvailable ? .purple : .secondary)
                .frame(width: 48, height: 48)
                .glassEffect(in: .rect(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text("Add a Font Source").font(.title2.bold())
                Text("Paste a repository or describe a font. Font Harbor finds installable files and keeps the source in your library. Check each source’s font license before use.")
                    .foregroundStyle(.secondary)
                Label(status.message, systemImage: status.isAvailable ? "checkmark.circle.fill" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(status.isAvailable ? .green : .secondary)
            }
        }
    }
}

