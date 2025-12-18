import AppKit
import Carbon

/// Manages global hotkeys for the desktop pet
class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var globalMonitor: Any?

    // Modifier mask for Command+Shift
    private let modifierMask: NSEvent.ModifierFlags = [.command, .shift]
    
    init() {
        setupGlobalHotkeys()
    }
    
    private func setupGlobalHotkeys() {
        NSLog("[HotkeyManager] Setting up global hotkeys...")

        // Request accessibility permission if needed
        let hasPerm = checkAccessibilityPermission()
        NSLog("[HotkeyManager] Accessibility permission: \(hasPerm)")
        if !hasPerm {
            NSLog("[HotkeyManager] Requesting accessibility permission...")
            requestAccessibilityPermission()
        }

        // Monitor global key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("[HotkeyManager] Key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
            self?.handleKeyEvent(event)
        }
        NSLog("[HotkeyManager] Global monitor installed: \(globalMonitor != nil)")
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Check if Cmd+Shift is pressed
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        guard modifiers == modifierMask else {
            return
        }

        NSLog("[HotkeyManager] 🔥 Cmd+Shift detected! keyCode: \(event.keyCode)")

        switch event.keyCode {
        case 38: // J key
            NSLog("[HotkeyManager] ✅ Hotkey: Open Chat (Cmd+Shift+J)")
            NotificationCenter.default.post(name: .hotkeyOpenChat, object: nil)

        case 40: // K key
            NSLog("[HotkeyManager] ✅ Hotkey: Translate Selection (Cmd+Shift+K)")
            translateSelection()

        case 37: // L key
            NSLog("[HotkeyManager] ✅ Hotkey: Screenshot Question (Cmd+Shift+L)")
            analyzeClipboardImage()

        default:
            break
        }
    }
    
    /// Translate currently selected text
    private func translateSelection() {
        // Simulate Cmd+C to copy selection
        simulateCopy()
        
        // Wait a moment for clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                // Determine target language
                let targetLang = text.range(of: "\\p{Han}", options: .regularExpression) != nil ? "English" : "Chinese"
                
                NotificationCenter.default.post(
                    name: .hotkeyTranslate,
                    object: nil,
                    userInfo: ["text": text, "targetLang": targetLang]
                )
            }
        }
    }
    
    /// Analyze image from clipboard
    private func analyzeClipboardImage() {
        let pasteboard = NSPasteboard.general
        
        // Check for image in clipboard
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // Convert to base64
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let base64String = pngData.base64EncodedString()
                
                NotificationCenter.default.post(
                    name: .hotkeyAnalyzeImage,
                    object: nil,
                    userInfo: ["imageBase64": base64String]
                )
            }
        } else {
            print("No image in clipboard")
            NotificationCenter.default.post(
                name: .hotkeyAnalyzeImage,
                object: nil,
                userInfo: ["error": "剪贴板里没有图片喵~ 先用 Shottr 截图吧！"]
            )
        }
    }
    
    /// Simulate Cmd+C keypress
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // C key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let hotkeyOpenChat = Notification.Name("hotkeyOpenChat")
    static let hotkeyTranslate = Notification.Name("hotkeyTranslate")
    static let hotkeyAnalyzeImage = Notification.Name("hotkeyAnalyzeImage")
}
