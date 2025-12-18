import SwiftUI
import AppKit

/// A separate window for AI chat input
class ChatInputWindow: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var mode: InputMode = .chat
    private var textField: NSTextField?
    
    func show(mode: InputMode) {
        self.mode = mode
        
        // Close existing window
        window?.close()
        window = nil
        
        createWindow()
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make text field first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.textField?.becomeFirstResponder()
            self?.window?.makeFirstResponder(self?.textField)
        }
    }
    
    private func createWindow() {
        // Use NSPanel which can become key even for menu bar apps
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 100),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.title = mode == .chat ? "💬 和猫咪聊天" : "🌐 翻译"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.center()
        
        // Create content view with AppKit controls
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 100))
        
        // Text field
        let textField = NSTextField(frame: NSRect(x: 20, y: 50, width: 310, height: 24))
        textField.placeholderString = mode == .chat ? "说点什么..." : "输入要翻译的文字..."
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.bezelStyle = .roundedBezel
        textField.target = self
        textField.action = #selector(submitFromTextField(_:))
        containerView.addSubview(textField)
        self.textField = textField
        
        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 150, y: 15, width: 80, height: 28))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        containerView.addSubview(cancelButton)
        
        // Submit button
        let submitButton = NSButton(frame: NSRect(x: 240, y: 15, width: 80, height: 28))
        submitButton.title = "发送"
        submitButton.bezelStyle = .rounded
        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.keyEquivalent = "\r" // Return
        containerView.addSubview(submitButton)
        
        panel.contentView = containerView
        window = panel
    }
    
    @objc private func submitFromTextField(_ sender: NSTextField) {
        submit()
    }
    
    @objc private func submit() {
        guard let text = textField?.stringValue.trimmingCharacters(in: .whitespaces),
              !text.isEmpty else { return }
        
        window?.close()
        
        NotificationCenter.default.post(
            name: .chatInputSubmitted,
            object: nil,
            userInfo: ["text": text, "mode": mode]
        )
    }
    
    @objc private func cancel() {
        window?.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        textField = nil
    }
}

// Notification for submitted input
extension Notification.Name {
    static let chatInputSubmitted = Notification.Name("chatInputSubmitted")
}
