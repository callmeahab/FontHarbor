# Releasing Font Harbor

## Initialize the repository

The project started as a standalone Xcode folder. Git initialization is blocked by the preparation session's filesystem policy. From a normal terminal in this directory:

```sh
git init -b main
git add .
git status --short
git commit -m "Prepare Font Harbor for open source"
```

Review the staged files before committing. `.gitignore` excludes Xcode personal state, caches, build products and credentials. Create a repository on your preferred host and add its remote explicitly. No remote or publication is configured by the preparation scripts.

## Verify a candidate

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both target configurations and update `CHANGELOG.md`.
2. Run `Scripts/package_release.sh`. It runs tests, builds both Mac architectures, then creates an unsigned app archive, matching source archive and SHA-256 checksums under `build/release`.
3. Review the archives. The source archive uses an explicit file/directory allowlist and excludes personal Xcode data; it packages the current working files, so release from a clean, reviewed checkout.
4. Run the UI and signed-installation checks in `CONTRIBUTING.md`. Test on macOS 26 and the latest supported macOS, including Intel if distributing that architecture. Unit tests do not verify user-session registration in other apps.

The CI workflow runs these build and test commands on `macos-26` and uploads unsigned build artifacts. Pushing a version tag such as `v1.0.0` also runs the Release workflow. The tag must match `MARKETING_VERSION`; after tests and packaging pass, the workflow creates a GitHub prerelease containing the unsigned universal app, corresponding source archive and checksums. The release prominently warns that the app is unsigned and unnotarized.

## Sign and notarize public binaries

The preparation script deliberately produces an unsigned development build. For public downloads, archive in Xcode using your Developer ID identity and hardened runtime, export with Developer ID distribution, and notarize with your own Apple credentials. Enable the sandbox and outgoing network entitlement from the existing target settings. Do not put certificates, signing keys, Apple passwords or notarization profiles in this repository.

Verify the exported artifact using `codesign --verify --deep --strict` and `spctl --assess --type execute`; staple the notarization ticket before packaging. Replace the unsigned artifact with the signed/notarized export, regenerate checksums, and repeat the installation smoke test. Signing and notarization were not performed in this preparation session.

## Publish

Tag the reviewed commit with a version matching `MARKETING_VERSION`, then push the tag. The Release workflow publishes both the app archive and its matching source archive with checksums as an unsigned development prerelease. The GPL license and third-party notices are included in the app download folder. Provide corresponding source from the exact version used for the binary; do not replace it with a source archive from a later working tree. Keep the generated icon source and catalog generation scripts available.

If only publishing source initially, omit the binary download and document the Xcode build steps.

## Restricted build hosts

If a nested Swift compiler sandbox fails with a malformed macro-plugin response, this session's verified workaround is:

```sh
FONTHARBOR_MACRO_SANDBOX=0 Scripts/test.sh
FONTHARBOR_MACRO_SANDBOX=0 Scripts/build.sh Release
```

This disables the nested compiler/SwiftPM sandbox for that invocation. It does not change the app's sandbox settings. Normal local and CI builds use the standard sandbox defaults.
