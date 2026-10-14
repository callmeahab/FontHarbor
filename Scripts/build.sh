#!/bin/bash
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Debug}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
    printf 'Usage: Scripts/build.sh [Debug|Release]\n' >&2
    exit 2
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
extra_flags=()
# Optional workaround for build hosts that cannot launch a nested compiler sandbox.
if [[ "${FONTHARBOR_MACRO_SANDBOX:-1}" == 0 ]]; then
    extra_flags+=('OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox')
fi
xcodebuild -quiet -project FontHarbor.xcodeproj -scheme FontHarbor \
    -configuration "$configuration" -destination 'generic/platform=macOS' \
    -derivedDataPath "build/$configuration" CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' "${extra_flags[@]}" build
printf 'Built build/%s/Build/Products/%s/Font Harbor.app (unsigned)\n' "$configuration" "$configuration"
