// Deterministic offscreen behavior regression check.
// Run from the repository root on a logged-in Mac:
//
//   xcrun swiftc -warnings-as-errors \
//     -module-cache-path /private/tmp/BunnyBarRuntimeCheckModuleCache \
//     -framework AppKit -framework Metal -framework SpriteKit \
//     BunnyBar/Sources/BunnyBar/App/SystemMetrics.swift \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
//     BunnyBar/Sources/BunnyBar/Scenes/RabbitScene.swift \
//     BunnyBar/Tests/RabbitBehaviorRuntimeCheck.swift \
//     -o /private/tmp/BunnyBarBehaviorRuntimeCheck && \
//   /private/tmp/BunnyBarBehaviorRuntimeCheck

import AppKit
import Metal
import SpriteKit

@MainActor
private final class OffscreenFrames {
    let renderer: SKRenderer
    let queue: any MTLCommandQueue
    let pass = MTLRenderPassDescriptor()

    init(scene: SKScene) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { fatalError("Metal unavailable") }
        self.queue = queue
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 88, height: 44, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        pass.colorAttachments[0].texture = device.makeTexture(descriptor: descriptor)
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        renderer = SKRenderer(device: device)
        renderer.scene = scene
    }

    func advance(to time: TimeInterval) {
        renderer.update(atTime: time)
        guard let buffer = queue.makeCommandBuffer() else { fatalError("No Metal buffer") }
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: 88, height: 44),
                        commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        precondition(buffer.status == .completed, "Metal frame failed")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

@main
@MainActor
private struct RabbitBehaviorRuntimeCheck {
    static var assertions = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        require(condition(), message)
    }

    static func main() {
        _ = NSApplication.shared
        let asset = "BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets/LopRabbit.imageset/lop-rabbit.png"
        if let image = NSImage(contentsOfFile: asset) { image.setName("LopRabbit") }

        for width in [CGFloat(1080), CGFloat(1920), CGFloat(100)] {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 88, height: 44))
            view.isPaused = true
            view.allowsTransparency = true
            let scene = RabbitScene(size: view.bounds.size)
            scene.worldWidth = width
            scene.behaviorSeedForTesting = 42 + UInt64(width)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
            guard let rabbit = scene.children.compactMap({ $0 as? RabbitNode }).first else {
                fatalError("Scene did not create rabbit")
            }
            let frames = OffscreenFrames(scene: scene)
            var time: TimeInterval = 100
            frames.advance(to: time)
            let initialX = rabbit.position.x
            var previousX = initialX
            var previousState = String(describing: scene.currentState)
            var visited = Set<String>()
            var directions = Set<Int>()
            var hasRestedElsewhere = false
            var pausedDuringHop = false
            var resumedHopNeedsLanding = false

            for step in 1...6000 {
                if step % 20 == 0 {
                    let stateBeforeLoad = scene.currentState
                    let positionBeforeLoad = rabbit.position
                    scene.applyPerformance(RabbitPerformance(cpuPercent: step % 40 == 0 ? 100 : 0))
                    check(scene.currentState == stateBeforeLoad, "CPU interrupted behavior")
                    check(rabbit.position == positionBeforeLoad, "CPU changed position")
                }
                time += 0.05
                frames.advance(to: time)
                let state = String(describing: scene.currentState)
                visited.insert(state)
                let visualBounds = rabbit.calculateAccumulatedFrame()
                check(visualBounds.minY >= 0 && visualBounds.maxY <= 44,
                      "Rabbit clipped vertically: \(visualBounds), state \(state)")
                let deltaX = rabbit.position.x - previousX
                if abs(deltaX) > 0.01 { directions.insert(deltaX > 0 ? 1 : -1) }
                check(abs(deltaX) < 22, "Warp or excessive step: \(deltaX), state \(state)")
                check(rabbit.position.x >= 0 && rabbit.position.x <= width,
                      "Rabbit left display: \(rabbit.position.x) / \(width)")
                check(abs(rabbit.yScale - 0.58) < 0.001, "Rabbit scale changed")
                if abs(deltaX) > 0.1 {
                    check(deltaX * rabbit.xScale > 0, "Rabbit moved backwards relative to its facing")
                }
                if state != "running" && state != "binky" {
                    check(abs(rabbit.position.y - 44 * 0.68) < 0.04,
                          "Resting baseline drifted: \(rabbit.position.y)")
                }
                if previousState != "running" && previousState != "binky"
                    && state != "running" && state != "binky" {
                    check(abs(deltaX) < 0.02, "Stationary transition changed X")
                }
                if state == "resting" && abs(rabbit.position.x - initialX) > 4 {
                    hasRestedElsewhere = true
                }

                if !pausedDuringHop && state == "running" && rabbit.position.y > 44 * 0.68 + 0.1 {
                    pausedDuringHop = true
                    resumedHopNeedsLanding = true
                    let pausedHopPosition = rabbit.position
                    let pausedHopState = scene.currentState
                    scene.isPaused = true
                    for _ in 0..<40 {
                        // Keep the renderer clock fixed while the scene is
                        // paused. Advancing a synthetic timestamp during a
                        // pause makes SKRenderer replay the elapsed action
                        // time on resume, which is not how an SKView pause
                        // behaves and would look like a teleport in this
                        // offscreen harness.
                        frames.advance(to: time)
                        check(rabbit.position == pausedHopPosition, "Hop pause moved rabbit")
                        check(scene.currentState == pausedHopState, "Hop pause advanced state")
                    }
                    scene.isPaused = false
                }
                if resumedHopNeedsLanding && state == "resting" {
                    resumedHopNeedsLanding = false
                }
                previousX = rabbit.position.x
                previousState = state
            }

            check(!directions.isEmpty, "Rabbit never moved")
            check(hasRestedElsewhere, "Rabbit never rested at an arrival location")
            if width == 100 { check(directions.count == 2, "Narrow display never turned") }
            check(visited.contains("resting"), "Resting state was never visited")
            check(pausedDuringHop && !resumedHopNeedsLanding, "Hop pause did not resume into landing")

            scene.isPaused = true
            let pausedPosition = rabbit.position
            let pausedState = scene.currentState
            for _ in 0..<40 {
                frames.advance(to: time)
                check(rabbit.position == pausedPosition, "Paused rabbit moved")
                check(scene.currentState == pausedState, "Paused behavior advanced")
            }
            scene.isPaused = false
            time += 0.05
            frames.advance(to: time)
            check(abs(rabbit.position.x - pausedPosition.x) < 22, "Resume caused a warp")

            // Directly exercise the rare pose in the same 44pt viewport. The
            // production state machine gates this behind its scene cooldown;
            // this check isolates the pose's vertical bounds and recovery.
            scene.removeAllActions()
            rabbit.speed = 1.0
            var binkyCompleted = false
            rabbit.performBinky { binkyCompleted = true }
            for _ in 0..<40 {
                time += 0.05
                frames.advance(to: time)
                let binkyBounds = rabbit.calculateAccumulatedFrame()
                check(binkyBounds.minY >= 0 && binkyBounds.maxY <= 44,
                      "Binky clipped vertically: \(binkyBounds)")
            }
            check(binkyCompleted, "Binky did not complete")
            rabbit.startRestingAnimation()
            check(abs(rabbit.position.y - 44 * 0.68) < 0.04, "Binky changed baseline")

            scene.stop()
            let stoppedPosition = rabbit.position
            for _ in 0..<20 {
                time += 0.05
                frames.advance(to: time)
                check(rabbit.position == stoppedPosition, "Stopped rabbit moved")
            }
            check(!scene.hasActions() && !rabbit.hasActions(), "Stop left actions scheduled")
            view.presentScene(nil)
        }
        print("PASS: \(assertions) native SpriteKit runtime assertions")
    }
}
