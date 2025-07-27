import Foundation
import PDFKit

// Data model for individual PDF document tabs
class DocumentTab: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published var document: PDFDocument?
    @Published var title: String
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 0
    @Published var zoomLevel: CGFloat = 1.0
    @Published var searchText: String = ""
    @Published var documentURL: URL?
    
    init(title: String = "New Tab", document: PDFDocument? = nil, url: URL? = nil) {
        self.title = title
        self.document = document
        self.documentURL = url
        
        if let document = document {
            self.totalPages = document.pageCount
        }
    }
    
    func loadPDF(from url: URL) {
        if let document = PDFDocument(url: url) {
            self.document = document
            self.documentURL = url
            self.title = url.lastPathComponent
            self.totalPages = document.pageCount
            self.currentPage = 1
            self.zoomLevel = 1.0
        }
    }
    
    var hasDocument: Bool {
        return document != nil
    }
    
    var displayTitle: String {
        if hasDocument {
            return title.replacingOccurrences(of: ".pdf", with: "")
        } else {
            return "New Tab"
        }
    }
} 