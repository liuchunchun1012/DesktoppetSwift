import SwiftUI
import AppKit

/// Tuxedo cat themed chat bubble - soft cream background with black accents
struct ChatBubbleView: View {
    let message: String
    let isLoading: Bool
    let onHover: (Bool) -> Void
    
    @State private var isHovering = false
    @State private var showSaveSuccess = false
    @State private var saveError: String?
    
    // Tuxedo cat color palette
    private let bubbleBackground = Color(red: 1.0, green: 0.98, blue: 0.95) // Warm cream
    private let textColor = Color(red: 0.2, green: 0.2, blue: 0.2) // Soft black
    private let accentColor = Color(red: 0.4, green: 0.4, blue: 0.4) // Gray accent
    private let borderColor = Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.3)
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble content with save button overlay
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    if isLoading && message.isEmpty {
                        HStack(spacing: 8) {
                            // Cute paw loading indicator
                            Text("🐾")
                                .font(.system(size: 14))
                                .opacity(0.8)
                            Text("Thinking...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                    } else {
                        ScrollView {
                            Text(message)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(textColor)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: 200)
                .frame(minHeight: 44, maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(bubbleBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                
                // Save to Obsidian button - shows on hover
                if isHovering && !message.isEmpty && !isLoading {
                    saveButton
                        .padding(6)
                }
                
                // Save success indicator
                if showSaveSuccess {
                    saveSuccessIndicator
                        .padding(6)
                }
            }
            
            // Cute rounded triangle pointer
            CatBubblePointer()
                .fill(bubbleBackground)
                .frame(width: 16, height: 8)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 2)
        }
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering)
        }
    }
    
    /// Save button - simple icon matching bubble style
    private var saveButton: some View {
        Button(action: saveToObsidian) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor)
        }
        .buttonStyle(.plain)
        .help("Save to Obsidian")
    }
    
    /// Success indicator - simple checkmark
    private var saveSuccessIndicator: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(accentColor)
    }
    
    /// Save current message to Obsidian
    private func saveToObsidian() {
        guard ObsidianClient.shared.isConfigured() else {
            // Show error tip
            ChatState.shared.chatMessage = "Please configure Obsidian Vault path in Settings"
            return
        }
        
        // 构建完整对话内容
        let userMessage = ChatState.shared.lastUserMessage
        let aiResponse = message
        let imageBase64 = ChatState.shared.lastImageBase64
        
        var fullContent = """
        ## My Question
        
        \(userMessage)
        
        ## Cat's Response
        
        \(aiResponse)
        """
        
        // 保存的回调处理
        let handleResult: (Result<String, Error>) -> Void = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileName):
                    // Show success indicator briefly
                    self.showSaveSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showSaveSuccess = false
                    }
                    print("[ChatBubbleView] Saved to Obsidian: \(fileName)")
                    
                case .failure(let error):
                    self.saveError = error.localizedDescription
                    ChatState.shared.chatMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
        
        // 如果有图片，使用带图片的保存方法
        if let imageData = imageBase64 {
            ObsidianClient.shared.quickSaveWithImage(
                content: fullContent,
                imageBase64: imageData,
                completion: handleResult
            )
        } else {
            ObsidianClient.shared.quickSave(
                content: fullContent,
                completion: handleResult
            )
        }
    }
}

/// Rounded triangle for cute bubble pointer
struct CatBubblePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 3
        
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - cornerRadius, y: rect.maxY - cornerRadius * 2),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.midX + cornerRadius, y: rect.maxY - cornerRadius * 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

/// Mac-style close button: red circle, shows X on hover
struct MacCloseButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        // Use ZStack with onTapGesture instead of Button for higher click priority
        // This bypasses the window drag gesture capture
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
            
            if isHovered {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .frame(width: 20, height: 20) // Larger hit area
        .contentShape(Rectangle()) // Make entire frame tappable
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Triangle shape for bubble pointer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Input popover for chat/translate
struct ChatInputView: View {
    @Binding var isPresented: Bool
    @Binding var inputText: String
    let placeholder: String
    let onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Input Container
            HStack(spacing: 0) {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(height: 24)
                    .padding(.horizontal, 12)
                    .onSubmit {
                        submitIfNotEmpty()
                    }
            }
            .frame(width: 340, height: 32)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    isPresented = false
                    inputText = ""
                }
                .buttonStyle(.bordered)
                
                Button("Send") {
                    submitIfNotEmpty()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 8)
        )
    }
    
    private func submitIfNotEmpty() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        inputText = ""
        isPresented = false
    }
}
