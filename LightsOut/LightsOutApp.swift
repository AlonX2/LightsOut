import SwiftUI
import CoreGraphics
import AppKit
import Sparkle

import SwiftUI
import AppKit

@main
struct LightsOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?
    let displaysViewModel = DisplaysViewModel()
    var updateController: SPUStandardUpdaterController!
    var contextMenuManager: ContextMenuManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        popover = NSPopover()
        popover.behavior = .applicationDefined
        
        // Set up the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenubarIcon")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }
        
        updateController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        if updateController.updater.automaticallyChecksForUpdates {
            updateController.updater.checkForUpdatesInBackground()
        }
        
        contextMenuManager = ContextMenuManager(updateController: updateController.updater, statusItem: statusItem)
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            contextMenuManager.showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let contentView = MenuBarView().environmentObject(displaysViewModel)
            popover.contentViewController = NSHostingController(rootView: contentView)

            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Ensure the app and popover window become active
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                popover.contentViewController?.view.window?.makeFirstResponder(popover.contentViewController?.view)
            }
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
}
