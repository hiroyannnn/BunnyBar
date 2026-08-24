//
//  RabbitScene.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import SpriteKit

class RabbitScene: SKScene {
    private var rabbit: RabbitNode!

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        rabbit = RabbitNode()
        rabbit.position = CGPoint(x: -50, y: size.height / 2)
        addChild(rabbit)

        startRunning()
    }

    private func startRunning() {
        let screenWidth = size.width
        let runDuration: TimeInterval = 10.0

        let runAction = SKAction.moveTo(x: screenWidth + 50, duration: runDuration)
        let resetAction = SKAction.moveTo(x: -50, duration: 0)
        let sequence = SKAction.sequence([runAction, resetAction])
        let repeatForever = SKAction.repeatForever(sequence)

        rabbit.run(repeatForever)
    }
}
