// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

@main
struct FontHarborApp: App {
    @NSApplicationDelegateAdaptor(FontHarborAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
    }
}

@MainActor
final class FontHarborAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set the current icon before the app finishes launching so the Dock never shows stale artwork.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
}
