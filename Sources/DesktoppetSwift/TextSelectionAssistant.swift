import AppKit
import ApplicationServices

/// 划词助手 - 使用剪贴板方式实现，无需辅助功能权限
/// 工作流程：用户选中文本 → Cmd+C 复制 → Cmd+Shift+S 触发工具栏
class TextSelectionAssistant {
    static let shared = TextSelectionAssistant()
    
    /// 是否已启用
    private(set) var isEnabled = false
    
    /// 上一次处理的文本（用于去重）
    private var lastProcessedText: String = ""
    
    /// 最小文本长度
    private let minTextLength = 2
    
    private init() {}
    
    // MARK: - Enable/Disable
    
    /// 启用划词助手
    func enable() {
        isEnabled = true
        print("[TextSelectionAssistant] ✅ Enabled (clipboard mode)")
    }
    
    /// 禁用划词助手
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
        // 剪贴板方式不需要辅助功能权限，始终返回 true
        return true
    }
    
    func checkAccessibilityPermission() -> Bool {
        // 剪贴板方式不需要辅助功能权限，始终返回 true
        return true
    }
    
    // MARK: - Clipboard-based Trigger
    
    /// 从剪贴板获取文本并触发工具栏（主要触发方式）
    func triggerFromClipboard() {
        guard isEnabled else {
            print("[TextSelectionAssistant] Not enabled, ignoring trigger")
            return
        }
        
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            print("[TextSelectionAssistant] Clipboard is empty")
            // 显示提示
            showTip("请先选中文字并按 Cmd+C 复制")
            return
        }
        
        // 检查长度
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= minTextLength else {
            print("[TextSelectionAssistant] Text too short")
            return
        }
        
        // 获取鼠标位置用于定位工具栏
        let mouseLocation = NSEvent.mouseLocation
        
        print("[TextSelectionAssistant] Triggering toolbar with: '\(trimmedText.prefix(30))...'")
        
        // 发送通知显示工具栏
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
    
    /// 显示提示信息
    private func showTip(_ message: String) {
        DispatchQueue.main.async {
            ChatState.shared.chatMessage = message
            ChatState.shared.showChatBubble = true
            ChatState.shared.isLoading = false
            
            // 3秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                ChatState.shared.showChatBubble = false
            }
        }
    }
    
    /// 清除上次处理的文本记录
    func clearLastSelection() {
        lastProcessedText = ""
    }
    
    // MARK: - Get Selected Text (Fallback - requires accessibility)
    
    /// 尝试使用 Accessibility API 获取当前选中的文本
    /// 仅作为备选方案，主要使用剪贴板方式
    func getSelectedText() -> String? {
        // 首先检查是否有辅助功能权限
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
    /// 显示划词工具栏
    static let showSelectionToolbar = Notification.Name("showSelectionToolbar")
    
    /// 划词动作触发（翻译、解释、总结等）
    static let selectionAction = Notification.Name("selectionAction")
}

// MARK: - Selection Action Types

/// 划词助手支持的操作类型
enum SelectionActionType: String, CaseIterable {
    case translate = "translate"
    case explain = "explain"
    case summarize = "summarize"
    case search = "search"
    
    var title: String {
        switch self {
        case .translate: return "翻译"
        case .explain: return "解释"
        case .summarize: return "总结"
        case .search: return "搜索"
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
