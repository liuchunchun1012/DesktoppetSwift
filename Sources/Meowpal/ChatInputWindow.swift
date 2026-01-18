import SwiftUI
import AppKit

/// A separate window for AI chat input
class ChatInputWindow: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var mode: InputMode = .chat
    private var textField: NSTextField?
    private var imageBase64: String?
    
    func show(mode: InputMode, imageBase64: String? = nil) {
        self.mode = mode
        self.imageBase64 = imageBase64
        
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
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 90),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        var title: String
        switch mode {
        case .chat:
            title = "Chat with \(UserSettings.shared.petNickname)"
        case .translate:
            title = "Translate"
        case .imageQuestion:
            title = "Ask \(UserSettings.shared.petNickname)"
        }
        
        panel.title = title
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.center()
        
        // Create main view
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 90))
        
        // Input Container
        let containerRect = NSRect(x: 16, y: 45, width: 348, height: 30)
        let inputContainer = NSView(frame: containerRect)
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 15
        inputContainer.layer?.borderWidth = 1.0
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Text Field
        let textField = NSTextField(frame: NSRect(x: 10, y: 3, width: 328, height: 24))
        var placeholder: String
        switch mode {
        case .chat:
            placeholder = "Meow~ Say something..."
        case .translate:
            placeholder = "Enter text to translate..."
        case .imageQuestion:
            placeholder = "Ask about this image~"
        }
        textField.placeholderString = placeholder
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.target = self
        textField.action = #selector(submitFromTextField(_:))
        inputContainer.addSubview(textField)
        self.textField = textField
        
        mainView.addSubview(inputContainer)
        
        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 190, y: 10, width: 70, height: 26))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        mainView.addSubview(cancelButton)
        
        // Submit button
        let submitButton = NSButton(frame: NSRect(x: 270, y: 10, width: 90, height: 26))
        submitButton.title = "Send"
        submitButton.bezelStyle = .rounded
        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.keyEquivalent = "\r"
        mainView.addSubview(submitButton)
        
        panel.contentView = mainView
        window = panel
    }

    @objc private func submitFromTextField(_ sender: NSTextField) {
        submit()
    }
    
    @objc private func submit() {
        guard let text = textField?.stringValue.trimmingCharacters(in: .whitespaces),
              !text.isEmpty else { return }
        
        window?.close()
        
        var userInfo: [String: Any] = ["text": text, "mode": mode.rawValue]
        if let imageBase64 = imageBase64 {
            userInfo["imageBase64"] = imageBase64
        }
        
        NotificationCenter.default.post(
            name: .chatInputSubmitted,
            object: nil,
            userInfo: userInfo
        )
    }
    
    @objc private func cancel() {
        window?.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        textField = nil
        imageBase64 = nil
    }
}

// Notification for submitted input
extension Notification.Name {
    static let chatInputSubmitted = Notification.Name("chatInputSubmitted")
}
