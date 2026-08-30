// Deterministic geometry regression check for the bounded SpriteKit viewport.
// Run from the repository root with the app sources and SpriteKit linked:
//
//   xcrun swiftc -framework AppKit -framework SpriteKit \
//     BunnyBar/Sources/BunnyBar/App/SystemMetrics.swift \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitScene.swift \
//     BunnyBar/Tests/RabbitSceneGeometryCheck.swift \
//     -o /private/tmp/BunnyBarRabbitSceneGeometryCheck && \
//   /private/tmp/BunnyBarRabbitSceneGeometryCheck
//
// This is intentionally a small standalone geometry check rather than an app
// launch test; it still needs WindowServer for SKView conversion.

import AppKit
import SpriteKit

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
@MainActor
private struct RabbitSceneGeometryCheck {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let asset = "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit.png"
        if let image = NSImage(contentsOfFile: asset) { image.setName("LopRabbit") }
        require(abs(Double(RabbitPerformance.speed(for: 0)) - 0.90) < 0.001,
                "idle CPU speed changed")
        require(abs(Double(RabbitPerformance.speed(for: 100)) - 1.15) < 0.001,
                "busy CPU speed changed")

        for worldWidth in [CGFloat(1080), CGFloat(1920)] {
            let viewport = CGSize(width: 88, height: 44)
            let scene = RabbitScene(size: viewport)
            scene.worldWidth = worldWidth
            scene.scaleMode = .resizeFill

            let view = SKView(frame: NSRect(origin: .zero, size: viewport))
            view.allowsTransparency = true
            view.wantsLayer = true
            view.layer?.isOpaque = false
            view.presentScene(scene)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

            // A 44pt viewport must remain 1:1; this catches accidental aspectFill
            // scaling caused by passing a full-display height to SKScene.
            require(scene.size == viewport, "scene size changed for world width \(worldWidth)")
            let home = CGPoint(x: worldWidth * 0.40, y: viewport.height * 0.68)
            let homeInView = scene.convertPoint(toView: home)
            let xPlusOne = scene.convertPoint(toView: CGPoint(x: home.x + 1, y: home.y))
            let yPlusOne = scene.convertPoint(toView: CGPoint(x: home.x, y: home.y + 1))
            require(abs((xPlusOne.x - homeInView.x) - 1) < 0.01,
                    "world X is not 1:1 for width \(worldWidth)")
            require(abs((yPlusOne.y - homeInView.y) - 1) < 0.01,
                    "world Y is not 1:1 for width \(worldWidth)")
            require(abs(homeInView.y - home.y) < 0.01,
                    "home Y changed for width \(worldWidth)")
            require(abs(homeInView.x - viewport.width / 2) < 0.01,
                    "home rabbit is not centered in its viewport for width \(worldWidth)")

            let halfViewport = viewport.width / 2
            let leftCamera = RabbitScene.cameraX(forRabbitX: 0, worldWidth: worldWidth, viewportWidth: viewport.width)
            let rightCamera = RabbitScene.cameraX(forRabbitX: worldWidth,
                                                  worldWidth: worldWidth,
                                                  viewportWidth: viewport.width)
            require(leftCamera == halfViewport, "left edge camera clamp changed")
            require(rightCamera == worldWidth - halfViewport, "right edge camera clamp changed")

            let homeOrigin = RabbitScene.viewportOriginX(screenMinX: 0,
                                                         screenWidth: worldWidth,
                                                         rabbitX: worldWidth * 0.40,
                                                         viewportWidth: viewport.width)
            let negativeOrigin = RabbitScene.viewportOriginX(screenMinX: -1920,
                                                             screenWidth: worldWidth,
                                                             rabbitX: worldWidth * 0.40,
                                                             viewportWidth: viewport.width)
            require(abs(homeOrigin - (worldWidth * 0.40 - viewport.width / 2)) < 0.01,
                    "positive screen origin home projection changed")
            require(abs(negativeOrigin - (-1920 + worldWidth * 0.40 - viewport.width / 2)) < 0.01,
                    "negative screen origin home projection changed")
            let rightOrigin = RabbitScene.viewportOriginX(screenMinX: 0,
                                                          screenWidth: worldWidth,
                                                          rabbitX: worldWidth,
                                                          viewportWidth: viewport.width)
            require(rightOrigin == worldWidth - viewport.width,
                    "right-edge viewport projection changed")
            require(RabbitScene.binkyCooldown == 900,
                    "binky cooldown changed")

            var first = RabbitBehaviorRandom(seed: 42)
            var second = RabbitBehaviorRandom(seed: 42)
            for _ in 0..<8 {
                require(first.unit() == second.unit(), "seeded behavior diverged")
            }
            for _ in 0..<16 {
                let requested = first.cgFloat(in: 24...58)
                let available = CGFloat(19 + Int(first.unit() * 500))
                require(RabbitScene.boundedHopDistance(requested: requested, available: available) <= available,
                        "short hop exceeded available room")
            }
        }

        print("PASS: RabbitScene bounded viewport geometry")
    }
}
