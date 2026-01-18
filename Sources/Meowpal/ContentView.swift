import SwiftUI
import AppKit

/// Manages sprite animations for the desktop pet
class SpriteAnimator: ObservableObject {
    @Published var currentFrame: NSImage?
    @Published var currentAction: String = "idle"
    
    private var frames: [String: [NSImage]] = [:]
    private var animationTimer: Timer?
    private var behaviorTimer: Timer?
    private var currentFrameIndex: Int = 0
    
    // Animation speeds per action (seconds per frame)
    private var animationSpeeds: [String: TimeInterval] = [
        "idle": 0.15,
        "walk_left": 0.12,
        "walk_right": 0.12,
        "walk_up": 0.12,
        "walk_down": 0.12,
        "happy_jump": 0.1,
        "eating": 0.15,
        "rest_prepare": 0.2,
        "rest_sleeping": 0.4,  // Slower breathing animation
        "rest_wakeup": 0.2,
        "interact_belly": 0.4,
        "interact_refuse": 0.4
    ]
    
    // How many times to loop each action before auto-transition
    private var actionLoops: [String: Int] = [
        "idle": 3,
        "walk_left": 2,
        "walk_right": 2,
        "walk_up": 2,
        "walk_down": 2,
        "happy_jump": 2,
        "eating": 2,
        "rest_prepare": 1,  // Only once!
        "rest_sleeping": 20, // Loop more times for longer sleep
        "rest_wakeup": 1,   // Only once!
        "interact_belly": 2,
        "interact_refuse": 2
    ]
    
    // State flags
    private var isInRestSequence = false
    private var isHovering = false
    private var hasTriggeredHoverInteraction = false
    private var currentLoopCount = 0
    
    /// 用户手动选择动作时为 true，暂停自动循环
    private var isManualAction = false
    
    /// 专注模式 - 小猫持续睡觉
    @Published var isFocusMode = false
    
    // Actions for random cycling
    private let walkActions = ["walk_left", "walk_right", "walk_up", "walk_down"]
    
    // Track if currently chatting (to stay in idle)
    var isChatting = false
    
    init() {
        loadAllSprites()
        setAction("idle")
        startBehaviorCycle()
    }
    
    private func loadAllSprites() {
        let actions = [
            "eating": "eating",
            "happy/jump": "happy_jump",
            "idle/grooming 1-12": "idle",
            "interact/belly": "interact_belly",
            "interact/refuse": "interact_refuse",
            "rest/prepare": "rest_prepare",
            "rest/sleeping": "rest_sleeping",
            "rest/wakeup": "rest_wakeup",
            "walk/left": "walk_left",
            "walk/right": "walk_right",
            "walk/up": "walk_up",
            "walk/down": "walk_down"
        ]
        
        // Load sprites from bundle resources
        guard let resourcePath = Bundle.main.resourcePath else {
            print("⚠️ Bundle resources not found!")
            return
        }

        let sourcePath = resourcePath + "/sprites_aligned"
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            print("⚠️ Sprites not found at: \(sourcePath)")
            print("Please ensure sprites are included in the app bundle.")
            return
        }

        print("✅ Loading sprites from: \(sourcePath)")
        
        for (folderPath, actionName) in actions {
            let fullPath = "\(sourcePath)/\(folderPath)"
            if let frameImages = loadFrames(from: fullPath) {
                frames[actionName] = frameImages
                print("Loaded \(frameImages.count) frames for \(actionName)")
            }
        }
    }
    
    private func loadFrames(from folder: String) -> [NSImage]? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder) else { return nil }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: folder)
                .filter { $0.hasSuffix(".png") }
                .sorted()
            
            var images: [NSImage] = []
            for file in files {
                let path = "\(folder)/\(file)"
                if let image = NSImage(contentsOfFile: path) {
                    images.append(image)
                }
            }
            return images.isEmpty ? nil : images
        } catch {
            return nil
        }
    }
    
    func startBehaviorCycle() {
        // 专注模式或手动动作时不启动自动循环
        if isInRestSequence || isFocusMode || isManualAction { return }
        
        behaviorTimer?.invalidate()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 5...12), repeats: false) { [weak self] _ in
            guard let self = self,
                  !self.isHovering,
                  !self.isInRestSequence,
                  !self.isFocusMode,
                  !self.isManualAction else {
                self?.startBehaviorCycle()
                return
            }
            self.pickRandomBehavior()
        }
    }
    
    private func pickRandomBehavior() {
        let choice = Int.random(in: 0...10)
        
        if choice < 4 {
            setAction("idle")
            startBehaviorCycle()
        } else if choice < 8 {
            if let walkAction = walkActions.randomElement() {
                setAction(walkAction)
            }
            startBehaviorCycle()
        } else {
            playRestSequence()
        }
    }
    
    private func playRestSequence() {
        isInRestSequence = true
        currentLoopCount = 0
        setAction("rest_prepare", onComplete: { [weak self] in
            self?.currentLoopCount = 0
            self?.setAction("rest_sleeping", onComplete: { [weak self] in
                self?.currentLoopCount = 0
                self?.setAction("rest_wakeup", onComplete: { [weak self] in
                    self?.isInRestSequence = false
                    self?.setAction("idle")
                    self?.startBehaviorCycle()
                })
            })
        })
    }
    
    func onHover(_ hovering: Bool) {
        isHovering = hovering
        if isInRestSequence { return }
        
        if hovering && !hasTriggeredHoverInteraction {
            hasTriggeredHoverInteraction = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isHovering else { return }
                if Bool.random() {
                    self.setAction("interact_belly")
                } else {
                    self.setAction("interact_refuse")
                }
            }
        } else if !hovering {
            hasTriggeredHoverInteraction = false
            setAction("idle")
            startBehaviorCycle()
        }
    }
    
    func onTap() {
        print("onTap called!")
        isInRestSequence = false // Interrupt rest for happy jump

        currentLoopCount = 0
        setAction("happy_jump", onComplete: { [weak self] in
            guard let self = self else { return }
            self.setAction("idle")
            self.startBehaviorCycle()
        })
    }
    
    func setAction(_ action: String, onComplete: (() -> Void)? = nil) {
        guard frames[action] != nil else {
            if let idleFrames = frames["idle"], !idleFrames.isEmpty {
                currentAction = "idle"
                startAnimation(onComplete: nil)
            }
            return
        }
        
        currentAction = action
        currentFrameIndex = 0
        currentLoopCount = 0
        startAnimation(onComplete: onComplete)
    }
    
    private func startAnimation(onComplete: (() -> Void)?) {
        animationTimer?.invalidate()
        
        guard let actionFrames = frames[currentAction], !actionFrames.isEmpty else {
            return
        }
        
        currentFrame = actionFrames[0]
        let speed = animationSpeeds[currentAction] ?? 0.15
        let maxLoops = actionLoops[currentAction] ?? 2
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] timer in
            guard let self = self, let actionFrames = self.frames[self.currentAction] else {
                timer.invalidate()
                return
            }
            
            self.currentFrameIndex += 1
            
            // Check if we completed a loop
            if self.currentFrameIndex >= actionFrames.count {
                self.currentFrameIndex = 0
                self.currentLoopCount += 1
                
                // If we've done enough loops and there's a completion handler
                if self.currentLoopCount >= maxLoops, let complete = onComplete {
                    timer.invalidate()
                    complete()
                    return
                }
            }
            
            DispatchQueue.main.async {
                self.currentFrame = actionFrames[self.currentFrameIndex]
            }
        }
    }
    
    /// 用户手动选择动作（暂停自动循环直到动作完成）
    func setManualAction(_ action: String) {
        isManualAction = true
        behaviorTimer?.invalidate()
        
        setAction(action, onComplete: { [weak self] in
            self?.isManualAction = false
            self?.setAction("idle")
            self?.startBehaviorCycle()
        })
    }
    
    /// 进入专注模式（小猫持续睡觉）
    func enterFocusMode() {
        isFocusMode = true
        isManualAction = false
        isInRestSequence = false
        behaviorTimer?.invalidate()
        
        // 播放入睡动画后进入睡眠循环
        setAction("rest_prepare", onComplete: { [weak self] in
            self?.loopFocusSleep()
        })
    }
    
    /// 专注模式下持续循环睡眠动画
    private func loopFocusSleep() {
        guard isFocusMode else { return }
        
        setAction("rest_sleeping", onComplete: { [weak self] in
            self?.loopFocusSleep()  // 无限循环
        })
    }
    
    /// 退出专注模式
    func exitFocusMode() {
        isFocusMode = false
        
        // 播放起床动画后恢复正常
        setAction("rest_wakeup", onComplete: { [weak self] in
            self?.setAction("idle")
            self?.startBehaviorCycle()
        })
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        behaviorTimer?.invalidate()
        behaviorTimer = nil
    }
    
    deinit {
        stopAnimation()
    }
}

/// 聊天状态管理器 - 使用 ObservableObject 确保在 NSHostingView 中正确更新 UI
class ChatState: ObservableObject {
    static let shared = ChatState()
    
    @Published var showChatBubble = false
    @Published var chatMessage = ""
    @Published var isLoading = false
    @Published var isBubbleHovered = false
    
    /// 最近一次用户输入（用于保存完整对话到 Obsidian）
    var lastUserMessage = ""
    
    /// 最近一次图片的 Base64（用于保存含图片的对话）
    var lastImageBase64: String?
    
    private init() {}
}

struct ContentView: View {
    @StateObject private var animator = SpriteAnimator()
    // 使用 @ObservedObject 因为 ChatState.shared 是外部管理的单例
    @ObservedObject private var chatState = ChatState.shared
    
    // UI state
    @State private var showInputPopover = false
    @State private var inputText = ""
    @State private var inputMode: InputMode = .chat
    @State private var hideTimer: DispatchWorkItem?
    
    // Image question support
    @State private var pendingImageBase64: String?
    private let imageInputWindow = ChatInputWindow()
    
    var body: some View {
        // VStack with fixed-height sections so bubble doesn't push cat
        VStack(spacing: 0) {
            // Chat bubble area (fixed height)
            ZStack {
                if chatState.showChatBubble {
                    ChatBubbleView(
                        message: chatState.chatMessage,
                        isLoading: chatState.isLoading,
                        onHover: { hovering in
                            chatState.isBubbleHovered = hovering
                            if hovering {
                                // Cancel hide timer when hovering
                                hideTimer?.cancel()
                            } else {
                                // Auto-hide 1 second after mouse leaves
                                scheduleHideBubble(afterSeconds: 1)
                            }
                        }
                    )
                    .id(chatState.chatMessage) // 强制在消息变化时重绘 ChatBubbleView
                    .transition(.opacity)
                }
            }
            .frame(height: 90) // Bubble area height

            // Cat sprite (always at the same position)
            ZStack {
                if let frame = animator.currentFrame {
                    Image(nsImage: frame)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 100, height: 100)
                }
            }
            .frame(height: 128)
            .onHover { hovering in
                // Only trigger cat interaction when hovering over cat area
                animator.onHover(hovering)
            }
        }
        .frame(width: 300, height: 220) // Total window size
        .contextMenu {
                // AI Features
                Button("Chat with Me") {
                    inputMode = .chat
                    showInputPopover = true
                }
                Button("Translate") {
                    inputMode = .translate
                    showInputPopover = true
                }
                Divider()
                
                // Notion & Obsidian
                Button("Daily Summary") {
                    DailySummaryGenerator.shared.generateAndPost { _ in }
                }
                Button("Sync to Obsidian") {
                    ObsidianClient.shared.syncTodayChatLogs { _ in }
                }
                Divider()
                
                // Animation controls - all in submenu
                Menu("Switch Action") {
                    Button("Idle Grooming") { animator.setManualAction("idle") }
                    Button("Happy Jump") { animator.setManualAction("happy_jump") }
                    Button("Eating") { animator.setManualAction("eating") }
                    Divider()
                    Button("Rest Prepare") { animator.setManualAction("rest_prepare") }
                    Button("Sleeping") { animator.setManualAction("rest_sleeping") }
                    Button("Wake Up") { animator.setManualAction("rest_wakeup") }
                    Divider()
                    Button("Walk Left") { animator.setManualAction("walk_left") }
                    Button("Walk Right") { animator.setManualAction("walk_right") }
                    Button("Walk Up") { animator.setManualAction("walk_up") }
                    Button("Walk Down") { animator.setManualAction("walk_down") }
                }
                
                Divider()
                Button("Settings...") {
                    SettingsWindowController.shared.showSettings()
                }
        }
        .popover(isPresented: $showInputPopover) {
            ChatInputView(
                isPresented: $showInputPopover,
                inputText: $inputText,
                placeholder: inputMode == .chat ? "Type something..." : "Enter text to translate...",
                onSubmit: { text in
                    handleInput(text)
                }
            )
        }
        .animation(.easeInOut(duration: 0.3), value: chatState.showChatBubble)
        // Listen for menu bar commands
        .onReceive(NotificationCenter.default.publisher(for: .setAnimation)) { notification in
            if let action = notification.object as? String {
                animator.setAction(action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChatInput)) { notification in
            if let mode = notification.object as? InputMode {
                inputMode = mode
                showInputPopover = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatInputSubmitted)) { notification in
            if let userInfo = notification.userInfo,
               let text = userInfo["text"] as? String,
               let modeString = userInfo["mode"] as? String {
                // Handle chat and translate modes (imageQuestion is handled by second handler)
                if modeString == InputMode.chat.rawValue {
                    inputMode = .chat
                    handleInput(text)
                } else if modeString == InputMode.translate.rawValue {
                    inputMode = .translate
                    handleInput(text)
                }
            }
        }
        // Listen for pet clicks (from PassthroughView)
        .onReceive(NotificationCenter.default.publisher(for: .petClicked)) { _ in
            // Jump anytime except while loading a response
            if !chatState.isLoading {
                animator.onTap()
            }
        }
        // Listen for bubble close (from PassthroughView)
        .onReceive(NotificationCenter.default.publisher(for: .bubbleClose)) { _ in
            withAnimation {
                chatState.showChatBubble = false
            }
            hideTimer?.cancel()
        }
        // MARK: - Hotkey handlers
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyOpenChat)) { _ in
            inputMode = .chat
            showInputPopover = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyTranslate)) { notification in
            if let userInfo = notification.userInfo,
               let text = userInfo["text"] as? String {
                handleTranslate(text: text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyAnalyzeImage)) { notification in
            if let userInfo = notification.userInfo {
                if let error = userInfo["error"] as? String {
                    // Show error message
                    chatState.showChatBubble = true
                    chatState.chatMessage = error
                    scheduleHideBubble(afterSeconds: 5)
                } else if let imageBase64 = userInfo["imageBase64"] as? String {
                    // Store image and open input window for question
                    pendingImageBase64 = imageBase64
                    imageInputWindow.show(mode: .imageQuestion, imageBase64: imageBase64)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatInputSubmitted)) { notification in
            print("[ContentView] Received chatInputSubmitted notification")
            if let userInfo = notification.userInfo,
               let text = userInfo["text"] as? String,
               let modeString = userInfo["mode"] as? String {
                print("[ContentView] mode: \(modeString), text: \(text)")
                if modeString == InputMode.imageQuestion.rawValue,
                   let imageBase64 = pendingImageBase64 {
                    print("[ContentView] Calling handleImageAnalysis with question: \(text)")
                    handleImageAnalysis(imageBase64: imageBase64, question: text)
                    pendingImageBase64 = nil  // Clear after use
                }
            }
        }
        // MARK: - Selection Toolbar Actions
        .onReceive(NotificationCenter.default.publisher(for: .selectionAction)) { notification in
            if let userInfo = notification.userInfo,
               let actionStr = userInfo["action"] as? String,
               let text = userInfo["text"] as? String {
                handleSelectionAction(actionStr, text: text)
            }
        }
        // Focus Mode Toggle Notification
        .onReceive(NotificationCenter.default.publisher(for: .toggleFocusMode)) { _ in
            if animator.isFocusMode {
                animator.exitFocusMode()
            } else {
                animator.enterFocusMode()
            }
        }
    }
    
    private func handleInput(_ text: String) {
        print("[ContentView] handleInput called with: \(text)")
        chatState.showChatBubble = true
        chatState.isLoading = true
        chatState.chatMessage = ""
        chatState.lastUserMessage = text  // 记录用户输入用于保存完整对话
        chatState.lastImageBase64 = nil   // 清除之前的图片缓存
        
        // Cancel any existing hide timer
        hideTimer?.cancel()
        
        // Stay in idle while thinking
        animator.setAction("idle")
        
        switch inputMode {
        case .chat:
            // 使用 AIProviderManager 支持多模型
            print("[ContentView] Calling AIProviderManager.chatStream")
            AIProviderManager.shared.chatStream(
                message: text,
                onUpdate: { partialResponse in
                    // Real-time streaming update
                    print("[ContentView] onUpdate received: \(partialResponse.prefix(50))...")
                    self.chatState.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.chatState.isLoading = false
                },
                onComplete: { result in
                    print("[ContentView] onComplete received")
                    switch result {
                    case .success(let response):
                        print("[ContentView] Success: \(response.prefix(50))...")
                        self.chatState.chatMessage = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    case .failure(let error):
                        print("[ContentView] Error: \(error)")
                        self.chatState.chatMessage = "喵呜... 出错了: \(error.localizedDescription)"
                    }
                    self.scheduleHideBubble(afterSeconds: 8)
                }
            )
            
        case .translate:
            // AIProviderManager.translateStream 从 UserSettings 获取目标语言
            AIProviderManager.shared.translateStream(
                text: text,
                onUpdate: { partialResponse in
                    self.chatState.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.chatState.isLoading = false
                },
                onComplete: { result in
                    switch result {
                    case .success(let translation):
                        self.chatState.chatMessage = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                    case .failure(let error):
                        self.chatState.chatMessage = "翻译失败: \(error.localizedDescription)"
                    }
                    self.scheduleHideBubble(afterSeconds: 15) // Longer for translation
                }
            )
        
        case .imageQuestion:
            // Image questions are handled via chatInputSubmitted notification, not here
            break
        }
    }
    
    private func scheduleHideBubble(afterSeconds: Double) {
        hideTimer?.cancel()
        
        let timer = DispatchWorkItem { [self] in
            // Only hide if not currently hovering
            if !self.chatState.isBubbleHovered {
                withAnimation {
                    self.chatState.showChatBubble = false
                }
                // Resume normal behavior cycle
                self.animator.startBehaviorCycle()
            } else {
                // Reschedule if still hovering
                self.scheduleHideBubble(afterSeconds: 3)
            }
        }
        
        hideTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + afterSeconds, execute: timer)
    }
    
    /// Handle hotkey translate (⌘⌃⌥⇧+K)
    private func handleTranslate(text: String) {
        chatState.showChatBubble = true
        chatState.isLoading = true
        chatState.chatMessage = ""
        hideTimer?.cancel()
        animator.setAction("idle")

        // AIProviderManager.translateStream 从 UserSettings 获取目标语言
        AIProviderManager.shared.translateStream(
            text: text,
            onUpdate: { partialResponse in
                self.chatState.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                self.chatState.isLoading = false
            },
            onComplete: { result in
                switch result {
                case .success(let translation):
                    self.chatState.chatMessage = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure(let error):
                    self.chatState.chatMessage = "翻译失败喵: \(error.localizedDescription)"
                }
                self.scheduleHideBubble(afterSeconds: 15)
            }
        )
    }
    
    /// Handle hotkey image analysis (⌘⌃⌥⇧+L)
    private func handleImageAnalysis(imageBase64: String, question: String? = nil) {
        chatState.showChatBubble = true
        chatState.isLoading = true
        chatState.chatMessage = ""
        chatState.lastUserMessage = question ?? "Please analyze this image"  // 记录用户问题
        chatState.lastImageBase64 = imageBase64  // 记录图片用于保存
        hideTimer?.cancel()
        animator.setAction("idle")
        
        // 使用 AIProviderManager 支持多模型
        AIProviderManager.shared.analyzeImageStream(
            imageBase64: imageBase64,
            question: question ?? PetConfig.imageAnalysisPrompt,
            onUpdate: { partialResponse in
                self.chatState.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                self.chatState.isLoading = false
            },
            onComplete: { result in
                switch result {
                case .success(let analysis):
                    self.chatState.chatMessage = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure(let error):
                    self.chatState.chatMessage = "分析失败喵: \(error.localizedDescription)"
                }
                self.scheduleHideBubble(afterSeconds: 20) // Longer for image analysis
            }
        )
    }
    
    /// Handle selection toolbar actions (explain, summarize, translate)
    private func handleSelectionAction(_ actionStr: String, text: String) {
        guard let action = SelectionActionType(rawValue: actionStr) else { return }
        
        chatState.showChatBubble = true
        chatState.isLoading = true
        chatState.chatMessage = ""
        hideTimer?.cancel()
        animator.setAction("idle")
        
        let prompt: String
        switch action {
        case .translate:
            // Reuse existing translate logic
            handleTranslate(text: text)
            return
            
        case .explain:
            prompt = """
            Please explain the following in simple terms. For technical terms, provide definitions and examples:
            
            \(text)
            
            用中文回答，保持简洁（不超过100字）。
            """
            
        case .summarize:
            prompt = """
            Please summarize the key points of the following:
            
            \(text)
            
            用中文回答，用要点列表形式，保持简洁（不超过100字）。
            """
            
        case .search:
            // Search is handled directly in SelectionToolbarWindowController
            return
        }
        
        AIProviderManager.shared.chatStream(
            message: prompt,
            onUpdate: { partialResponse in
                self.chatState.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                self.chatState.isLoading = false
            },
            onComplete: { result in
                switch result {
                case .success(let response):
                    self.chatState.chatMessage = response.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure(let error):
                    self.chatState.chatMessage = "处理失败喵: \(error.localizedDescription)"
                }
                self.scheduleHideBubble(afterSeconds: 15)
            }
        )
    }
}