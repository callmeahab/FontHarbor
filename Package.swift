// swift-tools-version: 6.2
// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only
import PackageDescription

// A dependency-free test harness. The shipping app remains an Xcode target.
let package = Package(
    name: "FontHarborCore",
    platforms: [.macOS("26.0")],
    products: [.library(name: "FontHarborCore", targets: ["FontHarborCore"])],
    targets: [
        .target(
            name: "FontHarborCore",
            path: "FontHarbor",
            exclude: ["FontHarborApp.swift", "ContentView.swift", "SidebarViews.swift", "BrowserViews.swift", "FontDetailViews.swift", "FontSheets.swift", "ViewStyles.swift", "Assets.xcassets", "FontIndex.json"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "FontHarborCoreTests", dependencies: ["FontHarborCore"])
    ]
)
