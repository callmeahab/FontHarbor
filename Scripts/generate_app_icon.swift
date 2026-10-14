// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

// Draw the simple typography mark without depending on a proprietary SF Symbol asset.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let tile = CGRect(x: 64, y: 64, width: 896, height: 896)
let shape = CGPath(roundedRect: tile, cornerWidth: 204, cornerHeight: 204, transform: nil)
let colors = [CGColor(red: 0.36, green: 0.34, blue: 0.84, alpha: 1),
              CGColor(red: 0.65, green: 0.28, blue: 0.78, alpha: 1),
              CGColor(red: 0.95, green: 0.25, blue: 0.53, alpha: 1)]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.55, 1])!
context.saveGState()
context.addPath(shape)
context.clip()
context.drawLinearGradient(gradient, start: CGPoint(x: 64, y: 960), end: CGPoint(x: 960, y: 64), options: [])
context.restoreGState()

let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, 370, nil)!
let text = NSAttributedString(string: "Aa", attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
    NSAttributedString.Key(kCTKernAttributeName as String): -8
])
let line = CTLineCreateWithAttributedString(text)
let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
context.textPosition = CGPoint(x: 512 - bounds.midX, y: 512 - bounds.midY)
CTLineDraw(line, context)

let output = URL(filePath: CommandLine.arguments.dropFirst().first ?? "Branding/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Could not write the icon")
print("Wrote simple typography icon to \(output.path)")
