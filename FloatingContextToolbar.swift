import SwiftUI

struct FloatingContextToolbar: View {
    let selectedTextFrame: CGRect
    let containerBounds: CGRect
    @Binding var isVisible: Bool
    let onUnderline: () -> Void
    let onHighlight: (Color) -> Void // Changed to accept color parameter
    let onDismiss: () -> Void
    
    @State private var animationOffset: CGFloat = 10
    @State private var animationScale: CGFloat = 0.9
    @State private var animationOpacity: Double = 0
    @State private var isColorPickerVisible: Bool = false
    @State private var highlightButtonFrame: CGRect = .zero
    
    var toolbarPosition: CGPoint {
        calculatePosition()
    }
    
    var body: some View {
        if isVisible {
            ZStack {
                // Main toolbar buttons
                HStack(spacing: 8) {
                    // Underline Button
                    ContextToolbarButton(
                        icon: "underline",
                        tooltip: "Underline",
                        action: onUnderline
                    )
                    
                    // Highlight Button
                    ContextToolbarButton(
                        icon: "pencil.tip",
                        tooltip: "Highlight",
                        action: {
                            // Show color picker instead of calling onHighlight directly
                            withAnimation(.easeOut(duration: 0.2)) {
                                isColorPickerVisible = true
                            }
                        }
                    )
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    // Calculate highlight button frame relative to the toolbar position
                                    let localFrame = geometry.frame(in: .local)
                                    let globalPosition = toolbarPosition
                                    highlightButtonFrame = CGRect(
                                        x: globalPosition.x + localFrame.minX - 14, // Adjust for center positioning
                                        y: globalPosition.y + localFrame.minY - 14,
                                        width: localFrame.width,
                                        height: localFrame.height
                                    )
                                }
                                .onChange(of: geometry.frame(in: .local)) { newFrame in
                                    let globalPosition = toolbarPosition
                                    highlightButtonFrame = CGRect(
                                        x: globalPosition.x + newFrame.minX - 14,
                                        y: globalPosition.y + newFrame.minY - 14,
                                        width: newFrame.width,
                                        height: newFrame.height
                                    )
                                }
                                .onChange(of: toolbarPosition) { newPosition in
                                    let localFrame = geometry.frame(in: .local)
                                    highlightButtonFrame = CGRect(
                                        x: newPosition.x + localFrame.minX - 14,
                                        y: newPosition.y + localFrame.minY - 14,
                                        width: localFrame.width,
                                        height: localFrame.height
                                    )
                                }
                        }
                    )
                }
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                .position(x: toolbarPosition.x, y: toolbarPosition.y + animationOffset)
                .animation(.easeOut(duration: 0.2), value: animationOpacity)
                .animation(.easeOut(duration: 0.2), value: animationScale)
                .animation(.easeOut(duration: 0.2), value: animationOffset)
                
                // Color picker popup
                ColorPickerPopup(
                    isVisible: $isColorPickerVisible,
                    onColorSelected: { color in
                        onHighlight(color)
                        // Hide color picker after selection
                        isColorPickerVisible = false
                    },
                    buttonFrame: highlightButtonFrame
                )
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    animationOpacity = 1.0
                    animationScale = 1.0
                    animationOffset = 0
                }
            }
            .onDisappear {
                withAnimation(.easeOut(duration: 0.15)) {
                    animationOpacity = 0.0
                    animationScale = 0.9
                    animationOffset = 10
                    isColorPickerVisible = false // Hide color picker when toolbar disappears
                }
            }
        }
    }
    
    private func calculatePosition() -> CGPoint {
        let buttonSize: CGFloat = 28 // Smaller button size
        let spacing: CGFloat = 8
        let toolbarWidth: CGFloat = (buttonSize * 2) + spacing // 2 buttons + 1 gap
        let toolbarHeight: CGFloat = buttonSize
        let offset: CGFloat = 8 // Smaller offset for closer positioning
        
        // Calculate center point for .position() modifier
        // Start with center-aligned to selection horizontally
        var centerX = selectedTextFrame.midX
        var centerY = selectedTextFrame.minY - offset - (toolbarHeight / 2)
        
        // Ensure stays within container bounds horizontally
        let minCenterX: CGFloat = toolbarWidth / 2 + 8
        let maxCenterX = containerBounds.width - (toolbarWidth / 2) - 8
        centerX = max(minCenterX, min(maxCenterX, centerX))
        
        // Ensure stays within container bounds vertically
        let minCenterY: CGFloat = toolbarHeight / 2 + 8
        centerY = max(minCenterY, centerY)
        
        // If positioning above would place it too high, position below instead
        if centerY < minCenterY && selectedTextFrame.maxY + offset + (toolbarHeight / 2) < containerBounds.height {
            centerY = selectedTextFrame.maxY + offset + (toolbarHeight / 2)
        }
        
        print("🎯 Toolbar position - Selection: \(selectedTextFrame), Center: (\(centerX), \(centerY)), Container: \(containerBounds)")
        
        return CGPoint(x: centerX, y: centerY)
    }
}

struct ContextToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isPressed ? Color(red: 0, green: 122/255, blue: 1) : (isHovered ? Color(red: 85/255, green: 85/255, blue: 85/255) : Color(red: 74/255, green: 74/255, blue: 74/255)))
                        .overlay(
                            Circle()
                                .stroke(Color(red: 90/255, green: 90/255, blue: 90/255), lineWidth: 0.5)
                        )
                )
                .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Preview
struct FloatingContextToolbar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .frame(width: 400, height: 300)
            
            FloatingContextToolbar(
                selectedTextFrame: CGRect(x: 100, y: 150, width: 200, height: 40),
                containerBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
                isVisible: .constant(true),
                onUnderline: { print("Underline") },
                onHighlight: { color in print("Highlight with color: \(color)") },
                onDismiss: { print("Dismiss") }
            )
        }
        .frame(width: 400, height: 300)
    }
} 