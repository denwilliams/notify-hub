#!/usr/bin/env swift

import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

for (px, filename) in sizes {
    let size = CGFloat(px)

    // Create bitmap at exact pixel size (1x scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded rect clip
    let cornerRadius = size * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    // Blue gradient background
    let gradient = NSGradient(
        colors: [
            NSColor(red: 0.20, green: 0.40, blue: 0.95, alpha: 1.0),
            NSColor(red: 0.40, green: 0.60, blue: 1.00, alpha: 1.0),
        ],
        atLocations: [0.0, 1.0],
        colorSpace: .deviceRGB
    )!
    gradient.draw(in: rect, angle: -45)

    // Draw bell symbol in white
    let symbolSize = size * 0.5
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolRect = NSRect(
            x: (size - symbol.size.width) / 2,
            y: (size - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.current = nil

    // Save PNG
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed: \(filename)")
        continue
    }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
    try! png.write(to: url)
    print("Created \(filename) (\(px)x\(px))")
}
