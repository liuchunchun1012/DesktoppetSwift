import SwiftUI
import AppKit

/// Manages the status bar (menu bar) icon and menu
class StatusBarController {
    private var statusItem: NSStatusItem!
    private var chatInputWindow: ChatInputWindow!

    // Menu items that need to be updated
    private var languageMenuItems: [TranslationLanguage: NSMenuItem] = [:]
    
    init() {
        chatInputWindow = ChatInputWindow()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to load custom template icon, fallback to SF Symbol
            if let customIcon = NSImage(named: "menubar_iconTemplate") {
                button.image = customIcon
                button.image?.isTemplate = true
            } else {
                button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Desktop Pet")
                button.image?.isTemplate = true
            }
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // AI Features
        let chatItem = NSMenuItem(title: "Chat with Me", action: #selector(openChat), keyEquivalent: "")
        chatItem.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil)
        chatItem.target = self
        menu.addItem(chatItem)
        
        let translateItem = NSMenuItem(title: "Translate", action: #selector(openTranslate), keyEquivalent: "")
        translateItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        translateItem.target = self
        menu.addItem(translateItem)
        
        // Translate target submenu
        let translateTargetMenu = NSMenu()

        // Add all supported translation languages
        for language in TranslationLanguage.allCases {
            let item = NSMenuItem(
                title: "Translate to \(language.displayName)",
                action: #selector(setTranslateLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language
            if let icon = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) {
                item.image = icon
            }
            translateTargetMenu.addItem(item)
            languageMenuItems[language] = item
        }

        let translateTargetMenuItem = NSMenuItem(title: "Target Language", action: nil, keyEquivalent: "")
        translateTargetMenuItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        translateTargetMenuItem.submenu = translateTargetMenu
        menu.addItem(translateTargetMenuItem)

        updateTranslateMenuState()
        
        menu.addItem(NSMenuItem.separator())
        
        // Daily Summary (Notion)
        let summaryItem = NSMenuItem(title: "Daily Summary", action: #selector(generateDailySummary), keyEquivalent: "")
        summaryItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        summaryItem.target = self
        menu.addItem(summaryItem)
        
        // Obsidian Sync
        let obsidianItem = NSMenuItem(title: "Sync to Obsidian", action: #selector(syncToObsidian), keyEquivalent: "")
        obsidianItem.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: nil)
        obsidianItem.target = self
        menu.addItem(obsidianItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Animation submenu
        let animMenu = NSMenu()
        animMenu.addItem(createAnimItem("Idle Grooming", action: "idle"))
        animMenu.addItem(createAnimItem("Happy Jump", action: "happy_jump"))
        animMenu.addItem(createAnimItem("Eating", action: "eating"))
        animMenu.addItem(NSMenuItem.separator())
        animMenu.addItem(createAnimItem("Rest Prepare", action: "rest_prepare"))
        animMenu.addItem(createAnimItem("Sleeping", action: "rest_sleeping"))
        animMenu.addItem(createAnimItem("Wake Up", action: "rest_wakeup"))
        animMenu.addItem(NSMenuItem.separator())
        animMenu.addItem(createAnimItem("Walk Left", action: "walk_left"))
        animMenu.addItem(createAnimItem("Walk Right", action: "walk_right"))
        animMenu.addItem(createAnimItem("Walk Up", action: "walk_up"))
        animMenu.addItem(createAnimItem("Walk Down", action: "walk_down"))
        
        let animMenuItem = NSMenuItem(title: "Switch Action", action: nil, keyEquivalent: "")
        animMenuItem.image = NSImage(systemSymbolName: "pawprint", accessibilityDescription: nil)
        animMenuItem.submenu = animMenu
        menu.addItem(animMenuItem)
        
        // Focus Mode
        let focusItem = NSMenuItem(title: "Focus Mode", action: #selector(toggleFocusMode), keyEquivalent: "")
        focusItem.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)
        focusItem.target = self
        menu.addItem(focusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func updateTranslateMenuState() {
        let currentLanguage = UserSettings.shared.translationLanguage
        for (language, menuItem) in languageMenuItems {
            menuItem.state = (language == currentLanguage) ? .on : .off
        }
    }

    @objc private func setTranslateLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? TranslationLanguage else { return }
        UserSettings.shared.translationLanguage = language
        updateTranslateMenuState()
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
    
    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }
    
    @objc private func generateDailySummary() {
        // 检查是否配置了 Notion
        guard UserSettings.shared.notionEnabled else {
            // 打开设置页面
            SettingsWindowController.shared.showSettings()
            return
        }
        
        // 检查今天是否有对话
        let logs = ChatLogManager.shared.getUnsyncedToNotion()
        guard !logs.isEmpty else {
            // 发送通知显示提示
            NotificationCenter.default.post(
                name: .dailySummaryResult,
                object: nil,
                userInfo: ["message": "No new conversations today!"]
            )
            return
        }
        
        // 生成并发送总结
        DailySummaryGenerator.shared.generateAndPost { result in
            switch result {
            case .success(let summary):
                NotificationCenter.default.post(
                    name: .dailySummaryResult,
                    object: nil,
                    userInfo: ["message": "已保存到 Notion：\(summary.title)"]
                )
            case .failure(let error):
                NotificationCenter.default.post(
                    name: .dailySummaryResult,
                    object: nil,
                    userInfo: ["message": "保存失败：\(error.localizedDescription)"]
                )
            }
        }
    }
    
    @objc private func syncToObsidian() {
        // 检查是否配置了 Obsidian
        guard UserSettings.shared.obsidianEnabled, ObsidianClient.shared.isConfigured() else {
            SettingsWindowController.shared.showSettings()
            return
        }
        
        ObsidianClient.shared.syncTodayChatLogs { result in
            switch result {
            case .success(let fileName):
                NotificationCenter.default.post(
                    name: .dailySummaryResult,
                    object: nil,
                    userInfo: ["message": "已同步到 Obsidian：\(fileName)"]
                )
            case .failure(let error):
                NotificationCenter.default.post(
                    name: .dailySummaryResult,
                    object: nil,
                    userInfo: ["message": "同步失败：\(error.localizedDescription)"]
                )
            }
        }
    }
    
    @objc private func toggleFocusMode() {
        NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
    }
}

// Notification names
extension Notification.Name {
    static let setAnimation = Notification.Name("setAnimation")
    static let openChatInput = Notification.Name("openChatInput")
    static let dailySummaryResult = Notification.Name("dailySummaryResult")
    static let toggleFocusMode = Notification.Name("toggleFocusMode")
}

// Input mode enum (shared)
enum InputMode: String {
    case chat = "chat"
    case translate = "translate"
    case imageQuestion = "imageQuestion"
}


