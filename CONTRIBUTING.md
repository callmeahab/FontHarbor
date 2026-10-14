# Contributing

Small, focused pull requests are welcome. For a larger UI or architecture change, open an issue describing the problem, a concrete example, and the proposed behavior first. Contributions are accepted under GPL-3.0-only.

Use Xcode 26+ on macOS 26+. Run `Scripts/test.sh` and `Scripts/build.sh Release` before submitting a change. Tests use temporary storage and an in-memory preferences fixture; they do not install fonts into your user session. The shipping app is the Xcode target; `Package.swift` is a dependency-free Swift Testing harness for the core code.

## Code layout

- `FontLibrary.swift`: observable UI state, filtering, registration and persistence.
- `FontCatalog.swift`: indexed search and shared collection membership.
- `FontDownloadStore.swift`: bounded, shared downloads, validation and cache I/O.
- `PreviewDownloadQueue.swift`: cancellation-aware concurrency permits.
- `SourceDiscovery.swift`: GitHub discovery and optional Foundation Models requests.
- `FontModels.swift`, `TypographyModels.swift`: catalog and specimen types.
- `ContentView.swift`: navigation and sheet coordination.
- The other view files contain the sidebar, browser, detail workstation and sheets.
- `Scripts/`: catalog, build, test, icon and release utilities.

Keep I/O out of SwiftUI view bodies. Preserve cancellation and download limits. Use actual font metadata for axis controls. Apply library filters through `LibraryScope`; do not assign an independently filtered array to the browser. Keep secrets, signing identities, Xcode user state and build products out of version control.

## UI verification

Check both light and dark appearances at 980 × 640 and a wider window. Verify keyboard list selection, search within Favorites/Installed/custom sources, empty results, preview failure and retry, static and variable fonts, four-font comparison limits, and source removal with shared or installed fonts. Use VoiceOver to check icon-only actions and sliders. A font preview failure should stay local to the affected font.

For installation changes, test a signed sandboxed build manually: install an unfamiliar font, use it in a second app, remove it, relaunch Font Harbor, and log out/in. This behavior is not covered by unit tests because it changes the user's font session.

## Catalog and artwork

Catalog changes should come from `Scripts/generate_font_index.py` and pass `Scripts/validate_catalog.py`. Do not add proprietary font binaries. Keep source links and licensing labels accurate; “check repository license” is preferable to an invented license.

The icon master is `Branding/AppIcon.png`. Regenerate all asset sizes with `Scripts/generate_app_icons.sh` on macOS. Its rendering source and provenance are recorded in [Branding/README.md](Branding/README.md).
