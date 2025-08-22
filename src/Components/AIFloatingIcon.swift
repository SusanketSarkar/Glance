import SwiftUI

struct AIFloatingIcon: View {
    @State private var isHovered = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: {
            // Dummy action for now - will be implemented later
            print("🤖 AI Icon clicked - functionality coming soon!")
        }) {
            ZStack {
                // Background circle with AI gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.3, green: 0.5, blue: 1.0),
                                Color(red: 0.5, green: 0.3, blue: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                
                // AI Brain Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                
                // Subtle sparkle overlay when hovered
                if isHovered {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                        .offset(x: 12, y: -12)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                }
                
                // Pulse ring effect
                if pulseAnimation {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 55, height: 55)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("AI Assistant - Ask questions about your PDF")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            // Start subtle pulse animation
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseAnimation = true
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// Preview
struct AIFloatingIcon_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .frame(width: 400, height: 300)
            
            AIFloatingIcon()
        }
        .frame(width: 400, height: 300)
    }
}
