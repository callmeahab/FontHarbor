// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct ContentView: View {
    @State private var library: FontLibrary
    @State private var isShowingSourceSheet = false
    @State private var isShowingComparison = false
    @State private var isShowingSurprise = false
    @State private var detailColumnWidth: CGFloat = 430
    @FocusState private var isSearchFocused: Bool

    init(library: FontLibrary? = nil) {
        _library = State(initialValue: library ?? FontLibrary())
    }

    var body: some View {
        NavigationSplitView {
            SourceSidebar(library: library) {
                isShowingSourceSheet = true
            }
            .navigationSplitViewColumnWidth(min: 205, ideal: 235)
        } content: {
            FontBrowser(library: library)
                .navigationSplitViewColumnWidth(min: 340, ideal: 390)
        } detail: {
            Group {
                if let font = library.selectedFont {
                    FontDetail(font: font, library: library)
                        .id(font.id)
                        .transition(.blurReplace)
                } else {
                    ContentUnavailableView(
                        "Choose a Font",
                        systemImage: "textformat",
                        description: Text("Select a family to explore its specimens and glyphs.")
                    )
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                detailColumnWidth = width
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = library.errorMessage {
                FontInlineStatus(message: message) { library.errorMessage = nil }
                    .padding(10)
            }
        }
        .toolbar {
            ToolbarSpacer(.fixed, placement: .navigation)
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    isShowingComparison = true
                } label: {
                    Label("Compare Fonts", systemImage: "rectangle.split.3x1")
                }
                .help("Compare \(library.comparedFontIDs.count) pinned fonts")
                .disabled(library.comparedFontIDs.count < 2)

                Button {
                    isShowingSourceSheet = true
                } label: {
                    Label("Add Source", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Menu {
                    Button("Search Fonts", systemImage: "magnifyingglass") { isSearchFocused = true }
                        .keyboardShortcut("f")
                    Button("Surprise Me", systemImage: "sparkles") { isShowingSurprise = true }
                    if let font = library.selectedFont {
                        Divider()
                        Button(library.comparedFontIDs.contains(font.id) ? "Unpin Comparison" : "Pin for Comparison", systemImage: "rectangle.stack") {
                            library.toggleComparison(font)
                        }
                        .disabled(!library.canCompare(font))
                        Button("View Source", systemImage: "arrow.up.right.square") {
                            NSWorkspace.shared.open(font.repositoryURL)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .menuIndicator(.hidden)
                .help("Font actions and recommendations")
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if let font = library.selectedFont {
                        InstallCapsule(font: font, library: library).id(font.id)
                            .fixedSize()
                    } else {
                        Button("Install", systemImage: "arrow.down.circle.fill") {}
                            .labelStyle(.titleAndIcon)
                            .buttonStyle(.glassProminent)
                            .disabled(true)
                            .fixedSize()
                    }
                    searchField
                }
                .controlSize(.large)
                .frame(width: max(0, detailColumnWidth - 32))
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $isShowingSourceSheet) {
            AddSourceView(library: library, isPresented: $isShowingSourceSheet)
        }
        .sheet(isPresented: $isShowingComparison) {
            ComparisonView(library: library, isPresented: $isShowingComparison)
        }
        .sheet(isPresented: $isShowingSurprise) {
            SurpriseMeView(library: library, isPresented: $isShowingSurprise)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search fonts", text: $library.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .accessibilityLabel("Search fonts, designers, or tags")
                .onKeyPress(.escape) {
                    library.searchText = ""
                    return .handled
                }
            if !library.searchText.isEmpty {
                Button {
                    library.searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .glassEffect(.regular, in: .capsule)
    }

}

#Preview {
    ContentView()
        .frame(width: 1380, height: 840)
}

#Preview("Add Source") {
    AddSourceView(library: FontLibrary(), isPresented: .constant(true))
}
