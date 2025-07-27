import SwiftUI
import PDFKit
import AppKit

// Custom NSView that wraps PDFView and handles trackpad gestures
class TrackpadEnabledView: NSView {
    let pdfView = PDFView()
    weak var coordinator: PDFViewWrapper.Coordinator?
    
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
}

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomLevel: CGFloat
    @Binding var searchText: String
    let updateTrigger: Int // Forces updates when this changes

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
        
        return containerView
    }
    
    func updateNSView(_ containerView: TrackpadEnabledView, context: Context) {
        let pdfView = containerView.pdfView
        
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
        let parent: PDFViewWrapper
        private var currentSearchText = ""
        
        init(_ parent: PDFViewWrapper) {
            self.parent = parent
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
                updateTrigger: 0 // Added updateTrigger for preview
            )
        } else {
            Text("No sample PDF found")
        }
    }
} 