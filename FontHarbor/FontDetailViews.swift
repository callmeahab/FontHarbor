// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

// MARK: - Detail workstation

struct FontDetail: View {
    let font: OpenFont
    let library: FontLibrary
    @State private var previewText = PreviewPreset.headline.text
    @State private var previewSize = PreviewPreset.headline.suggestedSize
    @State private var preset = PreviewPreset.headline
    @State private var theme = SpecimenTheme.paper
    @State private var variation = VariationSettings()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                EditorialHero(font: font, library: library)
                SpecimenWorkbench(
                    font: font,
                    library: library,
                    text: $previewText,
                    size: $previewSize,
                    preset: $preset,
                    theme: $theme,
                    variation: $variation
                )
                EditorialSpecimens(font: font, library: library, variation: variation)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        VariationControls(font: font, runtime: library.runtimeInfo[font.id], variation: $variation).frame(minWidth: 260)
                        GlyphCoverage(font: font, runtime: library.runtimeInfo[font.id], library: library).frame(minWidth: 260)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 18) {
                        VariationControls(font: font, runtime: library.runtimeInfo[font.id], variation: $variation)
                        GlyphCoverage(font: font, runtime: library.runtimeInfo[font.id], library: library)
                    }
                }
                FontMetadata(font: font)
            }
            .padding(22)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                RadialGradient(
                    colors: [font.source.color.opacity(0.17), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 720
                )
            }
            .ignoresSafeArea()
        }
        .navigationTitle(font.family)
        .task {
            await library.preparePreview(font)
            await library.prepareRepositoryMetadata(font)
        }
        .safeAreaInset(edge: .bottom) {
            FontInspectorBar(font: font, runtime: library.runtimeInfo[font.id], library: library)
        }

    }
}

struct FontInlineStatus: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .lineLimit(2)
            Spacer(minLength: 12)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .help("Dismiss message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.28))
        }
        .accessibilityElement(children: .contain)
    }
}

struct EditorialHero: View {
    let font: OpenFont
    let library: FontLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SourceArtwork(source: font.source, size: 72)
                Spacer()
                Button {
                    library.toggleFavorite(font)
                } label: {
                    Image(systemName: library.favoriteFontIDs.contains(font.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(library.favoriteFontIDs.contains(font.id) ? .pink : .secondary)
                }
                .buttonStyle(.glass)
                .help(library.favoriteFontIDs.contains(font.id) ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(library.favoriteFontIDs.contains(font.id) ? "Remove from Favorites" : "Add to Favorites")
            }
            ExactSpecimenText(text: font.family, font: font, size: 78, library: library)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
            Text("Designed by \(font.designer)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(font.description)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassEffect(.regular.tint(font.source.color.opacity(0.12)), in: .rect(cornerRadius: 24))
    }
}

struct SpecimenWorkbench: View {
    let font: OpenFont
    let library: FontLibrary
    @Binding var text: String
    @Binding var size: Double
    @Binding var preset: PreviewPreset
    @Binding var theme: SpecimenTheme
    @Binding var variation: VariationSettings

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    presetPicker
                    themePicker
                    sizeControl
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 12) {
                    HStack { presetPicker; themePicker }
                    sizeControl
                }
            }
            .padding(14)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.background)
                TextEditor(text: $text)
                    .font(library.swiftUIFont(for: font, size: size, variation: variation).map(Font.init) ?? .system(size: size, design: font.category.design))
                    .foregroundStyle(theme.foreground)
                    .scrollContentBackground(.hidden)
                    .padding(18)
                HStack(spacing: 7) {
                    if library.runtimeInfo[font.id] != nil {
                        Label("Exact preview", systemImage: "checkmark.seal.fill")
                    } else if library.previewErrors[font.id] != nil {
                        Text("Preview unavailable")
                        Button("Retry") { Task { await library.preparePreview(font) } }
                    } else {
                        ProgressView().controlSize(.mini)
                        Text("Loading font…")
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .padding(10)
                .background(theme.background.opacity(0.95), in: .rect(cornerRadius: 8))
                .padding(12)

            }
            .frame(minHeight: 270)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
    private var presetPicker: some View {
        Picker("Preset", selection: $preset) {
            ForEach(PreviewPreset.allCases) { preset in Text(preset.rawValue).tag(preset) }
        }
        .onChange(of: preset) { _, newValue in text = newValue.text; size = newValue.suggestedSize }
    }

    private var themePicker: some View {
        Picker("Theme", selection: $theme) {
            ForEach(SpecimenTheme.allCases) { theme in Text(theme.rawValue).tag(theme) }
        }.frame(width: 120)
    }

    private var sizeControl: some View {
        HStack {
            Text("\(Int(size)) pt").monospacedDigit().frame(width: 48)
            Slider(value: $size, in: 16...104).frame(minWidth: 100, maxWidth: 165)
                .accessibilityLabel("Preview font size")
        }
    }

}

struct EditorialSpecimens: View {
    let font: OpenFont
    let library: FontLibrary
    let variation: VariationSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Character").font(.headline)
            ExactSpecimenText(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", font: font, size: 34, library: library, variation: variation)
                .lineLimit(1).minimumScaleFactor(0.4)
            ExactSpecimenText(text: "abcdefghijklmnopqrstuvwxyz", font: font, size: 34, library: library, variation: variation)
                .lineLimit(1).minimumScaleFactor(0.4)
            ExactSpecimenText(text: "0123456789  ! ? @ # $ % & * ( )", font: font, size: 31, library: library, variation: variation)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct VariationControls: View {
    let font: OpenFont
    let runtime: FontRuntimeInfo?
    @Binding var variation: VariationSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Variable Axes", systemImage: "slider.horizontal.3").font(.headline)
            if let runtime {
                if runtime.axes.isEmpty {
                    Text("Static font").font(.subheadline.weight(.medium))
                    Text("This file has no variable axes.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(runtime.axes) { axis in
                        AxisSlider(label: axis.name, value: Binding(
                            get: { variation.value(for: axis) },
                            set: { variation.values[axis.id] = $0 }
                        ), range: axis.minimum...axis.maximum, valueLabel: variation.value(for: axis))
                            .disabled(axis.minimum == axis.maximum)
                    }
                    Button("Reset to Defaults") { variation = VariationSettings() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } else {
                Text("Axes appear after the font loads.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct AxisSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueLabel: Double

    var body: some View {
        HStack {
            Text(label).frame(width: 82, alignment: .leading)
            Slider(value: $value, in: range).accessibilityLabel(label)
            Text(valueLabel, format: .number.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .font(.caption)
    }
}

struct GlyphCoverage: View {
    let font: OpenFont
    let runtime: FontRuntimeInfo?
    let library: FontLibrary
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Character Samples", systemImage: "character.book.closed").font(.headline)
            TextField("Find a character", text: $search)
                .textFieldStyle(.roundedBorder)
            if let runtime {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 6) {
                        ForEach(filteredGlyphs(runtime.glyphs), id: \.self) { glyph in
                            ExactSpecimenText(text: glyph, font: font, size: 20, library: library)
                                .frame(width: 34, height: 34)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .frame(height: 112)
                Text("Sampled scripts: " + runtime.scripts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(library.previewErrors[font.id] == nil ? "Loading character samples…" : "Character samples are unavailable until the font loads.")
                    .font(.callout).foregroundStyle(.secondary).frame(height: 130)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func filteredGlyphs(_ glyphs: [String]) -> [String] {
        search.isEmpty ? glyphs : glyphs.filter { $0.localizedCaseInsensitiveContains(search) }
    }
}

struct InstallCapsule: View {
    let font: OpenFont
    let library: FontLibrary
    @State private var isConfirmingRemoval = false

    var body: some View {
        if library.installedFontIDs.contains(font.id) {
            Button {
                isConfirmingRemoval = true
            } label: {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .tint(.green)
            .help("Remove installed font")
            .confirmationDialog("Remove \(font.family) from your installed fonts?", isPresented: $isConfirmingRemoval) {
                Button("Remove Font", role: .destructive) { library.remove(font) }
            }
        } else {
            Button {
                Task { await library.install(font) }
            } label: {
                HStack(spacing: 7) {
                    if library.activeDownloadIDs.contains(font.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(library.activeDownloadIDs.contains(font.id) ? "Installing…" : "Install")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(library.activeDownloadIDs.contains(font.id))
        }
    }
}

struct FontInspectorBar: View {
    let font: OpenFont
    let runtime: FontRuntimeInfo?
    let library: FontLibrary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 18) {
            InspectorItem(icon: "doc", value: runtime?.format ?? font.downloadURL.pathExtension.uppercased())
            InspectorItem(icon: "internaldrive", value: runtime.map { ByteCountFormatter.string(fromByteCount: $0.fileSize, countStyle: .file) } ?? "—")
            InspectorItem(icon: "textformat.size", value: "\(runtime?.styleCount ?? 1) style")
            InspectorItem(icon: "slider.horizontal.3", value: runtime?.axes.isEmpty == false ? "\(runtime?.axes.count ?? 0) axes" : "Static")
            InspectorItem(icon: "checkmark.shield", value: font.license)
            InspectorItem(
                icon: "clock.arrow.circlepath",
                value: runtime?.repositoryUpdatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Update unknown"
            )
            Spacer()
            Text(font.source.rawValue).foregroundStyle(font.source.color)
        }
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.bar)
    }
}

struct InspectorItem: View {
    let icon: String
    let value: String

    var body: some View {
        Label(value, systemImage: icon).foregroundStyle(.secondary)
    }
}

struct FontMetadata: View {
    let font: OpenFont

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About this font").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 12) {
                MetadataRow(label: "Source", value: font.source.rawValue)
                MetadataRow(label: "Category", value: font.category.rawValue)
                MetadataRow(label: "License", value: font.license)
                GridRow {
                    Text("Tags").foregroundStyle(.secondary)
                    WrappingTagsLayout {
                        ForEach(font.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                                .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct MetadataRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}

