//
//  RabbitNode.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import SpriteKit

class RabbitNode: SKNode {
    private enum RunningFrame: CaseIterable, Hashable {
        case gather
        case launch
        case stretch
        case land
    }

    private var currentVisual: SKNode?
    private var runningShapes: [RunningFrame: SKShapeNode] = [:]

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
        for shape in runningShapes.values {
            applyAppearance(to: shape, foreground: foreground, outline: outline)
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
        runningShapes.values.forEach {
            $0.isHidden = true
            $0.removeFromParent()
        }
    }

    // MARK: - Four-frame lop-eared running cycle

    private func createRunningShape(frame: RunningFrame) -> SKShapeNode {
        let path = CGMutablePath()
        let lift: CGFloat
        switch frame {
        case .gather: lift = 0
        case .launch: lift = 0.75
        case .stretch: lift = 1.75
        case .land: lift = 0.25
        }

        appendSingleRunningContour(to: path, frame: frame, lift: lift)

        let shape = SKShapeNode(path: path)
        shape.fillColor = rabbitColor
        shape.strokeColor = rabbitColor
        shape.lineWidth = 1.0
        applyAppearance(to: shape, foreground: rabbitColor, outline: outlineColor)
        return shape
    }

    /// One continuous outside edge for the running rabbit. Ears, tail, and
    /// feet are broad perimeter lobes rather than overlapping subpaths; this
    /// keeps the 22px silhouette solid under Core Graphics' non-zero fill.
    private func appendSingleRunningContour(to path: CGMutablePath, frame: RunningFrame, lift: CGFloat) {
        path.move(to: CGPoint(x: -21, y: 4 + lift))
        // A single compact 2–3pt tail bump; no scallops or second path.
        path.addCurve(to: CGPoint(x: -24, y: 5 + lift), control1: CGPoint(x: -22, y: 3 + lift), control2: CGPoint(x: -25, y: 3 + lift))
        path.addCurve(to: CGPoint(x: -23, y: 8 + lift), control1: CGPoint(x: -25, y: 6 + lift), control2: CGPoint(x: -25, y: 8 + lift))
        path.addCurve(to: CGPoint(x: -20, y: 8 + lift), control1: CGPoint(x: -22, y: 9 + lift), control2: CGPoint(x: -21, y: 9 + lift))
        // Compact round rump and a shallow neck dip make the head readable.
        path.addCurve(to: CGPoint(x: -14, y: 14 + lift), control1: CGPoint(x: -20, y: 10 + lift), control2: CGPoint(x: -18, y: 13 + lift))
        path.addCurve(to: CGPoint(x: -5, y: 15 + lift), control1: CGPoint(x: -11, y: 15 + lift), control2: CGPoint(x: -8, y: 15 + lift))
        path.addCurve(to: CGPoint(x: 1, y: 13 + lift), control1: CGPoint(x: -4, y: 15 + lift), control2: CGPoint(x: -2, y: 14 + lift))
        // Large rounded head and tiny nose. The lop ear is shown only by the
        // internal transparent seam below; the outer contour stays head-like.
        path.addCurve(to: CGPoint(x: 8, y: 18 + lift), control1: CGPoint(x: 4, y: 12 + lift), control2: CGPoint(x: 5, y: 17 + lift))
        path.addCurve(to: CGPoint(x: 16, y: 18 + lift), control1: CGPoint(x: 12, y: 19 + lift), control2: CGPoint(x: 14, y: 19 + lift))
        path.addCurve(to: CGPoint(x: 23, y: 12 + lift), control1: CGPoint(x: 19, y: 17 + lift), control2: CGPoint(x: 21, y: 14 + lift))
        path.addCurve(to: CGPoint(x: 24, y: 7 + lift), control1: CGPoint(x: 25, y: 10 + lift), control2: CGPoint(x: 25, y: 8 + lift))
        path.addCurve(to: CGPoint(x: 23, y: 3 + lift), control1: CGPoint(x: 25, y: 5 + lift), control2: CGPoint(x: 25, y: 3 + lift))
        // Nose to jaw to chest is one shallow rounded transition; no ear
        // lobe hangs toward the feet.
        path.addCurve(to: CGPoint(x: 21, y: 0 + lift), control1: CGPoint(x: 24, y: 2 + lift), control2: CGPoint(x: 23, y: 0 + lift))
        path.addCurve(to: CGPoint(x: 18, y: -3 + lift), control1: CGPoint(x: 21, y: -1 + lift), control2: CGPoint(x: 20, y: -3 + lift))
        path.addCurve(to: CGPoint(x: 13, y: -4 + lift), control1: CGPoint(x: 16, y: -3 + lift), control2: CGPoint(x: 15, y: -4 + lift))
        path.addCurve(to: CGPoint(x: 8, y: -3 + lift), control1: CGPoint(x: 11, y: -4 + lift), control2: CGPoint(x: 9, y: -3 + lift))

        // Short front-foot bump. Only the position of this outer bump changes
        // between gait phases; the torso/head remain the same rabbit.
        switch frame {
        case .gather, .land:
            path.addCurve(to: CGPoint(x: 6, y: -9 + lift), control1: CGPoint(x: 7, y: -6 + lift), control2: CGPoint(x: 6, y: -8 + lift))
            path.addCurve(to: CGPoint(x: 10, y: -11 + lift), control1: CGPoint(x: 7, y: -10 + lift), control2: CGPoint(x: 9, y: -12 + lift))
            path.addCurve(to: CGPoint(x: 6, y: -12 + lift), control1: CGPoint(x: 11, y: -12 + lift), control2: CGPoint(x: 9, y: -13 + lift))
            path.addCurve(to: CGPoint(x: 1, y: -9 + lift), control1: CGPoint(x: 5, y: -12 + lift), control2: CGPoint(x: 2, y: -11 + lift))
        case .launch:
            path.addCurve(to: CGPoint(x: 6, y: -8 + lift), control1: CGPoint(x: 7, y: -5 + lift), control2: CGPoint(x: 7, y: -7 + lift))
            path.addCurve(to: CGPoint(x: 10, y: -10 + lift), control1: CGPoint(x: 7, y: -9 + lift), control2: CGPoint(x: 9, y: -11 + lift))
            path.addCurve(to: CGPoint(x: 6, y: -11 + lift), control1: CGPoint(x: 11, y: -11 + lift), control2: CGPoint(x: 9, y: -12 + lift))
            path.addCurve(to: CGPoint(x: 1, y: -8 + lift), control1: CGPoint(x: 5, y: -11 + lift), control2: CGPoint(x: 2, y: -10 + lift))
        case .stretch:
            path.addCurve(to: CGPoint(x: 6, y: -7 + lift), control1: CGPoint(x: 7, y: -4 + lift), control2: CGPoint(x: 7, y: -6 + lift))
            path.addCurve(to: CGPoint(x: 13, y: -9 + lift), control1: CGPoint(x: 8, y: -8 + lift), control2: CGPoint(x: 11, y: -10 + lift))
            path.addCurve(to: CGPoint(x: 9, y: -11 + lift), control1: CGPoint(x: 14, y: -10 + lift), control2: CGPoint(x: 12, y: -12 + lift))
            path.addCurve(to: CGPoint(x: 1, y: -7 + lift), control1: CGPoint(x: 8, y: -10 + lift), control2: CGPoint(x: 3, y: -9 + lift))
        }
        path.addCurve(to: CGPoint(x: 0, y: -5 + lift), control1: CGPoint(x: 2, y: -7 + lift), control2: CGPoint(x: 1, y: -6 + lift))

        // The hind-foot bump remains thick and compact even in stretch.
        switch frame {
        case .gather, .land:
            path.addCurve(to: CGPoint(x: -3, y: -10 + lift), control1: CGPoint(x: -1, y: -7 + lift), control2: CGPoint(x: -2, y: -9 + lift))
            path.addCurve(to: CGPoint(x: -9, y: -11 + lift), control1: CGPoint(x: -5, y: -10 + lift), control2: CGPoint(x: -7, y: -12 + lift))
            path.addCurve(to: CGPoint(x: -15, y: -11 + lift), control1: CGPoint(x: -11, y: -12 + lift), control2: CGPoint(x: -14, y: -12 + lift))
            path.addCurve(to: CGPoint(x: -19, y: -9 + lift), control1: CGPoint(x: -17, y: -11 + lift), control2: CGPoint(x: -19, y: -11 + lift))
            path.addCurve(to: CGPoint(x: -17, y: -6 + lift), control1: CGPoint(x: -19, y: -8 + lift), control2: CGPoint(x: -18, y: -7 + lift))
        case .launch:
            path.addCurve(to: CGPoint(x: -5, y: -10 + lift), control1: CGPoint(x: -1, y: -7 + lift), control2: CGPoint(x: -3, y: -9 + lift))
            path.addCurve(to: CGPoint(x: -13, y: -12 + lift), control1: CGPoint(x: -7, y: -11 + lift), control2: CGPoint(x: -10, y: -12 + lift))
            path.addCurve(to: CGPoint(x: -20, y: -11 + lift), control1: CGPoint(x: -16, y: -13 + lift), control2: CGPoint(x: -19, y: -13 + lift))
            path.addCurve(to: CGPoint(x: -22, y: -8 + lift), control1: CGPoint(x: -22, y: -10 + lift), control2: CGPoint(x: -22, y: -9 + lift))
            path.addCurve(to: CGPoint(x: -15, y: -6 + lift), control1: CGPoint(x: -20, y: -8 + lift), control2: CGPoint(x: -17, y: -7 + lift))
        case .stretch:
            path.addCurve(to: CGPoint(x: -5, y: -9 + lift), control1: CGPoint(x: -1, y: -7 + lift), control2: CGPoint(x: -3, y: -8 + lift))
            path.addCurve(to: CGPoint(x: -14, y: -10 + lift), control1: CGPoint(x: -8, y: -9 + lift), control2: CGPoint(x: -11, y: -10 + lift))
            path.addCurve(to: CGPoint(x: -21, y: -9 + lift), control1: CGPoint(x: -17, y: -11 + lift), control2: CGPoint(x: -20, y: -11 + lift))
            path.addCurve(to: CGPoint(x: -23, y: -6 + lift), control1: CGPoint(x: -23, y: -8 + lift), control2: CGPoint(x: -23, y: -7 + lift))
            path.addCurve(to: CGPoint(x: -15, y: -5 + lift), control1: CGPoint(x: -21, y: -6 + lift), control2: CGPoint(x: -18, y: -5 + lift))
        }
        path.addCurve(to: CGPoint(x: -24, y: -3 + lift), control1: CGPoint(x: -20, y: -4 + lift), control2: CGPoint(x: -22, y: -4 + lift))
        path.addCurve(to: CGPoint(x: -24, y: 4 + lift), control1: CGPoint(x: -27, y: 0 + lift), control2: CGPoint(x: -27, y: 2 + lift))
        path.closeSubpath()
        appendEarCutout(to: path, baseY: 10.0, yOffset: lift)
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

    private func showRunningPose(frame: RunningFrame = .gather) {
        if runningShapes.isEmpty {
            for runningFrame in RunningFrame.allCases {
                runningShapes[runningFrame] = createRunningShape(frame: runningFrame)
            }
        }

        let framesAreAttached = runningShapes.values.contains { $0.parent === self }
        if !framesAreAttached {
            clearCurrentShape()
            for shape in runningShapes.values {
                shape.isHidden = true
                addChild(shape)
            }
        }

        for (runningFrame, shape) in runningShapes {
            shape.isHidden = runningFrame != frame
        }
        currentVisual = runningShapes[frame]
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

    func startRunningAnimation() {
        stopAllAnimations()
        showRunningPose(frame: .gather)

        // A rabbit's bound is asymmetric: gather and landing have a little
        // more support time, while launch is a short push-off and stretch is
        // a clear airborne phase. The settle pause prevents a mechanical
        // four-frame loop at the menu-bar scale.
        let frameDurations: [RunningFrame: TimeInterval] = [
            .gather: 0.17,
            .launch: 0.11,
            .stretch: 0.16,
            .land: 0.15
        ]
        let frameActions = RunningFrame.allCases.flatMap { frame in
            [
                SKAction.run { [weak self] in
                    self?.showRunningPose(frame: frame)
                },
                SKAction.wait(forDuration: frameDurations[frame] ?? 0.15)
            ]
        } + [SKAction.wait(forDuration: 0.10)]
        run(SKAction.repeatForever(SKAction.sequence(frameActions)), withKey: "runningCycle")

        // The pose already contains the main lift. This small residual bob
        // keeps the silhouette grounded instead of making it float.
        let gentleBob = SKAction.moveBy(x: 0, y: 0.55, duration: 0.34)
        gentleBob.timingMode = .easeInEaseOut
        let gentleBobDown = SKAction.moveBy(x: 0, y: -0.55, duration: 0.34)
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

        let jumpHeight: CGFloat = 10
        let jumpDuration: TimeInterval = 0.42

        // Jump arc
        let jumpUp = SKAction.moveBy(x: 0, y: jumpHeight, duration: jumpDuration)
        jumpUp.timingMode = .easeOut
        let jumpDown = SKAction.moveBy(x: 0, y: -jumpHeight, duration: jumpDuration)
        jumpDown.timingMode = .easeIn

        // Slight twist
        let twist = SKAction.rotate(byAngle: .pi * 0.08, duration: jumpDuration)
        let untwist = SKAction.rotate(byAngle: -.pi * 0.08, duration: jumpDuration)

        let binkySequence = SKAction.sequence([
            SKAction.group([jumpUp, twist]),
            SKAction.group([jumpDown, untwist]),
            SKAction.wait(forDuration: 0.22),
            SKAction.run { completion() }
        ])

        run(binkySequence)
    }
}
