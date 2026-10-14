#!/usr/bin/env python3
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

"""Generate Font Harbor's bundled catalog from official upstream indexes."""

import json
import re
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "FontHarbor" / "FontIndex.json"
GOOGLE_METADATA = "https://fonts.google.com/metadata/fonts"
GOOGLE_TREE = "https://api.github.com/repos/google/fonts/git/trees/main?recursive=1"
NERD_TREE = "https://api.github.com/repos/ryanoasis/nerd-fonts/git/trees/master?recursive=1"


def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Font-Harbor-Indexer"})
    with urllib.request.urlopen(request, timeout=60) as response:
        result = json.load(response)
    if isinstance(result, dict) and result.get("truncated"):
        raise ValueError(f"Upstream tree is truncated: {url}; refusing to replace the catalog")
    return result


def slug(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


def encoded_raw_url(repository, branch, path):
    encoded_path = urllib.parse.quote(path, safe="/")
    return f"https://raw.githubusercontent.com/{repository}/{branch}/{encoded_path}"


def preferred_file(paths):
    def rank(path):
        name = path.rsplit("/", 1)[-1].lower()
        return (
            0 if "[" in name and "italic" not in name else 1,
            0 if "regular" in name and "italic" not in name else 1,
            0 if "italic" not in name else 1,
            len(name),
            name,
        )
    return sorted(paths, key=rank)[0]


def category(value):
    return {
        "Serif": "Serif",
        "Monospace": "Monospace",
        "Display": "Display",
        "Handwriting": "Display",
    }.get(value, "Sans Serif")


def google_fonts():
    metadata = fetch_json(GOOGLE_METADATA)["familyMetadataList"]
    tree = fetch_json(GOOGLE_TREE)["tree"]
    files = defaultdict(list)
    licenses = {"ofl": "SIL Open Font License", "apache": "Apache License 2.0", "ufl": "Ubuntu Font License"}
    roots = {}
    for item in tree:
        path = item.get("path", "")
        parts = path.split("/")
        if len(parts) == 3 and parts[0] in licenses and path.lower().endswith((".ttf", ".otf")):
            files[parts[1]].append(path)
            roots[parts[1]] = parts[0]

    records = []
    for family in metadata:
        key = slug(family["family"])
        candidates = files.get(key)
        if not candidates or not family.get("isOpenSource", True):
            continue
        path = preferred_file(candidates)
        axes = family.get("axes", [])
        subsets = family.get("subsets", [])
        tags = []
        if axes:
            tags.append("Variable")
        if category(family.get("category")) == "Monospace":
            tags.append("Coding")
        if category(family.get("category")) == "Serif":
            tags.append("Editorial")
        if family.get("popularity", 9999) <= 100:
            tags.append("Popular")
        tags.extend(value.title() for value in subsets if value in {"cyrillic", "greek", "vietnamese", "arabic", "hebrew", "japanese", "korean"})
        records.append({
            "id": f"google-{key}",
            "family": family["family"],
            "designer": ", ".join(family.get("designers", [])) or "Unknown designer",
            "category": category(family.get("category")),
            "source": "Google Fonts",
            "license": licenses[roots[key]],
            "description": f"An open-source {family.get('category', 'type')} family from Google Fonts.",
            "tags": tags,
            "downloadURL": encoded_raw_url("google/fonts", "main", path),
            "repositoryURL": f"https://github.com/google/fonts/tree/main/{roots[key]}/{key}",
            "fileName": path.rsplit("/", 1)[-1],
        })
    return records


def display_directory_name(value):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value).replace("_", " ").replace("-", " ")


def nerd_fonts(existing_ids):
    tree = fetch_json(NERD_TREE)["tree"]
    files = defaultdict(list)
    for item in tree:
        path = item.get("path", "")
        parts = path.split("/")
        if len(parts) >= 3 and parts[0] == "patched-fonts" and path.lower().endswith((".ttf", ".otf")):
            files[parts[1]].append(path)

    records = []
    for directory, candidates in sorted(files.items()):
        key = slug(directory)
        identifier = f"nerd-{key}"
        if identifier in existing_ids:
            continue
        preferred = [path for path in candidates if "mono" in path.lower() and "regular" in path.lower()]
        path = preferred_file(preferred or candidates)
        family = display_directory_name(directory)
        records.append({
            "id": identifier,
            "family": f"{family} Nerd Font",
            "designer": "Nerd Fonts community",
            "category": "Monospace",
            "source": "Nerd Fonts",
            "license": "Upstream open font license",
            "description": "A developer-focused font patched with programming and icon glyphs by Nerd Fonts.",
            "tags": ["Coding", "Icons", "Patched"],
            "downloadURL": encoded_raw_url("ryanoasis/nerd-fonts", "master", path),
            "repositoryURL": f"https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/{urllib.parse.quote(directory)}",
            "fileName": path.rsplit("/", 1)[-1],
        })
    return records


def main():
    records = google_fonts()
    records.extend(nerd_fonts({record["id"] for record in records}))
    records.sort(key=lambda item: (item["family"].casefold(), item["source"]))
    document = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "sources": [
            {"name": "Google Fonts", "url": GOOGLE_METADATA, "count": sum(item["source"] == "Google Fonts" for item in records)},
            {"name": "Nerd Fonts", "url": "https://github.com/ryanoasis/nerd-fonts", "count": sum(item["source"] == "Nerd Fonts" for item in records)},
        ],
        "fonts": records,
    }
    from validate_catalog import validate
    validate(document)
    temporary = OUTPUT.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temporary.replace(OUTPUT)
    print(f"Wrote {len(records)} families to {OUTPUT}")


if __name__ == "__main__":
    main()
