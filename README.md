# Glance - AI-Powered PDF Reader for macOS

A minimalist, privacy-first PDF reader built for macOS with AI-powered features.

## Features

- **Clean, Native macOS Interface** - Built with SwiftUI for a modern, responsive experience
- **Fast PDF Viewing** - Powered by Apple's PDFKit with smooth continuous scrolling
- **Search Functionality** - Find text within documents quickly
- **Drag & Drop Support** - Simply drag PDF files into the app
- **Zoom Controls** - Precise zoom control with keyboard shortcuts
- **Page Navigation** - Easy navigation through multi-page documents
- **Dark Mode Support** - Automatically follows system appearance

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)

## Building the App

### Option 1: Using Xcode (Recommended)

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd glance
   ```

2. Open Xcode and create a new macOS App project:
   - Choose "macOS" → "App"
   - Product Name: "Glance"
   - Interface: SwiftUI
   - Language: Swift
   - Bundle Identifier: `com.yourname.glance`

3. Replace the default files with the ones in this repository:
   - `GlanceApp.swift` → App entry point
   - `ContentView.swift` → Main interface
   - `PDFViewWrapper.swift` → PDF display component
   - `Info.plist` → App configuration

4. Build and run the project (⌘+R)

### Option 2: Using Swift Package Manager (Working!)

```bash
swift build
swift run
```

This creates a basic executable that runs the GUI app.

## Usage

1. **Opening PDFs**:
   - Click "Open PDF Document" or use ⌘+O
   - Drag and drop PDF files directly into the app window

2. **Navigation**:
   - Scroll continuously through all pages in the document
   - Use the arrow buttons to jump to specific pages
   - Smooth scrolling through the entire document

3. **Search**:
   - Type in the search bar to find text within the document
   - Press Enter to execute the search

4. **Zoom**:
   - Use the zoom controls in the toolbar
   - Click the "1x" button to reset zoom to 100%

## Keyboard Shortcuts

- `⌘+O` - Open PDF file
- `←/→` - Navigate pages
- `⌘++` - Zoom in
- `⌘+-` - Zoom out
- `⌘+0` - Reset zoom

## Architecture

The app is built using:
- **SwiftUI** - Modern declarative UI framework
- **PDFKit** - Apple's framework for PDF handling
- **NSViewRepresentable** - Bridge between SwiftUI and AppKit

## Future Features

This is the foundation for an AI-powered PDF reader. Planned features include:
- Semantic search with local AI models
- Document summarization
- Contextual chat assistant
- Text-to-speech
- Smart highlighting and annotations

## Contributing

This project is part of a larger AI-powered document reading initiative. Contributions are welcome!

## License

[Add your license here]

---

**Note**: This is a basic PDF viewer that serves as the foundation for more advanced AI features. The current version focuses on core PDF viewing functionality with a clean, native macOS interface. 