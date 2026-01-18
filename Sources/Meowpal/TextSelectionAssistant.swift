import AppKit
import ApplicationServices

/// Text Selection Assistant - Clipboard based implementation, no accessibility permission needed
/// Workflow: Select text -> Cmd+C -> Cmd+Shift+S triggers toolbar
class TextSelectionAssistant {
    static let shared = TextSelectionAssistant()
    
    /// Is enabled
    private(set) var isEnabled = false
    
    /// Last processed text (for deduplication)
    private var lastProcessedText: String = ""
    
    /// Minimum text length
    private let minTextLength = 2
    
    private init() {}
    
    // MARK: - Enable/Disable
    
    /// Enable selection assistant
    func enable() {
        isEnabled = true
        print("[TextSelectionAssistant] ✅ Enabled (clipboard mode)")
    }
    
    /// Disable selection assistant
    func disable() {
        isEnabled = false
        print("[TextSelectionAssistant] Disabled")
    }
    
    // MARK: - Legacy API (for backward compatibility)
    
    func startMonitoring() {
        enable()
    }
    
    func stopMonitoring() {
        disable()
    }
    
    func isAccessibilityEnabled() -> Bool {
        // Clipboard mode needs no permission, always return true
        return true
    }
    
    func checkAccessibilityPermission() -> Bool {
        // Clipboard mode needs no permission, always return true
        return true
    }
    
    // MARK: - Clipboard-based Trigger
    
    /// Get text from clipboard and trigger toolbar (primary method)
    func triggerFromClipboard() {
        guard isEnabled else {
            print("[TextSelectionAssistant] Not enabled, ignoring trigger")
            return
        }
        
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            print("[TextSelectionAssistant] Clipboard is empty")
            // 显示提示
            showTip("Please select text and press Cmd+C to copy")
            return
        }
        
        // Check length
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= minTextLength else {
            print("[TextSelectionAssistant] Text too short")
            return
        }
        
        // Get mouse position for toolbar positioning
        let mouseLocation = NSEvent.mouseLocation
        
        print("[TextSelectionAssistant] Triggering toolbar with: '\(trimmedText.prefix(30))...'")
        
        // Post notification to show toolbar
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showSelectionToolbar,
                object: nil,
                userInfo: [
                    "text": trimmedText,
                    "position": mouseLocation
                ]
            )
        }
    }
    
    /// Show tip message
    private func showTip(_ message: String) {
        DispatchQueue.main.async {
            ChatState.shared.chatMessage = message
            ChatState.shared.showChatBubble = true
            ChatState.shared.isLoading = false
            
            // Hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                ChatState.shared.showChatBubble = false
            }
        }
    }
    
    /// Clear last processed text record
    func clearLastSelection() {
        lastProcessedText = ""
    }
    
    // MARK: - Get Selected Text (Fallback - requires accessibility)
    
    /// Try getting selected text using Accessibility API
    /// Fallback method, primary is clipboard
    func getSelectedText() -> String? {
        // First check accessibility permission
        guard AXIsProcessTrusted() else {
            return nil
        }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        
        var selectedText: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success {
            if let text = selectedText as? String, !text.isEmpty {
                return text
            }
        }
        
        return nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Show selection toolbar
    static let showSelectionToolbar = Notification.Name("showSelectionToolbar")
    
    /// Selection action triggered (translate, explain, summarize, etc)
    static let selectionAction = Notification.Name("selectionAction")
}

// MARK: - Selection Action Types

/// Supported selection action types
enum SelectionActionType: String, CaseIterable {
    case translate = "translate"
    case explain = "explain"
    case summarize = "summarize"
    case search = "search"
    
    var title: String {
        switch self {
        case .translate: return "Translate"
        case .explain: return "Explain"
        case .summarize: return "Summarize"
        case .search: return "Search"
        }
    }
    
    var icon: String {
        switch self {
        case .translate: return "character.book.closed"
        case .explain: return "questionmark.circle"
        case .summarize: return "text.alignleft"
        case .search: return "magnifyingglass"
        }
    }
}
