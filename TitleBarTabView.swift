import SwiftUI

struct TitleBarTabView: View {
    @Binding var tabs: [DocumentTab]
    @Binding var selectedTabIndex: Int
    let onNewTab: () -> Void
    let onCloseTab: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                TitleBarTab(
                    tab: tab,
                    isSelected: index == selectedTabIndex,
                    canClose: tabs.count > 1
                ) {
                    selectedTabIndex = index
                } onClose: {
                    onCloseTab(index)
                }
            }
            
            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .help("New Tab")
        }
        .padding(.leading, 8) // Add some spacing from traffic lights
    }
}

struct TitleBarTab: View {
    @ObservedObject var tab: DocumentTab
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tab.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(textColor) // Use computed property for better color management
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140) // Limit tab width
            
            // Only show close button on selected tabs
            if canClose && isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)
                        // Removed red circle background
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // Computed property for text color with better hover effect
    private var textColor: Color {
        if isSelected {
            return .primary
        } else if isHovered {
            return Color.primary.opacity(0.8) // Slightly brighter when hovering inactive tabs
        } else {
            return .secondary
        }
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        } else {
            return Color.clear
        }
    }
}

#Preview {
    TitleBarTabView(
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