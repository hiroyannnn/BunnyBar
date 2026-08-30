#!/usr/bin/env swift

import AppKit
import Foundation

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let oldURL = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit@3x.png"
)
private let newURL = root.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/StatusRabbit.imageset/status-rabbit@2x.png"
)
private let outputDirectory = URL(fileURLWithPath:
    "/Users/hiro/.codex/visualizations/2026/08/18/01a0125f-404a-7c61-bef1-ef7215a5a6a8/bunny-status-icon-comparison",
    isDirectory: true
)

guard let oldSource = NSImage(contentsOf: oldURL),
      let newSource = NSImage(contentsOf: newURL) else {
    fputs("Could not load status icon sources\n", stderr)
    exit(1)
}

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
_ = NSApplication.shared
NSApp.appearance = NSAppearance(named: .aqua)

private func tinted(_ source: NSImage, size: NSSize, color: NSColor) -> NSImage {
    let result = NSImage(size: size)
    result.lockFocus()
    source.draw(in: NSRect(origin: .zero, size: size),
                from: .zero, operation: .sourceOver, fraction: 1)
    color.setFill()
    NSRect(origin: .zero, size: size).fill(using: .sourceIn)
    result.unlockFocus()
    return result
}

private func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BunnyBarStatusPreview", code: 1)
    }
    try png.write(to: url, options: .atomic)
}

private func panel(source: NSImage, logicalSize: NSSize, caption: String) -> NSImage {
    let width: CGFloat = 320
    let height: CGFloat = 132
    let barHeight: CGFloat = 96
    let result = NSImage(size: NSSize(width: width, height: height))
    result.lockFocus()

    NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
    NSRect(x: 0, y: height - barHeight, width: width, height: barHeight).fill()
    NSColor(calibratedWhite: 0.80, alpha: 1).setStroke()
    let separator = NSBezierPath()
    separator.move(to: NSPoint(x: 0, y: height - barHeight))
    separator.line(to: NSPoint(x: width, y: height - barHeight))
    separator.lineWidth = 1
    separator.stroke()

    // Four-times menu-bar scale makes the actual 24x12pt and 18x18pt forms
    // visible without changing their relative proportions.
    let drawSize = NSSize(width: logicalSize.width * 4, height: logicalSize.height * 4)
    let icon = tinted(source, size: drawSize, color: NSColor(calibratedWhite: 0.08, alpha: 1))
    let iconRect = NSRect(x: (width - drawSize.width) / 2,
                          y: height - barHeight + (barHeight - drawSize.height) / 2,
                          width: drawSize.width,
                          height: drawSize.height)
    icon.draw(in: iconRect)

    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: width, height: height - barHeight).fill()
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 1),
    ]
    let label = NSAttributedString(string: caption, attributes: attributes)
    label.draw(at: NSPoint(x: (width - label.size().width) / 2, y: 9))
    result.unlockFocus()
    return result
}

let oldPanel = panel(source: oldSource,
                     logicalSize: NSSize(width: 24, height: 12),
                     caption: "OLD — full body, 24 × 12 pt")
let newPanel = panel(source: newSource,
                     logicalSize: NSSize(width: 22, height: 18),
                     caption: "NEW — adopted lop, 22 × 18 pt")

let comparison = NSImage(size: NSSize(width: 656, height: 132))
comparison.lockFocus()
NSColor(calibratedWhite: 0.86, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 656, height: 132).fill()
oldPanel.draw(in: NSRect(x: 0, y: 0, width: 320, height: 132))
newPanel.draw(in: NSRect(x: 336, y: 0, width: 320, height: 132))
comparison.unlockFocus()

try savePNG(oldPanel, to: outputDirectory.appendingPathComponent("old-status-icon.png"))
try savePNG(newPanel, to: outputDirectory.appendingPathComponent("new-status-icon.png"))
try savePNG(comparison, to: outputDirectory.appendingPathComponent("status-icon-comparison.png"))
print("Rendered old/new status icon comparison in \(outputDirectory.path)")
