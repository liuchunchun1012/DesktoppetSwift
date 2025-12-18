import SwiftUI
import AppKit

/// Tuxedo cat themed chat bubble - soft cream background with black accents
struct ChatBubbleView: View {
    let message: String
    let isLoading: Bool
    let onHover: (Bool) -> Void
    
    @State private var isHovering = false
    
    // Tuxedo cat color palette
    private let bubbleBackground = Color(red: 1.0, green: 0.98, blue: 0.95) // Warm cream
    private let textColor = Color(red: 0.2, green: 0.2, blue: 0.2) // Soft black
    private let accentColor = Color(red: 0.4, green: 0.4, blue: 0.4) // Gray accent
    private let borderColor = Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.3)
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble content
            VStack(alignment: .leading, spacing: 4) {
                if isLoading && message.isEmpty {
                    HStack(spacing: 8) {
                        // Cute paw loading indicator
                        Text("🐾")
                            .font(.system(size: 14))
                            .opacity(0.8)
                        Text("喵喵思考中...")
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
            TextField(placeholder, text: $inputText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 200)
                .onSubmit {
                    submitIfNotEmpty()
                }
            
            HStack(spacing: 8) {
                Button("取消") {
                    isPresented = false
                    inputText = ""
                }
                .buttonStyle(.bordered)
                
                Button("发送") {
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
