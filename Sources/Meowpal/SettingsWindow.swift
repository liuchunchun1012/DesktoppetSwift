import SwiftUI
import AppKit
import Carbon

/// 设置窗口控制器
class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    func showSettings() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Settings"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        
        // 关闭时清理引用
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// 设置视图 - 侧边栏导航风格
struct SettingsView: View {
    @StateObject private var settings = UserSettings.shared
    @State private var selectedSection: SettingsSection = .ai
    
    var body: some View {
        HSplitView {
            // 侧边栏
            VStack(spacing: 0) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selectedSection == section,
                        action: { selectedSection = section }
                    )
                }
                Spacer()
            }
            .frame(width: 160)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            // 详情区域
            ScrollView {
                detailView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 450)
    }
    
    // 详情视图
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .ai:
            AISettingsTab()
        case .prompts:
            SystemPromptsTab()
        case .appearance:
            AppearanceSettingsTab()
        case .tools:
            ToolsSettingsTab()
        case .hotkeys:
            HotkeysSettingsTab()
        case .notion:
            NotionSettingsTab()
        case .obsidian:
            ObsidianSettingsTab()
        case .about:
            AboutTab()
        }
    }
}

/// 侧边栏项目
struct SidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: section.icon)
                .frame(width: 20)
            Text(section.title)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : (isHovered ? Color.gray.opacity(0.15) : Color.clear))
        )
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
}

/// 设置区域枚举
enum SettingsSection: String, CaseIterable {
    case ai
    case prompts
    case appearance
    case tools
    case hotkeys
    case notion
    case obsidian
    case about
    
    var title: String {
        switch self {
        case .ai: return "AI Settings"
        case .prompts: return "System Prompts"
        case .appearance: return "Appearance"
        case .tools: return "Tools"
        case .hotkeys: return "Hotkeys"
        case .notion: return "Notion Sync"
        case .obsidian: return "Obsidian Sync"
        case .about: return "About"
        }
    }
    
    var icon: String {
        switch self {
        case .ai: return "brain"
        case .prompts: return "text.bubble"
        case .appearance: return "paintbrush"
        case .tools: return "hammer"
        case .hotkeys: return "keyboard"
        case .notion: return "doc.text"
        case .obsidian: return "note.text"
        case .about: return "info.circle"
        }
    }
}

// MARK: - AI Settings Tab

struct AISettingsTab: View {
    @StateObject private var settings = UserSettings.shared
    @State private var apiKeyInput = ""
    @State private var baseURLInput = ""
    @State private var selectedModel = ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var ollamaModels: [String] = []

    // 新增的高级设置项
    @State private var enableWebSearch = true
    @State private var maxTokens = 8192
    @State private var temperature = 1.0
    @State private var topP = 0.95
    @State private var showAdvancedSettings = false

    enum ConnectionStatus {
        case unknown, testing, success, failed
    }
    
    var body: some View {
        Form {
            // Provider Selection
            Picker("Provider", selection: $settings.currentProvider) {
                ForEach(AIProviderType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .onChange(of: settings.currentProvider) { newValue in
                loadProviderConfig(for: newValue)
                connectionStatus = .unknown
            }
            
            // API Key Input
            if settings.currentProvider.requiresAPIKey {
                SecureField("API Key", text: $apiKeyInput)
                
                if settings.currentProvider == .custom {
                    TextField("Base URL", text: $baseURLInput)
                }
            }
            
            // Model Selection
            if settings.currentProvider == .ollama {
                Picker("Model", selection: $selectedModel) {
                    if ollamaModels.isEmpty {
                        Text("Loading...").tag("")
                    } else {
                        ForEach(ollamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                .onAppear { loadOllamaModels() }

                Button("Refresh Models") { loadOllamaModels() }
            } else {
                Picker("Model", selection: $selectedModel) {
                    ForEach(settings.currentProvider.recommendedModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Text("Or enter custom model name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $selectedModel)
            }

            Divider()

            // Advanced Settings
            DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedSettings) {
                Group {
                    Toggle("Enable Web Search", isOn: $enableWebSearch)
                    
                    TextField("Max Tokens", value: $maxTokens, format: .number)
                    Text("Recommended: \(settings.currentProvider.defaultMaxTokens)")
                        .font(.caption).foregroundColor(.secondary)
                    
                    VStack(alignment: .leading) {
                        Text("Temperature: \(String(format: "%.2f", temperature))")
                        Slider(value: $temperature, in: 0...2, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Top P: \(String(format: "%.2f", topP))")
                        Slider(value: $topP, in: 0...1, step: 0.05)
                    }
                }
            }

            Divider()
            
            // Actions
            HStack {
                Button("Save") { saveConfig() }
                    .buttonStyle(.borderedProminent)
                
                Button("Test") { testConnection() }
                    .disabled(connectionStatus == .testing)
                
                Spacer()
                
                switch connectionStatus {
                case .unknown: EmptyView()
                case .testing:
                    ProgressView().scaleEffect(0.7)
                    Text("Testing...")
                case .success:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("OK").foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text("Failed").foregroundColor(.red)
                }
            }
        }
        .padding()
        .onAppear {
            loadProviderConfig(for: settings.currentProvider)
        }
    }

    private func loadProviderConfig(for type: AIProviderType) {
        let config = settings.getConfig(for: type)
        selectedModel = config.model
        baseURLInput = config.baseURL

        // 加载高级设置
        enableWebSearch = config.enableWebSearch
        maxTokens = config.maxTokens
        temperature = config.temperature
        topP = config.topP

        // 从 Keychain 加载 API Key
        if type.requiresAPIKey {
            apiKeyInput = KeychainHelper.shared.getAPIKey(for: type) ?? ""
        }

        if type == .ollama {
            loadOllamaModels()
        }
    }
    
    private func loadOllamaModels() {
        AIProviderManager.shared.getInstalledOllamaModels { models in
            self.ollamaModels = models
            if !models.isEmpty && selectedModel.isEmpty {
                selectedModel = models.first ?? ""
            }
        }
    }
    
    private func saveConfig() {
        let type = settings.currentProvider

        // 只有当 API Key 真正变化时才保存到 Keychain
        if type.requiresAPIKey && !apiKeyInput.isEmpty {
            let existingKey = KeychainHelper.shared.getAPIKey(for: type) ?? ""
            if apiKeyInput != existingKey {
                try? KeychainHelper.shared.saveAPIKey(apiKeyInput, for: type)
                print("[Settings] API Key updated in Keychain")
            }
        }

        // 更新配置
        var config = settings.getConfig(for: type)
        config.model = selectedModel
        if type == .custom {
            config.baseURL = baseURLInput
        }

        // 保存高级设置
        config.enableWebSearch = enableWebSearch
        config.maxTokens = maxTokens
        config.temperature = temperature
        config.topP = topP

        settings.updateConfig(config)

        // 刷新当前提供商
        AIProviderManager.shared.refreshCurrentProvider()

        print("[Settings] Configuration saved for \(type.displayName)")
        print("[Settings] Advanced settings - WebSearch: \(enableWebSearch), MaxTokens: \(maxTokens), Temp: \(temperature), TopP: \(topP)")
    }
    
    private func testConnection() {
        connectionStatus = .testing
        saveConfig()  // 先保存配置
        
        AIProviderManager.shared.testConnection(for: settings.currentProvider) { success in
            self.connectionStatus = success ? .success : .failed
        }
    }
}

// MARK: - Appearance Settings Tab

struct AppearanceSettingsTab: View {
    @StateObject private var settings = UserSettings.shared
    @State private var showFilePicker = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Use Custom Sprites", isOn: $settings.useCustomSprites)
                
                if settings.useCustomSprites {
                    HStack {
                        TextField("Sprites Folder Path", text: $settings.customSpritesPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectSpritesFolder()
                        }
                    }
                    
                    Text("Folder structure requirements:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  idle/ - idle animations (frame_01.png, frame_02.png...)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  walk/left/, walk/right/ - walking animations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  rest/sleeping/ - sleeping animations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                Button("Restore Default Sprites") {
                    settings.useCustomSprites = false
                    settings.customSpritesPath = ""
                }
            }
            
            Spacer()
            
            Text("Note: Restart required after changing sprites")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func selectSpritesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择包含精灵图的文件夹"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.customSpritesPath = url.path
        }
    }
}

// MARK: - System Prompts Tab

struct SystemPromptsTab: View {
    @StateObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Pet Information")
                    .font(.headline)

                Text("Customize your desktop pet identity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    TextField("Pet Name:", text: $settings.petName)
                    TextField("Nickname:", text: $settings.petNickname)
                    TextField("Owner:", text: $settings.ownerName)
                }
                .textFieldStyle(.roundedBorder)

                Text("This information is used in chat titles and prompts")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Divider()

            Section {
                Text("System Prompt Configuration")
                    .font(.headline)

                Text("These prompts apply to all AI providers. Supports placeholders:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("• {petName} - Pet full name").font(.caption).foregroundColor(.blue)
                    Text("• {petNickname} - Pet nickname").font(.caption).foregroundColor(.blue)
                    Text("• {ownerName} - Owner name").font(.caption).foregroundColor(.blue)
                }
            }

            Divider()

            // Chat Prompt
            Section {
                HStack {
                    Text("Chat Prompt")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Button("Restore Default") {
                        settings.customChatPrompt = PetConfig.systemPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                TextEditor(text: $settings.customChatPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Text("Prompt set (\(settings.customChatPrompt.count) chars) - Supports {petName}, {petNickname}, {ownerName} placeholders")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Divider()

            // Image Analysis Prompt
            Section {
                HStack {
                    Text("Image Analysis Prompt")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Button("Restore Default") {
                        settings.customImagePrompt = PetConfig.imageAnalysisPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                TextEditor(text: $settings.customImagePrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Text("Prompt set (\(settings.customImagePrompt.count) chars) - Supports {petName}, {petNickname}, {ownerName} placeholders")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

// MARK: - Tools Settings Tab

struct ToolsSettingsTab: View {
    @StateObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            // MARK: - 翻译设置
            Section {
                Text("Translation Settings")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Language")
                        .font(.subheadline)
                    
                    Picker("Target Language", selection: $settings.translationLanguage) {
                        ForEach(TranslationLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to use:")
                        .font(.subheadline)
                        .bold()
                    Text("1. Copy the text you want to translate")
                        .foregroundColor(.secondary)
                    Text("2. Use the translate hotkey")
                        .foregroundColor(.secondary)
                    Text("3. Translation appears in chat bubble")
                        .foregroundColor(.secondary)
                }
            }

            Divider()
            
            // MARK: - 划词助手设置
            Section {
                Text("Selection Assistant")
                    .font(.headline)
                
                Toggle("Enable Selection Assistant", isOn: $settings.selectionAssistantEnabled)
                    .help("Use hotkey to trigger selection toolbar")
                
                if settings.selectionAssistantEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Enabled")
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to use:")
                                .font(.subheadline)
                                .bold()
                            Text("1. Select any text and copy it")
                                .foregroundColor(.secondary)
                            Text("2. Use selection assistant hotkey")
                                .foregroundColor(.secondary)
                            Text("3. Choose: Translate, Explain, Summarize, Search")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // MARK: - 图像分析说明
            Section {
                Text("Image Analysis")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to use:")
                        .font(.subheadline)
                        .bold()
                    Text("1. Take a screenshot to clipboard")
                        .foregroundColor(.secondary)
                    Text("2. Use image analysis hotkey")
                        .foregroundColor(.secondary)
                    Text("3. Enter your question")
                        .foregroundColor(.secondary)
                    Text("4. Your pet will analyze and answer")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Hotkeys Settings Tab

struct HotkeysSettingsTab: View {
    @StateObject private var settings = UserSettings.shared
    @State private var editingHotkey: HotkeyType? = nil
    
    enum HotkeyType: String, CaseIterable, Identifiable {
        case chat, translate, image, selection
        
        var id: String { rawValue }
        
        var name: String {
            switch self {
            case .chat: return "Open Chat"
            case .translate: return "Translate"
            case .image: return "Image Analysis"
            case .selection: return "Selection Toolbar"
            }
        }
        
        var description: String {
            switch self {
            case .chat: return "Chat with your pet"
            case .translate: return "Translate clipboard text"
            case .image: return "Analyze clipboard image"
            case .selection: return "Show translate/explain/summarize toolbar"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Text("Global Hotkeys")
                    .font(.headline)
                
                Text("Click a hotkey to modify")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 快捷键列表
            VStack(alignment: .leading, spacing: 16) {
                EditableHotkeyRow(
                    name: "Open Chat",
                    description: "Chat with your pet",
                    config: settings.hotkeyChat,
                    onEdit: { editingHotkey = .chat }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "Translate",
                    description: "Translate clipboard text",
                    config: settings.hotkeyTranslate,
                    onEdit: { editingHotkey = .translate }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "Image Analysis",
                    description: "Analyze clipboard image",
                    config: settings.hotkeyImage,
                    onEdit: { editingHotkey = .image }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "Selection Toolbar",
                    description: "Show translate/explain/summarize toolbar",
                    config: settings.hotkeySelection,
                    onEdit: { editingHotkey = .selection }
                )
            }
            
            Divider()
            
            // Restore Default
            HStack {
                Button("Restore Default") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips")
                    .font(.headline)
                
                Text("• Hotkeys work globally across all apps")
                    .foregroundColor(.secondary)
                Text("• Copy content with Cmd+C first, then use hotkey")
                    .foregroundColor(.secondary)
                Text("• Changes take effect immediately")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .sheet(item: $editingHotkey) { hotkeyType in
            HotkeyRecorderSheet(
                hotkeyType: hotkeyType,
                isPresented: Binding(
                    get: { editingHotkey != nil },
                    set: { if !$0 { editingHotkey = nil } }
                )
            )
        }
    }
    
    private func resetToDefaults() {
        settings.hotkeyChat = .defaultChat
        settings.hotkeyTranslate = .defaultTranslate
        settings.hotkeyImage = .defaultImage
        settings.hotkeySelection = .defaultSelection
        HotkeyManager.shared.reregisterHotkeys()
    }
}

/// 可编辑的快捷键行
struct EditableHotkeyRow: View {
    let name: String
    let description: String
    let config: HotkeyConfig
    let onEdit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 快捷键按钮（可点击编辑）
            Button(action: onEdit) {
                Text(config.displayString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isHovered ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}

/// 快捷键录制弹窗
struct HotkeyRecorderSheet: View {
    let hotkeyType: HotkeysSettingsTab.HotkeyType
    @Binding var isPresented: Bool
    @StateObject private var settings = UserSettings.shared
    @State private var recordedKey: HotkeyConfig?
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set '\(hotkeyType.name)' Hotkey")
                .font(.headline)
            
            Text("Press new key combination")
                .foregroundColor(.secondary)
            
            // Current/Recording Display
            HotkeyRecorderView(
                currentConfig: getCurrentConfig(),
                recordedKey: $recordedKey,
                isRecording: $isRecording
            )
            .frame(width: 150, height: 50)
            
            if isRecording {
                Text("Recording... Press ESC to cancel")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    if let key = recordedKey {
                        saveHotkey(key)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedKey == nil)
            }
        }
        .padding(30)
        .frame(width: 300)
    }
    
    private func getCurrentConfig() -> HotkeyConfig {
        switch hotkeyType {
        case .chat: return settings.hotkeyChat
        case .translate: return settings.hotkeyTranslate
        case .image: return settings.hotkeyImage
        case .selection: return settings.hotkeySelection
        }
    }
    
    private func saveHotkey(_ config: HotkeyConfig) {
        switch hotkeyType {
        case .chat: settings.hotkeyChat = config
        case .translate: settings.hotkeyTranslate = config
        case .image: settings.hotkeyImage = config
        case .selection: settings.hotkeySelection = config
        }
        HotkeyManager.shared.reregisterHotkeys()
    }
}

/// 快捷键录制视图（使用 NSViewRepresentable）
struct HotkeyRecorderView: NSViewRepresentable {
    let currentConfig: HotkeyConfig
    @Binding var recordedKey: HotkeyConfig?
    @Binding var isRecording: Bool
    
    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.currentConfig = currentConfig
        view.onKeyRecorded = { config in
            recordedKey = config
            isRecording = false
        }
        view.onRecordingStateChanged = { recording in
            isRecording = recording
        }
        return view
    }
    
    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentConfig = currentConfig
    }
}

/// NSView 用于捕获键盘事件
class HotkeyRecorderNSView: NSView {
    var currentConfig: HotkeyConfig?
    var onKeyRecorded: ((HotkeyConfig) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?
    
    private var isRecording = false
    private var displayString: String {
        currentConfig?.displayString ?? "???"
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bgColor = isRecording ? NSColor.systemBlue.withAlphaComponent(0.2) : NSColor.gray.withAlphaComponent(0.2)
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        path.fill()
        
        // Draw border
        if isRecording {
            NSColor.systemBlue.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
        
        // Draw text
        let text = isRecording ? "Press keys..." : displayString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
    }
    
    override func mouseDown(with event: NSEvent) {
        isRecording = true
        onRecordingStateChanged?(true)
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        
        // ESC 取消
        if event.keyCode == 53 {
            isRecording = false
            onRecordingStateChanged?(false)
            needsDisplay = true
            return
        }
        
        // 需要修饰键
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command) || flags.contains(.control) else {
            return // 必须包含 Cmd 或 Control
        }
        
        var modifiers = 0
        if flags.contains(.command) { modifiers |= cmdKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.control) { modifiers |= controlKey }
        
        let config = HotkeyConfig(keyCode: Int(event.keyCode), modifiers: modifiers)
        currentConfig = config
        onKeyRecorded?(config)
        
        isRecording = false
        needsDisplay = true
    }
}

// MARK: - Notion Settings Tab

struct NotionSettingsTab: View {
    @StateObject private var settings = UserSettings.shared
    @State private var notionToken = ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var todayLogCount = 0
    
    enum ConnectionStatus {
        case unknown, testing, success, failed
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Summary")
                        .font(.headline)
                    
                    Text("Generate daily AI summary and save to Notion.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Toggle
                Toggle("Enable Notion Sync", isOn: $settings.notionEnabled)
                
                if settings.notionEnabled {
                    // Notion Token
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Integration Token")
                            .font(.subheadline)
                        SecureField("secret_xxx...", text: $notionToken)
                            .textFieldStyle(.roundedBorder)
                        Text("Get from Notion Developer page after creating Integration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Log Database ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log Database ID")
                            .font(.subheadline)
                        TextField("Log Database ID", text: $settings.notionDatabaseId)
                            .textFieldStyle(.roundedBorder)
                        Text("Used for saving daily log summaries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // TodoList Database ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TodoList Database ID")
                            .font(.subheadline)
                        TextField("Todo Database ID", text: $settings.todoListDatabaseId)
                            .textFieldStyle(.roundedBorder)
                        Text("Used for creating tasks via 'Task:' command")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    HStack {
                        Button("Save Config") {
                            saveConfig()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(connectionStatus == .testing)
                        
                        Spacer()
                        
                        // 状态指示
                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .testing:
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Testing...")
                                .foregroundColor(.secondary)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Connection Failed")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                    
                    // Summary Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Chats")
                            .font(.headline)
                        
                        Text("Today recorded \(todayLogCount) conversations")
                            .foregroundColor(.secondary)
                        
                        Button("Generate Summary") {
                            generateSummary()
                        }
                        .disabled(todayLogCount == 0)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadConfig()
            updateLogCount()
        }
    }
    
    private func loadConfig() {
        notionToken = KeychainHelper.shared.getNotionToken() ?? ""
    }
    
    private func saveConfig() {
        if !notionToken.isEmpty {
            try? KeychainHelper.shared.saveNotionToken(notionToken)
        }
        print("[NotionSettings] Configuration saved")
    }
    
    private func testConnection() {
        saveConfig()
        connectionStatus = .testing
        
        NotionClient.shared.testConnection { success in
            connectionStatus = success ? .success : .failed
        }
    }
    
    private func updateLogCount() {
        todayLogCount = ChatLogManager.shared.getTodayConversations().count
    }
    
    private func generateSummary() {
        connectionStatus = .testing
        
        DailySummaryGenerator.shared.generateAndPost { result in
            switch result {
            case .success:
                connectionStatus = .success
                print("[NotionSettings] Daily summary posted successfully!")
            case .failure(let error):
                connectionStatus = .failed
                print("[NotionSettings] Failed to post summary: \(error)")
            }
        }
    }
}

// MARK: - Obsidian Settings Tab

struct ObsidianSettingsTab: View {
    @StateObject private var settings = UserSettings.shared
    @State private var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle, syncing, success, failed
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Obsidian Sync")
                        .font(.headline)
                    
                    Text("Sync chat logs to Obsidian Vault as knowledge base.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Toggle
                Toggle("Enable Obsidian Sync", isOn: $settings.obsidianEnabled)
                
                if settings.obsidianEnabled {
                    // Vault Path
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vault Path")
                            .font(.subheadline)
                        
                        HStack {
                            TextField("Select Obsidian Vault Folder", text: $settings.obsidianVaultPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Browse...") {
                                selectVaultFolder()
                            }
                        }
                        
                        Text("Choose your Obsidian Vault root directory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Chat Log Folder
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat Log Folder")
                            .font(.subheadline)
                        TextField("ChatLogs", text: $settings.obsidianChatLogFolder)
                            .textFieldStyle(.roundedBorder)
                        Text("Logs will be saved in this folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Save Folder
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Save Folder")
                            .font(.subheadline)
                        TextField("QuickNotes", text: $settings.obsidianQuickSaveFolder)
                            .textFieldStyle(.roundedBorder)
                        Text("Chat bubble save button will save here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    HStack {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(settings.obsidianVaultPath.isEmpty)
                        
                        Button("Sync Today's Chat") {
                            syncToday()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(settings.obsidianVaultPath.isEmpty || syncStatus == .syncing)
                        
                        Spacer()
                        
                        switch syncStatus {
                        case .idle:
                            EmptyView()
                        case .syncing:
                            ProgressView()
                                .scaleEffect(0.7)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select Obsidian Vault Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.obsidianVaultPath = url.path
        }
    }
    
    private func testConnection() {
        syncStatus = .syncing
        
        ObsidianClient.shared.testConnection { result in
            switch result {
            case .success:
                syncStatus = .success
            case .failure:
                syncStatus = .failed
            }
        }
    }
    
    private func syncToday() {
        syncStatus = .syncing
        
        ObsidianClient.shared.syncTodayChatLogs { result in
            switch result {
            case .success(let fileName):
                syncStatus = .success
                print("[ObsidianSettings] Synced to: \(fileName)")
            case .failure(let error):
                syncStatus = .failed
                print("[ObsidianSettings] Sync failed: \(error)")
            }
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }
            
            Text("DesktoppetSwift")
                .font(.title)
                .bold()
            
            Text("Version 1.1.0")
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("AI-Powered macOS Desktop Pet")
                .foregroundColor(.secondary)

            Text("Supports Ollama, OpenAI, Claude, Gemini, Qwen, etc.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Developer: Liuchunchun")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/liuchunchun1012/DesktoppetSwift")!)
                Text("·")
                    .foregroundColor(.secondary)
                Link("Report Issue", destination: URL(string: "https://github.com/liuchunchun1012/DesktoppetSwift/issues")!)
            }
            .font(.caption)
        }
        .padding()
    }
}
