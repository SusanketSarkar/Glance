import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomLevel: CGFloat
    @Binding var searchText: String
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Configure PDF view for continuous scrolling
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous  // Enables continuous scrolling through all pages
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.textBackgroundColor
        
        // Enable smooth scrolling and better page transitions
        pdfView.interpolationQuality = .high  // High-quality rendering during zoom/scroll
        pdfView.enableDataDetectors = true    // Detect links, phone numbers, etc.
        
        // Enable selection and highlighting
        // Note: Some properties may not be available in all macOS versions
        
        // Set up delegate for page changes
        pdfView.delegate = context.coordinator
        
        // Add notification observers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update current page if changed externally
        if let page = document.page(at: currentPage - 1), 
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
        
        // Update zoom level
        if abs(pdfView.scaleFactor - zoomLevel) > 0.01 {
            pdfView.scaleFactor = zoomLevel
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
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex + 1
                self.parent.totalPages = document.pageCount
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
                searchText: .constant("")
            )
        } else {
            Text("No sample PDF found")
        }
    }
} 