# Project investigation and release preparation

Reviewed on 2026-10-13. The starting project was a native SwiftUI macOS app with a 1,999-record metadata catalog, no third-party dependencies, and optional on-device Foundation Models integration. It had no Git repository, release documentation, shared scheme, app icon or regression tests.

## Changes made

| Finding | Result |
| --- | --- |
| Favorites, Installed and custom sources replaced a browser array directly; search then rebuilt All Fonts | One `LibraryScope` participates in every query. Selected rows recover when results return. |
| Every query re-sorted the catalog; sidebar body repeatedly scanned it | Sort/search indexing and source/collection counts are built on catalog changes. Selected and compared fonts use dictionary lookup. |
| Install and preview could download the same font twice | One actor-owned cache shares in-flight downloads, capped at four across both operations. Consumer cancellation releases unneeded queued work. |
| Punctuation-normalized cache IDs and plain install filenames could collide | Full identities become SHA-256 filenames; font contents are validated before caching/registration. Failed new installs roll back their files. |
| A cancelled queue waiter could leave a cancellation tombstone behind | Waiters are removed directly; a permit granted during cancellation is returned. Regression tests cover capacity recovery. |
| Background previews wrote a global error banner | Per-font errors, fallback status and retry. Source discovery errors appear inside its sheet. |
| All variable sliders were offered with arbitrary ranges | Render only axes reported by Core Text, with actual defaults, bounds and reset. Static fonts get an explicit explanation. |
| Browser buttons nested comparison buttons; list had no native selection model | Native `List` selection supports keyboard navigation; grid actions are siblings of the selection button. |
| Compact detail controls, toolbar and inspector could overflow; metadata had an intrinsic width | Workbench controls reflow; library toolbar controls use the navigation region and native fixed spacing, with secondary actions in More; inspection cards stretch to a shared row height, metadata spans the card column, tags wrap, and the inspector scrolls horizontally. |
| Removing one source could delete a font shared by another, and lose saved installed community fonts | Retain shared/installed entries and persist the retained custom catalog. Source removal asks for confirmation. |
| Discovery dropped license metadata for search results and accepted unsafe schemes | Fetch repository metadata, validate HTTPS URLs/hosts, preserve license uncertainty, reject truncated trees. |
| Fira Code and Archivo were labeled as patched Nerd Fonts/Fontshare | Correct the curated entries to Google Fonts, their actual download catalog. Hide empty sources. |
| No reproducible release setup | GPL-3.0-only license, source notices, contributor/security docs, shared scheme, tests, universal build/package scripts and CI. |

The UI keeps the existing specimen-first design and restrained glass styling. The left panel uses the native macOS sidebar list, system selection and section styling, with a continuous sidebar background and the unified window toolbar. The app icon follows the original simple typography mark; the sidebar retains that native mark. The view code has been split into focused files for contributors.

## Verification

Swift regression tests exercise scoped filtering, selection recovery, shared-source removal, failed installation state, supported variation bounds, safe repository parsing, collision-resistant filenames, invalid font rejection, concurrent cache reuse, and queue cancellation/concurrency. Python tests cover catalog generation choices and structural validation. Validation checks all 1,999 bundled metadata records.

Build verification and visual checks are recorded in `docs/VALIDATION.md`. Hosted CI has not run yet. No public repository, signed release or notarization has been created.

## Useful next improvements

- Add cache size controls and an explicit refresh action for upstream fonts that change under stable URLs.
- Expand character inspection beyond the current representative samples; single-character script checks do not establish full language coverage.
- Add repository-specific font license-file discovery. The GitHub repository SPDX field is informational, not proof of every font's license.
- Add a signed macOS integration test for install/remove behavior in another app and after a new login session.
- Measure scrolling and font descriptor allocation with Instruments on slower Macs before adding more caching.
- Add UI automation coverage for compact windows, VoiceOver, comparison sheets and disconnected networks.

There is intentionally no public font redistribution bundle; the release packages contain app code, generated metadata and artwork. Fonts download directly from upstream and retain their own terms.
