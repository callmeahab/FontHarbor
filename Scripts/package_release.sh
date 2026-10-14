#!/bin/bash
# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/test.sh
Scripts/build.sh Release
python3 Scripts/package_release.py
