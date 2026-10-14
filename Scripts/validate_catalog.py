#!/usr/bin/env python3
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

"""Validate the bundled metadata locally; this does not verify upstream URLs/licenses."""
import argparse
import json
from collections import Counter
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CATEGORIES = {'Sans Serif', 'Serif', 'Monospace', 'Display'}
SOURCES = {'Google Fonts', 'Fontshare', 'The League', 'Adobe', 'JetBrains', 'Mozilla', 'Nerd Fonts', 'Community'}


def validate(document):
    if document.get('schemaVersion') != 1:
        raise ValueError('Unsupported catalog schema')
    generated = datetime.fromisoformat(document['generatedAt'])
    if generated.tzinfo is None:
        raise ValueError('generatedAt must include a timezone')
    fonts = document['fonts']
    if not fonts:
        raise ValueError('Catalog is empty')
    ids = set()
    for font in fonts:
        identifier = font['id']
        if not isinstance(identifier, str) or not identifier.strip() or identifier in ids:
            raise ValueError(f'Invalid or duplicate font ID: {identifier}')
        ids.add(identifier)
        for field in ('family', 'designer', 'license', 'description', 'fileName'):
            if not isinstance(font[field], str) or not font[field].strip():
                raise ValueError(f'{identifier}: missing {field}')
        if font['category'] not in CATEGORIES or font['source'] not in SOURCES:
            raise ValueError(f'{identifier}: unknown category or source')
        if not isinstance(font['tags'], list) or any(not isinstance(tag, str) or not tag for tag in font['tags']):
            raise ValueError(f'{identifier}: invalid tags')
        if len(font['tags']) != len(set(font['tags'])):
            raise ValueError(f'{identifier}: duplicate tags')
        name = font['fileName']
        if '/' in name or '\\' in name or Path(name).suffix.lower() not in ('.ttf', '.otf', '.ttc', '.otc'):
            raise ValueError(f'{identifier}: invalid font filename')
        for field in ('downloadURL', 'repositoryURL'):
            url = urlparse(font[field])
            if url.scheme != 'https' or not url.hostname or url.username or url.password:
                raise ValueError(f'{identifier}: {field} must be HTTPS without credentials')
    counts = Counter(font['source'] for font in fonts)
    summaries = document['sources']
    if len({source['name'] for source in summaries}) != len(summaries):
        raise ValueError('Duplicate source summary')
    if {source['name']: source['count'] for source in summaries} != dict(counts):
        raise ValueError('Source summary counts do not match the catalog')
    return len(fonts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', nargs='?', type=Path, default=ROOT / 'FontHarbor/FontIndex.json')
    args = parser.parse_args()
    try:
        count = validate(json.loads(args.path.read_text(encoding='utf-8')))
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f'Catalog validation failed: {error}\n')
    print(f'Validated {count} font records (schema, identities, URLs and source counts).')


if __name__ == '__main__':
    main()
