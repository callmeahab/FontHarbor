// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct SourceSidebar: View {
    let library: FontLibrary
    let addSource: () -> Void
    @State private var sourceToRemove: CustomFontSource?
    @State private var isConfirmingRemoval = false

    var body: some View {
        List(selection: Binding<LibraryScope?>(
            get: { library.selectedScope },
            set: { if let scope = $0 { library.selectScope(scope) } }
        )) {
            SidebarBrand()
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 14, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .allowsHitTesting(false)

            Section("Library") {
                SidebarRow(title: "All Fonts", systemImage: "square.grid.2x2", count: library.allFonts.count, tint: .accentColor)
                    .tag(LibraryScope.all)
                SidebarRow(title: "Favorites", systemImage: "heart.fill", count: library.favoriteFontIDs.count, tint: .pink)
                    .tag(LibraryScope.favorites)
                SidebarRow(title: "Installed", systemImage: "checkmark.seal.fill", count: library.installedFontIDs.count, tint: .green)
                    .tag(LibraryScope.installed)
            }

            Section("Collections") {
                ForEach(CuratedCollection.allCases) { collection in
                    SidebarRow(title: collection.rawValue, systemImage: collection.icon,
                               count: library.collectionCounts[collection, default: 0], tint: .purple)
                        .tag(LibraryScope.collection(collection))
                }
            }

            Section("Sources") {
                ForEach(FontSource.allCases.filter { library.sourceCounts[$0, default: 0] > 0 }) { source in
                    SidebarRow(title: source.rawValue, systemImage: source.icon,
                               count: library.sourceCounts[source, default: 0], tint: source.color)
                        .tag(LibraryScope.source(source))
                }
            }

            if !library.customSources.isEmpty {
                Section("My Sources") {
                    ForEach(library.customSources) { source in
                        SidebarRow(title: source.name, systemImage: "shippingbox.fill",
                                   count: source.fontIDs.count, tint: .teal)
                            .tag(LibraryScope.custom(source.id))
                            .contextMenu {
                                Button("Remove Source…", role: .destructive) {
                                    sourceToRemove = source
                                    isConfirmingRemoval = true
                                }
                            }
                    }
                }
            }

            Button(action: addSource) {
                Label("Add Source…", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("Font Harbor")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                Text("\(library.sourceCounts.count + library.customSources.count) sources")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(14)
        }
        .confirmationDialog("Remove \(sourceToRemove?.name ?? "source")? Installed fonts will be kept.",
                            isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            if let source = sourceToRemove {
                Button("Remove Source", role: .destructive) { library.removeSource(source) }
            }
        }
    }
}

struct SidebarRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack {
            Label {
                Text(title).lineLimit(1)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(tint)
            }
            Spacer(minLength: 4)
            Text(count, format: .number)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

struct SidebarBrand: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat.alt")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .shadow(color: .purple.opacity(0.3), radius: 8, y: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Font Harbor").font(.headline)
                Text("Open type, one click").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
