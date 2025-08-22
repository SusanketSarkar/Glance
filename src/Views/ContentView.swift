import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var tabs: [DocumentTab] = [DocumentTab()]
    @State private var selectedTabIndex: Int = 0
    @State private var showingFileImporter = false
    @State private var updateTrigger: Int = 0 // Force PDFViewWrapper updates
    
    private var selectedTab: DocumentTab {
        guard selectedTabIndex < tabs.count else {
            return tabs.first ?? DocumentTab()
        }
        return tabs[selectedTabIndex]
    }
    
    // Bindings for selected tab properties
    private var selectedTabSearchText: Binding<String> {
        Binding(
            get: { self.selectedTab.searchText },
            set: { self.tabs[self.selectedTabIndex].searchText = $0 }
        )
    }
    
    private var selectedTabCurrentPage: Binding<Int> {
        Binding(
            get: { self.selectedTab.currentPage },
            set: { self.tabs[self.selectedTabIndex].currentPage = $0 }
        )
    }
    
    private var selectedTabTotalPages: Binding<Int> {
        Binding(
            get: { self.selectedTab.totalPages },
            set: { self.tabs[self.selectedTabIndex].totalPages = $0 }
        )
    }
    
    private var selectedTabZoomLevel: Binding<CGFloat> {
        Binding(
            get: { 
                let value = self.selectedTab.zoomLevel
                return value
            },
            set: { newValue in
                self.tabs[self.selectedTabIndex].zoomLevel = newValue
            }
        )
    }
    
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
                    TextField("Search in document...", text: selectedTabSearchText)
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
                if selectedTabTotalPages.wrappedValue > 0 {
                    HStack {
                        Button(action: previousPage) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedTabCurrentPage.wrappedValue <= 1)
                        
                        Text("\(selectedTabCurrentPage.wrappedValue) / \(selectedTabTotalPages.wrappedValue)")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(minWidth: 60)
                        
                        Button(action: nextPage) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedTabCurrentPage.wrappedValue >= selectedTabTotalPages.wrappedValue)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Zoom controls
                    HStack {
                        Button(action: zoomOut) {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .disabled(selectedTabZoomLevel.wrappedValue <= 0.25)
                        
                        Text("\(Int(selectedTabZoomLevel.wrappedValue * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        
                        Button(action: zoomIn) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .disabled(selectedTabZoomLevel.wrappedValue >= 5.0)
                        
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
            if let document = selectedTab.document {
                PDFViewWrapper(document: document,
                             documentName: selectedTab.title,
                             documentURL: selectedTab.documentURL,
                             currentPage: selectedTabCurrentPage, 
                             totalPages: selectedTabTotalPages,
                             zoomLevel: selectedTabZoomLevel,
                             searchText: selectedTabSearchText,
                             updateTrigger: updateTrigger)
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
                    
                    HStack(spacing: 16) {
                        Button("Open PDF Document") {
                            openPDF()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    Text("Or drag & drop a PDF file here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                TitleBarTabView(
                    tabs: $tabs,
                    selectedTabIndex: $selectedTabIndex,
                    onNewTab: createNewTab,
                    onCloseTab: closeTab
                )
            }
        }
        .navigationTitle("") // Remove window title
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
        .onReceive(selectedTab.$currentPage) { newPage in
            // Force UI update when page changes from scrolling
            updateTrigger += 1
        }
        .onReceive(selectedTab.$totalPages) { newTotal in
            // Force UI update when total pages changes
            updateTrigger += 1
        }
    }
    
    // MARK: - Actions
    
    private func openPDF() {
        showingFileImporter = true
    }
    
    private func createNewTab() {
        let newTab = DocumentTab()
        tabs.append(newTab)
        selectedTabIndex = tabs.count - 1
    }
    
    private func closeTab(at index: Int) {
        guard tabs.count > 1 && index < tabs.count else { return }
        
        tabs.remove(at: index)
        
        // Adjust selected tab index if necessary
        if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        } else if selectedTabIndex > index {
            selectedTabIndex -= 1
        }
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
        selectedTab.loadPDF(from: url)
    }
    
    private func performSearch() {
        // Search functionality will be implemented later
        print("Searching for: \(selectedTab.searchText)")
    }
    
    private func previousPage() {
        if selectedTab.currentPage > 1 {
            selectedTabCurrentPage.wrappedValue = selectedTab.currentPage - 1
            updateTrigger += 1 // Force PDFViewWrapper update
        }
    }
    
    private func nextPage() {
        if selectedTab.currentPage < selectedTab.totalPages {
            selectedTabCurrentPage.wrappedValue = selectedTab.currentPage + 1
            updateTrigger += 1 // Force PDFViewWrapper update
        }
    }
    
    private func zoomIn() {
        selectedTabZoomLevel.wrappedValue = min(selectedTabZoomLevel.wrappedValue + 0.25, 5.0)
        updateTrigger += 1 // Force PDFViewWrapper update
    }
    
    private func zoomOut() {
        selectedTabZoomLevel.wrappedValue = max(selectedTabZoomLevel.wrappedValue - 0.25, 0.25)
        updateTrigger += 1 // Force PDFViewWrapper update
    }
    
    private func resetZoom() {
        selectedTabZoomLevel.wrappedValue = 1.0
        updateTrigger += 1 // Force PDFViewWrapper update
    }
} 
