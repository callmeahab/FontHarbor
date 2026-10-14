#!/usr/bin/env python3
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

"""Create matching unsigned app/source archives without local user or build state."""
import hashlib
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/release'
ROOT_FILES = ['README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'CONTRIBUTING.md', 'SECURITY.md',
              'CODE_OF_CONDUCT.md', 'CHANGELOG.md', '.gitignore', 'Package.swift']
SOURCE_DIRS = ['FontHarbor', 'FontHarbor.xcodeproj', 'Scripts', 'Tests', 'Branding', 'docs', '.github']
EXCLUDED = {'xcuserdata', '__pycache__', '.DS_Store'}


def main():
    project = (ROOT / 'FontHarbor.xcodeproj/project.pbxproj').read_text()
    version = re.search(r'MARKETING_VERSION = ([0-9.]+);', project).group(1)
    app = ROOT / 'build/Release/Build/Products/Release/Font Harbor.app'
    if not app.is_dir():
        raise SystemExit('Release app missing; run Scripts/package_release.sh')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    staging = OUTPUT / 'FontHarbor'
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    subprocess.run(['ditto', str(app), str(staging / app.name)], check=True)
    for name in ['LICENSE', 'THIRD_PARTY_NOTICES.md']:
        shutil.copy2(ROOT / name, staging / name)
    (staging / 'README.txt').write_text(
        'Font Harbor ' + version + '\nUnsigned universal macOS 26+ development build.\n'
        'Not Developer ID signed or notarized. Build from the matching source archive if needed.\n'
        'GPL-3.0-only; see LICENSE. Font licenses remain separate.\n')
    binary = OUTPUT / f'FontHarbor-{version}-macos-universal-unsigned.zip'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staging), str(binary)], check=True)
    source = OUTPUT / f'FontHarbor-{version}-source.zip'
    paths = [ROOT / name for name in ROOT_FILES]
    for directory in SOURCE_DIRS:
        paths.extend((ROOT / directory).rglob('*'))
    with zipfile.ZipFile(source, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(set(paths)):
            relative = path.relative_to(ROOT)
            if (path.is_file() and not path.is_symlink() and not any(part in EXCLUDED for part in relative.parts)
                    and path.suffix not in {'.xcuserstate', '.pyc', '.pyo'}):
                archive.write(path, Path(f'FontHarbor-{version}-source') / relative)
    sums = OUTPUT / 'SHA256SUMS.txt'
    sums.write_text(''.join(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name + '\n' for path in [binary, source]))
    print(f'Prepared {binary.name}, {source.name}, and {sums.name} in {OUTPUT}')


if __name__ == '__main__':
    main()
