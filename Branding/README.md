# Font Harbor icon

`AppIcon.png` is the 1024 × 1024 transparent PNG master. It matches the original sidebar's simple white typography on an indigo, purple and pink rounded tile.

The app icon uses original “Aa” lettering drawn with Core Text. The sidebar retains its original native `textformat.alt` system symbol. The app icon does not embed that SF Symbol. No generated lighthouse or wave artwork is used in the release.

The icon is reproducible from `Scripts/generate_app_icon.swift`, which draws the tile and typography using Core Graphics and Core Text. Run `Scripts/generate_app_icons.sh` to regenerate the master and all macOS AppIcon representations from 16 to 1024 pixels. This uses Apple's system tools and Python's standard library; no image generation service or API key is needed.

Original project artwork and its rendering code are licensed under GPL-3.0-only. The system font itself is not redistributed.
