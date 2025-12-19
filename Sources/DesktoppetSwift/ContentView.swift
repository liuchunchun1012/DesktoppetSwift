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
        if isInRestSequence { return }
        
        behaviorTimer?.invalidate()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 5...12), repeats: false) { [weak self] _ in
            guard let self = self, !self.isHovering, !self.isInRestSequence else {
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

struct ContentView: View {
    @StateObject private var animator = SpriteAnimator()
    
    // AI Chat state
    @State private var showChatBubble = false
    @State private var chatMessage = ""
    @State private var isLoading = false
    @State private var showInputPopover = false
    @State private var inputText = ""
    @State private var inputMode: InputMode = .chat
    @State private var isBubbleHovered = false
    @State private var hideTimer: DispatchWorkItem?
    
    // Image question support
    @State private var pendingImageBase64: String?
    private let imageInputWindow = ChatInputWindow()
    
    var body: some View {
        // VStack with fixed-height sections so bubble doesn't push cat
        VStack(spacing: 0) {
            // Chat bubble area (fixed height)
            ZStack {
                if showChatBubble {
                    ChatBubbleView(
                        message: chatMessage,
                        isLoading: isLoading,
                        onHover: { hovering in
                            isBubbleHovered = hovering
                            if hovering {
                                // Cancel hide timer when hovering
                                hideTimer?.cancel()
                            } else {
                                // Auto-hide 1 second after mouse leaves
                                scheduleHideBubble(afterSeconds: 1)
                            }
                        }
                    )
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
                Button("💬 和我聊天") {
                    inputMode = .chat
                    showInputPopover = true
                }
                Button("🌐 翻译") {
                    inputMode = .translate
                    showInputPopover = true
                }
                Divider()
                
                // Animation controls
                Button("待机舔毛") { animator.setAction("idle") }
                Button("开心跳跃") { animator.setAction("happy_jump") }
                Button("吃猫粮") { animator.setAction("eating") }
                Divider()
                Menu("休息") {
                    Button("准备睡觉") { animator.setAction("rest_prepare") }
                    Button("睡觉中") { animator.setAction("rest_sleeping") }
                    Button("起床") { animator.setAction("rest_wakeup") }
                }
                Menu("走路") {
                    Button("向左走") { animator.setAction("walk_left") }
                    Button("向右走") { animator.setAction("walk_right") }
                    Button("向上走") { animator.setAction("walk_up") }
                    Button("向下走") { animator.setAction("walk_down") }
                }
                Menu("互动") {
                    Button("翻肚皮") { animator.setAction("interact_belly") }
                    Button("拒绝") { animator.setAction("interact_refuse") }
                }
        }
        .popover(isPresented: $showInputPopover) {
            ChatInputView(
                isPresented: $showInputPopover,
                inputText: $inputText,
                placeholder: inputMode == .chat ? "说点什么..." : "输入要翻译的文字...",
                onSubmit: { text in
                    handleInput(text)
                }
            )
        }
        .animation(.easeInOut(duration: 0.3), value: showChatBubble)
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
            if !isLoading {
                animator.onTap()
            }
        }
        // Listen for bubble close (from PassthroughView)
        .onReceive(NotificationCenter.default.publisher(for: .bubbleClose)) { _ in
            withAnimation {
                showChatBubble = false
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
               let text = userInfo["text"] as? String,
               let targetLang = userInfo["targetLang"] as? String {
                handleTranslate(text: text, to: targetLang)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyAnalyzeImage)) { notification in
            if let userInfo = notification.userInfo {
                if let error = userInfo["error"] as? String {
                    // Show error message
                    showChatBubble = true
                    chatMessage = error
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
    }
    
    private func handleInput(_ text: String) {
        showChatBubble = true
        isLoading = true
        chatMessage = ""
        
        // Cancel any existing hide timer
        hideTimer?.cancel()
        
        // Stay in idle while thinking
        animator.setAction("idle")
        
        switch inputMode {
        case .chat:
            OllamaClient.shared.chatStream(
                message: text,
                onUpdate: { partialResponse in
                    // Real-time streaming update
                    self.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isLoading = false
                },
                onComplete: { result in
                    switch result {
                    case .success(let response):
                        self.chatMessage = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    case .failure(let error):
                        self.chatMessage = "喵呜... 出错了: \(error.localizedDescription)"
                    }
                    self.scheduleHideBubble(afterSeconds: 8)
                }
            )
            
        case .translate:
            let targetLang = text.range(of: "\\p{Han}", options: .regularExpression) != nil ? "English" : "Chinese"
            OllamaClient.shared.translateStream(
                text: text,
                to: targetLang,
                onUpdate: { partialResponse in
                    self.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isLoading = false
                },
                onComplete: { result in
                    switch result {
                    case .success(let translation):
                        self.chatMessage = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                    case .failure(let error):
                        self.chatMessage = "翻译失败: \(error.localizedDescription)"
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
            if !self.isBubbleHovered {
                withAnimation {
                    self.showChatBubble = false
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
    private func handleTranslate(text: String, to targetLang: String) {
        showChatBubble = true
        isLoading = true
        chatMessage = ""
        hideTimer?.cancel()
        animator.setAction("idle")
        
        OllamaClient.shared.translateStream(
            text: text,
            to: targetLang,
            onUpdate: { partialResponse in
                self.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isLoading = false
            },
            onComplete: { result in
                switch result {
                case .success(let translation):
                    self.chatMessage = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure(let error):
                    self.chatMessage = "翻译失败喵: \(error.localizedDescription)"
                }
                self.scheduleHideBubble(afterSeconds: 15)
            }
        )
    }
    
    /// Handle hotkey image analysis (⌘⌃⌥⇧+L)
    private func handleImageAnalysis(imageBase64: String, question: String? = nil) {
        showChatBubble = true
        isLoading = true
        chatMessage = ""
        hideTimer?.cancel()
        animator.setAction("idle")
        
        OllamaClient.shared.analyzeImageStream(
            imageBase64: imageBase64,
            question: question,
            onUpdate: { partialResponse in
                self.chatMessage = partialResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isLoading = false
            },
            onComplete: { result in
                switch result {
                case .success(let analysis):
                    self.chatMessage = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
                case .failure(let error):
                    self.chatMessage = "分析失败喵: \(error.localizedDescription)"
                }
                self.scheduleHideBubble(afterSeconds: 20) // Longer for image analysis
            }
        )
    }
}