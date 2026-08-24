//
//  AppDelegate.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import AppKit
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var rabbitScene: RabbitScene!

    override init() {
        super.init()
        print("AppDelegate init called")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching called")
        guard let screen = NSScreen.main else {
            print("No screen found")
            return
        }

        print("Screen frame: \(screen.frame)")
        print("Visible frame: \(screen.visibleFrame)")

        let height: CGFloat = 80
        // Use visibleFrame to avoid menu bar area
        let frame = NSRect(
            x: screen.visibleFrame.minX,
            y: screen.visibleFrame.maxY - height,
            width: screen.visibleFrame.width,
            height: height
        )

        print("Window frame: \(frame)")

        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.red.withAlphaComponent(0.3) // Debug: visible background
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)

        let contentFrame = CGRect(origin: .zero, size: frame.size)

        let skView = SKView(frame: contentFrame)
        skView.allowsTransparency = true

        let hostingView = ClickableHostingView(frame: contentFrame)
        hostingView.addSubview(skView)
        window.contentView = hostingView

        rabbitScene = RabbitScene(size: frame.size)
        rabbitScene.scaleMode = .resizeFill
        skView.presentScene(rabbitScene)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
