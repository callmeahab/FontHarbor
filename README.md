<p align="center"><img src="Branding/AppIcon.png" width="128" alt="Font Harbor icon"></p>

# Font Harbor

A native macOS browser for finding, previewing, comparing, and installing fonts from open font catalogs and your own sources.

Font Harbor includes metadata for roughly 2,000 Google Fonts and Nerd Fonts families. Font files download on demand; previews do not install fonts for other apps.

- Browse by source, category, or curated collection. Search names, designers, and tags.
- Save favorites and compare two to four families with the same specimen text.
- Try editable specimens, color themes, and the variable axes supported by each font file.
- Inspect character samples, file details, and repository links.
- Add GitHub repositories or direct HTTPS font URLs.
- Get a recommendation from Apple Intelligence when available, with a category-based fallback.

## Build and run

Requires macOS 26 or later and Xcode 26 or later (Swift 6.2+). Apple Intelligence features require an eligible Mac, enabled Apple Intelligence, and a downloaded on-device model. Browsing, installation, and source discovery work without it.

Open `FontHarbor.xcodeproj`, choose the shared **FontHarbor** scheme and **My Mac**, then run. For a signed local build, select your own development team in Signing & Capabilities.

Or build an unsigned universal app without a developer account:

```sh
Scripts/build.sh Debug
open "build/Debug/Build/Products/Debug/Font Harbor.app"
```

No third-party package dependencies, API keys, or account are required. The Python utilities use the standard library.

## Development

```sh
Scripts/test.sh                  # Swift regression tests, Python tests, catalog validation
Scripts/build.sh Release         # unsigned arm64 + x86_64 app
Scripts/package_release.sh       # app archive, corresponding source archive, checksums
```

[Contributing](CONTRIBUTING.md) covers the code layout and UI checks. [Release instructions](docs/RELEASING.md) cover signing, notarization, and publication. [Investigation notes](docs/PROJECT_REVIEW.md) describe the fixes and remaining improvements.

Refresh the bundled catalog explicitly; builds do not fetch metadata:

```sh
python3 Scripts/generate_font_index.py
python3 Scripts/validate_catalog.py
```

The updater refuses incomplete upstream trees and writes the validated catalog atomically. Catalog validation checks structure and identities; it does not verify every font's current license or download availability.

## Data and network access

Favorites, custom sources, and layout preference are stored locally in the app's preferences. Preview files are stored in the app's cache; managed installed files are stored in its Application Support directory. Signed sandboxed builds keep these inside the app container.

Install registers the managed font file for the current macOS user session using Core Text. Font Harbor re-registers saved installations when it opens. Other apps may need to reopen their font menus. Font Harbor manages its own files; it does not import or remove fonts installed using Font Book.

Downloads contact the selected upstream provider. GitHub discovery and repository dates use GitHub's unauthenticated API, which can be rate limited. Apple Intelligence requests run through Apple's on-device Foundation Models framework. There is no app analytics or hosted backend.

## License

Font Harbor's original app code, scripts, documentation, and artwork are licensed under **GPL-3.0-only**. See [LICENSE](LICENSE).

Fonts and upstream catalog metadata retain their own licenses and attribution. No font binaries are included in the source repository. Review the source's license before using or redistributing a font; a repository-wide license may not cover every font file. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
