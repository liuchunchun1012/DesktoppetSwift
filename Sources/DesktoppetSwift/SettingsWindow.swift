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
        
        newWindow.title = "设置"
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
        case .ai: return "AI 设置"
        case .prompts: return "系统提示词"
        case .appearance: return "外观"
        case .tools: return "工具"
        case .hotkeys: return "快捷键"
        case .notion: return "Notion 同步"
        case .obsidian: return "Obsidian 同步"
        case .about: return "关于"
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
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    // 提供商选择
                    Section {
                        Picker("AI 提供商", selection: $settings.currentProvider) {
                            ForEach(AIProviderType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .onChange(of: settings.currentProvider) { newValue in
                            loadProviderConfig(for: newValue)
                            connectionStatus = .unknown
                        }
                    }
            
            Divider()
            
            // API Key 输入（除 Ollama 外）
            if settings.currentProvider.requiresAPIKey {
                Section {
                    SecureField("API Key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    
                    if settings.currentProvider == .custom {
                        TextField("Base URL", text: $baseURLInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            // 模型选择
            Section {
                if settings.currentProvider == .ollama {
                    Picker("模型", selection: $selectedModel) {
                        if ollamaModels.isEmpty {
                            Text("正在加载...").tag("")
                        } else {
                            ForEach(ollamaModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                    .onAppear {
                        loadOllamaModels()
                    }

                    Button("刷新模型列表") {
                        loadOllamaModels()
                    }
                } else {
                    Picker("模型", selection: $selectedModel) {
                        ForEach(settings.currentProvider.recommendedModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    TextField("或输入自定义模型名", text: $selectedModel)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            // 高级设置 (可折叠)
            Section {
                DisclosureGroup("高级设置", isExpanded: $showAdvancedSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 联网搜索开关
                        Toggle("启用联网搜索", isOn: $enableWebSearch)
                            .help("允许 AI 搜索互联网获取最新信息（需模型支持）")

                        Divider()

                        // Max Tokens
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("最大输出长度")
                                Spacer()
                                TextField("", value: $maxTokens, format: .number)
                                    .frame(width: 80)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Text("控制生成文本的最大长度，建议：\(settings.currentProvider.defaultMaxTokens)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Temperature
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Temperature: \(String(format: "%.2f", temperature))")
                                Spacer()
                            }
                            Slider(value: $temperature, in: 0...2, step: 0.05)
                            Text("控制生成的随机性。越低越确定，越高越创造性（0-2）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Top P
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Top P: \(String(format: "%.2f", topP))")
                                Spacer()
                            }
                            Slider(value: $topP, in: 0...1, step: 0.05)
                            Text("核采样参数，控制生成的多样性（0-1）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                    }
                    .padding(.top, 8)
                }
            }

            Divider()
            
            // 操作按钮
            HStack {
                Button("保存配置") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                
                Button("测试连接") {
                    testConnection()
                }
                .disabled(connectionStatus == .testing)
                
                Spacer()
                
                // 连接状态指示
                switch connectionStatus {
                case .unknown:
                    EmptyView()
                case .testing:
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("测试中...")
                        .foregroundColor(.secondary)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("连接成功")
                        .foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("连接失败")
                        .foregroundColor(.red)
                }
            }
                }
            }
        }
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
            connectionStatus = success ? .success : .failed
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
                Toggle("使用自定义精灵图", isOn: $settings.useCustomSprites)
                
                if settings.useCustomSprites {
                    HStack {
                        TextField("精灵图文件夹路径", text: $settings.customSpritesPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("选择...") {
                            selectSpritesFolder()
                        }
                    }
                    
                    Text("文件夹结构要求：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  idle/ - 待机动画（frame_01.png, frame_02.png...）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  walk/left/, walk/right/ - 行走动画")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("  rest/sleeping/ - 睡觉动画")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                Button("恢复默认精灵图") {
                    settings.useCustomSprites = false
                    settings.customSpritesPath = ""
                }
            }
            
            Spacer()
            
            Text("提示：修改精灵图后需要重启应用生效")
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
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Text("宠物信息")
                            .font(.headline)

                        Text("自定义你的桌面宠物身份信息")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("宠物全名:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("例如：小猫咪", text: $settings.petName)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("宠物小名:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("例如：咪咪", text: $settings.petNickname)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("主人名称:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("例如：主人", text: $settings.ownerName)
                                .textFieldStyle(.roundedBorder)
                        }

                        Text("这些信息会在聊天窗口标题和提示词中使用")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Divider()

                    Section {
                        Text("系统提示词配置")
                            .font(.headline)

                        Text("这些提示词对所有 AI 提供商通用。支持占位符：")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("• {petName} - 宠物全名")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("• {petNickname} - 宠物小名")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("• {ownerName} - 主人名称")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Divider()

            // 文本对话提示词
            Section {
                HStack {
                    Text("文本对话提示词")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Button("恢复默认") {
                        settings.customChatPrompt = PetConfig.systemPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                TextEditor(text: $settings.customChatPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Text("提示词已设置（\(settings.customChatPrompt.count) 字符）- 可使用 {petName}, {petNickname}, {ownerName} 占位符")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Divider()

            // 图片分析提示词
            Section {
                HStack {
                    Text("图片分析提示词")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Button("恢复默认") {
                        settings.customImagePrompt = PetConfig.imageAnalysisPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                TextEditor(text: $settings.customImagePrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Text("提示词已设置（\(settings.customImagePrompt.count) 字符）- 可使用 {petName}, {petNickname}, {ownerName} 占位符")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Spacer()
                }
                .padding()
            }
        }
    }
}

// MARK: - Tools Settings Tab

struct ToolsSettingsTab: View {
    @StateObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            // MARK: - 翻译设置
            Section {
                Text("翻译设置")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("翻译目标语言")
                        .font(.subheadline)
                    
                    Picker("", selection: $settings.translationLanguage) {
                        ForEach(TranslationLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("使用方法：")
                        .font(.subheadline)
                        .bold()
                    Text("1. 复制要翻译的文字")
                        .foregroundColor(.secondary)
                    Text("2. 使用翻译快捷键触发")
                        .foregroundColor(.secondary)
                    Text("3. 翻译结果显示在气泡中")
                        .foregroundColor(.secondary)
                }
            }

            Divider()
            
            // MARK: - 划词助手设置
            Section {
                Text("划词助手")
                    .font(.headline)
                
                Toggle("启用划词助手", isOn: $settings.selectionAssistantEnabled)
                    .help("使用快捷键触发划词工具栏")
                
                if settings.selectionAssistantEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已启用")
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("使用方法：")
                                .font(.subheadline)
                                .bold()
                            Text("1. 选中任意文字并复制")
                                .foregroundColor(.secondary)
                            Text("2. 使用划词快捷键触发工具栏")
                                .foregroundColor(.secondary)
                            Text("3. 选择操作：翻译、解释、总结、搜索")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // MARK: - 图像分析说明
            Section {
                Text("图像分析")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("使用方法：")
                        .font(.subheadline)
                        .bold()
                    Text("1. 使用截图工具截图到剪贴板")
                        .foregroundColor(.secondary)
                    Text("2. 使用图像分析快捷键触发")
                        .foregroundColor(.secondary)
                    Text("3. 在输入框中输入问题")
                        .foregroundColor(.secondary)
                    Text("4. 小猫会分析图片并回答")
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
    @State private var editingHotkey: HotkeyType?
    @State private var showingRecorder = false
    
    enum HotkeyType: String, CaseIterable {
        case chat, translate, image, selection
        
        var name: String {
            switch self {
            case .chat: return "打开对话"
            case .translate: return "翻译"
            case .image: return "图像分析"
            case .selection: return "划词工具栏"
            }
        }
        
        var description: String {
            switch self {
            case .chat: return "与小猫聊天"
            case .translate: return "翻译剪贴板中的文字"
            case .image: return "分析剪贴板中的图片"
            case .selection: return "显示翻译/解释/总结工具栏"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Text("全局快捷键")
                    .font(.headline)
                
                Text("点击快捷键可以修改")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 快捷键列表
            VStack(alignment: .leading, spacing: 16) {
                EditableHotkeyRow(
                    name: "打开对话",
                    description: "与小猫聊天",
                    config: settings.hotkeyChat,
                    onEdit: { editingHotkey = .chat; showingRecorder = true }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "翻译",
                    description: "翻译剪贴板中的文字",
                    config: settings.hotkeyTranslate,
                    onEdit: { editingHotkey = .translate; showingRecorder = true }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "图像分析",
                    description: "分析剪贴板中的图片",
                    config: settings.hotkeyImage,
                    onEdit: { editingHotkey = .image; showingRecorder = true }
                )
                
                Divider()
                
                EditableHotkeyRow(
                    name: "划词工具栏",
                    description: "显示翻译/解释/总结工具栏",
                    config: settings.hotkeySelection,
                    onEdit: { editingHotkey = .selection; showingRecorder = true }
                )
            }
            
            Divider()
            
            // 恢复默认按钮
            HStack {
                Button("恢复默认") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("提示")
                    .font(.headline)
                
                Text("• 快捷键在所有应用中全局生效")
                    .foregroundColor(.secondary)
                Text("• 先用 Cmd+C 复制内容，再使用快捷键")
                    .foregroundColor(.secondary)
                Text("• 修改后即时生效")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingRecorder) {
            HotkeyRecorderSheet(
                hotkeyType: editingHotkey ?? .chat,
                isPresented: $showingRecorder
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
            Text("设置「\(hotkeyType.name)」快捷键")
                .font(.headline)
            
            Text("请按下新的快捷键组合")
                .foregroundColor(.secondary)
            
            // 当前/录制中的快捷键显示
            HotkeyRecorderView(
                currentConfig: getCurrentConfig(),
                recordedKey: $recordedKey,
                isRecording: $isRecording
            )
            .frame(width: 150, height: 50)
            
            if isRecording {
                Text("正在录制... 按 ESC 取消")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            HStack(spacing: 16) {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
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
        let text = isRecording ? "按下快捷键..." : displayString
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
                // 功能说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("每日总结")
                        .font(.headline)
                    
                    Text("将每天的对话记录生成 AI 总结，保存到 Notion。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 开关
                Toggle("启用 Notion 同步", isOn: $settings.notionEnabled)
                
                if settings.notionEnabled {
                    // Notion Token
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Integration Token")
                            .font(.subheadline)
                        SecureField("secret_xxx...", text: $notionToken)
                            .textFieldStyle(.roundedBorder)
                        Text("在 Notion 开发者页面创建 Integration 后获取")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 日志 Database ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("日志 Database ID")
                            .font(.subheadline)
                        TextField("日志数据库 ID", text: $settings.notionDatabaseId)
                            .textFieldStyle(.roundedBorder)
                        Text("用于保存每日日志总结")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // TodoList Database ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TodoList Database ID")
                            .font(.subheadline)
                        TextField("待办数据库 ID", text: $settings.todoListDatabaseId)
                            .textFieldStyle(.roundedBorder)
                        Text("用于「记任务：」命令创建任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    HStack {
                        Button("保存配置") {
                            saveConfig()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("测试连接") {
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
                            Text("测试中...")
                                .foregroundColor(.secondary)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("连接成功")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("连接失败")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                    
                    // 今日对话统计
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日对话")
                            .font(.headline)
                        
                        Text("今天已记录 \(todayLogCount) 条对话")
                            .foregroundColor(.secondary)
                        
                        Button("生成今日总结") {
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
                // 功能说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("Obsidian 同步")
                        .font(.headline)
                    
                    Text("将聊天记录同步到 Obsidian Vault，作为知识库存档。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 开关
                Toggle("启用 Obsidian 同步", isOn: $settings.obsidianEnabled)
                
                if settings.obsidianEnabled {
                    // Vault 路径
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vault 路径")
                            .font(.subheadline)
                        
                        HStack {
                            TextField("选择 Obsidian Vault 文件夹", text: $settings.obsidianVaultPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("选择...") {
                                selectVaultFolder()
                            }
                        }
                        
                        Text("选择你的 Obsidian Vault 根目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 聊天记录文件夹
                    VStack(alignment: .leading, spacing: 4) {
                        Text("聊天记录文件夹")
                            .font(.subheadline)
                        TextField("ChatLogs", text: $settings.obsidianChatLogFolder)
                            .textFieldStyle(.roundedBorder)
                        Text("聊天记录将保存在 Vault 的这个文件夹下")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 快速保存文件夹
                    VStack(alignment: .leading, spacing: 4) {
                        Text("快速保存文件夹")
                            .font(.subheadline)
                        TextField("QuickNotes", text: $settings.obsidianQuickSaveFolder)
                            .textFieldStyle(.roundedBorder)
                        Text("气泡保存按钮将保存到这个文件夹")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    HStack {
                        Button("测试连接") {
                            testConnection()
                        }
                        .disabled(settings.obsidianVaultPath.isEmpty)
                        
                        Button("同步今日聊天") {
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
        panel.message = "选择 Obsidian Vault 文件夹"
        
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
            
            Text("版本 1.1.0")
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("由 AI 驱动的 macOS 桌面宠物")
                .foregroundColor(.secondary)

            Text("支持 Ollama、OpenAI、Claude、Gemini、Qwen 等多种 AI 服务")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("开发者：硫醇醇")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/liuchunchun1012/DesktoppetSwift")!)
                Text("·")
                    .foregroundColor(.secondary)
                Link("问题反馈", destination: URL(string: "https://github.com/liuchunchun1012/DesktoppetSwift/issues")!)
            }
            .font(.caption)
        }
        .padding()
    }
}
