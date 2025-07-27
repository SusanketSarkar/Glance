import SwiftUI
import PDFKit
import UniformTypeIdentifiers

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
                    containerBounds: $containerBounds
                )
                
                FloatingContextToolbar(
                    selectedTextFrame: selectedTextFrame,
                    containerBounds: containerBounds,
                    isVisible: $isToolbarVisible,
                    onUnderline: { handleUnderline() },
                    onHighlight: { handleHighlight() },
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
    
    private func handleHighlight() {
        print("Highlight text: \(selectedText)")
        // TODO: Implement text highlighting
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
            containerBounds: $containerBounds
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
        
        // Text selection bindings
        var selectedTextFrame: Binding<CGRect>?
        var isToolbarVisible: Binding<Bool>?
        var selectedText: Binding<String>?
        var containerBounds: Binding<CGRect>?
        
        init(_ parent: PDFViewRepresentable) {
            self.parent = parent
        }
        
        func updateBindings(selectedTextFrame: Binding<CGRect>, isToolbarVisible: Binding<Bool>, selectedText: Binding<String>, containerBounds: Binding<CGRect>) {
            self.selectedTextFrame = selectedTextFrame
            self.isToolbarVisible = isToolbarVisible
            self.selectedText = selectedText
            self.containerBounds = containerBounds
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
                    // Get the bounds of the selected text in PDF coordinates
                    let selectionBounds = selection.bounds(for: pdfView.currentPage!)
                    
                    // Convert to view coordinates (this gives us NSView coordinates)
                    let viewBounds = pdfView.convert(selectionBounds, from: pdfView.currentPage!)
                    
                    // Convert NSView coordinates to SwiftUI coordinates
                    // NSView has origin at bottom-left, SwiftUI has origin at top-left
                    let containerHeight = pdfView.bounds.height
                    let swiftUIBounds = CGRect(
                        x: viewBounds.origin.x,
                        y: containerHeight - viewBounds.origin.y - viewBounds.height,
                        width: viewBounds.width,
                        height: viewBounds.height
                    )
                    
                    print("🎯 Selection bounds - PDF: \(selectionBounds), NSView: \(viewBounds), SwiftUI: \(swiftUIBounds)")
                    
                    // Update the selection data immediately
                    self.selectedTextFrame?.wrappedValue = swiftUIBounds
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
                    // Hide the toolbar when no text is selected
                    self.dismissToolbar()
                }
            }
        }
        
        func dismissToolbar() {
            // Cancel any pending timer
            selectionTimer?.invalidate()
            
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