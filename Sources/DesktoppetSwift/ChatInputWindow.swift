import SwiftUI
import AppKit
import Combine

/// A separate window for AI chat input
class ChatInputWindow: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var mode: InputMode = .chat
    private var textField: NSTextField?
    private var imageBase64: String?
    
    private var speechRecognizer: SpeechRecognizer?
    private var micButton: NSButton?
    private var recognitionObserver: AnyCancellable?
    
    func show(mode: InputMode, imageBase64: String? = nil) {
        self.mode = mode
        self.imageBase64 = imageBase64
        
        // Close existing window
        window?.close()
        window = nil
        
        // Initialize SpeechRecognizer if needed
        if speechRecognizer == nil {
            speechRecognizer = SpeechRecognizer()
        }
        
        createWindow()
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Observe speech recognition results
        recognitionObserver = speechRecognizer?.$recognizedText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.textField?.stringValue = text
                }
            }
        
        // Observe recording state to update UI
        speechRecognizer?.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                self?.updateMicButtonState(isRecording: isRecording)
            }
            .store(in: &cancellables)
            
        // Make text field first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.textField?.becomeFirstResponder()
            self?.window?.makeFirstResponder(self?.textField)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func createWindow() {
        // Use NSPanel which can become key even for menu bar apps
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 90), // Increased width to 380 for better spacing
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // ... (title logic same as before) ...
        var title: String
        switch mode {
        case .chat:
            title = "和\(UserSettings.shared.petNickname)聊天 (v2)"
        case .translate:
            title = "翻译"
        case .imageQuestion:
            title = "问问\(UserSettings.shared.petNickname)"
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
        
        // --- Unified Input Container ---
        let containerRect = NSRect(x: 16, y: 45, width: 348, height: 30) // Wider container
        let inputContainer = NSView(frame: containerRect)
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 15 // Capsule style
        inputContainer.layer?.borderWidth = 1.0
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 1. Text Field (Inside Container)
        let textField = NSTextField(frame: NSRect(x: 10, y: 3, width: 300, height: 24))
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
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none // Remove blue focus ring
        textField.target = self
        textField.action = #selector(submitFromTextField(_:))
        inputContainer.addSubview(textField)
        self.textField = textField
        
        // 2. Mic Button (Inside Container, Right aligned)
        let micBtn = NSButton(frame: NSRect(x: 316, y: 3, width: 24, height: 24))
        micBtn.bezelStyle = .regularSquare
        micBtn.isBordered = false
        micBtn.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "语音输入")
        micBtn.contentTintColor = .secondaryLabelColor
        micBtn.target = self
        micBtn.action = #selector(toggleRecording)
        inputContainer.addSubview(micBtn)
        self.micButton = micBtn
        
        mainView.addSubview(inputContainer)
        
        // Initialize default mic state
        updateMicButtonState(isRecording: false)
        
        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 190, y: 10, width: 70, height: 26))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        mainView.addSubview(cancelButton)
        
        // Submit button
        let submitButton = NSButton(frame: NSRect(x: 270, y: 10, width: 90, height: 26))
        submitButton.title = "发送"
        submitButton.bezelStyle = .rounded
        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.keyEquivalent = "\r"
        mainView.addSubview(submitButton)
        
        panel.contentView = mainView
        window = panel
    }
    
    @objc private func toggleRecording() {
        speechRecognizer?.toggleRecording()
    }
    
    private func updateMicButtonState(isRecording: Bool) {
        micButton?.image = NSImage(systemSymbolName: isRecording ? "mic.fill" : "mic", accessibilityDescription: "语音输入")
        micButton?.contentTintColor = isRecording ? .red : .labelColor
    }

    @objc private func submitFromTextField(_ sender: NSTextField) {
        submit()
    }
    
    @objc private func submit() {
        // Stop recording if active
        if speechRecognizer?.isRecording == true {
            speechRecognizer?.toggleRecording()
        }
        
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
        if speechRecognizer?.isRecording == true {
            speechRecognizer?.toggleRecording()
        }
        window?.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        if speechRecognizer?.isRecording == true {
            speechRecognizer?.toggleRecording()
        }
        textField = nil
        imageBase64 = nil
        cancellables.removeAll()
    }
}

// Notification for submitted input
extension Notification.Name {
    static let chatInputSubmitted = Notification.Name("chatInputSubmitted")
}


