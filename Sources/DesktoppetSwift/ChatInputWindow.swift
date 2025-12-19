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
        // Use NSPanel which can become key even for menu bar apps
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        var title: String
        switch mode {
        case .chat:
            title = "🐱 和喵喵聊天"
        case .translate:
            title = "🌐 翻译"
        case .imageQuestion:
            title = "📸 问问喵喵"
        }
        
        panel.title = title
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.center()
        
        // Tuxedo cat color palette
        let creamColor = NSColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        let darkGray = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
        
        // Create content view with custom background
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 90))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = creamColor.cgColor
        
        let textFieldY: CGFloat = 45
        
        // Styled text field
        let textField = NSTextField(frame: NSRect(x: 16, y: textFieldY, width: 288, height: 26))
        var placeholder: String
        switch mode {
        case .chat:
            placeholder = "喵~ 说点什么吧..."
        case .translate:
            placeholder = "输入要翻译的文字..."
        case .imageQuestion:
            placeholder = "问一个关于这张图的问题喵~"
        }
        textField.placeholderString = placeholder
        textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textField.bezelStyle = .roundedBezel
        textField.target = self
        textField.action = #selector(submitFromTextField(_:))
        containerView.addSubview(textField)
        self.textField = textField
        
        // Styled cancel button
        let cancelButton = NSButton(frame: NSRect(x: 130, y: 10, width: 70, height: 26))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.font = NSFont.systemFont(ofSize: 12)
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        containerView.addSubview(cancelButton)
        
        // Styled submit button with accent color
        let submitButton = NSButton(frame: NSRect(x: 210, y: 10, width: 90, height: 26))
        submitButton.title = "发送 🐾"
        submitButton.bezelStyle = .rounded
        submitButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.keyEquivalent = "\r"
        submitButton.contentTintColor = darkGray
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

