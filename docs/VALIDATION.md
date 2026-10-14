# Validation record

Verified locally on 2026-10-13 using macOS 27.0.1, Xcode 27.0 and Swift 6.4. The deployment target is macOS 26.0. macOS 26 and physical Intel hardware have not been tested in this session.

## Passed

- 12 Swift Testing regression tests in three suites, using temporary storage and in-memory preferences.
- Four Python unit tests for generation ranking and catalog validation failure cases.
- Structural validation of all 1,999 bundled font records, including unique IDs, HTTPS URLs, filenames and source summary counts.
- Release build in Swift 6 language mode, with both `arm64` and `x86_64` slices confirmed by `lipo`.
- App Info.plist contains version `1.0.0`, minimum macOS `26.0`, and the `AppIcon` name. The compiled icon resource is present.
- Simple icon master is a 1024 × 1024 PNG with alpha; the asset catalog supplies every required macOS 1×/2× size.
- Source packaging excludes Xcode user data, `.DS_Store`, Python caches and build products. App and source archives include GPL license information and third-party notices.
- A source/configuration scan found no embedded user filesystem paths, personal Xcode state, signing keys or application secrets in the packaged program/configuration files.

The build scripts were run with `FONTHARBOR_MACRO_SANDBOX=0` because this restricted host cannot launch a nested compiler sandbox. App sandbox settings remain enabled. The Xcode tools emitted host-service warnings about unavailable simulator services; the macOS build completed.

## UI evidence and limits

A local helper hosted the real SwiftUI views with temporary preferences and storage. Component captures were inspected at 1380 × 900 and 980 × 640, in light and dark appearances, including empty Favorites. These captures show the sidebar/browser content, editable text and compact workbench control reflow. Some macOS glass surfaces and their content are absent from AppKit bitmap captures; the environment denied window screenshot capture. They are not full visual acceptance screenshots.

The user's supplied native window screenshot confirmed the intended original logo and unified macOS panel appearance. The final sidebar implementation uses a native `.sidebar` List with system selection/sections, a continuous footer background, and the existing unified window toolbar. The final native-sidebar revision and compact toolbar were compiled successfully. The detail toolbar measures the pane width, anchors Install at its left inset and gives search the remaining space. Search supports a clear action, Escape, and a Cmd-F action in More. Inspection cards now share a row height, the metadata card fills the detail column, and tags wrap. The Release app was opened for review; its launch delegate refreshes the Dock image from the compiled simplified icon. Full live interaction and VoiceOver acceptance remain manual release checks.

## Still required before a public binary release

- Run the signed, sandboxed install/remove checks from `CONTRIBUTING.md`, including use in another app and after a new login.
- Verify on macOS 26 and Intel hardware, or distribute only architectures/platforms actually validated.
- Run the prepared workflow on the chosen host; hosted CI has not executed yet.
- Initialize Git from a normal terminal, review/commit/tag, and publish to the chosen repository.
- Sign and notarize any public binary with the maintainer's Developer ID credentials, then regenerate the archives/checksums from that reviewed source revision.

No repository publication, Developer ID signing or notarization was performed in this session.
