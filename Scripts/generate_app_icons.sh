#!/bin/bash
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build/ModuleCache Branding
xcrun swift -module-cache-path "$PWD/build/ModuleCache" Scripts/generate_app_icon.swift Branding/AppIcon.png
source_image="Branding/AppIcon.png"
icon_set="FontHarbor/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$icon_set"
for size in 16 32 64 128 256 512 1024; do
    sips -z "$size" "$size" "$source_image" --out "$icon_set/icon_${size}.png" >/dev/null
done
python3 - <<'PY'
import json
from pathlib import Path
entries = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        entries.append({'idiom': 'mac', 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': f'icon_{size*scale}.png'})
p = Path('FontHarbor/Assets.xcassets/AppIcon.appiconset/Contents.json')
p.write_text(json.dumps({'images': entries, 'info': {'author': 'xcode', 'version': 1}}, indent=2)+'\n')
PY
printf 'Updated simple typography app icon.\n'
