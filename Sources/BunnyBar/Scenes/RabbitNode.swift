//
//  RabbitNode.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import SpriteKit

class RabbitNode: SKNode {
    private var body: SKShapeNode!
    private var head: SKShapeNode!
    private var leftEar: SKShapeNode!
    private var rightEar: SKShapeNode!
    private var tail: SKShapeNode!
    private var legs: [SKShapeNode] = []

    override init() {
        super.init()
        setupRabbit()
        startHoppingAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupRabbit() {
        let rabbitColor = NSColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1.0)
        let pinkColor = NSColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)

        // Body (ellipse)
        body = SKShapeNode(ellipseOf: CGSize(width: 30, height: 20))
        body.fillColor = rabbitColor
        body.strokeColor = .gray
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: 0)
        addChild(body)

        // Head (circle)
        head = SKShapeNode(circleOfRadius: 10)
        head.fillColor = rabbitColor
        head.strokeColor = .gray
        head.lineWidth = 1
        head.position = CGPoint(x: 18, y: 5)
        addChild(head)

        // Left ear
        leftEar = createEar()
        leftEar.position = CGPoint(x: 14, y: 18)
        leftEar.zRotation = -0.2
        addChild(leftEar)

        // Right ear
        rightEar = createEar()
        rightEar.position = CGPoint(x: 22, y: 18)
        rightEar.zRotation = 0.2
        addChild(rightEar)

        // Tail (small circle)
        tail = SKShapeNode(circleOfRadius: 4)
        tail.fillColor = rabbitColor
        tail.strokeColor = .gray
        tail.lineWidth = 1
        tail.position = CGPoint(x: -18, y: 2)
        addChild(tail)

        // Legs
        let legPositions: [CGPoint] = [
            CGPoint(x: -8, y: -12),
            CGPoint(x: 8, y: -12),
            CGPoint(x: -5, y: -10),
            CGPoint(x: 10, y: -10)
        ]

        for position in legPositions {
            let leg = SKShapeNode(ellipseOf: CGSize(width: 6, height: 10))
            leg.fillColor = rabbitColor
            leg.strokeColor = .gray
            leg.lineWidth = 1
            leg.position = position
            legs.append(leg)
            addChild(leg)
        }

        // Eye
        let eye = SKShapeNode(circleOfRadius: 2)
        eye.fillColor = .black
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 22, y: 7)
        addChild(eye)

        // Nose
        let nose = SKShapeNode(ellipseOf: CGSize(width: 3, height: 2))
        nose.fillColor = pinkColor
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 27, y: 4)
        addChild(nose)
    }

    private func createEar() -> SKShapeNode {
        let earPath = CGMutablePath()
        earPath.addEllipse(in: CGRect(x: -3, y: 0, width: 6, height: 18))

        let ear = SKShapeNode(path: earPath)
        ear.fillColor = NSColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1.0)
        ear.strokeColor = .gray
        ear.lineWidth = 1

        // Inner ear (pink)
        let innerEar = SKShapeNode(ellipseOf: CGSize(width: 3, height: 12))
        innerEar.fillColor = NSColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
        innerEar.strokeColor = .clear
        innerEar.position = CGPoint(x: 0, y: 9)
        ear.addChild(innerEar)

        return ear
    }

    private func startHoppingAnimation() {
        // Hopping animation
        let hopUp = SKAction.moveBy(x: 0, y: 8, duration: 0.15)
        hopUp.timingMode = .easeOut
        let hopDown = SKAction.moveBy(x: 0, y: -8, duration: 0.15)
        hopDown.timingMode = .easeIn
        let hopSequence = SKAction.sequence([hopUp, hopDown])
        let hopForever = SKAction.repeatForever(hopSequence)
        run(hopForever)

        // Ear wiggle animation
        let earWiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.1, duration: 0.1),
            SKAction.rotate(byAngle: -0.2, duration: 0.2),
            SKAction.rotate(byAngle: 0.1, duration: 0.1)
        ])
        let earWiggleForever = SKAction.repeatForever(
            SKAction.sequence([earWiggle, SKAction.wait(forDuration: 0.5)])
        )
        leftEar.run(earWiggleForever)
        rightEar.run(earWiggleForever)

        // Leg animation
        animateLegs()
    }

    private func animateLegs() {
        guard legs.count >= 4 else { return }

        let frontLegs = [legs[1], legs[3]]
        let backLegs = [legs[0], legs[2]]

        let legForward = SKAction.moveBy(x: 3, y: 0, duration: 0.15)
        let legBackward = SKAction.moveBy(x: -3, y: 0, duration: 0.15)
        let legCycle = SKAction.sequence([legForward, legBackward])
        let legCycleForever = SKAction.repeatForever(legCycle)

        for leg in frontLegs {
            leg.run(legCycleForever)
        }

        let legCycleOffset = SKAction.sequence([legBackward, legForward])
        let legCycleOffsetForever = SKAction.repeatForever(legCycleOffset)

        for leg in backLegs {
            leg.run(legCycleOffsetForever)
        }
    }
}
