// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

// MARK: - Browser

struct FontBrowser: View {
    let library: FontLibrary

    var body: some View {
        VStack(spacing: 0) {
            BrowserHeader(library: library)
            Divider()
            if library.visibleFonts.isEmpty {
                BrowserEmptyState(library: library)
            } else if library.browserLayout == .list {
                FontList(library: library)
            } else {
                FontGrid(library: library)
            }
        }
        .navigationTitle(library.scopeTitle)
        .task(id: library.visibleFonts.map(\.id)) {
            await library.preloadPreviews(library.visibleFonts)
        }
    }
}

struct BrowserHeader: View {
    let library: FontLibrary

    var body: some View {
        HStack(spacing: 10) {
            Label("\(library.visibleFonts.count) families", systemImage: "textformat")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Category", selection: Binding(
                get: { library.selectedCategory },
                set: { library.selectedCategory = $0 }
            )) {
                Text("All styles").tag(FontCategory?.none)
                ForEach(FontCategory.allCases) { category in
                    Text(category.rawValue).tag(Optional(category))
                }
            }
            .labelsHidden()
            .frame(width: 125)

            Picker("Layout", selection: Binding(
                get: { library.browserLayout },
                set: { library.browserLayout = $0 }
            )) {
                ForEach(BrowserLayout.allCases) { layout in
                    Image(systemName: layout.systemImage).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 72)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct BrowserEmptyState: View {
    let library: FontLibrary

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        } actions: {
            if !library.searchText.isEmpty || library.selectedCategory != nil {
                Button("Clear Filters") { library.clearFilters() }
            }
        }
    }

    private var title: String {
        if !library.searchText.isEmpty || library.selectedCategory != nil { return "No Matching Fonts" }
        switch library.selectedScope {
        case .favorites: return "No Favorites Yet"
        case .installed: return "No Installed Fonts"
        default: return "No Fonts Here"
        }
    }
    private var icon: String {
        switch library.selectedScope {
        case .favorites: "heart"
        case .installed: "arrow.down.circle"
        default: "text.magnifyingglass"
        }
    }
    private var description: String {
        if !library.searchText.isEmpty || library.selectedCategory != nil {
            return "Try another search or clear the filters in \(library.scopeTitle)."
        }
        switch library.selectedScope {
        case .favorites: return "Save a family using the heart in its preview."
        case .installed: return "Choose a family from All Fonts and click Install."
        default: return "Add a font source to start exploring."
        }
    }
}

struct FontList: View {
    let library: FontLibrary

    var body: some View {
        List(selection: Binding(get: { library.selectedFontID }, set: { library.selectedFontID = $0 })) {
            ForEach(library.visibleFonts) { font in
                HStack(spacing: 12) {
                    SourceArtwork(source: font.source, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        ExactSpecimenText(text: "Hamburgefonts", font: font, size: 22, library: library)
                            .lineLimit(1)
                        Text(font.family).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    FontRowActions(font: font, library: library)
                }
                .padding(.vertical, 7)
                .tag(font.id)
                .contextMenu {
                    Button(library.favoriteFontIDs.contains(font.id) ? "Remove Favorite" : "Add to Favorites") { library.toggleFavorite(font) }
                    Button(library.comparedFontIDs.contains(font.id) ? "Unpin Comparison" : "Pin for Comparison") { library.toggleComparison(font) }
                        .disabled(!library.canCompare(font))
                }
                .task { await library.preparePreview(font) }
            }
        }
        .listStyle(.inset)
        .accessibilityLabel("Font families")
    }
}

struct FontGrid: View {
    let library: FontLibrary
    private let columns = [GridItem(.adaptive(minimum: 185), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(library.visibleFonts) { font in
                    FontGridCard(font: font, library: library)
                }
            }
            .padding(10)
        }
    }
}

struct FontGridCard: View {
    let font: OpenFont
    let library: FontLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SourceArtwork(source: font.source, size: 30)
                Spacer()
                FontRowActions(font: font, library: library)
            }
            Button {
                library.selectedFontID = font.id
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ExactSpecimenText(text: "Ag", font: font, size: 56, library: library)
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    Text(font.family).font(.headline).lineLimit(1)
                    Text(font.category.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(font.family)")
        }
        .padding(15)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(library.selectedFontID == font.id ? Color.accentColor : Color.secondary.opacity(0.16), lineWidth: library.selectedFontID == font.id ? 2 : 1)
        }
        .accessibilityAddTraits(library.selectedFontID == font.id ? [.isSelected] : [])
        .task { await library.preparePreview(font) }
    }
}

struct FontRowActions: View {
    let font: OpenFont
    let library: FontLibrary

    var body: some View {
        HStack(spacing: 7) {
            if library.previewDownloadIDs.contains(font.id) {
                ProgressView().controlSize(.mini)
            }
            if library.favoriteFontIDs.contains(font.id) {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
            Button {
                library.toggleComparison(font)
            } label: {
                Image(systemName: library.comparedFontIDs.contains(font.id) ? "rectangle.stack.fill" : "rectangle.stack")
            }
            .buttonStyle(.plain)
            .foregroundStyle(library.comparedFontIDs.contains(font.id) ? .purple : .secondary)
            .help(library.canCompare(font) ? "Pin or unpin for comparison" : "Comparison holds up to four fonts")
            .accessibilityLabel(library.comparedFontIDs.contains(font.id) ? "Unpin \(font.family)" : "Compare \(font.family)")
            .disabled(!library.canCompare(font))
            if library.installedFontIDs.contains(font.id) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .font(.caption)
    }
}

struct SourceArtwork: View {
    let source: FontSource
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(
                    LinearGradient(
                        colors: [source.color.opacity(0.9), source.color.opacity(0.66)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.24)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
            Image(systemName: source.icon)
                .font(.system(size: size * 0.34, weight: .medium))
                .foregroundStyle(.white.opacity(0.94))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
    }
}

struct ExactSpecimenText: View {
    let text: String
    let font: OpenFont
    let size: CGFloat
    let library: FontLibrary
    var variation = VariationSettings()

    var body: some View {
        if let nsFont = library.swiftUIFont(for: font, size: size, variation: variation) {
            Text(text)
                .font(Font(nsFont))
        } else {
            ZStack(alignment: .leading) {
                Text(text)
                    .font(.system(size: size, design: font.category.design))
                    .redacted(reason: .placeholder)
                    .foregroundStyle(.tertiary)
                    .opacity(0.35)
                    .accessibilityHidden(true)

                if library.previewErrors[font.id] == nil {
                    ProgressView()
                        .controlSize(size >= 40 ? .regular : .small)
                        .accessibilityLabel("Loading preview for \(font.family)")
                } else {
                    Label("Preview unavailable", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

