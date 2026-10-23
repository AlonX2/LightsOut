//
//  ContextMenuManager.swift
//  LightsOut
//

import AppKit
import LaunchAtLogin

class ContextMenuManager {
    private weak var statusItem: NSStatusItem?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func showContextMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        let launch_at_login = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: "l"
        )
        
        launch_at_login.target = self;
        updateLaunchAtLoginItem(launch_at_login)
        
        menu.addItem(launch_at_login)
        
        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit LightsOut",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    private func updateLaunchAtLoginItem(_ item: NSMenuItem) {
        item.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    @objc private func toggleLaunchAtLogin(_ item: NSMenuItem) {
        LaunchAtLogin.isEnabled = item.state == .off
        updateLaunchAtLoginItem(item)
    }

}
