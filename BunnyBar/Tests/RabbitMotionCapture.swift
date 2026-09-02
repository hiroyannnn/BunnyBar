// Captures the six production running poses at their real 88x44 overlay size.
// Run from the repository root:
//
//   xcrun swiftc -module-cache-path /private/tmp/BunnyBarMotionCaptureModuleCache \
//     -framework AppKit -framework Metal -framework SpriteKit \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
//     BunnyBar/Tests/RabbitMotionCapture.swift \
//     -o /private/tmp/BunnyBarMotionCapture && \
//   /private/tmp/BunnyBarMotionCapture

import AppKit
import Metal
import SpriteKit

@MainActor
private final class MotionRenderer {
    private let renderer: SKRenderer
    private let queue: any MTLCommandQueue
    private let texture: any MTLTexture
    private let pass = MTLRenderPassDescriptor()

    init(
        scene: SKScene,
        width: Int,
        height: Int,
        clearColor: MTLClearColor = MTLClearColorMake(1, 1, 1, 1)
    ) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal unavailable")
        }
        self.queue = queue
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Could not allocate capture texture")
        }
        self.texture = texture
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = clearColor
        renderer = SKRenderer(device: device)
        renderer.scene = scene
    }

    func capture(at time: TimeInterval) -> CGImage {
        renderer.update(atTime: time)
        guard let buffer = queue.makeCommandBuffer() else {
            fatalError("Could not create command buffer")
        }
        renderer.render(
            withViewport: CGRect(x: 0, y: 0, width: texture.width, height: texture.height),
            commandBuffer: buffer,
            renderPassDescriptor: pass
        )
        buffer.commit()
        buffer.waitUntilCompleted()
        precondition(buffer.status == .completed, "Metal frame failed")

        let bytesPerRow = texture.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * texture.height)
        texture.getBytes(
            &bytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: texture.width,
                height: texture.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
                    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            fatalError("Could not create capture image")
        }
        return image
    }
}

private func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode capture")
    }
    do {
        try data.write(to: url, options: .atomic)
    } catch {
        fatalError("Could not write \(url.path): \(error)")
    }
}

private func inkArea(of image: CGImage) -> CGFloat {
    let rep = NSBitmapImageRep(cgImage: image)
    var area: CGFloat = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            area += 1 - (color.redComponent + color.greenComponent + color.blueComponent) / 3
        }
    }
    return area
}

private func lightArea(of image: CGImage) -> CGFloat {
    let rep = NSBitmapImageRep(cgImage: image)
    var area: CGFloat = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            area += (color.redComponent + color.greenComponent + color.blueComponent) / 3
        }
    }
    return area
}

private func requireWhiteTintMask(at url: URL, named name: String) {
    guard let data = try? Data(contentsOf: url),
          let rep = NSBitmapImageRep(data: data) else {
        fatalError("Could not inspect \(name) tint mask")
    }

    var visiblePixels = 0
    var minimumTintRatio: CGFloat = 1
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(NSColorSpace.deviceRGB),
                  color.alphaComponent > 0.08 else { continue }
            visiblePixels += 1
            // Bitmap reads can return premultiplied edge RGB. Dividing by
            // alpha treats an antialiased white edge as white while a black
            // source mask still produces a ratio of zero.
            let minimumComponent = min(
                color.redComponent,
                color.greenComponent,
                color.blueComponent
            )
            minimumTintRatio = min(
                minimumTintRatio,
                min(1, minimumComponent / color.alphaComponent)
            )
        }
    }

    precondition(visiblePixels > 0, "\(name) tint mask is empty")
    precondition(
        minimumTintRatio >= 0.95,
        "\(name) must use white RGB with alpha so light/dark tinting stays consistent "
            + "(minimum tint ratio: \(minimumTintRatio))"
    )
}

@main
@MainActor
private struct RabbitMotionCapture {
    static func main() {
        _ = NSApplication.shared
        let originalAppearance = NSApp.appearance
        defer { NSApp.appearance = originalAppearance }
        NSApp.appearance = NSAppearance(named: .aqua)
        let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let assets = repositoryRoot.appendingPathComponent(
            "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets"
        )
        let stillURL = assets.appendingPathComponent("LopRabbit.imageset/lop-rabbit.png")
        let hopURL = assets.appendingPathComponent("NaturalHop.imageset/natural-hop.png")
        guard let still = NSImage(contentsOf: stillURL),
              let hop = NSImage(contentsOf: hopURL) else {
            fatalError("Could not load motion assets")
        }
        requireWhiteTintMask(at: stillURL, named: "LopRabbit")
        requireWhiteTintMask(at: hopURL, named: "NaturalHop")
        still.setName("LopRabbit")
        hop.setName("NaturalHop")

        let width = 88
        let height = 44
        let scene = SKScene(size: CGSize(width: width, height: height))
        scene.backgroundColor = .clear
        let rabbit = RabbitNode()
        rabbit.setScale(0.58)
        rabbit.position = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.68)
        scene.addChild(rabbit)
        let aqua = NSAppearance(named: .aqua)
        aqua?.performAsCurrentDrawingAppearance {
            rabbit.startRunningAnimation(includeResidualBob: false)
            rabbit.refreshAppearance()
        }

        let renderer = MotionRenderer(scene: scene, width: width, height: height)
        let start: TimeInterval = 100
        _ = renderer.capture(at: start)
        let sampleOffsets: [TimeInterval] = [
            RabbitNode.hopBraceDuration / 2,
            RabbitNode.hopBraceDuration + RabbitNode.hopCrouchDuration / 2,
            RabbitNode.hopSupportDuration + RabbitNode.hopPropulsionDuration / 2,
            RabbitNode.hopSupportDuration + RabbitNode.hopPropulsionDuration
                + RabbitNode.hopFlightDuration / 2,
            RabbitNode.hopSupportDuration + RabbitNode.hopPropulsionDuration
                + RabbitNode.hopFlightDuration + RabbitNode.hopForepawContactDuration / 2,
            RabbitNode.hopSupportDuration + RabbitNode.hopPropulsionDuration
                + RabbitNode.hopFlightDuration + RabbitNode.hopForepawContactDuration
                + RabbitNode.hopHindfootLoadDuration / 2
        ]
        let frames = sampleOffsets.map { renderer.capture(at: start + $0) }
        let frameAreas = frames.map(inkArea)
        guard let braceArea = frameAreas.first, braceArea > 0 else {
            fatalError("Brace frame is empty")
        }
        let areaRatios = frameAreas.map { $0 / braceArea }

        // Repeat the real six-frame cycle against a black surface in dark
        // appearance. A black source texture would disappear here even if the
        // light-appearance capture passed, reproducing the original bug.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkScene = SKScene(size: CGSize(width: width, height: height))
        darkScene.backgroundColor = .clear
        let darkRabbit = RabbitNode()
        darkRabbit.setScale(0.58)
        darkRabbit.position = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.68)
        darkScene.addChild(darkRabbit)
        let darkAqua = NSAppearance(named: .darkAqua)
        darkAqua?.performAsCurrentDrawingAppearance {
            darkRabbit.startRunningAnimation(includeResidualBob: false)
            darkRabbit.refreshAppearance()
        }
        let darkRenderer = MotionRenderer(
            scene: darkScene,
            width: width,
            height: height,
            clearColor: MTLClearColorMake(0, 0, 0, 1)
        )
        let darkStart: TimeInterval = 200
        _ = darkRenderer.capture(at: darkStart)
        let darkFrames = sampleOffsets.map { darkRenderer.capture(at: darkStart + $0) }
        let darkFrameAreas = darkFrames.map(lightArea)
        guard let darkBraceArea = darkFrameAreas.first, darkBraceArea > 0 else {
            fatalError("Dark-appearance brace frame is empty")
        }
        let darkAreaRatios = darkFrameAreas.map { $0 / darkBraceArea }
        precondition(
            darkAreaRatios.dropFirst().allSatisfy { $0 >= 0.86 && $0 <= 1.15 },
            "Dark appearance changed color or apparent size: \(darkAreaRatios)"
        )
        guard let sheetContext = CGContext(
            data: nil,
            width: width * frames.count,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Could not create contact sheet")
        }
        sheetContext.setFillColor(NSColor.white.cgColor)
        sheetContext.fill(CGRect(x: 0, y: 0, width: width * frames.count, height: height))
        for (index, frame) in frames.enumerated() {
            sheetContext.draw(
                frame,
                in: CGRect(x: index * width, y: 0, width: width, height: height)
            )
        }
        guard let sheet = sheetContext.makeImage() else {
            fatalError("Could not finalize contact sheet")
        }
        let output: URL
        if let requestedOutput = CommandLine.arguments.dropFirst().first {
            output = URL(fileURLWithPath: requestedOutput, relativeTo: repositoryRoot)
                .standardizedFileURL
        } else {
            output = repositoryRoot.appendingPathComponent(
                "docs/assets/bunnybar-natural-hop-motion-sheet.png"
            )
        }
        writePNG(sheet, to: output)
        let areaRatioSummary = areaRatios
            .map { String(format: "%.3f", $0) }
            .joined(separator: ", ")
        print("Visual-area ratios: \(areaRatioSummary)")
        let darkAreaRatioSummary = darkAreaRatios
            .map { String(format: "%.3f", $0) }
            .joined(separator: ", ")
        print("Dark visual-area ratios: \(darkAreaRatioSummary)")
        print("Captured production motion sheet at \(output.path)")
        precondition(
            areaRatios.dropFirst().allSatisfy { $0 >= 0.86 && $0 <= 1.15 },
            "Motion frame changed apparent size: \(areaRatios)"
        )
    }
}
