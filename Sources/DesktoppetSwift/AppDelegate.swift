import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    private(set) var window: NSWindow!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Setup menu bar icon
        statusBarController = StatusBarController()
        
        // Setup global hotkeys
        hotkeyManager = HotkeyManager.shared
        
        let windowRect = NSRect(x: 100, y: 100, width: 300, height: 220)
        
        // Create the window
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window for transparency and floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false // No shadow for a clean look
        window.isMovableByWindowBackground = true // Allow dragging by background
        window.ignoresMouseEvents = false

        // Set the custom view with hit-testing logic as the content view
        let passthroughView = PassthroughView(rootView: ContentView())
        window.contentView = passthroughView
        
        window.makeKeyAndOrderFront(nil)
    }
}
