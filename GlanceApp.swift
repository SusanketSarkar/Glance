import SwiftUI

@main
struct GlanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF...") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("New Tab") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            
            CommandGroup(after: .windowArrangement) {
                Button("Close Tab") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("w", modifiers: .command)
                
                Button("Next Tab") {
                    // This will be handled by the ContentView  
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                
                Button("Previous Tab") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            }
        }
    }
} 