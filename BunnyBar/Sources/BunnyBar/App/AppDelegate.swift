//
//  AppDelegate.swift
//  BunnyBar
//

import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private final class Overlay {
        let window: NSWindow
        let view: SKView
        let scene: RabbitScene
        let hostingView: ClickableHostingView

        init(screen: NSScreen, appearance: NSAppearance?) {
            let height: CGFloat = 44
            let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - height,
                               width: screen.frame.width, height: height)
            window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            // Keep the transparent overlay just above the system menu-bar
            // content; `.statusBar` itself can render behind the bar's own
            // compositor layer. This remains the minimum elevation needed to
            // make the rabbit visible while retaining click-through behavior.
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false

            let contentFrame = NSRect(origin: .zero, size: frame.size)
            view = SKView(frame: contentFrame)
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            // This is a narrow ambient overlay, not a game surface. A 20 fps
            // cap keeps motion readable while avoiding a full-width 60 fps
            // transparent redraw on every display.
            view.preferredFramesPerSecond = 20
            view.shouldCullNonVisibleNodes = true
            hostingView = ClickableHostingView(frame: contentFrame)
            hostingView.addSubview(view)
            window.contentView = hostingView

            // The overlay is a separate borderless window, so inherit the
            // menu-bar button's appearance explicitly instead of resolving
            // colors against the accessory app's default appearance.
            window.appearance = appearance
            hostingView.appearance = appearance
            view.appearance = appearance

            scene = RabbitScene(size: frame.size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
            hostingView.onAppearanceChange = { [weak self] in
                self?.applyAppearance(self?.menuBarAppearance)
            }
            scene.refreshAppearance()
        }

        private var menuBarAppearance: NSAppearance? {
            NSApp.delegate.flatMap { ($0 as? AppDelegate)?.statusItem.button?.effectiveAppearance }
        }

        func applyAppearance(_ appearance: NSAppearance?) {
            window.appearance = appearance
            hostingView.appearance = appearance
            view.appearance = appearance
            scene.refreshAppearance()
        }

        func show() {
            view.isPaused = false
            window.orderFrontRegardless()
        }

        func hide() {
            view.isPaused = true
            window.orderOut(nil)
        }

        func close() {
            scene.stop()
            view.presentScene(nil)
            window.orderOut(nil)
        }
    }

    private var statusItem: NSStatusItem!
    private var overlays: [ObjectIdentifier: Overlay] = [:]
    private let sampler = SystemMetricsSampler()
    private var metricsTimer: Timer?
    private var screenChangeObserver: NSObjectProtocol?
    private var isBunnyVisible = true
    private var latestSnapshot = SystemMetricsSnapshot(cpuPercent: 0, memoryPercent: nil)
    private var latestPerformance = RabbitPerformance(cpuPercent: 0)

    private let cpuMenuItem = NSMenuItem(title: "CPU 0% · Calm", action: nil, keyEquivalent: "")
    private let stateMenuItem = NSMenuItem(title: "Rabbit state · Sleeping", action: nil, keyEquivalent: "")
    private let speedMenuItem = NSMenuItem(title: "Rabbit speed 0.75×", action: nil, keyEquivalent: "")
    private let memoryMenuItem = NSMenuItem(title: "Memory —", action: nil, keyEquivalent: "")
    private var visibilityMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        rebuildOverlays()
        startMetricsTimer()

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildOverlays() }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐰"
        statusItem.button?.toolTip = "BunnyBar"

        let menu = NSMenu()
        cpuMenuItem.isEnabled = false
        stateMenuItem.isEnabled = false
        speedMenuItem.isEnabled = false
        memoryMenuItem.isEnabled = false
        menu.addItem(cpuMenuItem)
        menu.addItem(stateMenuItem)
        menu.addItem(speedMenuItem)
        menu.addItem(memoryMenuItem)
        menu.addItem(.separator())

        visibilityMenuItem = NSMenuItem(title: "Hide Bunny", action: #selector(toggleBunny), keyEquivalent: "b")
        visibilityMenuItem.target = self
        menu.addItem(visibilityMenuItem)
        let quitItem = NSMenuItem(title: "Quit BunnyBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func rebuildOverlays() {
        overlays.values.forEach { $0.close() }
        overlays.removeAll(keepingCapacity: true)
        for screen in NSScreen.screens {
            let overlay = Overlay(screen: screen, appearance: statusItem.button?.effectiveAppearance)
            overlay.scene.applyPerformance(latestPerformance)
            overlays[ObjectIdentifier(screen)] = overlay
            isBunnyVisible ? overlay.show() : overlay.hide()
        }
    }

    private func startMetricsTimer() {
        metricsTimer?.invalidate()
        updateMetrics()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMetrics()
            }
        }
        // Keep values live while an NSStatusItem menu is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        metricsTimer = timer
    }

    private func updateMetrics() {
        latestSnapshot = sampler.sample()
        latestPerformance = RabbitPerformance(cpuPercent: latestSnapshot.cpuPercent)
        overlays.values.forEach { $0.scene.applyPerformance(latestPerformance) }
        cpuMenuItem.title = String(format: "CPU %.0f%% · %@", latestPerformance.cpuPercent, latestPerformance.status)
        let state = overlays.values.first?.scene.stateDescription ?? "Sleeping"
        stateMenuItem.title = "Rabbit state · \(state)"
        speedMenuItem.title = String(format: "Rabbit speed %.2f×", Double(latestPerformance.animationSpeed))
        if let memory = latestSnapshot.memoryPercent {
            memoryMenuItem.title = String(format: "Memory %.0f%% used", memory)
        } else {
            memoryMenuItem.title = "Memory unavailable"
        }
        statusItem.button?.toolTip = String(format: "BunnyBar · CPU %.0f%% · %@", latestPerformance.cpuPercent, latestPerformance.status)
    }

    @objc private func toggleBunny() {
        isBunnyVisible.toggle()
        visibilityMenuItem.title = isBunnyVisible ? "Hide Bunny" : "Show Bunny"
        overlays.values.forEach { isBunnyVisible ? $0.show() : $0.hide() }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        metricsTimer?.invalidate()
        metricsTimer = nil
        if let observer = screenChangeObserver { NotificationCenter.default.removeObserver(observer) }
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
