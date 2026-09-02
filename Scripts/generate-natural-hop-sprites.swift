#!/usr/bin/env swift

import AppKit
import Foundation

private let frameCount = 6
private let logicalFrameSize = NSSize(width: 64, height: 31)
private let bottomPadding: CGFloat = 1.0
private let visibleFrameSizes: [NSSize] = [
    NSSize(width: 60, height: 27), // brace
    NSSize(width: 59, height: 25), // crouch
    NSSize(width: 61, height: 28), // propulsion
    NSSize(width: 62, height: 26), // flight
    NSSize(width: 60, height: 27), // forepaw contact
    NSSize(width: 60, height: 27)  // hindfoot loading
]
private let dilationRadiusByFrame = [0, 0, 2, 1, 2, 2]

private struct AlphaBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var rect: NSRect {
        NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func sourceRect(imageHeight: Int) -> NSRect {
        NSRect(
            x: minX,
            y: imageHeight - maxY - 1,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }
}

private func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

private func dilateAlpha(
    in image: NSBitmapImageRep,
    frame: Int,
    frameWidth: Int,
    frameHeight: Int,
    radius: Int
) {
    guard radius > 0 else { return }
    let startX = frame * frameWidth
    var alphas = [CGFloat](repeating: 0, count: frameWidth * frameHeight)
    for y in 0..<frameHeight {
        for x in 0..<frameWidth {
            alphas[y * frameWidth + x] = image.colorAt(x: startX + x, y: y)?.alphaComponent ?? 0
        }
    }

    var transparentComponentSize = [Int](repeating: 0, count: alphas.count)
    var visited = [Bool](repeating: false, count: alphas.count)
    for startY in 0..<frameHeight {
        for startX in 0..<frameWidth {
            let startIndex = startY * frameWidth + startX
            guard !visited[startIndex], alphas[startIndex] < 0.55 else { continue }
            var component = [startIndex]
            var cursor = 0
            visited[startIndex] = true
            while cursor < component.count {
                let index = component[cursor]
                cursor += 1
                let x = index % frameWidth
                let y = index / frameWidth
                for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let nextX = x + dx
                    let nextY = y + dy
                    guard nextX >= 0, nextX < frameWidth,
                          nextY >= 0, nextY < frameHeight else { continue }
                    let nextIndex = nextY * frameWidth + nextX
                    guard !visited[nextIndex], alphas[nextIndex] < 0.55 else { continue }
                    visited[nextIndex] = true
                    component.append(nextIndex)
                }
            }
            for index in component {
                transparentComponentSize[index] = component.count
            }
        }
    }

    let minimumGapArea = max(3, radius * 2)
    let gapSearch = radius + 3
    func hasOpaquePixel(fromX x: Int, y: Int, dx: Int, dy: Int) -> Bool {
        for distance in 1...gapSearch {
            let candidateX = x + dx * distance
            let candidateY = y + dy * distance
            guard candidateX >= 0, candidateX < frameWidth,
                  candidateY >= 0, candidateY < frameHeight else { return false }
            if alphas[candidateY * frameWidth + candidateX] > 0.55 { return true }
        }
        return false
    }

    for y in 0..<frameHeight {
        for x in 0..<frameWidth {
            let originalAlpha = alphas[y * frameWidth + x]
            let index = y * frameWidth + x
            let isOpposedBySilhouette = (
                hasOpaquePixel(fromX: x, y: y, dx: -1, dy: 0)
                    && hasOpaquePixel(fromX: x, y: y, dx: 1, dy: 0)
            ) || (
                hasOpaquePixel(fromX: x, y: y, dx: 0, dy: -1)
                    && hasOpaquePixel(fromX: x, y: y, dx: 0, dy: 1)
            ) || (
                hasOpaquePixel(fromX: x, y: y, dx: -1, dy: -1)
                    && hasOpaquePixel(fromX: x, y: y, dx: 1, dy: 1)
            ) || (
                hasOpaquePixel(fromX: x, y: y, dx: -1, dy: 1)
                    && hasOpaquePixel(fromX: x, y: y, dx: 1, dy: -1)
            )
            let preservesEarCutout = originalAlpha < 0.55
                && x >= Int(CGFloat(frameWidth) * 0.62)
                && y >= Int(CGFloat(frameHeight) * 0.18)
                && transparentComponentSize[index] >= minimumGapArea
                && isOpposedBySilhouette
            var expandedAlpha = originalAlpha
            for offsetY in -radius...radius {
                for offsetX in -radius...radius
                    where offsetX * offsetX + offsetY * offsetY <= radius * radius {
                    let sourceX = x + offsetX
                    let sourceY = y + offsetY
                    guard sourceX >= 0, sourceX < frameWidth,
                          sourceY >= 0, sourceY < frameHeight else { continue }
                    expandedAlpha = max(
                        expandedAlpha,
                        alphas[sourceY * frameWidth + sourceX]
                    )
                }
            }
            if preservesEarCutout {
                expandedAlpha = originalAlpha
            }
            image.setColor(
                // SpriteKit multiplies a sprite's texture RGB by its tint.
                // Keep every silhouette asset as a white RGB + alpha mask so
                // `labelColor` can produce black in light appearance and
                // white in dark appearance without poses changing color.
                NSColor(deviceRed: 1, green: 1, blue: 1, alpha: expandedAlpha),
                atX: startX + x,
                y: y
            )
        }
    }
}

private func normalizeAsWhiteTintMask(_ image: NSBitmapImageRep) {
    guard let graphics = NSGraphicsContext(bitmapImageRep: image) else {
        fail("Could not create tint-mask graphics context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    // `sourceIn` replaces every visible RGB value with white while retaining
    // the silhouette's existing alpha, including antialiased edges and the
    // transparent lop-ear cutout.
    graphics.cgContext.setBlendMode(.sourceIn)
    graphics.cgContext.setFillColor(NSColor.white.cgColor)
    graphics.cgContext.fill(
        CGRect(x: 0, y: 0, width: image.pixelsWide, height: image.pixelsHigh)
    )
    NSGraphicsContext.restoreGraphicsState()
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = repositoryRoot.appendingPathComponent(
    CommandLine.arguments.dropFirst().first
        ?? "docs/assets/bunnybar-natural-hop-image2-reference.png"
)
let outputDirectory = repositoryRoot.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/NaturalHop.imageset",
    isDirectory: true
)

guard let sourceData = try? Data(contentsOf: sourceURL),
      let sourceRep = NSBitmapImageRep(data: sourceData) else {
    fail("Could not load Image-2 reference at \(sourceURL.path)")
}

let sourceWidth = sourceRep.pixelsWide
let sourceHeight = sourceRep.pixelsHigh
guard sourceWidth.isMultiple(of: frameCount) else {
    fail("Reference width \(sourceWidth) is not divisible by \(frameCount)")
}
let sourceCellWidth = sourceWidth / frameCount

let canonicalURL = repositoryRoot.appendingPathComponent(
    "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit.png"
)
var canonicalOpaqueArea: CGFloat = 0
if let canonicalData = try? Data(contentsOf: canonicalURL),
   let canonicalRep = NSBitmapImageRep(data: canonicalData) {
    var minX = canonicalRep.pixelsWide
    var minY = canonicalRep.pixelsHigh
    var maxX = -1
    var maxY = -1
    for y in 0..<canonicalRep.pixelsHigh {
        for x in 0..<canonicalRep.pixelsWide {
            guard let color = canonicalRep.colorAt(x: x, y: y), color.alphaComponent > 0.08 else {
                continue
            }
            canonicalOpaqueArea += color.alphaComponent
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    if maxX >= minX, maxY >= minY {
        print("canonical: x=\(minX) y=\(minY) w=\(maxX - minX + 1) h=\(maxY - minY + 1) area=\(Int(canonicalOpaqueArea.rounded()))")
    }
}

private let bounds: [AlphaBounds] = (0..<frameCount).map { frame in
    let cellStartX = frame * sourceCellWidth
    let cellEndX = cellStartX + sourceCellWidth
    var minX = cellEndX
    var minY = sourceHeight
    var maxX = cellStartX - 1
    var maxY = -1

    for y in 0..<sourceHeight {
        for x in cellStartX..<cellEndX {
            guard let color = sourceRep.colorAt(x: x, y: y), color.alphaComponent > 0.08 else {
                continue
            }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard maxX >= minX, maxY >= minY else {
        fail("Frame \(frame + 1) contains no visible pixels")
    }
    return AlphaBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

try? FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

let sourceImage = NSImage(size: NSSize(width: sourceWidth, height: sourceHeight))
sourceImage.addRepresentation(sourceRep)

for outputScale in 1...3 {
    let pixelFrameWidth = Int(logicalFrameSize.width) * outputScale
    let pixelFrameHeight = Int(logicalFrameSize.height) * outputScale
    guard let outputRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelFrameWidth * frameCount,
        pixelsHigh: pixelFrameHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fail("Could not allocate \(outputScale)x sprite sheet")
    }
    outputRep.size = NSSize(width: outputRep.pixelsWide, height: outputRep.pixelsHigh)

    guard let graphics = NSGraphicsContext(bitmapImageRep: outputRep) else {
        fail("Could not create \(outputScale)x graphics context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    graphics.cgContext.clear(
        CGRect(x: 0, y: 0, width: outputRep.pixelsWide, height: outputRep.pixelsHigh)
    )

    for (frame, alphaBounds) in bounds.enumerated() {
        let sourceRect = alphaBounds.sourceRect(imageHeight: sourceHeight)
        let logicalVisibleSize = visibleFrameSizes[frame]
        let destinationSize = NSSize(
            width: logicalVisibleSize.width * CGFloat(outputScale),
            height: logicalVisibleSize.height * CGFloat(outputScale)
        )
        let destinationRect = NSRect(
            x: CGFloat(frame * pixelFrameWidth)
                + (CGFloat(pixelFrameWidth) - destinationSize.width) / 2,
            y: bottomPadding * CGFloat(outputScale),
            width: destinationSize.width,
            height: destinationSize.height
        )
        sourceImage.draw(
            in: destinationRect,
            from: sourceRect,
            operation: .copy,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
    NSGraphicsContext.restoreGraphicsState()

    for frame in 0..<frameCount {
        dilateAlpha(
            in: outputRep,
            frame: frame,
            frameWidth: pixelFrameWidth,
            frameHeight: pixelFrameHeight,
            radius: dilationRadiusByFrame[frame] * outputScale
        )
    }
    normalizeAsWhiteTintMask(outputRep)

    guard let png = outputRep.representation(using: .png, properties: [:]) else {
        fail("Could not encode \(outputScale)x sprite sheet")
    }
    let suffix = outputScale == 1 ? "" : "@\(outputScale)x"
    let outputURL = outputDirectory.appendingPathComponent("natural-hop\(suffix).png")
    do {
        try png.write(to: outputURL, options: .atomic)
    } catch {
        fail("Could not write \(outputURL.path): \(error)")
    }

    if outputScale == 1 {
        for frame in 0..<frameCount {
            var opaqueArea: CGFloat = 0
            for y in 0..<pixelFrameHeight {
                for x in (frame * pixelFrameWidth)..<((frame + 1) * pixelFrameWidth) {
                    opaqueArea += outputRep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                }
            }
            let ratio = canonicalOpaqueArea > 0 ? opaqueArea / canonicalOpaqueArea : 0
            let ratioString = String(format: "%.3f", ratio)
            print("runtime frame \(frame + 1): area=\(Int(opaqueArea.rounded())) ratio=\(ratioString)")
        }
    }
}

for (index, alphaBounds) in bounds.enumerated() {
    let rect = alphaBounds.rect
    print("frame \(index + 1): x=\(Int(rect.minX)) y=\(Int(rect.minY)) "
          + "w=\(Int(rect.width)) h=\(Int(rect.height))")
}
print("Generated NaturalHop sprites normalized to the canonical 62x29px silhouette")
