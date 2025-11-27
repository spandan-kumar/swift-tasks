import SwiftUI
import AppKit

class MenuBarManager: NSObject {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventHandler: OpaquePointer?
    
    override init() {
        super.init()
        setupMenuBar()
        setupGlobalHotkey()
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Tasks")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    func setupGlobalHotkey() {
        // Global monitor (requires accessibility permissions in System Settings)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                if let chars = event.charactersIgnoringModifiers, chars.uppercased() == "T" {
                    DispatchQueue.main.async {
                        self?.togglePopover(nil)
                    }
                }
            }
        }
        
        // Local monitor (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                if let chars = event.charactersIgnoringModifiers, chars.uppercased() == "T" {
                    self?.togglePopover(nil)
                    return nil // Consume event
                }
            }
            return event
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(sender)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    popover.contentViewController?.view.window?.level = .floating
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    func setLaunchAtLogin(enabled: Bool) {
        print("Launch at Login not supported in this build version.")
        // SMAppService requires proper signing and bundling which is complex for this script-based build.
    }
}
