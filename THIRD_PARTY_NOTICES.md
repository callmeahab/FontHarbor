# Third-party sources and font licenses

Font Harbor has no third-party code dependencies. SwiftUI, AppKit, Core Text, CryptoKit and Foundation Models are Apple system frameworks; they are not redistributed with the source.

## Catalog metadata

`FontHarbor/FontIndex.json` is a generated metadata snapshot. `Scripts/generate_font_index.py` records the upstream sources and generation time. Family names, designer attribution and font licenses are retained in each record. This file does not contain font binaries. Upstream material remains subject to its upstream terms; Font Harbor's GPL does not relicense it.

- [Google Fonts](https://github.com/google/fonts): font metadata and links. The catalog includes fonts with SIL Open Font License, Apache License 2.0, and Ubuntu Font License labels. Consult the license file in each linked family directory for the applicable text, copyright and reserved names.
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts): patched developer font metadata and links. Base fonts and added icon glyphs can have distinct licenses. Consult the family directory and the project's [license information](https://github.com/ryanoasis/nerd-fonts#license); the catalog's generic label is not a license grant.

The curated entries also link to Inter, Montserrat, Lato, Playfair Display, Oswald, Raleway, Adobe Source families, JetBrains Mono, Fira Sans, Fira Code and Archivo. The app preserves their designer and repository attribution in the catalog. Actual files download directly from their linked upstream hosts.

## User-added sources

A GitHub repository's reported SPDX identifier is shown when available. That identifier may describe the repository's code rather than all font files. Direct font URLs and unrecognized licenses are labeled “Check repository license.” Discovery is not a license audit. Users are responsible for checking the font's own terms before use or redistribution.

## Artwork

The Font Harbor app icon is original typography artwork rendered from `Scripts/generate_app_icon.swift` using Core Graphics and Core Text. It uses an installed system font to draw letterforms; no font file or SF Symbol asset is redistributed in the icon. The sidebar uses Apple's native system symbol API within the app. Original artwork and rendering code are provided under GPL-3.0-only. See `Branding/README.md` for the source and regeneration steps.
