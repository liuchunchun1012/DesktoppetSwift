import AppKit
import Carbon

/// Manages global hotkeys using Carbon API
/// Bypasses Accessibility Permission requirements for simple hotkeys
class HotkeyManager {
    static let shared = HotkeyManager()
    
    // Keep track of registered hotkeys to identify them in callback
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    
    // Define hotkey IDs
    private enum HotkeyID: UInt32 {
        case openChat = 1
        case translate = 2
        case analyzeImage = 3
    }
    
    init() {
        setupCarbonHotkeys()
    }
    
    private func setupCarbonHotkeys() {
        print("[HotkeyManager] Setting up Carbon hotkeys...")
        
        // 1. Register Hotkeys
        registerHotkey(keyCode: kVK_ANSI_J, id: .openChat)
        registerHotkey(keyCode: kVK_ANSI_K, id: .translate)
        registerHotkey(keyCode: kVK_ANSI_L, id: .analyzeImage)
        
        // 2. Install Event Handler
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            return HotkeyManager.shared.handleCarbonEvent(event)
        }, 1, eventSpec, nil, &eventHandler)
        
        print("[HotkeyManager] Carbon event handler installed")
    }
    
    private func registerHotkey(keyCode: Int, id: HotkeyID) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4445534B), id: id.rawValue) // Sig: 'DESK'
        
        // Cmd + Shift + Key
        let modifiers = cmdKey | shiftKey
        
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs[id.rawValue] = ref
            print("[HotkeyManager] Registered hotkey ID \(id.rawValue) for key \(keyCode)")
        } else {
            print("[HotkeyManager] Failed to register hotkey ID \(id.rawValue), error: \(status)")
        }
    }
    
    private func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(event,
                                     EventParamName(kEventParamDirectObject),
                                     EventParamType(typeEventHotKeyID),
                                     nil,
                                     MemoryLayout<EventHotKeyID>.size,
                                     nil,
                                     &hotKeyID)
        
        if status != noErr { return status }
        
        // Dispatch based on ID
        if let id = HotkeyID(rawValue: hotKeyID.id) {
            switch id {
            case .openChat:
                print("[HotkeyManager] 🔥 Carbon Hotkey: Open Chat")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .hotkeyOpenChat, object: nil)
                }
                
            case .translate:
                print("[HotkeyManager] 🔥 Carbon Hotkey: Translate")
                DispatchQueue.main.async {
                    self.translateSelection()
                }
                
            case .analyzeImage:
                print("[HotkeyManager] 🔥 Carbon Hotkey: Analyze")
                DispatchQueue.main.async {
                    self.analyzeClipboardImage()
                }
            }
        }
        
        return noErr
    }
    
    // MARK: - Features
    
    private func translateSelection() {
        // Simulating keys requires Accessibility permissions
        if !checkAccessibilityPermission() {
            print("[HotkeyManager] ❌ Missing Accessibility permissions for Translate")
            requestAccessibilityPermission()
            return
        }
    
        print("[HotkeyManager] ⌨️ Simulating Cmd+C...")
        simulateCopy()
        
        // Wait longer for clipboard to update (0.1s might be too short if system is busy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                print("[HotkeyManager] ✅ Text copied: \(text.prefix(20))...")
                let targetLang = text.range(of: "\\p{Han}", options: .regularExpression) != nil ? "English" : "Chinese"
                NotificationCenter.default.post(
                    name: .hotkeyTranslate,
                    object: nil,
                    userInfo: ["text": text, "targetLang": targetLang]
                )
            } else {
                print("[HotkeyManager] ⚠️ No text found in clipboard after copy")
            }
        }
    }
    
    // ... existing analyzeClipboardImage code ...
    
    private func analyzeClipboardImage() {
        let pasteboard = NSPasteboard.general
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
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
    
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // C key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
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
        // Unregister hotkeys would go here if needed
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let hotkeyOpenChat = Notification.Name("hotkeyOpenChat")
    static let hotkeyTranslate = Notification.Name("hotkeyTranslate")
    static let hotkeyAnalyzeImage = Notification.Name("hotkeyAnalyzeImage")
}

