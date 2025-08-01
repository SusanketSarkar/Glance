import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// Extension to convert SwiftUI Color to NSColor
extension NSColor {
    convenience init(_ color: Color) {
        // Convert common colors to NSColor
        switch color {
        case .red:
            self.init(red: 1, green: 0, blue: 0, alpha: 0.5)
        case .green:
            self.init(red: 0, green: 1, blue: 0, alpha: 0.5)
        case .yellow:
            self.init(red: 1, green: 1, blue: 0, alpha: 0.5)
        case .blue:
            self.init(red: 0, green: 0, blue: 1, alpha: 0.5)
        default:
            // For magenta and others
            self.init(red: 1, green: 0, blue: 1, alpha: 0.5)
        }
    }
}

// Custom NSView that wraps PDFView and handles trackpad gestures
class TrackpadEnabledView: NSView {
    let pdfView = PDFView()
    weak var coordinator: PDFViewRepresentable.Coordinator?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPDFView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPDFView()
    }
    
    private func setupPDFView() {
        addSubview(pdfView)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // Handle trackpad pinch-to-zoom gestures
    override func magnify(with event: NSEvent) {
        print("🎯 Magnify gesture detected! Magnification: \(event.magnification)")
        
        // Get current scale and apply magnification
        let currentScale = pdfView.scaleFactor
        let newScale = currentScale * (1.0 + event.magnification)
        
        // Clamp to limits
        let clampedScale = max(0.25, min(5.0, newScale))
        pdfView.scaleFactor = clampedScale
        
        // Update the coordinator's zoom level binding
        DispatchQueue.main.async {
            self.coordinator?.updateZoomLevel(clampedScale)
        }
        
        super.magnify(with: event)
    }
    
    // Handle trackpad rotation gestures  
    override func rotate(with event: NSEvent) {
        print("🎯 Rotate gesture detected! Rotation: \(event.rotation)")
        super.rotate(with: event)
    }
    
    // Handle mouse clicks to dismiss toolbar when clicking outside selection
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Small delay to allow text selection to update first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.pdfView.currentSelection == nil || self.pdfView.currentSelection?.string?.isEmpty == true {
                self.coordinator?.dismissToolbar()
            }
        }
    }
}

struct PDFViewWrapper: View {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomLevel: CGFloat
    @Binding var searchText: String
    let updateTrigger: Int // Forces updates when this changes
    
    // Text selection state
    @State private var selectedTextFrame: CGRect = .zero
    @State private var isToolbarVisible: Bool = false
    @State private var selectedText: String = ""
    @State private var containerBounds: CGRect = .zero
    @State private var selectionTimer: Timer?
    @State private var highlightColor: Color?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                PDFViewRepresentable(
                    document: document,
                    currentPage: $currentPage,
                    totalPages: $totalPages,
                    zoomLevel: $zoomLevel,
                    searchText: $searchText,
                    updateTrigger: updateTrigger,
                    selectedTextFrame: $selectedTextFrame,
                    isToolbarVisible: $isToolbarVisible,
                    selectedText: $selectedText,
                    containerBounds: $containerBounds,
                    highlightColor: $highlightColor
                )
                
                FloatingContextToolbar(
                    selectedTextFrame: selectedTextFrame,
                    containerBounds: containerBounds,
                    isVisible: $isToolbarVisible,
                    onUnderline: { handleUnderline() },
                    onHighlight: { color in handleHighlight(color: color) },
                    onDismiss: { dismissToolbar() }
                )
            }
            .onAppear {
                containerBounds = geometry.frame(in: .local)
            }
            .onChange(of: geometry.size) { _ in
                containerBounds = geometry.frame(in: .local)
            }
        }
    }
    
    private func handleUnderline() {
        print("Underline text: \(selectedText)")
        // TODO: Implement text underlining
        dismissToolbar()
    }
    
    private func handleHighlight(color: Color) {
        print("Highlight text: \(selectedText) with color: \(color)")
        
        // Trigger highlighting by setting the color
        highlightColor = color
        
        dismissToolbar()
    }
    
    private func dismissToolbar() {
        withAnimation(.easeOut(duration: 0.15)) {
            isToolbarVisible = false
        }
    }
}

struct PDFViewRepresentable: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomLevel: CGFloat
    @Binding var searchText: String
    let updateTrigger: Int
    
    // Text selection bindings
    @Binding var selectedTextFrame: CGRect
    @Binding var isToolbarVisible: Bool
    @Binding var selectedText: String
    @Binding var containerBounds: CGRect
    @Binding var highlightColor: Color?

    func makeNSView(context: Context) -> TrackpadEnabledView {
        let containerView = TrackpadEnabledView()
        let pdfView = containerView.pdfView
        
        // Set up coordinator reference for gesture callbacks
        containerView.coordinator = context.coordinator
        
        // Configure PDF view for continuous scrolling
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous  // Enables continuous scrolling through all pages
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.textBackgroundColor
        
        // Enable smooth scrolling and better page transitions
        pdfView.interpolationQuality = .high  // High-quality rendering during zoom/scroll
        pdfView.enableDataDetectors = true    // Detect links, phone numbers, etc.
        
        // Configure zoom limits
        pdfView.maxScaleFactor = 5.0           // Maximum zoom level (500%)
        pdfView.minScaleFactor = 0.25          // Minimum zoom level (25%)
        
        // Set up delegate for page changes
        pdfView.delegate = context.coordinator
        
        // Add notification observers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scaleChanged),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        
        // Add text selection observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textSelectionChanged),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        // Add scroll observer to track view changes
        if let scrollView = pdfView.documentView?.enclosingScrollView {
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.viewBoundsChanged),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
        
        // Also observe the PDFView itself for bounds changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewBoundsChanged),
            name: NSView.boundsDidChangeNotification,
            object: pdfView
        )
        
        return containerView
    }
    
    func updateNSView(_ containerView: TrackpadEnabledView, context: Context) {
        let pdfView = containerView.pdfView
        
        // Update container bounds with actual view size
        DispatchQueue.main.async {
            self.containerBounds = containerView.bounds
        }
        
        // Update coordinator bindings
        context.coordinator.updateBindings(
            selectedTextFrame: $selectedTextFrame,
            isToolbarVisible: $isToolbarVisible,
            selectedText: $selectedText,
            containerBounds: $containerBounds,
            highlightColor: $highlightColor
        )
        
        // Update document if it has changed (crucial for tab switching)
        if pdfView.document != document {
            pdfView.document = document
            
            // Reset search state for new document
            context.coordinator.resetSearchState()
            
            // Reset view state for new document
            if document.pageCount > 0 {
                pdfView.go(to: document.page(at: 0)!)
                context.coordinator.updateTotalPages(document.pageCount)
            }
        }
        
        // Always update zoom level (important for zoom buttons to work)
        if abs(pdfView.scaleFactor - zoomLevel) > 0.01 {
            pdfView.scaleFactor = zoomLevel
        }
        
        // Update current page if changed externally
        if let page = document.page(at: currentPage - 1), 
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
        
        // Update search if needed
        context.coordinator.updateSearch(searchText: searchText, in: pdfView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFViewRepresentable
        private var currentSearchText = ""
        private var selectionTimer: Timer?
        
        // Text selection tracking
        private var currentSelection: PDFSelection?
        private var currentPDFView: PDFView?
        
        // Text selection bindings
        var selectedTextFrame: Binding<CGRect>?
        var isToolbarVisible: Binding<Bool>?
        var selectedText: Binding<String>?
        var containerBounds: Binding<CGRect>?
        var highlightColor: Binding<Color?>?
        
        init(_ parent: PDFViewRepresentable) {
            self.parent = parent
        }
        
        func updateBindings(selectedTextFrame: Binding<CGRect>, isToolbarVisible: Binding<Bool>, selectedText: Binding<String>, containerBounds: Binding<CGRect>, highlightColor: Binding<Color?>?) {
            self.selectedTextFrame = selectedTextFrame
            self.isToolbarVisible = isToolbarVisible
            self.selectedText = selectedText
            self.containerBounds = containerBounds
            
            // Check if highlight color changed and perform highlighting
            if let newColorBinding = highlightColor,
               let newColor = newColorBinding.wrappedValue,
               newColor != self.highlightColor?.wrappedValue {
                self.highlightColor = newColorBinding
                performHighlighting(with: newColor)
                // Reset the color after highlighting
                DispatchQueue.main.async {
                    newColorBinding.wrappedValue = nil
                }
            } else {
                self.highlightColor = highlightColor
            }
        }
        
        // Called by TrackpadEnabledView when trackpad gestures change zoom
        func updateZoomLevel(_ newZoom: CGFloat) {
            parent.zoomLevel = newZoom
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            let newPageNumber = pageIndex + 1
            
            DispatchQueue.main.async {
                self.parent.currentPage = newPageNumber
                self.parent.totalPages = document.pageCount
            }
        }
        
        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            
            DispatchQueue.main.async {
                // Update the zoom level binding when user pinch-zooms or scroll-zooms
                self.parent.zoomLevel = pdfView.scaleFactor
            }
        }
        
        func updateSearch(searchText: String, in pdfView: PDFView) {
            // Clear previous search
            if currentSearchText != searchText {
                pdfView.document?.cancelFindString()
                
                if !searchText.isEmpty {
                    pdfView.document?.findString(searchText, withOptions: [])
                }
                
                currentSearchText = searchText
            }
        }
        
        func updateTotalPages(_ newTotalPages: Int) {
            DispatchQueue.main.async {
                self.parent.totalPages = newTotalPages
            }
        }
        
        func resetSearchState() {
            currentSearchText = ""
        }
        
        @objc func textSelectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            
            // Cancel any existing timer
            selectionTimer?.invalidate()
            
            DispatchQueue.main.async {
                if let selection = pdfView.currentSelection, let selectionString = selection.string, !selectionString.isEmpty {
                    // Store current selection and PDFView for scroll tracking
                    self.currentSelection = selection
                    self.currentPDFView = pdfView
                    
                    // Calculate initial position
                    self.updateToolbarPositionWithVisibilityCheck()
                    
                    // Update the selection text
                    self.selectedText?.wrappedValue = selectionString
                    
                    // Hide toolbar immediately during selection
                    self.isToolbarVisible?.wrappedValue = false
                    
                    // Set a timer to show the toolbar after selection is complete (500ms delay)
                    self.selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        DispatchQueue.main.async {
                            // Check if selection is still active before showing toolbar
                            if let selection = pdfView.currentSelection, let selectionString = selection.string, !selectionString.isEmpty {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    self.isToolbarVisible?.wrappedValue = true
                                }
                            }
                        }
                    }
                } else {
                    // Clear stored selection
                    self.currentSelection = nil
                    self.currentPDFView = nil
                    // Hide the toolbar when no text is selected
                    self.dismissToolbar()
                }
            }
        }
        
        @objc func viewBoundsChanged(_ notification: Notification) {
            // Update toolbar position when view bounds change (scrolling, zooming)
            DispatchQueue.main.async {
                // Always check current selection state, don't rely on cached data
                self.updateToolbarPositionWithVisibilityCheck()
            }
        }
        
        private func updateToolbarPositionWithVisibilityCheck() {
            guard let pdfView = currentPDFView else { return }
            
            // Get the CURRENT selection from PDFView (not cached)
            // This ensures we get the live, up-to-date selection state
            guard let liveSelection = pdfView.currentSelection,
                  let selectionString = liveSelection.string,
                  !selectionString.isEmpty else {
                // No current selection, hide toolbar
                withAnimation(.easeOut(duration: 0.15)) {
                    self.isToolbarVisible?.wrappedValue = false
                }
                return
            }
            
            // Find which page the selection is on
            var targetPage: PDFPage?
            var selectionBounds = CGRect.zero
            
            for pageIndex in 0..<pdfView.document!.pageCount {
                if let page = pdfView.document!.page(at: pageIndex) {
                    let pageBounds = liveSelection.bounds(for: page)
                    if !pageBounds.isEmpty {
                        targetPage = page
                        selectionBounds = pageBounds
                        break
                    }
                }
            }
            
            guard let page = targetPage else { return }
            
            // Convert PDF page coordinates to current PDFView coordinates
            // This should account for current zoom and scroll state
            let viewBounds = pdfView.convert(selectionBounds, from: page)
            
            // Convert NSView coordinates to SwiftUI coordinates
            // NSView has origin at bottom-left, SwiftUI has origin at top-left
            let containerHeight = pdfView.bounds.height
            let swiftUIBounds = CGRect(
                x: viewBounds.origin.x,
                y: containerHeight - viewBounds.origin.y - viewBounds.height,
                width: viewBounds.width,
                height: viewBounds.height
            )
            
            print("🎯 Live selection - Page: \(selectionBounds), View: \(viewBounds), SwiftUI: \(swiftUIBounds), Container: \(containerHeight)")
            
            // Update position
            self.selectedTextFrame?.wrappedValue = swiftUIBounds
            
            // Show/hide toolbar based on visibility  
            let isVisible = swiftUIBounds.minY >= -50 && swiftUIBounds.maxY <= containerHeight + 50 &&
                           swiftUIBounds.minX >= -50 && swiftUIBounds.maxX <= pdfView.bounds.width + 50
            
            if isVisible && self.isToolbarVisible?.wrappedValue == false {
                // Show toolbar when selection comes back into view
                withAnimation(.easeOut(duration: 0.2)) {
                    self.isToolbarVisible?.wrappedValue = true
                }
            } else if !isVisible && self.isToolbarVisible?.wrappedValue == true {
                // Hide toolbar when selection goes off-screen
                withAnimation(.easeOut(duration: 0.15)) {
                    self.isToolbarVisible?.wrappedValue = false
                }
            }
        }
        

        
        private func performHighlighting(with color: Color) {
            guard let pdfView = currentPDFView,
                  let selection = pdfView.currentSelection else { return }
            
            print("🎨 Performing highlighting with color: \(color)")
            
            // Find the page containing the selection
            for pageIndex in 0..<pdfView.document!.pageCount {
                if let page = pdfView.document!.page(at: pageIndex) {
                    let selectionBounds = selection.bounds(for: page)
                    if !selectionBounds.isEmpty {
                        // Create a highlight annotation
                        let annotation = PDFAnnotation(bounds: selectionBounds, forType: .highlight, withProperties: nil)
                        
                        // Convert SwiftUI Color to NSColor
                        let nsColor = NSColor(color)
                        annotation.color = nsColor
                        
                        // Set annotation properties
                        annotation.contents = "Highlighted text: \(selection.string ?? "")"
                        
                        // Add annotation to the page
                        page.addAnnotation(annotation)
                        
                        print("✅ Added highlight annotation to page \(pageIndex)")
                        break
                    }
                }
            }
            
            // Clear the selection after highlighting
            DispatchQueue.main.async {
                pdfView.clearSelection()
            }
        }
        
        func dismissToolbar() {
            // Cancel any pending timer
            selectionTimer?.invalidate()
            
            // Clear stored selection
            currentSelection = nil
            currentPDFView = nil
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.15)) {
                    self.isToolbarVisible?.wrappedValue = false
                }
                self.selectedText?.wrappedValue = ""
                self.selectedTextFrame?.wrappedValue = .zero
            }
        }
        
        // PDFViewDelegate methods
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
            // Handle link clicks if needed
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview
struct PDFViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
           let document = PDFDocument(url: url) {
            PDFViewWrapper(
                document: document,
                currentPage: .constant(1),
                totalPages: .constant(document.pageCount),
                zoomLevel: .constant(1.0),
                searchText: .constant(""),
                updateTrigger: 0
            )
        } else {
            Text("No sample PDF found")
        }
    }
} 