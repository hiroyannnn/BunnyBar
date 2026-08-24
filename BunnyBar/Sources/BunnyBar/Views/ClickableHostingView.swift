//
//  ClickableHostingView.swift
//  BunnyBar
//
//  Created by hiro on 2026/01/12.
//

import AppKit

final class ClickableHostingView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit BunnyBar",
            action: #selector(exitApp),
            keyEquivalent: "q"
        )
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func exitApp() {
        NSApp.terminate(nil)
    }
}
