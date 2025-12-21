import SwiftUI
import AppKit

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
        
        newWindow.title = "⚙️ 设置"
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

/// 设置视图
struct SettingsView: View {
    @StateObject private var settings = UserSettings.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AISettingsTab()
                .tabItem {
                    Label("AI 设置", systemImage: "brain")
                }
                .tag(0)

            SystemPromptsTab()
                .tabItem {
                    Label("系统提示词", systemImage: "text.bubble")
                }
                .tag(1)

            AppearanceSettingsTab()
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }
                .tag(2)

            LanguageSettingsTab()
                .tabItem {
                    Label("语言", systemImage: "globe")
                }
                .tag(3)

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(4)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 400)
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

                        Text("💡 这些信息会在聊天窗口标题和提示词中使用")
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

// MARK: - Language Settings Tab

struct LanguageSettingsTab: View {
    @StateObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Text("翻译目标语言")
                    .font(.headline)

                Picker("翻译到", selection: $settings.translationLanguage) {
                    ForEach(TranslationLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            Section {
                Text("使用方法")
                    .font(.headline)

                Text("1. 复制要翻译的文字")
                    .foregroundColor(.secondary)
                Text("2. 按 Cmd+Shift+T 进行翻译")
                    .foregroundColor(.secondary)
                Text("3. 翻译结果将显示在宠物气泡中")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🐱")
                .font(.system(size: 60))
            
            Text("DesktoppetSwift")
                .font(.title)
                .bold()
            
            Text("版本 1.0")
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
