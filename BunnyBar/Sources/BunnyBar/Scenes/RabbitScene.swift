//
//  RabbitScene.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import SpriteKit

enum RabbitState {
    case sleeping    // 寝ている（デフォルト、最も長い）
    case resting     // ゴロゴロ（起きてるけど動かない）
    case grooming    // 毛づくろい
    case idle        // 起きて周囲を見る
    case running     // 走る（レア）
    case binky       // 喜びジャンプ（超レア）
}

class RabbitScene: SKScene {
    private var rabbit: RabbitNode!
    private(set) var currentState: RabbitState = .sleeping
    private var stateTimer: Timer?
    private(set) var performance = RabbitPerformance(cpuPercent: 0)

    // A real rabbit spends most of its time still.  Keep load-triggered
    // activity as a sustained signal with a generous refractory period so a
    // busy CPU cannot turn into an endless patrol loop.
    private var sustainedHighLoadSamples = 0
    private var lastRunDate: Date?
    private var lastBinkyDate: Date?
    private let runCooldown: TimeInterval = 75
    private let binkyCooldown: TimeInterval = 900

    // Position where rabbit stays (left side, avoiding center)
    private var homePosition: CGPoint = .zero

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        // Position rabbit on the left side, lower on screen
        // Keep the scaled silhouette inside the native 30px menu-bar strip;
        // the overlay itself is 44px tall, so the rabbit's local baseline
        // sits well above the lower edge instead of dipping into the app below.
        homePosition = CGPoint(x: size.width * 0.40, y: size.height * 0.68)

        rabbit = RabbitNode()
        // The vector silhouette is authored around 38pt tall. This keeps the
        // lop ears and feet readable at roughly 22px without crowding the bar.
        rabbit.setScale(0.58)
        rabbit.speed = performance.animationSpeed
        rabbit.position = homePosition
        addChild(rabbit)

        // Start with sleeping (most common state)
        enterState(.sleeping)
    }

    deinit {
        stateTimer?.invalidate()
    }

    /// Applies a sampled system load without coupling the sampler to the
    /// scene's state machine. SKNode.speed affects all pose and movement
    /// actions, so transitions stay smooth at every load level.
    func applyPerformance(_ performance: RabbitPerformance) {
        self.performance = performance
        rabbit?.speed = performance.animationSpeed

        // Require two consecutive high-load samples (~3 seconds with the
        // current sampler), and use hysteresis so a threshold-edge reading
        // cannot repeatedly wake the rabbit. Low-load sleeping is never
        // force-started; only sustained high load can interrupt a sleep pose.
        if performance.cpuPercent >= 70 {
            sustainedHighLoadSamples += 1
        } else if performance.cpuPercent < 55 {
            sustainedHighLoadSamples = 0
        }

        guard sustainedHighLoadSamples >= 2,
              currentState != .running,
              currentState != .binky,
              rabbit != nil,
              canStartRun else { return }
        enterState(.running)
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

    func refreshAppearance() {
        rabbit?.refreshAppearance()
    }

    func stop() {
        stateTimer?.invalidate()
        stateTimer = nil
        rabbit?.removeAllActions()
        isPaused = true
    }

    // MARK: - State Machine

    private func enterState(_ state: RabbitState) {
        stateTimer?.invalidate()
        currentState = state

        switch state {
        case .sleeping:
            rabbit.position = homePosition
            rabbit.startSleepingAnimation()
            // Rabbits rest in long blocks; activity is an interruption, not
            // the default animation loop.
            scheduleNextState(afterMin: 60, afterMax: 150)

        case .resting:
            rabbit.position = homePosition
            rabbit.startRestingAnimation()
            scheduleNextState(afterMin: 30, afterMax: 75)

        case .grooming:
            rabbit.position = homePosition
            rabbit.startGroomingAnimation()
            scheduleNextState(afterMin: 20, afterMax: 45)

        case .idle:
            rabbit.position = homePosition
            rabbit.startIdleAnimation()
            scheduleNextState(afterMin: 10, afterMax: 25)

        case .running:
            startRunning()

        case .binky:
            guard canStartBinky else {
                enterState(.resting)
                return
            }
            lastBinkyDate = Date()
            rabbit.performBinky { [weak self] in
                self?.enterState(.resting)
            }
        }
    }

    private func scheduleNextState(afterMin: TimeInterval, afterMax: TimeInterval) {
        let delay = TimeInterval.random(in: afterMin...afterMax)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.transitionToNextState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        stateTimer = timer
    }

    private func transitionToNextState() {
        let roll = Double.random(in: 0...100)

        switch currentState {
        case .sleeping:
            // 35% -> resting, 35% -> grooming, 20% -> idle, 9.5% -> running, 0.5% -> binky
            if roll < 35 {
                enterState(.resting)
            } else if roll < 70 {
                enterState(.grooming)
            } else if roll < 90 {
                enterState(.idle)
            } else if roll < 99.5 {
                enterState(.running)
            } else {
                enterState(.binky)
            }

        case .resting:
            // 35% -> sleeping, 35% -> grooming, 20% -> idle, 9.5% -> running, 0.5% -> binky
            if roll < 35 {
                enterState(.sleeping)
            } else if roll < 70 {
                enterState(.grooming)
            } else if roll < 90 {
                enterState(.idle)
            } else if roll < 99.5 {
                enterState(.running)
            } else {
                enterState(.binky)
            }

        case .grooming:
            // 40% -> resting, 25% -> sleeping, 25% -> idle, 9.8% -> running, 0.2% -> binky
            if roll < 40 {
                enterState(.resting)
            } else if roll < 65 {
                enterState(.sleeping)
            } else if roll < 90 {
                enterState(.idle)
            } else if roll < 99.8 {
                enterState(.running)
            } else {
                enterState(.binky)
            }

        case .idle:
            // 35% -> resting, 25% -> sleeping, 25% -> grooming, 14.5% -> running, 0.5% -> binky
            if roll < 35 {
                enterState(.resting)
            } else if roll < 60 {
                enterState(.sleeping)
            } else if roll < 85 {
                enterState(.grooming)
            } else if roll < 99.5 {
                enterState(.running)
            } else {
                enterState(.binky)
            }

        case .running:
            // A bound is followed by a recovery rest.
            enterState(.resting)

        case .binky:
            // Handled by completion callback
            break
        }
    }

    // MARK: - Running (Rare Event)

    private var canStartRun: Bool {
        guard let lastRunDate else { return true }
        return Date().timeIntervalSince(lastRunDate) >= runCooldown
    }

    private var canStartBinky: Bool {
        guard let lastBinkyDate else { return true }
        return Date().timeIntervalSince(lastBinkyDate) >= binkyCooldown
    }

    private func startRunning() {
        guard canStartRun else {
            enterState(.resting)
            return
        }
        // Keep a sustained high-load signal latched; lastRunDate provides the
        // separate 75-second refractory period before another burst.
        lastRunDate = Date()
        rabbit.startRunningAnimation()

        let screenWidth = size.width

        // One visible pass is enough. Returning across the screen made the
        // rabbit look like a scheduled patrol; it now resets home off-screen
        // after the burst and settles.
        let runRight = SKAction.moveTo(x: screenWidth + 30, duration: 6.0)
        let disappear = SKAction.run { [weak self] in
            guard let self else { return }
            self.rabbit.position = self.homePosition
        }
        let done = SKAction.run { [weak self] in
            self?.enterState(.resting)
        }

        let sequence = SKAction.sequence([runRight, disappear, done])
        rabbit.run(sequence, withKey: "movement")
    }
}
