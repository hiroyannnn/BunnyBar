//
//  AppDelegate.swift
//  BunnyBar
//

import AppKit
import ServiceManagement
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private final class Overlay {
        private let screenFrame: NSRect
        let window: NSWindow
        let view: SKView
        let scene: RabbitScene
        let hostingView: ClickableHostingView

        init(screen: NSScreen, appearance: NSAppearance?) {
            let height: CGFloat = 44
            screenFrame = screen.frame
            // The viewport only needs room for the ~37pt still texture and a
            // little motion margin. A bounded window is important: even if a
            // compositor loses the clear surface, it cannot cover the whole
            // menu bar or another display.
            let viewportWidth = min(88, max(1, screen.frame.width))
            let initialRabbitX = screen.frame.width * 0.40
            let initialX = RabbitScene.viewportOriginX(screenMinX: screen.frame.minX,
                                                       screenWidth: screen.frame.width,
                                                       rabbitX: initialRabbitX,
                                                       viewportWidth: viewportWidth)
            let frame = NSRect(x: initialX, y: screen.frame.maxY - height,
                               width: viewportWidth, height: height)
            window = OverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.alphaValue = 1
            window.hasShadow = false
            // Keep the transparent overlay just above the system menu-bar
            // content; `.statusBar` itself can render behind the bar's own
            // compositor layer.
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = true
            window.acceptsMouseMovedEvents = false
            window.isExcludedFromWindowsMenu = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false

            let contentFrame = NSRect(origin: .zero, size: frame.size)
            view = SKView(frame: contentFrame)
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            // This is a narrow ambient overlay, not a game surface. A 20 fps
            // cap keeps motion readable without a continuous high-rate redraw.
            view.preferredFramesPerSecond = 20
            view.shouldCullNonVisibleNodes = true
            view.wantsLayer = true
            view.layer?.isOpaque = false
            view.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView = ClickableHostingView(frame: contentFrame)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView.addSubview(view)
            window.contentView = hostingView

            // The overlay is a separate borderless window, so inherit the
            // menu-bar button's appearance explicitly instead of resolving
            // colors against the accessory app's default appearance.
            window.appearance = appearance
            hostingView.appearance = appearance
            view.appearance = appearance

            scene = RabbitScene(size: frame.size)
            scene.worldWidth = screen.frame.width
            scene.scaleMode = .resizeFill
            scene.onRabbitPositionChange = { [weak self] rabbitX in
                self?.updateWindowPosition(forRabbitX: rabbitX)
            }
            view.presentScene(scene)
            hostingView.onAppearanceChange = { [weak self] in
                self?.applyAppearance(self?.menuBarAppearance)
            }
            scene.refreshAppearance()
        }

        private func updateWindowPosition(forRabbitX rabbitX: CGFloat) {
            guard Thread.isMainThread else {
                DispatchQueue.main.async { [weak self] in
                    self?.updateWindowPosition(forRabbitX: rabbitX)
                }
                return
            }
            let clampedX = RabbitScene.viewportOriginX(screenMinX: screenFrame.minX,
                                                       screenWidth: screenFrame.width,
                                                       rabbitX: rabbitX,
                                                       viewportWidth: window.frame.width)
            guard abs(window.frame.minX - clampedX) > 0.25 else { return }
            window.setFrameOrigin(NSPoint(x: clampedX, y: window.frame.minY))
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
    private let stateMenuItem = NSMenuItem(title: "Rabbit state · Watching", action: nil, keyEquivalent: "")
    private let speedMenuItem = NSMenuItem(title: "Next hop tempo 0.90×", action: nil, keyEquivalent: "")
    private let memoryMenuItem = NSMenuItem(title: "Memory —", action: nil, keyEquivalent: "")
    private let launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let source = NSImage(named: "StatusRabbit"),
           let icon = source.copy() as? NSImage {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            statusItem.button?.image = icon
            statusItem.button?.imagePosition = .imageOnly
            statusItem.button?.imageScaling = .scaleProportionallyDown
        } else {
            statusItem.button?.title = "🐰"
        }
        statusItem.button?.toolTip = "BunnyBar"

        let menu = NSMenu()
        cpuMenuItem.isEnabled = false
        stateMenuItem.isEnabled = false
        speedMenuItem.isEnabled = false
        memoryMenuItem.isEnabled = false
        launchAtLoginMenuItem.target = self
        menu.addItem(cpuMenuItem)
        menu.addItem(stateMenuItem)
        menu.addItem(speedMenuItem)
        menu.addItem(memoryMenuItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginMenuItem)

        visibilityMenuItem = NSMenuItem(title: "Hide Bunny", action: #selector(toggleBunny), keyEquivalent: "b")
        visibilityMenuItem.target = self
        menu.addItem(visibilityMenuItem)
        let quitItem = NSMenuItem(title: "Quit BunnyBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.delegate = self
        statusItem.menu = menu
        refreshLaunchAtLoginMenuItem()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        refreshLaunchAtLoginMenuItem()
    }

    private func refreshLaunchAtLoginMenuItem() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginMenuItem.title = "Launch at Login"
            launchAtLoginMenuItem.state = .on
            launchAtLoginMenuItem.isEnabled = true
        case .requiresApproval:
            launchAtLoginMenuItem.title = "Launch at Login (Open System Settings…)"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = true
        case .notRegistered:
            launchAtLoginMenuItem.title = "Launch at Login"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = true
        case .notFound:
            launchAtLoginMenuItem.title = "Launch at Login (Unavailable)"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = false
        @unknown default:
            launchAtLoginMenuItem.title = "Launch at Login (Unavailable)"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = false
        }
    }

    @objc private func toggleLaunchAtLogin(_: NSMenuItem) {
        let service = SMAppService.mainApp
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }

        if service.status == .enabled {
            do {
                try service.unregister()
            } catch {
                NSLog("BunnyBar: failed to disable Launch at Login: \(error.localizedDescription)")
            }
        } else {
            do {
                try service.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } catch {
                NSLog("BunnyBar: failed to enable Launch at Login: \(error.localizedDescription)")
                SMAppService.openSystemSettingsLoginItems()
            }
        }
        refreshLaunchAtLoginMenuItem()
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
        let state = overlays.values.first?.scene.stateDescription ?? "Watching"
        stateMenuItem.title = "Rabbit state · \(state)"
        speedMenuItem.title = String(format: "Next hop tempo %.2f×", Double(latestPerformance.animationSpeed))
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
