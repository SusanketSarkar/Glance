import SwiftUI

struct ColorPickerPopup: View {
    @Binding var isVisible: Bool
    let onColorSelected: (Color) -> Void
    let buttonFrame: CGRect // Frame of the highlight button to position above it
    
    @State private var animationOffset: CGFloat = 10
    @State private var animationScale: CGFloat = 0.9
    @State private var animationOpacity: Double = 0
    
    // Define the 5 highlight colors
    private let highlightColors: [(color: Color, name: String)] = [
        (Color.red, "Red"),
        (Color.green, "Green"), 
        (Color.yellow, "Yellow"),
        (Color(red: 1, green: 0, blue: 1), "Magenta"), // Magenta
        (Color.blue, "Blue")
    ]
    
    var body: some View {
        if isVisible {
            HStack(spacing: 3) {
                ForEach(Array(highlightColors.enumerated()), id: \.offset) { index, colorInfo in
                    ColorButton(
                        color: colorInfo.color,
                        name: colorInfo.name,
                                                    onTap: {
                                print("🟢 Color selected: \(colorInfo.color)")
                                onColorSelected(colorInfo.color)
                                dismissPopup()
                            }
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 45/255, green: 45/255, blue: 45/255).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(animationScale)
            .opacity(animationOpacity)
            .position(x: calculatePosition().x, y: calculatePosition().y + animationOffset)
            .animation(.easeOut(duration: 0.2), value: animationOpacity)
            .animation(.easeOut(duration: 0.2), value: animationScale)
            .animation(.easeOut(duration: 0.2), value: animationOffset)
                               .onAppear {
                       print("🟢 ColorPickerPopup appeared")
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
                }
            }
        }
    }
    
    private func calculatePosition() -> CGPoint {
        let popupHeight: CGFloat = 18 // Smaller color button height + reduced padding
        let offset: CGFloat = 6
        
        // Position above the highlight button
        let centerX = buttonFrame.midX
        let centerY = buttonFrame.minY - offset - (popupHeight / 2)
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    private func dismissPopup() {
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
    }
}

struct ColorButton: View {
    let color: Color
    let name: String
    let onTap: () -> Void
    
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
                onTap()
            }
        }) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Highlight with \(name)")
    }
}

// Preview
struct ColorPickerPopup_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .frame(width: 400, height: 300)
            
            ColorPickerPopup(
                isVisible: .constant(true),
                onColorSelected: { color in
                    print("Selected color: \(color)")
                },
                buttonFrame: CGRect(x: 180, y: 150, width: 28, height: 28)
            )
        }
        .frame(width: 400, height: 300)
    }
} 