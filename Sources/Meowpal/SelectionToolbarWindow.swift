import SwiftUI
import AppKit

/// Selection Toolbar Window Controller
/// Manages the display, positioning, and hiding of the floating toolbar window
class SelectionToolbarWindowController {
    static let shared = SelectionToolbarWindowController()
    
    private var window: NSWindow?
    private var currentText: String = ""
    
    /// Monitor for clicks outside the window to hide it
    private var clickMonitor: Any?
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Observe toolbar display notification
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
        // Hide existing window first
        dismissToolbar()
        
        // Create SwiftUI view
        let toolbarView = SelectionToolbarView(
            selectedText: text,
            onAction: { [weak self] action in
                self?.handleAction(action, text: text)
            },
            onDismiss: { [weak self] in
                self?.dismissToolbar()
            }
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: toolbarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 50)
        
        // Calculate window position (above mouse)
        let windowRect = calculateWindowPosition(mousePosition: mousePosition, windowSize: hostingView.frame.size)
        
        // Create window
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
        
        // Show window with animation
        newWindow.alphaValue = 0
        newWindow.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            newWindow.animator().alphaValue = 1
        }
        
        self.window = newWindow
        
        // Add monitor for outside clicks
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Check if click is outside toolbar window
            if let window = self?.window {
                let clickLocation = event.locationInWindow
                let windowFrame = window.frame
                
                // Convert to screen coordinates
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
        
        // Default: center above mouse
        var x = mousePosition.x - windowSize.width / 2
        var y = mousePosition.y + 20 // 20pt above mouse
        
        // Ensure not off-screen left
        if x < screenFrame.minX {
            x = screenFrame.minX + 10
        }
        
        // Ensure not off-screen right
        if x + windowSize.width > screenFrame.maxX {
            x = screenFrame.maxX - windowSize.width - 10
        }
        
        // Ensure not off-screen top (show below if needed)
        if y + windowSize.height > screenFrame.maxY {
            y = mousePosition.y - windowSize.height - 10
        }
        
        // Ensure not off-screen bottom
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
        
        // Clear selection record to allow re-selecting same text
        TextSelectionAssistant.shared.clearLastSelection()
    }
    
    private func handleAction(_ action: SelectionActionType, text: String) {
        dismissToolbar()
        
        switch action {
        case .search:
            // Open default browser for search
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            
        case .translate, .explain, .summarize:
            // Post notification for ContentView to handle AI request
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

/// Selection Toolbar UI View
/// Dark translucent capsule shape with cat icon + function buttons
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
            // Left cat icon
            catIcon
                .padding(.leading, 4)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 20)
            
            // Function buttons
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
    
    /// Cat icon (load from bundle)
    private var catIcon: some View {
        Group {
            if let catImage = loadCatIcon() {
                Image(nsImage: catImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            } else {
                // Fallback icon
                Text("🐱")
                    .font(.system(size: 18))
            }
        }
    }
    
    /// Load cat icon from bundle
    private func loadCatIcon() -> NSImage? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let iconPath = "\(resourcePath)/sprites_aligned/idle/grooming 1-12/frame_02.png"
        return NSImage(contentsOfFile: iconPath)
    }
}

// MARK: - ToolbarButton

/// Individual toolbar button
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
