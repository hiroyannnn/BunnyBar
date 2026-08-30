#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct IconSlot {
    let filename: String
    let pixels: Int
}

private let slots = [
    IconSlot(filename: "icon_16x16.png", pixels: 16),
    IconSlot(filename: "icon_16x16@2x.png", pixels: 32),
    IconSlot(filename: "icon_32x32.png", pixels: 32),
    IconSlot(filename: "icon_32x32@2x.png", pixels: 64),
    IconSlot(filename: "icon_128x128.png", pixels: 128),
    IconSlot(filename: "icon_128x128@2x.png", pixels: 256),
    IconSlot(filename: "icon_256x256.png", pixels: 256),
    IconSlot(filename: "icon_256x256@2x.png", pixels: 512),
    IconSlot(filename: "icon_512x512.png", pixels: 512),
    IconSlot(filename: "icon_512x512@2x.png", pixels: 1024),
]

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let sourceURL = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit@3x.png"
)
private let outputDirectory = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)

guard let source = NSImage(contentsOf: sourceURL),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Could not load LopRabbit source image at \(sourceURL.path)\n", stderr)
    exit(1)
}

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let pixels = slot.pixels
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Could not create \(pixels)x\(pixels) bitmap context\n", stderr)
        exit(1)
    }

    let side = CGFloat(pixels)
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    context.clear(CGRect(x: 0, y: 0, width: side, height: side))

    // A restrained, near-white macOS tile keeps the accepted black silhouette
    // legible without adding facial details or mascot-style decoration.
    let tileInset = side * 0.055
    let tileRect = CGRect(x: tileInset, y: tileInset,
                          width: side - tileInset * 2, height: side - tileInset * 2)
    let tilePath = CGPath(roundedRect: tileRect,
                          cornerWidth: side * 0.205,
                          cornerHeight: side * 0.205,
                          transform: nil)
    context.addPath(tilePath)
    context.setFillColor(CGColor(red: 0.955, green: 0.949, blue: 0.925, alpha: 1))
    context.fillPath()

    context.addPath(tilePath)
    context.setStrokeColor(CGColor(gray: 0, alpha: 0.10))
    context.setLineWidth(max(1, side * 0.012))
    context.strokePath()

    let sourceAspect = CGFloat(sourceCG.width) / CGFloat(sourceCG.height)
    let rabbitWidth = side * 0.75
    let rabbitHeight = rabbitWidth / sourceAspect
    let rabbitRect = CGRect(
        x: (side - rabbitWidth) / 2,
        y: side * 0.315,
        width: rabbitWidth,
        height: rabbitHeight
    )

    context.saveGState()
    context.clip(to: rabbitRect, mask: sourceCG)
    context.setFillColor(CGColor(gray: 0.055, alpha: 1))
    context.fill(rabbitRect)
    context.restoreGState()

    guard let image = context.makeImage() else {
        fputs("Could not render \(slot.filename)\n", stderr)
        exit(1)
    }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let png = representation.representation(using: .png, properties: [:]) else {
        fputs("Could not encode \(slot.filename)\n", stderr)
        exit(1)
    }
    try png.write(to: outputDirectory.appendingPathComponent(slot.filename), options: .atomic)
}

print("Generated \(slots.count) BunnyBar app icon images in \(outputDirectory.path)")
