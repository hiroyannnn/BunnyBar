#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO

private struct StatusIconSlot {
    let filename: String
    let scale: Int
}

private let slots = [
    StatusIconSlot(filename: "status-rabbit.png", scale: 1),
    StatusIconSlot(filename: "status-rabbit@2x.png", scale: 2),
]

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let sourceURL = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit@3x.png"
)
private let outputDirectory = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/StatusRabbit.imageset",
    isDirectory: true
)

guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let rabbit = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    fputs("Could not load the adopted LopRabbit silhouette\n", stderr)
    exit(1)
}

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let width = 22 * slot.scale
    let height = 18 * slot.scale
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Could not create status icon context\n", stderr)
        exit(1)
    }

    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(slot.scale), y: CGFloat(slot.scale))

    // Keep the already accepted rabbit contour intact. Raising it from the
    // old 24x12pt slot to a 22x14pt visible mark restores the round head,
    // drooping ear, tail and tucked feet at menu-bar scale.
    context.draw(rabbit, in: CGRect(x: 0.4, y: 2.0, width: 21.2, height: 14.0))

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

print("Generated \(slots.count) status icons from the adopted LopRabbit silhouette")
