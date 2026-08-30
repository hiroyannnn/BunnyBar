//
//  RabbitScene.swift
//  BunnyBar
//

import Foundation
import SpriteKit

enum RabbitState {
    case sleeping
    case resting
    case grooming
    case idle
    case running
    case binky
}

final class RabbitScene: SKScene {
    private var rabbit: RabbitNode!
    private var cameraNode: SKCameraNode!
    var worldWidth: CGFloat = 0
    var onRabbitPositionChange: ((CGFloat) -> Void)?
    private(set) var currentState: RabbitState = .sleeping
    private(set) var performance = RabbitPerformance(cpuPercent: 0)

    private var random: RabbitBehaviorRandom = {
        var system = SystemRandomNumberGenerator()
        return RabbitBehaviorRandom(seed: UInt64.random(in: 1...UInt64.max, using: &system))
    }()
    var behaviorSeedForTesting: UInt64? {
        didSet {
            if rabbit == nil, let seed = behaviorSeedForTesting {
                random = RabbitBehaviorRandom(seed: seed)
            }
        }
    }
    private var direction: CGFloat = 1
    private var hopsRemaining = 0
    private var hasStartedExploration = false
    private var binkyAvailable = true
    private let stateScheduleKey = "rabbit-state-schedule"
    private let binkyCooldownKey = "rabbit-binky-cooldown"
    private let movementKey = "rabbit-hop-movement"
    private let bodyMargin: CGFloat = 19
    private let minimumHop: CGFloat = 24
    private let maximumHop: CGFloat = 58

    static let binkyCooldown: TimeInterval = 900

    static func cameraX(forRabbitX rabbitX: CGFloat, worldWidth: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let halfWidth = max(1, viewportWidth) / 2
        let minCameraX = halfWidth
        let maxCameraX = max(minCameraX, worldWidth - halfWidth)
        return min(maxCameraX, max(minCameraX, rabbitX))
    }

    static func viewportOriginX(screenMinX: CGFloat, screenWidth: CGFloat,
                                rabbitX: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let minX = screenMinX
        let maxX = max(minX, screenMinX + screenWidth - viewportWidth)
        let targetX = screenMinX + rabbitX - viewportWidth / 2
        return min(maxX, max(minX, targetX))
    }

    static func boundedHopDistance(requested: CGFloat, available: CGFloat) -> CGFloat {
        min(max(0, requested), max(0, available))
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        if worldWidth <= 0 { worldWidth = size.width }

        cameraNode = SKCameraNode()
        addChild(cameraNode)
        camera = cameraNode

        rabbit = RabbitNode()
        rabbit.setScale(0.58)
        rabbit.speed = 1.0
        rabbit.position = CGPoint(x: initialPositionX, y: size.height * 0.68)
        addChild(rabbit)

        // Show a short initial look before the first small exploration bout.
        enterStillState(.idle)
        scheduleTransition(after: random.duration(2.4...4.0)) { [weak self] in
            self?.beginExploration()
        }
        syncViewport()
    }

    override func didFinishUpdate() {
        super.didFinishUpdate()
        syncViewport()
    }

    private var initialPositionX: CGFloat {
        min(max(bodyMargin, worldWidth * 0.40), max(bodyMargin, worldWidth - bodyMargin))
    }

    private var minimumX: CGFloat { bodyMargin }
    private var maximumX: CGFloat { max(minimumX, worldWidth - bodyMargin) }

    private func syncViewport() {
        guard let rabbit, let cameraNode else { return }
        cameraNode.position = CGPoint(
            x: Self.cameraX(forRabbitX: rabbit.position.x, worldWidth: worldWidth, viewportWidth: size.width),
            y: size.height / 2
        )
        onRabbitPositionChange?(rabbit.position.x)
    }

    deinit {
        removeAllActions()
    }

    /// CPU load changes tempo only. It never wakes or interrupts a rest.
    func applyPerformance(_ performance: RabbitPerformance) {
        self.performance = performance
    }

    var stateDescription: String {
        switch currentState {
        case .sleeping: return "Sleeping"
        case .resting: return "Resting"
        case .grooming: return "Grooming"
        case .idle: return "Watching"
        case .running: return "Running"
        case .binky: return "Binky"
        }
    }

    func refreshAppearance() { rabbit?.refreshAppearance() }

    func stop() {
        removeAllActions()
        rabbit?.stopAllAnimations()
        rabbit?.removeAllActions()
        onRabbitPositionChange = nil
        isPaused = true
    }

    // MARK: - State scheduling

    private func enterStillState(_ state: RabbitState) {
        removeAction(forKey: stateScheduleKey)
        currentState = state
        // Still poses use the scene clock. This also keeps an in-flight
        // SpriteKit movement from being retimed by an external metric sample.
        rabbit.speed = 1.0
        switch state {
        case .sleeping: rabbit.startSleepingAnimation()
        case .resting: rabbit.startRestingAnimation()
        case .grooming: rabbit.startGroomingAnimation()
        case .idle: rabbit.startIdleAnimation()
        case .running, .binky: break
        }
    }

    private func scheduleTransition(after delay: TimeInterval, _ transition: @escaping () -> Void) {
        removeAction(forKey: stateScheduleKey)
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run(transition)
        ]), withKey: stateScheduleKey)
    }

    private func scheduleNextStillState() {
        let delay: ClosedRange<TimeInterval>
        switch currentState {
        case .sleeping: delay = 45...100
        case .resting: delay = 7...18
        case .grooming: delay = 10...24
        case .idle: delay = 2.5...7.0
        case .running, .binky: return
        }
        scheduleTransition(after: random.duration(delay)) { [weak self] in
            self?.chooseNextStillState()
        }
    }

    private func chooseNextStillState() {
        let roll = random.unit()
        switch currentState {
        case .sleeping:
            if !hasStartedExploration || roll >= 0.82 {
                beginExploration()
            } else {
                enterStillState(roll < 0.58 ? .resting : .idle)
                scheduleNextStillState()
            }
        case .resting:
            if roll < 0.005 {
                performBinky()
            } else if roll < 0.35 {
                enterStillState(.sleeping); scheduleNextStillState()
            } else if roll < 0.62 {
                enterStillState(.grooming); scheduleNextStillState()
            } else if roll < 0.82 {
                enterStillState(.idle); scheduleNextStillState()
            } else {
                beginExploration()
            }
        case .grooming:
            if roll < 0.002 {
                performBinky()
            } else if roll < 0.45 {
                enterStillState(.resting); scheduleNextStillState()
            } else if roll < 0.72 {
                enterStillState(.sleeping); scheduleNextStillState()
            } else {
                beginExploration()
            }
        case .idle:
            if roll < 0.005 {
                performBinky()
            } else if roll < 0.28 {
                enterStillState(.resting); scheduleNextStillState()
            } else if roll < 0.48 {
                enterStillState(.grooming); scheduleNextStillState()
            } else {
                beginExploration()
            }
        case .running, .binky:
            break
        }
    }

    // MARK: - Short exploration bouts

    private func beginExploration() {
        guard rabbit != nil, !isPaused else { return }
        hasStartedExploration = true
        hopsRemaining = random.int(in: 1...3)
        enterStillState(.idle)
        scheduleTransition(after: random.duration(0.45...0.9)) { [weak self] in
            self?.startNextHop()
        }
    }

    private func chooseDirectionAndDistance() -> (direction: CGFloat, distance: CGFloat, turnPause: TimeInterval) {
        let x = rabbit.position.x
        let leftRoom = x - minimumX
        let rightRoom = maximumX - x
        var nextDirection = direction
        var turnPause: TimeInterval = 0.18

        func room(for travelDirection: CGFloat) -> CGFloat {
            travelDirection > 0 ? rightRoom : leftRoom
        }

        if room(for: nextDirection) < minimumHop {
            nextDirection = -nextDirection
            turnPause = random.duration(0.55...0.9)
        } else if random.unit() < 0.22 {
            let reversed = -nextDirection
            if room(for: reversed) >= minimumHop {
                nextDirection = reversed
                turnPause = random.duration(0.35...0.7)
            }
        }

        let available = max(0, room(for: nextDirection))
        let requested = random.cgFloat(in: minimumHop...maximumHop)
        let distance = Self.boundedHopDistance(requested: requested, available: available)
        direction = nextDirection
        return (nextDirection, distance, turnPause)
    }

    private func startNextHop() {
        guard hopsRemaining > 0, rabbit != nil, !isPaused else { return }
        let plan = chooseDirectionAndDistance()
        currentState = .running
        rabbit.xScale = 0.58 * plan.direction
        rabbit.yScale = 0.58
        rabbit.startIdleAnimation()

        // The look pause is followed by gather -> takeoff -> flight -> land.
        scheduleTransition(after: plan.turnPause) { [weak self] in
            guard let self, let rabbit = self.rabbit, !self.isPaused else { return }
            // Apply the latest CPU tempo only after the visual node has cleared
            // its prior actions. Changing SKNode.speed during a running move
            // action can freeze that action.
            rabbit.startRunningAnimation(includeResidualBob: false)
            rabbit.speed = self.performance.animationSpeed
            let push = plan.distance * 0.16
            let flight = plan.distance * 0.62
            let landing = plan.distance - push - flight
            rabbit.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.17),
                SKAction.moveBy(x: plan.direction * push, y: 0.6, duration: 0.11),
                SKAction.moveBy(x: plan.direction * flight, y: 1.2, duration: 0.16),
                SKAction.moveBy(x: plan.direction * landing, y: -1.8, duration: 0.15),
                SKAction.wait(forDuration: 0.10),
                SKAction.run { [weak self] in self?.finishHop() }
            ]), withKey: self.movementKey)
        }
    }

    private func finishHop() {
        guard rabbit != nil else { return }
        hopsRemaining -= 1
        rabbit.startRestingAnimation()
        rabbit.speed = 1.0
        currentState = .resting
        if hopsRemaining > 0 {
            scheduleTransition(after: random.duration(0.7...1.7)) { [weak self] in
                self?.startNextHop()
            }
        } else {
            scheduleTransition(after: random.duration(8...18)) { [weak self] in
                self?.chooseNextStillState()
            }
        }
    }

    // MARK: - Rare binky

    private func performBinky() {
        guard rabbit != nil, binkyAvailable else {
            enterStillState(.resting)
            scheduleNextStillState()
            return
        }
        removeAction(forKey: stateScheduleKey)
        binkyAvailable = false
        run(SKAction.sequence([
            SKAction.wait(forDuration: Self.binkyCooldown),
            SKAction.run { [weak self] in self?.binkyAvailable = true }
        ]), withKey: binkyCooldownKey)
        currentState = .binky
        rabbit.performBinky { [weak self] in
            guard let self else { return }
            self.enterStillState(.resting)
            self.scheduleNextStillState()
        }
    }
}
