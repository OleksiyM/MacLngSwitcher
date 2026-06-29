import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the menu bar item (StatusBar)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use a standard system keyboard icon
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacLngSwitcher") {
                // Make the icon template-based to adapt to dark/light menu bar themes
                image.isTemplate = true
                button.image = image
            }
            
            // Configure click handlers (left and right click)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Prompt for accessibility access automatically on first launch (non-blocking)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            EventTapManager.shared.checkAccessibility(prompt: true)
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right click -> Show context menu
            statusItem.menu = makeContextMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // Clear the menu to not break the left click
        } else {
            // Left click -> Open settings window
            showSettings()
        }
    }
    
    // Create the right-click context menu
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let activeItem = NSMenuItem(title: "Active", action: #selector(toggleActive(_:)), keyEquivalent: "")
        activeItem.target = self
        activeItem.state = EventTapManager.shared.isEnabled ? .on : .off
        menu.addItem(activeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MacLngSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc func toggleActive(_ sender: NSMenuItem) {
        EventTapManager.shared.isEnabled.toggle()
        sender.state = EventTapManager.shared.isEnabled ? .on : .off
        
        // Toggle EventTap based on status
        if EventTapManager.shared.isEnabled {
            EventTapManager.shared.startEventTap()
        } else {
            EventTapManager.shared.stopEventTap()
        }
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView()
            
            // Create a borderless settings window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.title = "MacLngSwitcher"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.hasShadow = true
            
            // Set up the hosting view for SwiftUI content
            window.contentView = NSHostingView(rootView: contentView)
            
            self.settingsWindow = window
        }
        
        // Center and bring the window to the front
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        
        // Make the application active to focus the window
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Stop EventTap before exiting
        EventTapManager.shared.stopEventTap()
    }
}
