#!/bin/bash
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
python3 -m unittest discover -s Tests/Python -v
python3 Scripts/validate_catalog.py
mkdir -p build/ModuleCache build/SPMCache build/SPMConfig build/SPMSecurity
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PWD/build/ModuleCache"
swift_test_arguments=(
    --scratch-path build/Tests
    --cache-path build/SPMCache
    --config-path build/SPMConfig
    --security-path build/SPMSecurity
)
if [[ "${FONTHARBOR_MACRO_SANDBOX:-1}" == 0 ]]; then
    swift_test_arguments+=(--disable-sandbox -Xswiftc -disable-sandbox)
fi
swift test "${swift_test_arguments[@]}"
