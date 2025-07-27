import SwiftUI
import AppKit

struct TabBarView: View {
    @Binding var tabs: [DocumentTab]
    @Binding var selectedTabIndex: Int
    let onNewTab: () -> Void
    let onCloseTab: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#3A3A3A"),
                        Color(hex: "#2E2E2E")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                HStack(spacing: 0) {
                    // Traffic light area spacing (just enough for the buttons)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 78) // Just enough space for traffic lights
                    
                    // Tabs container
                    HStack(spacing: 2) {
                        ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                            MacOSTabView(
                                tab: tab,
                                isSelected: index == selectedTabIndex,
                                canClose: tabs.count > 1,
                                geometryWidth: geometry.size.width,
                                tabsCount: tabs.count
                            ) {
                                selectedTabIndex = index
                            } onClose: {
                                onCloseTab(index)
                            }
                        }
                        
                        // New tab button
                        NewTabButton(action: onNewTab)
                        
                        Spacer()
                    }
                }
                
                // Bottom border
                Rectangle()
                    .fill(Color(hex: "#484848"))
                    .frame(height: 1)
            }
        }
        .frame(height: 32)
    }
}

struct MacOSTabView: View {
    @ObservedObject var tab: DocumentTab
    let isSelected: Bool
    let canClose: Bool
    let geometryWidth: CGFloat
    let tabsCount: Int
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    @State private var isCloseHovered = false
    
    private var tabWidth: CGFloat {
        let availableWidth = geometryWidth - 78 - 32 - 16 // Subtract traffic light area, new tab button, and padding
        let idealWidth = availableWidth / CGFloat(max(1, tabsCount))
        return min(max(idealWidth, 140), 240) // Sleeker: Min 140px, Max 240px
    }
    
    var body: some View {
        ZStack {
            // Tab background - sleeker rounded corners only on top
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 6
            )
            .fill(backgroundGradient)
            .shadow(
                color: isSelected ? .black.opacity(0.15) : .clear,
                radius: isSelected ? 2 : 0,
                x: 0,
                y: isSelected ? 1 : 0
            )
            
            HStack(spacing: 6) {
                // Tab title
                Text(tab.displayTitle)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular, design: .default))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // Close button
                if canClose {
                    CloseButton(
                        isVisible: isSelected || isHovered,
                        isHovered: isCloseHovered,
                        action: onClose
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCloseHovered = hovering
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: tabWidth, height: 28) // Dynamic width, sleeker height
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var backgroundGradient: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(hex: "#4A4A4A"))
        } else if isHovered {
            return AnyShapeStyle(Color(hex: "#404040"))
        } else {
            return AnyShapeStyle(Color(hex: "#3A3A3A"))
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return Color(hex: "#FFFFFF")
        } else if isHovered {
            return Color(hex: "#D1D1D1")
        } else {
            return Color(hex: "#B8B8B8")
        }
    }
}

struct CloseButton: View {
    let isVisible: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isHovered ? Color(hex: "#FFFFFF") : Color(hex: "#9A9A9A"))
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(isHovered ? Color(hex: "#FF5F5F") : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct NewTabButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? Color(hex: "#FFFFFF") : Color(hex: "#B8B8B8"))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isHovered ? Color(hex: "#404040") : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 6)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Extension to create Color from hex strings
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TabBarView(
        tabs: .constant([
            DocumentTab(title: "Sample Document.pdf"),
            DocumentTab(title: "Another File.pdf"),
            DocumentTab()
        ]),
        selectedTabIndex: .constant(0),
        onNewTab: {},
        onCloseTab: { _ in }
    )
} 