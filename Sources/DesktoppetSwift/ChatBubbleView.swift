import SwiftUI
import AppKit

/// Chat bubble that appears above the pet - simple auto-sizing with scroll
/// Disappears automatically when mouse leaves
struct ChatBubbleView: View {
    let message: String
    let isLoading: Bool
    let onHover: (Bool) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Bubble content
            VStack(alignment: .leading, spacing: 4) {
                if isLoading && message.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("思考中...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 200)
            .frame(minHeight: 40, maxHeight: 300)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Triangle pointer
            Triangle()
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 12, height: 6)
        }
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering)
        }
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
