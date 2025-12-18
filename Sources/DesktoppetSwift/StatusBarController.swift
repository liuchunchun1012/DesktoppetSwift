import SwiftUI
import AppKit

/// Manages the status bar (menu bar) icon and menu
class StatusBarController {
    private var statusItem: NSStatusItem!
    private var chatInputWindow: ChatInputWindow!
    
    init() {
        chatInputWindow = ChatInputWindow()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Desktop Pet")
            button.image?.isTemplate = true
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // AI Features
        let chatItem = NSMenuItem(title: "💬 和我聊天", action: #selector(openChat), keyEquivalent: "")
        chatItem.target = self
        menu.addItem(chatItem)
        
        let translateItem = NSMenuItem(title: "🌐 翻译", action: #selector(openTranslate), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Animation submenu
        let animMenu = NSMenu()
        animMenu.addItem(createAnimItem("待机舔毛", action: "idle"))
        animMenu.addItem(createAnimItem("开心跳跃", action: "happy_jump"))
        animMenu.addItem(createAnimItem("吃猫粮", action: "eating"))
        animMenu.addItem(NSMenuItem.separator())
        animMenu.addItem(createAnimItem("准备睡觉", action: "rest_prepare"))
        animMenu.addItem(createAnimItem("睡觉中", action: "rest_sleeping"))
        animMenu.addItem(createAnimItem("起床", action: "rest_wakeup"))
        animMenu.addItem(NSMenuItem.separator())
        animMenu.addItem(createAnimItem("向左走", action: "walk_left"))
        animMenu.addItem(createAnimItem("向右走", action: "walk_right"))
        animMenu.addItem(createAnimItem("向上走", action: "walk_up"))
        animMenu.addItem(createAnimItem("向下走", action: "walk_down"))
        
        let animMenuItem = NSMenuItem(title: "🐱 切换动作", action: nil, keyEquivalent: "")
        animMenuItem.submenu = animMenu
        menu.addItem(animMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func createAnimItem(_ title: String, action: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(triggerAnimation(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action
        return item
    }
    
    @objc private func triggerAnimation(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? String {
            NotificationCenter.default.post(name: .setAnimation, object: action)
        }
    }
    
    @objc private func openChat() {
        chatInputWindow.show(mode: .chat)
    }
    
    @objc private func openTranslate() {
        chatInputWindow.show(mode: .translate)
    }
}

// Notification names
extension Notification.Name {
    static let setAnimation = Notification.Name("setAnimation")
    static let openChatInput = Notification.Name("openChatInput")
}

// Input mode enum (shared)
enum InputMode {
    case chat
    case translate
}
