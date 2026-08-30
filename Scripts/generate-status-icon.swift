#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct StatusIconSlot {
    let filename: String
    let pixels: Int
}

private let slots = [
    StatusIconSlot(filename: "status-rabbit.png", pixels: 18),
    StatusIconSlot(filename: "status-rabbit@2x.png", pixels: 36),
]

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let outputDirectory = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/StatusRabbit.imageset",
    isDirectory: true
)

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let side = slot.pixels
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: side * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Could not create status icon context\n", stderr)
        exit(1)
    }

    let scale = CGFloat(side) / 18
    context.scaleBy(x: scale, y: scale)
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.setFillColor(CGColor(gray: 0, alpha: 1))

    // A compact sitting mass reads more clearly than the long resting sprite
    // at 18pt. There are still no eyes or mascot-style facial details.
    context.fillEllipse(in: CGRect(x: 2.5, y: 1.7, width: 10.5, height: 8.8))
    context.fillEllipse(in: CGRect(x: 8.0, y: 1.1, width: 7.5, height: 2.7))
    context.fillEllipse(in: CGRect(x: 0.8, y: 6.2, width: 3.5, height: 3.5))

    // Oversized side-profile head and a restrained nose projection make the
    // species readable without adding an eye or mascot expression.
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 9.0, y: 14.2))
    head.addCurve(to: CGPoint(x: 14.4, y: 14.6),
                  control1: CGPoint(x: 10.8, y: 16.1),
                  control2: CGPoint(x: 13.2, y: 16.0))
    head.addCurve(to: CGPoint(x: 15.8, y: 12.8),
                  control1: CGPoint(x: 15.2, y: 14.1),
                  control2: CGPoint(x: 15.6, y: 13.5))
    head.addCurve(to: CGPoint(x: 17.2, y: 11.1),
                  control1: CGPoint(x: 16.8, y: 12.3),
                  control2: CGPoint(x: 17.3, y: 11.8))
    head.addCurve(to: CGPoint(x: 15.1, y: 9.0),
                  control1: CGPoint(x: 17.0, y: 10.0),
                  control2: CGPoint(x: 16.2, y: 9.2))
    head.addCurve(to: CGPoint(x: 11.5, y: 7.8),
                  control1: CGPoint(x: 14.1, y: 8.2),
                  control2: CGPoint(x: 12.9, y: 7.7))
    head.addCurve(to: CGPoint(x: 8.1, y: 9.3),
                  control1: CGPoint(x: 10.0, y: 7.5),
                  control2: CGPoint(x: 8.8, y: 8.1))
    head.addCurve(to: CGPoint(x: 9.0, y: 14.2),
                  control1: CGPoint(x: 7.2, y: 11.0),
                  control2: CGPoint(x: 7.5, y: 13.1))
    head.closeSubpath()
    context.addPath(head)
    context.fillPath()

    // One low, heavy lop ear hangs behind the head. Its outer edge, rather than
    // an internal stripe, carries most of the lop-ear recognition at 18pt.
    let ear = CGMutablePath()
    ear.move(to: CGPoint(x: 11.1, y: 14.8))
    ear.addCurve(to: CGPoint(x: 7.2, y: 14.3),
                 control1: CGPoint(x: 9.7, y: 15.7),
                 control2: CGPoint(x: 8.2, y: 15.3))
    ear.addCurve(to: CGPoint(x: 5.0, y: 9.1),
                 control1: CGPoint(x: 5.7, y: 13.0),
                 control2: CGPoint(x: 5.1, y: 10.8))
    ear.addCurve(to: CGPoint(x: 6.7, y: 6.4),
                 control1: CGPoint(x: 4.8, y: 7.5),
                 control2: CGPoint(x: 5.5, y: 6.4))
    ear.addCurve(to: CGPoint(x: 9.1, y: 8.9),
                 control1: CGPoint(x: 8.3, y: 6.5),
                 control2: CGPoint(x: 9.2, y: 7.4))
    ear.addCurve(to: CGPoint(x: 12.1, y: 13.5),
                 control1: CGPoint(x: 9.3, y: 11.2),
                 control2: CGPoint(x: 10.3, y: 13.0))
    ear.addCurve(to: CGPoint(x: 11.1, y: 14.8),
                 control1: CGPoint(x: 12.0, y: 14.4),
                 control2: CGPoint(x: 11.6, y: 14.8))
    ear.closeSubpath()
    context.addPath(ear)
    context.fillPath()

    // A short negative notch only separates the ear at its root. Extending it
    // through the body turns the silhouette into a skunk-like stripe.
    context.saveGState()
    context.setBlendMode(.clear)
    context.setLineWidth(1.05)
    context.setLineCap(.round)
    let fold = CGMutablePath()
    fold.move(to: CGPoint(x: 10.7, y: 14.0))
    fold.addCurve(to: CGPoint(x: 7.1, y: 9.4),
                  control1: CGPoint(x: 8.8, y: 13.5),
                  control2: CGPoint(x: 7.3, y: 11.6))
    context.addPath(fold)
    context.strokePath()
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

print("Generated \(slots.count) dedicated BunnyBar status icons")
