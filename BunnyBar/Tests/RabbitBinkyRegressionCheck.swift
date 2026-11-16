// Regression check for the rare binky transition.
// Run from the repository root on a logged-in Mac:
//
//   xcrun swiftc -warnings-as-errors \
//     -module-cache-path /private/tmp/BunnyBarBinkyRegressionModuleCache \
//     -framework AppKit -framework Metal -framework SpriteKit \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
//     BunnyBar/Tests/RabbitBinkyRegressionCheck.swift \
//     -o /private/tmp/BunnyBarBinkyRegressionCheck && \
//   /private/tmp/BunnyBarBinkyRegressionCheck

import AppKit
import Metal
import SpriteKit

@MainActor
private final class BinkyRegressionRenderer {
    private let renderer: SKRenderer
    private let queue: any MTLCommandQueue
    private let texture: any MTLTexture
    private let pass = MTLRenderPassDescriptor()

    init(scene: SKScene, clearColor: MTLClearColor) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal unavailable")
        }
        self.queue = queue

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 88,
            height: 44,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Could not allocate regression texture")
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
            fatalError("Could not create regression command buffer")
        }
        renderer.render(
            withViewport: CGRect(x: 0, y: 0, width: texture.width, height: texture.height),
            commandBuffer: buffer,
            renderPassDescriptor: pass
        )
        buffer.commit()
        buffer.waitUntilCompleted()
        precondition(buffer.status == .completed, "Regression frame failed")

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
            fatalError("Could not create regression image")
        }
        return image
    }
}

private enum BinkyRegressionAppearance {
    case light
    case dark

    var nsAppearance: NSAppearance {
        switch self {
        case .light: return NSAppearance(named: .aqua)!
        case .dark: return NSAppearance(named: .darkAqua)!
        }
    }

    var clearColor: MTLClearColor {
        switch self {
        case .light: return MTLClearColorMake(1, 1, 1, 1)
        case .dark: return MTLClearColorMake(0, 0, 0, 1)
        }
    }
}

private func visibleArea(of image: CGImage, appearance: BinkyRegressionAppearance) -> CGFloat {
    let rep = NSBitmapImageRep(cgImage: image)
    var area: CGFloat = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
            switch appearance {
            case .light:
                area += 1 - brightness
            case .dark:
                area += brightness
            }
        }
    }
    return area
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

@main
@MainActor
private struct RabbitBinkyRegressionCheck {
    static var assertions = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        require(condition(), message)
    }

    static func main() {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let assetURL = root.appendingPathComponent(
            "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit.png"
        )
        guard let image = NSImage(contentsOf: assetURL) else {
            fatalError("Could not load LopRabbit asset")
        }
        image.setName("LopRabbit")

        let stillStates: [(String, (RabbitNode) -> Void)] = [
            ("idle", { $0.startIdleAnimation() }),
            ("resting", { $0.startRestingAnimation() }),
            ("sleeping", { $0.startSleepingAnimation() }),
            ("grooming", { $0.startGroomingAnimation() })
        ]

        for appearance in [BinkyRegressionAppearance.light, .dark] {
            NSApp.appearance = appearance.nsAppearance
            for (stateName, enterStillState) in stillStates {
                for direction in [CGFloat(1), CGFloat(-1)] {
                    let scene = SKScene(size: CGSize(width: 88, height: 44))
                    scene.backgroundColor = .clear
                    let rabbit = RabbitNode()
                    rabbit.setScale(0.58)
                    rabbit.xScale = 0.58 * direction
                    rabbit.yScale = 0.58
                    rabbit.position = CGPoint(x: 44, y: 44 * 0.68)
                    scene.addChild(rabbit)
                    let renderer = BinkyRegressionRenderer(
                        scene: scene,
                        clearColor: appearance.clearColor
                    )
                    let start: TimeInterval = 100
                    let directionName = direction > 0 ? "right" : "left"
                    let context = stateName + " " + String(describing: appearance)
                        + " " + directionName

                    enterStillState(rabbit)
                    let stillArea = visibleArea(
                        of: renderer.capture(at: start),
                        appearance: appearance
                    )
                    check(stillArea > 100, context + " still pose is empty")

                    var binkyCompleted = false
                    rabbit.performBinky {
                        binkyCompleted = true
                        // This is the production completion path's visual reset.
                        rabbit.startRestingAnimation()
                    }
                    let binkyArea = visibleArea(
                        of: renderer.capture(at: start + 0.01),
                        appearance: appearance
                    )
                    let binkyRatio = binkyArea / stillArea
                    check(
                        binkyRatio >= 0.90 && binkyRatio <= 1.10,
                        context + " binky changed apparent mass: " + String(describing: binkyRatio)
                    )
                    let initialBinkyBounds = rabbit.calculateAccumulatedFrame()
                    let initialPosition = rabbit.position
                    check(
                        initialBinkyBounds.minY >= 0 && initialBinkyBounds.maxY <= 44,
                        context + " binky start is clipped: " + String(describing: initialBinkyBounds)
                    )

                    for step in 1...30 {
                        let frameTime = start + Double(step) * 0.05
                        let frame = renderer.capture(at: frameTime)
                        let frameArea = visibleArea(of: frame, appearance: appearance)
                        let frameRatio = frameArea / stillArea
                        check(
                            frameRatio >= 0.86 && frameRatio <= 1.15,
                            context + " binky frame " + String(step)
                                + " changed apparent mass: " + String(describing: frameRatio)
                        )
                        let frameBounds = rabbit.calculateAccumulatedFrame()
                        check(
                            frameBounds.minY >= 0 && frameBounds.maxY <= 44,
                            context + " binky frame " + String(step)
                                + " is clipped: " + String(describing: frameBounds)
                        )
                    }
                    check(binkyCompleted, context + " binky did not complete")
                    check(
                        abs(rabbit.position.x - initialPosition.x) < 0.001
                            && abs(rabbit.position.y - initialPosition.y) < 0.001,
                        context + " binky did not return to its starting position"
                    )
                    check(abs(rabbit.zRotation) < 0.001, context + " binky rotation did not reset")
                    check(
                        abs(rabbit.xScale - 0.58 * direction) < 0.001,
                        context + " binky direction did not reset"
                    )
                    let restoredArea = visibleArea(
                        of: renderer.capture(at: start + 1.7),
                        appearance: appearance
                    )
                    let restoredRatio = restoredArea / stillArea
                    check(
                        restoredRatio >= 0.90 && restoredRatio <= 1.10,
                        context + " did not restore still mass: " + String(describing: restoredRatio)
                    )
                    rabbit.stopAllAnimations()
                    scene.removeAllActions()
                }
            }
        }
        print("PASS: " + String(assertions) + " binky appearance regression assertions")
    }
}
