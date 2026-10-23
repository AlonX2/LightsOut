//
//  PopoverService.swift
//  LightsOut
//
//  Created by DE4ME on 19.10.2026.
//

import AppKit


class PopoverService {
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var contextMenuManager: ContextMenuManager!
    private var eventMonitor: Any?
    
    var contentViewController: NSViewController? {
        set {
            popover.contentViewController = newValue
        }
        get {
            popover.contentViewController
        }
    }
    
    
    init() {
        popover = NSPopover()
        popover.behavior = .applicationDefined
        
        // Set up the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenubarIcon")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        contextMenuManager = ContextMenuManager(statusItem: statusItem)
    }
    
    
    @objc private func handleClick(_ sender: Any?) {
        guard !popover.isShown else {
            hidePopover(sender)
            return
        }
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            contextMenuManager?.showContextMenu()
        case .leftMouseUp:
            showPopover()
        default:
            break
        }
    }
    
    
    @objc private func handleEvent(_ event: NSEvent) {
        #if DEBUG
        print(#function)
        #endif
        guard popover.isShown else {
            return
        }
        hidePopover(event)
    }
    
    
    func beginMonitoreEvents() {
        self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handleEvent)
    }
    
    
    func endMonitoreEvents() {
        guard let eventMonitor else {
            return
        }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }
    
    
    private func hidePopover(_ sender: Any?) {
        popover.performClose(sender)
        endMonitoreEvents()
    }
    
    
    func showPopover() {
        guard let contentViewController = popover.contentViewController,
              let button = statusItem.button
        else {
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        beginMonitoreEvents()
        
        // Ensure the app and popover window become active
        NSApp.activate(ignoringOtherApps: true)
        contentViewController.view.window?.makeKeyAndOrderFront(nil)
        contentViewController.view.window?.makeFirstResponder(contentViewController.view)
    }
    
}
