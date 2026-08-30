//
//  RabbitNode.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import SpriteKit

class RabbitNode: SKNode {
    private enum RunningFrame: Int, CaseIterable, Hashable {
        case brace
        case crouch
        case propulsion
        case flight
        case forepawContact
        case hindfootLoad
    }

    // A relaxed house-rabbit hop is a compact half-bound, not a held leap.
    // The two support poses lead into a brief flight, then the forepaws and
    // hindfeet get enough screen time to make the contact order readable.
    static let hopBraceDuration: TimeInterval = 0.05
    static let hopCrouchDuration: TimeInterval = 0.08
    static let hopPropulsionDuration: TimeInterval = 0.06
    static let hopFlightDuration: TimeInterval = 0.09
    static let hopForepawContactDuration: TimeInterval = 0.08
    static let hopHindfootLoadDuration: TimeInterval = 0.09
    static let hopSettleDuration: TimeInterval = 0.05

    static var hopSupportDuration: TimeInterval {
        hopBraceDuration + hopCrouchDuration
    }

    static var hopMotionDuration: TimeInterval {
        hopPropulsionDuration + hopFlightDuration
            + hopForepawContactDuration + hopHindfootLoadDuration
    }

    private var currentVisual: SKNode?

    // Resolve the label color against the overlay's effective appearance so
    // the monochrome rabbit remains visible on both light and dark menu bars.
    private var rabbitColor: NSColor { resolvedSystemColor(.labelColor) }
    private var outlineColor: NSColor { resolvedSystemColor(.textBackgroundColor) }

    private func resolvedSystemColor(_ color: NSColor) -> NSColor {
        let appearance = scene?.view?.effectiveAppearance ?? NSApp.effectiveAppearance
        var resolved = color
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.deviceRGB) ?? color
        }
        return resolved
    }

    /// SpriteKit resolves NSColor when assigned, so update existing nodes when
    /// the hosting view moves between light and dark appearances.
    func refreshAppearance() {
        let foreground = rabbitColor
        let outline = outlineColor
        if let currentShape = currentVisual as? SKShapeNode {
            applyAppearance(to: currentShape, foreground: foreground, outline: outline)
        } else if let currentTexture = currentVisual as? SKSpriteNode {
            applyAppearance(to: currentTexture, foreground: foreground)
        }
    }

    private func applyAppearance(to shape: SKShapeNode, foreground: NSColor, outline _: NSColor) {
        shape.fillColor = foreground
        // Do not stroke the inner ear cutout: it must reveal the real
        // transparent menu-bar background rather than paint a fixed line.
        shape.strokeColor = .clear
        shape.lineWidth = 0.0
    }

    private func applyAppearance(to texture: SKSpriteNode, foreground: NSColor) {
        // The source asset is white RGB with alpha. Blend the resolved label
        // color through it while preserving the transparent ear cutout.
        texture.color = foreground
        texture.colorBlendFactor = 1.0
    }

    override init() {
        super.init()
        // Start with running pose
        showRunningPose()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Shape Creation

    private func clearCurrentShape() {
        currentVisual?.removeFromParent()
        currentVisual = nil
    }

    /// Reverse-winding, closed teardrop inside the lop ear. With the
    /// non-zero fill rule this is a real transparent hole, not a painted
    /// background-colored stroke. At the menu-bar scale it resolves to a
    /// restrained 1px white/transparent ear seam.
    private func appendEarCutout(to path: CGMutablePath, baseY: CGFloat = 10.0, yOffset: CGFloat = 0) {
        // A fine J-shaped band starts in the neck valley and curves down into
        // the cheek before returning upward. It is reverse-wound relative to
        // the outside contour, making the narrow strip a real transparent
        // hole rather than an eye-like filled teardrop.
        let y = baseY + yOffset
        path.move(to: CGPoint(x: 5.0, y: y))
        path.addCurve(to: CGPoint(x: 7.0, y: y - 9.0),
                      control1: CGPoint(x: 5.2, y: y - 3.0),
                      control2: CGPoint(x: 6.0, y: y - 7.0))
        path.addCurve(to: CGPoint(x: 9.0, y: y - 10.8),
                      control1: CGPoint(x: 7.4, y: y - 10.5),
                      control2: CGPoint(x: 8.2, y: y - 11.0))
        path.addCurve(to: CGPoint(x: 13.0, y: y - 4.2),
                      control1: CGPoint(x: 10.4, y: y - 11.0),
                      control2: CGPoint(x: 12.4, y: y - 7.0))
        path.addCurve(to: CGPoint(x: 11.7, y: y - 5.0),
                      control1: CGPoint(x: 12.8, y: y - 4.8),
                      control2: CGPoint(x: 12.2, y: y - 5.0))
        path.addCurve(to: CGPoint(x: 9.8, y: y - 8.6),
                      control1: CGPoint(x: 11.3, y: y - 6.2),
                      control2: CGPoint(x: 10.5, y: y - 8.0))
        path.addCurve(to: CGPoint(x: 8.0, y: y - 8.0),
                      control1: CGPoint(x: 9.3, y: y - 9.0),
                      control2: CGPoint(x: 8.6, y: y - 8.8))
        path.addCurve(to: CGPoint(x: 6.7, y: y - 0.3),
                      control1: CGPoint(x: 7.5, y: y - 5.8),
                      control2: CGPoint(x: 6.9, y: y - 2.0))
        path.addCurve(to: CGPoint(x: 5.0, y: y),
                      control1: CGPoint(x: 5.6, y: y - 0.1),
                      control2: CGPoint(x: 5.2, y: y - 0.0))
        path.closeSubpath()
    }

    // MARK: - Idle Pose (sitting, alert)

    private func createIdleShape() -> SKShapeNode {
        let path = CGMutablePath()

        // Body - sitting round shape
        path.move(to: CGPoint(x: -10, y: -10))
        // Bottom
        path.addQuadCurve(to: CGPoint(x: 10, y: -10), control: CGPoint(x: 0, y: -14))
        // Right side up
        path.addQuadCurve(to: CGPoint(x: 8, y: 4), control: CGPoint(x: 14, y: -4))
        // Shoulder to head
        path.addQuadCurve(to: CGPoint(x: 6, y: 10), control: CGPoint(x: 10, y: 8))
        // Head top
        path.addQuadCurve(to: CGPoint(x: -2, y: 10), control: CGPoint(x: 2, y: 14))
        // Left side down
        path.addQuadCurve(to: CGPoint(x: -10, y: -10), control: CGPoint(x: -14, y: 0))
        path.closeSubpath()

        // Lop ears fall to either side of the head.
        path.move(to: CGPoint(x: -4, y: 10))
        path.addCurve(to: CGPoint(x: -19, y: 5), control1: CGPoint(x: -10, y: 13), control2: CGPoint(x: -18, y: 11))
        path.addCurve(to: CGPoint(x: 0, y: 9), control1: CGPoint(x: -22, y: -1), control2: CGPoint(x: -8, y: 3))
        path.closeSubpath()

        // Near ear hangs forward and down, separated by the outline.
        path.move(to: CGPoint(x: 5, y: 10))
        path.addCurve(to: CGPoint(x: 15, y: 2), control1: CGPoint(x: 8, y: 3), control2: CGPoint(x: 16, y: -4))
        path.addCurve(to: CGPoint(x: 2, y: 12), control1: CGPoint(x: 17, y: 8), control2: CGPoint(x: 10, y: 12))
        path.closeSubpath()

        // Small front feet
        path.addEllipse(in: CGRect(x: 6, y: -12, width: 5, height: 4))

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = outlineColor
        shape.lineWidth = 1.25
        return shape
    }

    // MARK: - Resting Pose (lying down, awake)

    private func createRestingShape() -> SKShapeNode {
        let path = CGMutablePath()

        // Lying flat but head up slightly
        path.move(to: CGPoint(x: -16, y: -6))
        // Back (flat)
        path.addQuadCurve(to: CGPoint(x: 8, y: -2), control: CGPoint(x: -4, y: 2))
        // Head raised
        path.addQuadCurve(to: CGPoint(x: 14, y: 4), control: CGPoint(x: 12, y: 0))
        // Head top
        path.addQuadCurve(to: CGPoint(x: 8, y: 6), control: CGPoint(x: 12, y: 8))
        // Back of head
        path.addQuadCurve(to: CGPoint(x: 4, y: 2), control: CGPoint(x: 4, y: 6))
        // Body back down
        path.addQuadCurve(to: CGPoint(x: -16, y: -6), control: CGPoint(x: -8, y: -2))
        path.closeSubpath()

        // Lop ears rest backward along the body.
        path.move(to: CGPoint(x: 6, y: 6))
        path.addCurve(to: CGPoint(x: -12, y: 8), control1: CGPoint(x: 0, y: 13), control2: CGPoint(x: -10, y: 13))
        path.addCurve(to: CGPoint(x: 8, y: 4), control1: CGPoint(x: -16, y: 2), control2: CGPoint(x: -2, y: 2))
        path.closeSubpath()

        path.move(to: CGPoint(x: 10, y: 6))
        path.addCurve(to: CGPoint(x: -8, y: 1), control1: CGPoint(x: 2, y: 9), control2: CGPoint(x: -7, y: 7))
        path.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: -10, y: -4), control2: CGPoint(x: 2, y: 0))
        path.closeSubpath()

        // Tail
        path.addEllipse(in: CGRect(x: -20, y: -8, width: 5, height: 5))

        // Front paws visible
        path.addEllipse(in: CGRect(x: 10, y: -8, width: 4, height: 3))

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = outlineColor
        shape.lineWidth = 1.25
        return shape
    }

    // MARK: - Grooming Pose (sitting, paw to face)

    private func createGroomingShape() -> SKShapeNode {
        let path = CGMutablePath()

        // Sitting body (similar to idle but with raised paw)
        path.move(to: CGPoint(x: -10, y: -10))
        path.addQuadCurve(to: CGPoint(x: 10, y: -10), control: CGPoint(x: 0, y: -14))
        path.addQuadCurve(to: CGPoint(x: 8, y: 4), control: CGPoint(x: 14, y: -4))
        path.addQuadCurve(to: CGPoint(x: 6, y: 10), control: CGPoint(x: 10, y: 8))
        path.addQuadCurve(to: CGPoint(x: -2, y: 10), control: CGPoint(x: 2, y: 14))
        path.addQuadCurve(to: CGPoint(x: -10, y: -10), control: CGPoint(x: -14, y: 0))
        path.closeSubpath()

        // Relaxed lop ears; grooming never switches to an upright silhouette.
        path.move(to: CGPoint(x: -4, y: 10))
        path.addCurve(to: CGPoint(x: -19, y: 5), control1: CGPoint(x: -10, y: 13), control2: CGPoint(x: -18, y: 11))
        path.addCurve(to: CGPoint(x: 0, y: 9), control1: CGPoint(x: -22, y: -1), control2: CGPoint(x: -8, y: 3))
        path.closeSubpath()

        path.move(to: CGPoint(x: 5, y: 10))
        path.addCurve(to: CGPoint(x: 14, y: 2), control1: CGPoint(x: 8, y: 3), control2: CGPoint(x: 15, y: -4))
        path.addCurve(to: CGPoint(x: 2, y: 12), control1: CGPoint(x: 16, y: 8), control2: CGPoint(x: 9, y: 12))
        path.closeSubpath()

        // Raised paw (grooming face)
        path.move(to: CGPoint(x: 8, y: 4))
        path.addLine(to: CGPoint(x: 12, y: 10))
        path.addQuadCurve(to: CGPoint(x: 10, y: 12), control: CGPoint(x: 14, y: 12))
        path.addLine(to: CGPoint(x: 6, y: 6))
        path.closeSubpath()

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = outlineColor
        shape.lineWidth = 1.25
        return shape
    }

    // MARK: - Sleeping Pose (curled up)

    private func createSleepingShape() -> SKShapeNode {
        let path = CGMutablePath()

        // Curled body - compact round shape
        path.move(to: CGPoint(x: -14, y: 0))
        // Back curve (top)
        path.addQuadCurve(to: CGPoint(x: 14, y: 0), control: CGPoint(x: 0, y: 12))
        // Front (right side)
        path.addQuadCurve(to: CGPoint(x: 10, y: -8), control: CGPoint(x: 16, y: -4))
        // Bottom
        path.addQuadCurve(to: CGPoint(x: -10, y: -8), control: CGPoint(x: 0, y: -10))
        // Back (left side)
        path.addQuadCurve(to: CGPoint(x: -14, y: 0), control: CGPoint(x: -16, y: -4))
        path.closeSubpath()

        // Both lop ears lie along the curled body.
        path.move(to: CGPoint(x: 10, y: 2))
        path.addCurve(to: CGPoint(x: -10, y: 7), control1: CGPoint(x: 0, y: 0), control2: CGPoint(x: -13, y: 1))
        path.addCurve(to: CGPoint(x: 8, y: 4), control1: CGPoint(x: -9, y: 11), control2: CGPoint(x: 1, y: 11))
        path.closeSubpath()

        // Near ear droops lower and remains visibly separate.
        path.move(to: CGPoint(x: 8, y: 3))
        path.addCurve(to: CGPoint(x: -13, y: 0), control1: CGPoint(x: -1, y: -1), control2: CGPoint(x: -14, y: -5))
        path.addCurve(to: CGPoint(x: 6, y: 6), control1: CGPoint(x: -12, y: 5), control2: CGPoint(x: -1, y: 7))
        path.closeSubpath()

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = outlineColor
        shape.lineWidth = 1.25
        return shape
    }

    // MARK: - Binky Pose (jumping, stretched)

    private func createBinkyShape() -> SKShapeNode {
        let path = CGMutablePath()

        // Stretched jumping body
        path.move(to: CGPoint(x: -18, y: 2))
        // Back
        path.addQuadCurve(to: CGPoint(x: -8, y: 10), control: CGPoint(x: -14, y: 8))
        // Back to head
        path.addQuadCurve(to: CGPoint(x: 10, y: 8), control: CGPoint(x: 0, y: 14))
        // Head
        path.addQuadCurve(to: CGPoint(x: 18, y: 4), control: CGPoint(x: 16, y: 10))
        // Nose
        path.addQuadCurve(to: CGPoint(x: 16, y: 0), control: CGPoint(x: 20, y: 2))
        // Chin
        path.addQuadCurve(to: CGPoint(x: 8, y: -2), control: CGPoint(x: 12, y: -2))
        // Front legs (tucked/extended)
        path.addLine(to: CGPoint(x: 12, y: -10))
        path.addLine(to: CGPoint(x: 10, y: -12))
        path.addLine(to: CGPoint(x: 6, y: -4))
        // Belly
        path.addQuadCurve(to: CGPoint(x: -6, y: -2), control: CGPoint(x: 0, y: -6))
        // Back legs (kicked out)
        path.addLine(to: CGPoint(x: -16, y: -10))
        path.addLine(to: CGPoint(x: -18, y: -8))
        path.addLine(to: CGPoint(x: -12, y: 0))
        // To tail
        path.addQuadCurve(to: CGPoint(x: -18, y: 2), control: CGPoint(x: -16, y: 0))
        path.closeSubpath()

        // Lop ears fly backward, nearly horizontal during the binky.
        path.move(to: CGPoint(x: 6, y: 7))
        path.addCurve(to: CGPoint(x: -19, y: 13), control1: CGPoint(x: -5, y: 5), control2: CGPoint(x: -23, y: 7))
        path.addCurve(to: CGPoint(x: 4, y: 10), control1: CGPoint(x: -17, y: 18), control2: CGPoint(x: -4, y: 17))
        path.closeSubpath()

        path.move(to: CGPoint(x: 10, y: 7))
        path.addCurve(to: CGPoint(x: -16, y: 5), control1: CGPoint(x: -2, y: 3), control2: CGPoint(x: -19, y: 0))
        path.addCurve(to: CGPoint(x: 8, y: 10), control1: CGPoint(x: -15, y: 11), control2: CGPoint(x: -1, y: 13))
        path.closeSubpath()

        // Tail
        path.addEllipse(in: CGRect(x: -22, y: 0, width: 6, height: 6))

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = outlineColor
        shape.lineWidth = 1.25
        return shape
    }

    // MARK: - Single-contour still poses

    private func makeSilhouetteShape(path: CGMutablePath) -> SKShapeNode {
        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = rabbitColor
        shape.lineWidth = 1.0
        applyAppearance(to: shape, foreground: rabbitColor, outline: outlineColor)
        return shape
    }

    /// The generated C reference is the canonical still pose. Keeping it as
    /// one texture preserves its exact low loaf/head/ear-cut proportions at
    /// the menu-bar scale; the scene's existing 0.58 parent scale applies to
    /// the 64x31 logical asset.
    private func createStillTextureNode() -> SKSpriteNode {
        let texture = SKTexture(imageNamed: "LopRabbit")
        texture.filteringMode = .linear
        let node = SKSpriteNode(texture: texture)
        applyAppearance(to: node, foreground: rabbitColor)
        return node
    }

    /// The adopted LopRabbit is retained for brace/loading so entering a hop
    /// cannot change the rabbit's apparent size. Image-2 supplies the four
    /// contact-specific silhouettes from propulsion through hindfoot loading.
    private func runningTexture(for frame: RunningFrame) -> SKTexture {
        switch frame {
        case .brace, .crouch:
            let texture = SKTexture(imageNamed: "LopRabbit")
            texture.filteringMode = .linear
            return texture
        case .propulsion, .flight, .forepawContact, .hindfootLoad:
            break
        }

        let sheet = SKTexture(imageNamed: "NaturalHop")
        sheet.filteringMode = .linear
        let frameCount = CGFloat(RunningFrame.allCases.count)
        let imageFrame: Int
        switch frame {
        case .propulsion: imageFrame = 2
        case .flight: imageFrame = 3
        case .forepawContact: imageFrame = 4
        case .hindfootLoad: imageFrame = 5
        case .brace, .crouch: preconditionFailure("Handled above")
        }
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(imageFrame) / frameCount,
                y: 0,
                width: 1 / frameCount,
                height: 1
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private func createRunningTextureNode(frame: RunningFrame) -> SKSpriteNode {
        let node = SKSpriteNode(
            texture: runningTexture(for: frame),
            size: CGSize(width: 64, height: 31)
        )
        applyAppearance(to: node, foreground: rabbitColor)
        return node
    }

    /// Curled sleeping lop rabbit. The tail and one ear are perimeter bumps;
    /// there are deliberately no inner paths, holes, or facial marks.
    private func createSingleSleepingShape() -> SKShapeNode {
        let path = CGMutablePath()
        // One low, side-on outer contour: tail, rump, head, short lop ear,
        // folded paws, and belly. No nested ear/body paths are used.
        path.move(to: CGPoint(x: -18, y: 2))
        path.addCurve(to: CGPoint(x: -22, y: 4), control1: CGPoint(x: -20, y: 2), control2: CGPoint(x: -23, y: 2))
        path.addCurve(to: CGPoint(x: -21, y: 8), control1: CGPoint(x: -23, y: 6), control2: CGPoint(x: -23, y: 8))
        path.addCurve(to: CGPoint(x: -18, y: 8), control1: CGPoint(x: -20, y: 9), control2: CGPoint(x: -19, y: 9))
        path.addCurve(to: CGPoint(x: -14, y: 12), control1: CGPoint(x: -17, y: 9), control2: CGPoint(x: -16, y: 11))
        path.addCurve(to: CGPoint(x: -8, y: 15), control1: CGPoint(x: -12, y: 14), control2: CGPoint(x: -10, y: 15))
        path.addCurve(to: CGPoint(x: 0, y: 14), control1: CGPoint(x: -4, y: 15), control2: CGPoint(x: -2, y: 15))
        // Low neck valley, then the same rounded head as the running pose.
        path.addCurve(to: CGPoint(x: 4, y: 11), control1: CGPoint(x: 2, y: 13), control2: CGPoint(x: 3, y: 11))
        path.addCurve(to: CGPoint(x: 8, y: 16), control1: CGPoint(x: 6, y: 12), control2: CGPoint(x: 6, y: 15))
        path.addCurve(to: CGPoint(x: 14, y: 17), control1: CGPoint(x: 10, y: 17), control2: CGPoint(x: 12, y: 18))
        path.addCurve(to: CGPoint(x: 19, y: 13), control1: CGPoint(x: 17, y: 16), control2: CGPoint(x: 19, y: 15))
        path.addCurve(to: CGPoint(x: 22, y: 8), control1: CGPoint(x: 21, y: 11), control2: CGPoint(x: 23, y: 9))
        path.addCurve(to: CGPoint(x: 22, y: 4), control1: CGPoint(x: 23, y: 6), control2: CGPoint(x: 23, y: 4))
        // Rounded head underside; the ear is an internal cutout only.
        path.addCurve(to: CGPoint(x: 19, y: 1), control1: CGPoint(x: 21, y: 3), control2: CGPoint(x: 20, y: 2))
        path.addCurve(to: CGPoint(x: 16, y: -2), control1: CGPoint(x: 19, y: 0), control2: CGPoint(x: 18, y: -2))
        path.addCurve(to: CGPoint(x: 12, y: -4), control1: CGPoint(x: 15, y: -2), control2: CGPoint(x: 14, y: -4))
        path.addCurve(to: CGPoint(x: 8, y: -2), control1: CGPoint(x: 10, y: -4), control2: CGPoint(x: 9, y: -2))
        // Compact front paw and a folded belly.
        path.addCurve(to: CGPoint(x: 7, y: -5), control1: CGPoint(x: 8, y: -4), control2: CGPoint(x: 7, y: -5))
        path.addCurve(to: CGPoint(x: 9, y: -7), control1: CGPoint(x: 7, y: -6), control2: CGPoint(x: 8, y: -7))
        path.addCurve(to: CGPoint(x: 6, y: -8), control1: CGPoint(x: 9, y: -8), control2: CGPoint(x: 8, y: -9))
        path.addCurve(to: CGPoint(x: 1, y: -8), control1: CGPoint(x: 4, y: -8), control2: CGPoint(x: 2, y: -8))
        // Low, flat loaf belly; no large downward hind-leg lobe.
        path.addCurve(to: CGPoint(x: -4, y: -8), control1: CGPoint(x: 0, y: -8), control2: CGPoint(x: -2, y: -8))
        path.addCurve(to: CGPoint(x: -10, y: -9), control1: CGPoint(x: -7, y: -9), control2: CGPoint(x: -8, y: -10))
        path.addCurve(to: CGPoint(x: -15, y: -7), control1: CGPoint(x: -12, y: -9), control2: CGPoint(x: -14, y: -8))
        path.addCurve(to: CGPoint(x: -16, y: -4), control1: CGPoint(x: -17, y: -6), control2: CGPoint(x: -17, y: -5))
        path.addCurve(to: CGPoint(x: -18, y: 2), control1: CGPoint(x: -17, y: -3), control2: CGPoint(x: -19, y: 0))
        path.closeSubpath()
        appendEarCutout(to: path, baseY: 9.0)
        return makeSilhouetteShape(path: path)
    }

    /// Low resting pose with a single thick ear lobe over the back.
    private func createSingleRestingShape() -> SKShapeNode {
        let path = CGMutablePath()
        // Same contour as sleeping with the head raised 2–3pt and the belly
        // slightly less tucked; still one continuous silhouette.
        path.move(to: CGPoint(x: -18, y: 3))
        path.addCurve(to: CGPoint(x: -22, y: 5), control1: CGPoint(x: -20, y: 3), control2: CGPoint(x: -23, y: 3))
        path.addCurve(to: CGPoint(x: -21, y: 9), control1: CGPoint(x: -23, y: 7), control2: CGPoint(x: -23, y: 9))
        path.addCurve(to: CGPoint(x: -18, y: 9), control1: CGPoint(x: -20, y: 10), control2: CGPoint(x: -19, y: 10))
        path.addCurve(to: CGPoint(x: -14, y: 13), control1: CGPoint(x: -17, y: 10), control2: CGPoint(x: -16, y: 12))
        path.addCurve(to: CGPoint(x: -8, y: 16), control1: CGPoint(x: -12, y: 15), control2: CGPoint(x: -10, y: 16))
        path.addCurve(to: CGPoint(x: 0, y: 15), control1: CGPoint(x: -4, y: 16), control2: CGPoint(x: -2, y: 16))
        path.addCurve(to: CGPoint(x: 4, y: 12), control1: CGPoint(x: 2, y: 14), control2: CGPoint(x: 3, y: 12))
        path.addCurve(to: CGPoint(x: 8, y: 18), control1: CGPoint(x: 6, y: 13), control2: CGPoint(x: 6, y: 17))
        path.addCurve(to: CGPoint(x: 14, y: 19), control1: CGPoint(x: 10, y: 19), control2: CGPoint(x: 12, y: 20))
        path.addCurve(to: CGPoint(x: 19, y: 15), control1: CGPoint(x: 17, y: 18), control2: CGPoint(x: 19, y: 17))
        path.addCurve(to: CGPoint(x: 22, y: 10), control1: CGPoint(x: 21, y: 13), control2: CGPoint(x: 23, y: 11))
        path.addCurve(to: CGPoint(x: 22, y: 6), control1: CGPoint(x: 23, y: 8), control2: CGPoint(x: 23, y: 6))
        path.addCurve(to: CGPoint(x: 19, y: 3), control1: CGPoint(x: 21, y: 5), control2: CGPoint(x: 20, y: 4))
        path.addCurve(to: CGPoint(x: 16, y: 0), control1: CGPoint(x: 19, y: 2), control2: CGPoint(x: 18, y: 0))
        path.addCurve(to: CGPoint(x: 12, y: -2), control1: CGPoint(x: 15, y: 0), control2: CGPoint(x: 14, y: -2))
        path.addCurve(to: CGPoint(x: 8, y: 0), control1: CGPoint(x: 10, y: -2), control2: CGPoint(x: 9, y: 0))
        path.addCurve(to: CGPoint(x: 7, y: -5), control1: CGPoint(x: 8, y: -2), control2: CGPoint(x: 7, y: -4))
        path.addCurve(to: CGPoint(x: 10, y: -9), control1: CGPoint(x: 7, y: -7), control2: CGPoint(x: 9, y: -10))
        path.addCurve(to: CGPoint(x: 7, y: -11), control1: CGPoint(x: 11, y: -11), control2: CGPoint(x: 9, y: -12))
        path.addCurve(to: CGPoint(x: 3, y: -8), control1: CGPoint(x: 5, y: -11), control2: CGPoint(x: 3, y: -10))
        path.addCurve(to: CGPoint(x: -3, y: -6), control1: CGPoint(x: 0, y: -6), control2: CGPoint(x: -1, y: -6))
        path.addCurve(to: CGPoint(x: -7, y: -10), control1: CGPoint(x: -5, y: -7), control2: CGPoint(x: -6, y: -10))
        path.addCurve(to: CGPoint(x: -13, y: -11), control1: CGPoint(x: -9, y: -11), control2: CGPoint(x: -11, y: -12))
        path.addCurve(to: CGPoint(x: -17, y: -8), control1: CGPoint(x: -15, y: -11), control2: CGPoint(x: -17, y: -10))
        path.addCurve(to: CGPoint(x: -16, y: -4), control1: CGPoint(x: -18, y: -6), control2: CGPoint(x: -18, y: -5))
        path.addCurve(to: CGPoint(x: -18, y: 3), control1: CGPoint(x: -17, y: -1), control2: CGPoint(x: -19, y: 1))
        path.closeSubpath()
        appendEarCutout(to: path)
        return makeSilhouetteShape(path: path)
    }

    private func createSingleIdleShape() -> SKShapeNode {
        createSingleSideProfileShape(grooming: false)
    }

    private func createSingleSideProfileShape(grooming: Bool) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -18, y: 3))
        path.addCurve(to: CGPoint(x: -22, y: 5), control1: CGPoint(x: -20, y: 3), control2: CGPoint(x: -23, y: 3))
        path.addCurve(to: CGPoint(x: -21, y: 9), control1: CGPoint(x: -23, y: 7), control2: CGPoint(x: -23, y: 9))
        path.addCurve(to: CGPoint(x: -18, y: 9), control1: CGPoint(x: -20, y: 10), control2: CGPoint(x: -19, y: 10))
        path.addCurve(to: CGPoint(x: -14, y: 13), control1: CGPoint(x: -17, y: 10), control2: CGPoint(x: -16, y: 12))
        path.addCurve(to: CGPoint(x: -8, y: 16), control1: CGPoint(x: -12, y: 15), control2: CGPoint(x: -10, y: 16))
        path.addCurve(to: CGPoint(x: 0, y: 15), control1: CGPoint(x: -4, y: 16), control2: CGPoint(x: -2, y: 16))
        path.addCurve(to: CGPoint(x: 4, y: 12), control1: CGPoint(x: 2, y: 14), control2: CGPoint(x: 3, y: 12))
        path.addCurve(to: CGPoint(x: 8, y: 17), control1: CGPoint(x: 6, y: 13), control2: CGPoint(x: 6, y: 16))
        path.addCurve(to: CGPoint(x: 14, y: 18), control1: CGPoint(x: 10, y: 18), control2: CGPoint(x: 12, y: 19))
        path.addCurve(to: CGPoint(x: 19, y: 14), control1: CGPoint(x: 17, y: 17), control2: CGPoint(x: 19, y: 16))
        path.addCurve(to: CGPoint(x: 22, y: 9), control1: CGPoint(x: 21, y: 12), control2: CGPoint(x: 23, y: 10))
        path.addCurve(to: CGPoint(x: 22, y: 5), control1: CGPoint(x: 23, y: 7), control2: CGPoint(x: 23, y: 5))
        path.addCurve(to: CGPoint(x: 19, y: 2), control1: CGPoint(x: 21, y: 4), control2: CGPoint(x: 20, y: 3))
        path.addCurve(to: CGPoint(x: 16, y: 0), control1: CGPoint(x: 19, y: 2), control2: CGPoint(x: 18, y: 0))
        path.addCurve(to: CGPoint(x: 12, y: -2), control1: CGPoint(x: 15, y: 0), control2: CGPoint(x: 14, y: -2))
        path.addCurve(to: CGPoint(x: 8, y: 0), control1: CGPoint(x: 10, y: -2), control2: CGPoint(x: 9, y: 0))
        if grooming {
            // A small paw bump touches the cheek without turning the body
            // into a C-shaped hook.
            path.addCurve(to: CGPoint(x: 10, y: 1), control1: CGPoint(x: 11, y: -1), control2: CGPoint(x: 10, y: 0))
            path.addCurve(to: CGPoint(x: 13, y: 4), control1: CGPoint(x: 11, y: 2), control2: CGPoint(x: 13, y: 3))
            path.addCurve(to: CGPoint(x: 10, y: 6), control1: CGPoint(x: 13, y: 6), control2: CGPoint(x: 12, y: 7))
            path.addCurve(to: CGPoint(x: 8, y: 2), control1: CGPoint(x: 9, y: 5), control2: CGPoint(x: 8, y: 4))
        } else {
            path.addCurve(to: CGPoint(x: 8, y: 0), control1: CGPoint(x: 10, y: -2), control2: CGPoint(x: 9, y: 0))
        }
        path.addCurve(to: CGPoint(x: 7, y: -5), control1: CGPoint(x: 8, y: -2), control2: CGPoint(x: 7, y: -4))
        path.addCurve(to: CGPoint(x: 10, y: -9), control1: CGPoint(x: 7, y: -7), control2: CGPoint(x: 9, y: -10))
        path.addCurve(to: CGPoint(x: 7, y: -11), control1: CGPoint(x: 11, y: -11), control2: CGPoint(x: 9, y: -12))
        path.addCurve(to: CGPoint(x: 3, y: -8), control1: CGPoint(x: 5, y: -11), control2: CGPoint(x: 3, y: -10))
        path.addCurve(to: CGPoint(x: -3, y: -6), control1: CGPoint(x: 0, y: -6), control2: CGPoint(x: -1, y: -6))
        path.addCurve(to: CGPoint(x: -7, y: -10), control1: CGPoint(x: -5, y: -7), control2: CGPoint(x: -6, y: -10))
        path.addCurve(to: CGPoint(x: -13, y: -11), control1: CGPoint(x: -9, y: -11), control2: CGPoint(x: -11, y: -12))
        path.addCurve(to: CGPoint(x: -17, y: -8), control1: CGPoint(x: -15, y: -11), control2: CGPoint(x: -17, y: -10))
        path.addCurve(to: CGPoint(x: -16, y: -4), control1: CGPoint(x: -18, y: -6), control2: CGPoint(x: -18, y: -5))
        path.addCurve(to: CGPoint(x: -18, y: 3), control1: CGPoint(x: -17, y: -1), control2: CGPoint(x: -19, y: 1))
        path.closeSubpath()
        appendEarCutout(to: path)
        return makeSilhouetteShape(path: path)
    }

    private func createSingleGroomingShape() -> SKShapeNode {
        createSingleSideProfileShape(grooming: true)
    }

    private func createSingleBinkyShape() -> SKShapeNode {
        let path = CGMutablePath()
        // Airborne version of the same rabbit profile: round head and ear,
        // compact tail, and only shallow tucked-foot bumps.
        path.move(to: CGPoint(x: -20, y: 3))
        path.addCurve(to: CGPoint(x: -24, y: 5), control1: CGPoint(x: -22, y: 3), control2: CGPoint(x: -25, y: 3))
        path.addCurve(to: CGPoint(x: -23, y: 8), control1: CGPoint(x: -25, y: 6), control2: CGPoint(x: -25, y: 8))
        path.addCurve(to: CGPoint(x: -19, y: 8), control1: CGPoint(x: -21, y: 9), control2: CGPoint(x: -20, y: 9))
        path.addCurve(to: CGPoint(x: -14, y: 12), control1: CGPoint(x: -18, y: 9), control2: CGPoint(x: -16, y: 11))
        path.addCurve(to: CGPoint(x: -6, y: 13), control1: CGPoint(x: -11, y: 13), control2: CGPoint(x: -8, y: 14))
        path.addCurve(to: CGPoint(x: 1, y: 12), control1: CGPoint(x: -3, y: 13), control2: CGPoint(x: -1, y: 13))
        path.addCurve(to: CGPoint(x: 6, y: 15), control1: CGPoint(x: 3, y: 12), control2: CGPoint(x: 4, y: 14))
        path.addCurve(to: CGPoint(x: 14, y: 15), control1: CGPoint(x: 9, y: 16), control2: CGPoint(x: 12, y: 16))
        path.addCurve(to: CGPoint(x: 20, y: 11), control1: CGPoint(x: 17, y: 14), control2: CGPoint(x: 19, y: 13))
        path.addCurve(to: CGPoint(x: 23, y: 6), control1: CGPoint(x: 22, y: 9), control2: CGPoint(x: 24, y: 7))
        path.addCurve(to: CGPoint(x: 22, y: 2), control1: CGPoint(x: 24, y: 4), control2: CGPoint(x: 24, y: 2))
        path.addCurve(to: CGPoint(x: 19, y: 0), control1: CGPoint(x: 21, y: 1), control2: CGPoint(x: 20, y: 1))
        path.addCurve(to: CGPoint(x: 16, y: -1), control1: CGPoint(x: 19, y: 0), control2: CGPoint(x: 18, y: -1))
        path.addCurve(to: CGPoint(x: 12, y: -3), control1: CGPoint(x: 15, y: -1), control2: CGPoint(x: 14, y: -3))
        path.addCurve(to: CGPoint(x: 8, y: -1), control1: CGPoint(x: 10, y: -3), control2: CGPoint(x: 9, y: -1))
        path.addCurve(to: CGPoint(x: 8, y: -5), control1: CGPoint(x: 8, y: -2), control2: CGPoint(x: 8, y: -4))
        path.addCurve(to: CGPoint(x: 5, y: -7), control1: CGPoint(x: 8, y: -7), control2: CGPoint(x: 6, y: -8))
        path.addCurve(to: CGPoint(x: 2, y: -5), control1: CGPoint(x: 4, y: -7), control2: CGPoint(x: 3, y: -6))
        path.addCurve(to: CGPoint(x: -3, y: -3), control1: CGPoint(x: 0, y: -4), control2: CGPoint(x: -1, y: -3))
        path.addCurve(to: CGPoint(x: -8, y: -7), control1: CGPoint(x: -5, y: -4), control2: CGPoint(x: -6, y: -7))
        path.addCurve(to: CGPoint(x: -13, y: -8), control1: CGPoint(x: -10, y: -8), control2: CGPoint(x: -12, y: -9))
        path.addCurve(to: CGPoint(x: -16, y: -5), control1: CGPoint(x: -15, y: -8), control2: CGPoint(x: -17, y: -7))
        path.addCurve(to: CGPoint(x: -15, y: -2), control1: CGPoint(x: -17, y: -4), control2: CGPoint(x: -17, y: -3))
        path.addCurve(to: CGPoint(x: -20, y: 3), control1: CGPoint(x: -17, y: -1), control2: CGPoint(x: -19, y: 1))
        path.closeSubpath()
        appendEarCutout(to: path, baseY: 9.0)
        return makeSilhouetteShape(path: path)
    }

    // MARK: - Show Poses

    private func showRunningPose(frame: RunningFrame = .brace) {
        let textureNode: SKSpriteNode
        if let existingTexture = currentVisual as? SKSpriteNode {
            textureNode = existingTexture
        } else {
            clearCurrentShape()
            textureNode = createRunningTextureNode(frame: frame)
            addChild(textureNode)
        }

        textureNode.texture = runningTexture(for: frame)
        textureNode.size = CGSize(width: 64, height: 31)
        switch frame {
        case .brace:
            textureNode.position = .zero
            textureNode.xScale = 1.0
            textureNode.yScale = 1.0
        case .crouch:
            // Preserve visual mass while lowering the hips. Shrinking both
            // axes was read as the whole rabbit momentarily getting smaller.
            textureNode.position = CGPoint(x: 0, y: -0.45)
            textureNode.xScale = 1.02
            textureNode.yScale = 0.94
        case .propulsion:
            textureNode.position = CGPoint(x: 0, y: 0.93)
            textureNode.xScale = 1.06
            textureNode.yScale = 1.06
        case .flight:
            textureNode.position = CGPoint(x: 0, y: 1.86)
            textureNode.xScale = 1.12
            textureNode.yScale = 1.12
        case .forepawContact:
            textureNode.position = CGPoint(x: 0, y: 1.40)
            textureNode.xScale = 1.09
            textureNode.yScale = 1.09
        case .hindfootLoad:
            textureNode.position = CGPoint(x: 0, y: 0.47)
            textureNode.xScale = 1.03
            textureNode.yScale = 1.03
        }
        applyAppearance(to: textureNode, foreground: rabbitColor)
        currentVisual = textureNode
    }

    private func showIdlePose() {
        clearCurrentShape()
        currentVisual = createStillTextureNode()
        addChild(currentVisual!)
    }

    private func showSleepingPose() {
        clearCurrentShape()
        currentVisual = createStillTextureNode()
        addChild(currentVisual!)
    }

    private func showBinkyPose() {
        clearCurrentShape()
        currentVisual = createSingleBinkyShape()
        addChild(currentVisual!)
    }

    private func showRestingPose() {
        clearCurrentShape()
        currentVisual = createStillTextureNode()
        addChild(currentVisual!)
    }

    private func showGroomingPose() {
        clearCurrentShape()
        currentVisual = createStillTextureNode()
        addChild(currentVisual!)
    }

    // MARK: - Animation Control

    func stopAllAnimations() {
        removeAllActions()
        currentVisual?.removeAllActions()
    }

    // MARK: - Resting Animation (lying down, occasional ear twitch)

    func startRestingAnimation() {
        stopAllAnimations()
        showRestingPose()

        // Very occasional, subtle ear movement
        // Rabbits at rest barely move
    }

    // MARK: - Grooming Animation (paw moving to face)

    func startGroomingAnimation() {
        stopAllAnimations()
        showGroomingPose()

        // Subtle grooming motion - body rocks slightly
        let groomForward = SKAction.rotate(byAngle: 0.028, duration: 0.55)
        let groomBack = SKAction.rotate(byAngle: -0.028, duration: 0.55)
        let groomSequence = SKAction.sequence([
            groomForward,
            groomBack,
            SKAction.wait(forDuration: Double.random(in: 2.0...4.0))
        ])
        currentVisual?.run(SKAction.repeatForever(groomSequence))
    }

    // MARK: - Running Animation

    func startRunningAnimation(includeResidualBob: Bool = true) {
        stopAllAnimations()
        showRunningPose(frame: .brace)

        // Contact order matters more than even frame spacing: brace, hindquarter
        // loading, toe-off, flight, forepaw contact, then hindfoot loading.
        // Keeping propulsion short and both landings visible avoids the old
        // impression of one static silhouette sliding along a programmed arc.
        let frameDurations: [RunningFrame: TimeInterval] = [
            .brace: Self.hopBraceDuration,
            .crouch: Self.hopCrouchDuration,
            .propulsion: Self.hopPropulsionDuration,
            .flight: Self.hopFlightDuration,
            .forepawContact: Self.hopForepawContactDuration,
            .hindfootLoad: Self.hopHindfootLoadDuration
        ]
        let frameActions = RunningFrame.allCases.flatMap { frame in
            [
                SKAction.run { [weak self] in
                    self?.showRunningPose(frame: frame)
                },
                SKAction.wait(forDuration: frameDurations[frame] ?? 0.15)
            ]
        } + [SKAction.wait(forDuration: Self.hopSettleDuration)]
        run(SKAction.repeatForever(SKAction.sequence(frameActions)), withKey: "runningCycle")

        guard includeResidualBob else { return }

        // Preview-only residual motion. Production exploration supplies the
        // full ballistic arc and disables this bob.
        let gentleBob = SKAction.moveBy(x: 0, y: 0.45, duration: 0.31)
        gentleBob.timingMode = .easeInEaseOut
        let gentleBobDown = SKAction.moveBy(x: 0, y: -0.45, duration: 0.31)
        gentleBobDown.timingMode = .easeInEaseOut
        let bobSequence = SKAction.sequence([gentleBob, gentleBobDown])
        run(SKAction.repeatForever(bobSequence), withKey: "runningBob")
    }

    // MARK: - Idle Animation

    func startIdleAnimation() {
        stopAllAnimations()
        showIdlePose()

        // Subtle body movement (alert)
        let alert = SKAction.sequence([
            SKAction.scaleY(to: 1.01, duration: 0.3),
            SKAction.scaleY(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: Double.random(in: 4.0...10.0))
        ])
        currentVisual?.run(SKAction.repeatForever(alert))
    }

    // MARK: - Sleeping Animation

    func startSleepingAnimation() {
        stopAllAnimations()
        showSleepingPose()

        // Breathing
        let breatheIn = SKAction.scaleY(to: 1.015, duration: 2.6)
        breatheIn.timingMode = .easeInEaseOut
        let breatheOut = SKAction.scaleY(to: 1.0, duration: 2.6)
        breatheOut.timingMode = .easeInEaseOut
        let breatheSequence = SKAction.sequence([breatheIn, breatheOut])
        currentVisual?.run(SKAction.repeatForever(breatheSequence))
    }

    // MARK: - Binky Animation

    func performBinky(completion: @escaping () -> Void) {
        stopAllAnimations()
        showBinkyPose()

        let jumpHeight: CGFloat = 2.5
        let jumpDuration: TimeInterval = 0.42

        // Jump arc
        let jumpUp = SKAction.moveBy(x: 0, y: jumpHeight, duration: jumpDuration)
        jumpUp.timingMode = .easeOut
        let jumpDown = SKAction.moveBy(x: 0, y: -jumpHeight, duration: jumpDuration)
        jumpDown.timingMode = .easeIn

        // Slight twist
        let twist = SKAction.rotate(byAngle: .pi * 0.04, duration: jumpDuration)
        let untwist = SKAction.rotate(byAngle: -.pi * 0.04, duration: jumpDuration)

        let binkySequence = SKAction.sequence([
            SKAction.group([jumpUp, twist]),
            SKAction.group([jumpDown, untwist]),
            SKAction.wait(forDuration: 0.22),
            SKAction.run { completion() }
        ])

        run(binkySequence)
    }
}
