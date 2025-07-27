import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var showingFileImporter = false
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                // File operations
                Button(action: openPDF) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                }
                .help("Open PDF")
                
                Divider()
                    .frame(height: 20)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search in document...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Page navigation
                if totalPages > 0 {
                    HStack {
                        Button(action: previousPage) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentPage <= 1)
                        
                        Text("\(currentPage) / \(totalPages)")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(minWidth: 60)
                        
                        Button(action: nextPage) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentPage >= totalPages)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Zoom controls
                    HStack {
                        Button(action: zoomOut) {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .disabled(zoomLevel <= 0.5)
                        
                        Text("\(Int(zoomLevel * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        
                        Button(action: zoomIn) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .disabled(zoomLevel >= 3.0)
                        
                        Button(action: resetZoom) {
                            Image(systemName: "1.magnifyingglass")
                        }
                        .help("Reset zoom")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
            
            // PDF Content
            if let document = pdfDocument {
                PDFViewWrapper(document: document, 
                             currentPage: $currentPage, 
                             totalPages: $totalPages,
                             zoomLevel: $zoomLevel,
                             searchText: $searchText)
            } else {
                // Welcome screen
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("Welcome to Glance")
                            .font(.title)
                            .fontWeight(.medium)
                        
                        Text("Your AI-powered PDF reader")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Open PDF Document") {
                        openPDF()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("Or drag & drop a PDF file here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onDrop(of: [.pdf], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Actions
    
    private func openPDF() {
        showingFileImporter = true
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                loadPDF(from: url)
            }
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, error in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    loadPDF(from: url)
                }
            }
        }
        return true
    }
    
    private func loadPDF(from url: URL) {
        if let document = PDFDocument(url: url) {
            self.pdfDocument = document
            self.totalPages = document.pageCount
            self.currentPage = 1
            self.zoomLevel = 1.0
        }
    }
    
    private func performSearch() {
        // Search functionality will be implemented later
        print("Searching for: \(searchText)")
    }
    
    private func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
        }
    }
    
    private func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
        }
    }
    
    private func zoomIn() {
        zoomLevel = min(zoomLevel + 0.25, 3.0)
    }
    
    private func zoomOut() {
        zoomLevel = max(zoomLevel - 0.25, 0.5)
    }
    
    private func resetZoom() {
        zoomLevel = 1.0
    }
} 