import SwiftUI
import AppKit

/// 划词工具栏窗口控制器
/// 管理浮动工具栏窗口的显示、定位和隐藏
class SelectionToolbarWindowController {
    static let shared = SelectionToolbarWindowController()
    
    private var window: NSWindow?
    private var currentText: String = ""
    
    /// 点击外部区域隐藏的监听器
    private var clickMonitor: Any?
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // 监听显示工具栏通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showToolbar(_:)),
            name: .showSelectionToolbar,
            object: nil
        )
    }
    
    @objc private func showToolbar(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let position = userInfo["position"] as? NSPoint else {
            return
        }
        
        currentText = text
        
        DispatchQueue.main.async { [weak self] in
            self?.presentToolbar(at: position, with: text)
        }
    }
    
    private func presentToolbar(at mousePosition: NSPoint, with text: String) {
        // 先隐藏现有窗口
        dismissToolbar()
        
        // 创建 SwiftUI 视图
        let toolbarView = SelectionToolbarView(
            selectedText: text,
            onAction: { [weak self] action in
                self?.handleAction(action, text: text)
            },
            onDismiss: { [weak self] in
                self?.dismissToolbar()
            }
        )
        
        // 创建托管视图
        let hostingView = NSHostingView(rootView: toolbarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 50)
        
        // 计算窗口位置（在鼠标上方）
        let windowRect = calculateWindowPosition(mousePosition: mousePosition, windowSize: hostingView.frame.size)
        
        // 创建窗口
        let newWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newWindow.hasShadow = true
        newWindow.contentView = hostingView
        newWindow.ignoresMouseEvents = false
        
        // 显示窗口并添加动画
        newWindow.alphaValue = 0
        newWindow.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            newWindow.animator().alphaValue = 1
        }
        
        self.window = newWindow
        
        // 添加点击外部区域隐藏的监听
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // 检查点击是否在工具栏窗口外部
            if let window = self?.window {
                let clickLocation = event.locationInWindow
                let windowFrame = window.frame
                
                // 转换为屏幕坐标
                let screenLocation = NSEvent.mouseLocation
                if !windowFrame.contains(screenLocation) {
                    self?.dismissToolbar()
                }
            }
        }
    }
    
    private func calculateWindowPosition(mousePosition: NSPoint, windowSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: mousePosition, size: windowSize)
        }
        
        let screenFrame = screen.visibleFrame
        
        // 默认在鼠标上方居中显示
        var x = mousePosition.x - windowSize.width / 2
        var y = mousePosition.y + 20 // 鼠标上方 20pt
        
        // 确保不超出屏幕左边
        if x < screenFrame.minX {
            x = screenFrame.minX + 10
        }
        
        // 确保不超出屏幕右边
        if x + windowSize.width > screenFrame.maxX {
            x = screenFrame.maxX - windowSize.width - 10
        }
        
        // 确保不超出屏幕上边（如果超出，则显示在鼠标下方）
        if y + windowSize.height > screenFrame.maxY {
            y = mousePosition.y - windowSize.height - 10
        }
        
        // 确保不超出屏幕下边
        if y < screenFrame.minY {
            y = screenFrame.minY + 10
        }
        
        return NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
    
    func dismissToolbar() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        
        if let window = self.window {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                self?.window = nil
            })
        }
        
        // 清除选择记录，允许再次选择相同文本
        TextSelectionAssistant.shared.clearLastSelection()
    }
    
    private func handleAction(_ action: SelectionActionType, text: String) {
        dismissToolbar()
        
        switch action {
        case .search:
            // 打开默认浏览器搜索
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            
        case .translate, .explain, .summarize:
            // 发送通知给 ContentView 处理 AI 请求
            NotificationCenter.default.post(
                name: .selectionAction,
                object: nil,
                userInfo: [
                    "action": action.rawValue,
                    "text": text
                ]
            )
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SelectionToolbarView

/// 划词工具栏 UI 视图
/// 深色半透明胶囊形状，左侧小猫图标 + 5个功能按钮
struct SelectionToolbarView: View {
    let selectedText: String
    let onAction: (SelectionActionType) -> Void
    let onDismiss: () -> Void
    
    // 配色方案
    private let backgroundColor = Color.black.opacity(0.85)
    private let hoverColor = Color.white.opacity(0.15)
    private let textColor = Color.white
    private let iconColor = Color.white.opacity(0.9)
    
    var body: some View {
        HStack(spacing: 6) {
            // 左侧小猫图标
            catIcon
                .padding(.leading, 4)
            
            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 20)
            
            // 功能按钮
            ForEach(SelectionActionType.allCases, id: \.rawValue) { action in
                ToolbarButton(
                    action: action,
                    iconColor: iconColor,
                    textColor: textColor,
                    hoverColor: hoverColor
                ) {
                    onAction(action)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    /// 小猫图标（从 bundle 加载）
    private var catIcon: some View {
        Group {
            if let catImage = loadCatIcon() {
                Image(nsImage: catImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            } else {
                // 备用图标
                Text("🐱")
                    .font(.system(size: 18))
            }
        }
    }
    
    /// 从 bundle 加载小猫图标
    private func loadCatIcon() -> NSImage? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let iconPath = "\(resourcePath)/sprites_aligned/idle/grooming 1-12/frame_02.png"
        return NSImage(contentsOfFile: iconPath)
    }
}

// MARK: - ToolbarButton

/// 单个工具栏按钮
struct ToolbarButton: View {
    let action: SelectionActionType
    let iconColor: Color
    let textColor: Color
    let hoverColor: Color
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)
                
                Text(action.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? hoverColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SelectionToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        SelectionToolbarView(
            selectedText: "Hello World",
            onAction: { _ in },
            onDismiss: { }
        )
        .padding()
        .background(Color.gray)
    }
}
#endif
