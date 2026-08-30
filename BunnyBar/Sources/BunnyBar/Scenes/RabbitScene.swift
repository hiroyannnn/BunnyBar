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
    private var boutNeedsTurnPause = false
    private var hasStartedExploration = false
    private var binkyAvailable = true
    private let stateScheduleKey = "rabbit-state-schedule"
    private let binkyCooldownKey = "rabbit-binky-cooldown"
    private let movementKey = "rabbit-hop-movement"
    private let bodyMargin: CGFloat = 19
    private let minimumHop: CGFloat = 18
    private let maximumHop: CGFloat = 38

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

    /// Normalized centre-of-mass travel for one relaxed indoor hop.
    ///
    /// Rear-leg propulsion accelerates into a short, low flight. The body is
    /// back on the baseline when the forepaws contact, then forward motion
    /// decelerates while the hindfeet swing under the body and load. This is
    /// deliberately not a symmetric ease-in/ease-out arc: that read as a
    /// generic programmed tween rather than rabbit locomotion.
    static func naturalHopProgress(at unitTime: CGFloat) -> CGPoint {
        let time = min(1, max(0, unitTime))
        let motionDuration = CGFloat(RabbitNode.hopMotionDuration)
        let propulsionEnd = CGFloat(RabbitNode.hopPropulsionDuration) / motionDuration
        let flightEnd = CGFloat(
            RabbitNode.hopPropulsionDuration + RabbitNode.hopFlightDuration
        ) / motionDuration
        let forepawEnd = CGFloat(
            RabbitNode.hopPropulsionDuration + RabbitNode.hopFlightDuration
                + RabbitNode.hopForepawContactDuration
        ) / motionDuration

        let horizontal: CGFloat
        if time <= propulsionEnd {
            let phase = time / propulsionEnd
            horizontal = 0.13 * phase * phase
        } else if time <= flightEnd {
            let phase = (time - propulsionEnd) / (flightEnd - propulsionEnd)
            horizontal = 0.13 + 0.54 * phase
        } else if time <= forepawEnd {
            let phase = (time - flightEnd) / (forepawEnd - flightEnd)
            horizontal = 0.67 + 0.21 * phase
        } else {
            let phase = (time - forepawEnd) / (1 - forepawEnd)
            horizontal = 0.88 + 0.12 * (1 - (1 - phase) * (1 - phase))
        }

        let vertical: CGFloat
        if time < flightEnd {
            let airbornePhase = time / flightEnd
            vertical = 4 * airbornePhase * (1 - airbornePhase)
        } else {
            // Forepaw and hindfoot contact frames must not float on the arc.
            vertical = 0
        }
        return CGPoint(x: horizontal, y: vertical)
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
        case .sleeping: delay = 60...150
        case .resting: delay = 12...30
        case .grooming: delay = 6...14
        case .idle: delay = 3.5...9.0
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
            if !hasStartedExploration || roll >= 0.88 {
                beginExploration()
            } else {
                enterStillState(roll < 0.60 ? .resting : .idle)
                scheduleNextStillState()
            }
        case .resting:
            if roll < 0.003 {
                performBinky()
            } else if roll < 0.40 {
                enterStillState(.sleeping); scheduleNextStillState()
            } else if roll < 0.60 {
                enterStillState(.grooming); scheduleNextStillState()
            } else if roll < 0.82 {
                enterStillState(.idle); scheduleNextStillState()
            } else {
                beginExploration()
            }
        case .grooming:
            if roll < 0.001 {
                performBinky()
            } else if roll < 0.55 {
                enterStillState(.resting); scheduleNextStillState()
            } else if roll < 0.78 {
                enterStillState(.sleeping); scheduleNextStillState()
            } else if roll < 0.90 {
                enterStillState(.idle); scheduleNextStillState()
            } else {
                beginExploration()
            }
        case .idle:
            if roll < 0.003 {
                performBinky()
            } else if roll < 0.38 {
                enterStillState(.resting); scheduleNextStillState()
            } else if roll < 0.55 {
                enterStillState(.grooming); scheduleNextStillState()
            } else if roll < 0.66 {
                enterStillState(.sleeping); scheduleNextStillState()
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
        hopsRemaining = random.int(in: 2...4)

        // Direction changes happen before a bout, never randomly between two
        // consecutive hops. A house rabbit normally commits to a short line,
        // then pauses to look or sniff before choosing another one.
        if random.unit() < 0.14 {
            let reversed = -direction
            let reverseRoom = reversed > 0
                ? maximumX - rabbit.position.x
                : rabbit.position.x - minimumX
            if reverseRoom >= minimumHop {
                direction = reversed
                boutNeedsTurnPause = true
            }
        }
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
        var turnPause = boutNeedsTurnPause
            ? random.duration(0.32...0.55)
            : random.duration(0.06...0.12)
        boutNeedsTurnPause = false

        func room(for travelDirection: CGFloat) -> CGFloat {
            travelDirection > 0 ? rightRoom : leftRoom
        }

        if room(for: nextDirection) < minimumHop {
            nextDirection = -nextDirection
            turnPause = random.duration(0.45...0.72)
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

        // The look pause is followed by support/loading, one continuous
        // ballistic hop, forepaw contact, and hindfoot loading.
        scheduleTransition(after: plan.turnPause) { [weak self] in
            guard let self, let rabbit = self.rabbit, !self.isPaused else { return }
            // Apply the latest CPU tempo only after the visual node has cleared
            // its prior actions. Changing SKNode.speed during a running move
            // action can freeze that action.
            rabbit.startRunningAnimation(includeResidualBob: false)
            rabbit.speed = self.performance.animationSpeed

            let takeoffPosition = rabbit.position
            let landingPosition = CGPoint(
                x: takeoffPosition.x + plan.direction * plan.distance,
                y: takeoffPosition.y
            )
            let hopHeight = min(2.2, 1.3 + plan.distance / 45)
            let movement = SKAction.customAction(
                withDuration: RabbitNode.hopMotionDuration
            ) { node, elapsed in
                let duration = CGFloat(RabbitNode.hopMotionDuration)
                let time = min(1, max(0, elapsed / duration))
                let progress = Self.naturalHopProgress(at: time)
                node.position = CGPoint(
                    x: takeoffPosition.x
                        + plan.direction * plan.distance * progress.x,
                    y: takeoffPosition.y + hopHeight * progress.y
                )
            }
            rabbit.run(SKAction.sequence([
                SKAction.wait(forDuration: RabbitNode.hopSupportDuration),
                movement,
                SKAction.run { rabbit.position = landingPosition },
                SKAction.wait(forDuration: RabbitNode.hopSettleDuration),
                SKAction.run { [weak self] in self?.finishHop() }
            ]), withKey: self.movementKey)
        }
    }

    private func finishHop() {
        guard rabbit != nil else { return }
        hopsRemaining -= 1
        rabbit.speed = 1.0
        if hopsRemaining > 0 {
            // Keep a bout connected. This is a foot-placement beat, not a
            // full stop; the old 0.7–1.7 second pause made every hop look like
            // a separate command.
            rabbit.startIdleAnimation()
            currentState = .running
            scheduleTransition(after: random.duration(0.10...0.24)) { [weak self] in
                self?.startNextHop()
            }
        } else {
            rabbit.startRestingAnimation()
            currentState = .resting
            scheduleTransition(after: random.duration(10...24)) { [weak self] in
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
