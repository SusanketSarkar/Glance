import Foundation
import SwiftUI
import PDFKit
import CryptoKit

class AnnotationManager: ObservableObject {
    static let shared = AnnotationManager()
    
    private let documentsDirectory: URL
    private let annotationsDirectory: URL
    
    private init() {
        // Create annotations directory in Documents folder
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.annotationsDirectory = documentsDirectory.appendingPathComponent("GlanceAnnotations")
        
        // Ensure annotations directory exists
        try? FileManager.default.createDirectory(at: annotationsDirectory, withIntermediateDirectories: true)
        
        print("📁 AnnotationManager initialized. Storage: \(annotationsDirectory.path)")
    }
    
    // MARK: - Document Hashing
    
    /// Generate a simple, consistent identifier for a PDF document
    private func generateDocumentHash(from url: URL) -> String? {
        // Use file URL path + size as identifier - much faster and more consistent
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else { 
            print("❌ Failed to get file attributes for: \(url.path)")
            return nil 
        }
        
        let filename = url.lastPathComponent
        let identifier = filename + "_" + fileSize.stringValue
        
        // Clean up the identifier by removing problematic characters
        let cleanIdentifier = identifier
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "...", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        
        print("🔍 Generated URL hash: '\(cleanIdentifier)' for '\(filename)'")
        return cleanIdentifier
    }
    
    private func generateDocumentHash(from pdfDocument: PDFDocument) -> String? {
        // For PDFDocument without URL, use page count and basic content hash
        let pageCount = pdfDocument.pageCount
        let basicId = "doc_\(pageCount)_\(pdfDocument.string?.prefix(100).hash ?? 0)"
        return basicId.replacingOccurrences(of: " ", with: "_")
    }
    
    // MARK: - File Management
    
    private func annotationsFileURL(for documentHash: String) -> URL {
        return annotationsDirectory.appendingPathComponent("\(documentHash).json")
    }
    
    // Try to find annotation file with potential hash variations
    private func findAnnotationFile(for documentHash: String) -> URL? {
        let primaryURL = annotationsFileURL(for: documentHash)
        if FileManager.default.fileExists(atPath: primaryURL.path) {
            print("✅ Found exact annotation file: \(primaryURL.lastPathComponent)")
            return primaryURL
        }
        
        // Look for existing files that might match (for backward compatibility)
        do {
            let files = try FileManager.default.contentsOfDirectory(at: annotationsDirectory, 
                                                                   includingPropertiesForKeys: nil)
            
            print("🔍 Searching through \(files.count) annotation files...")
            
            // Extract the file size from the target hash
            let components = documentHash.split(separator: "_")
            guard let targetFileSize = components.last else { return nil }
            
            // Look for files ending with the same file size
            for file in files where file.pathExtension == "json" {
                let filename = file.deletingPathExtension().lastPathComponent
                print("🔍 Checking file: \(filename)")
                
                if filename.hasSuffix("_\(targetFileSize)") {
                    print("✅ Found matching file by size: \(filename)")
                    return file
                }
            }
        } catch {
            print("❌ Error searching for annotation files: \(error)")
        }
        
        print("❌ No matching annotation file found")
        return nil
    }
    
    // MARK: - Save Annotations
    
    func saveAnnotation(_ annotationData: AnnotationData, for document: PDFDocument, documentName: String) {
        guard let documentHash = self.generateDocumentHash(from: document) else {
            print("❌ Failed to generate document hash")
            return
        }
        
        self.saveAnnotationWithHash(annotationData, documentHash: documentHash, documentName: documentName)
    }
    
    func saveAnnotation(_ annotationData: AnnotationData, forURL url: URL, documentName: String) {
        guard let documentHash = self.generateDocumentHash(from: url) else {
            print("❌ Failed to generate document hash from URL")
            return
        }
        
        self.saveAnnotationWithHash(annotationData, documentHash: documentHash, documentName: documentName)
    }
    
    private let saveQueue = DispatchQueue(label: "com.glance.annotations.save", qos: .utility)
    private var fileLocks: [String: NSLock] = [:]
    private let lockQueueSync = DispatchQueue(label: "com.glance.annotations.locks")
    
    private func getFileLock(for documentHash: String) -> NSLock {
        return lockQueueSync.sync {
            if let existingLock = fileLocks[documentHash] {
                return existingLock
            } else {
                let newLock = NSLock()
                fileLocks[documentHash] = newLock
                return newLock
            }
        }
    }
    
    private func saveAnnotationWithHash(_ annotationData: AnnotationData, documentHash: String, documentName: String) {
        saveQueue.async {
            let lock = self.getFileLock(for: documentHash)
            
            lock.lock()
            defer { lock.unlock() }
            
            let fileURL = self.annotationsFileURL(for: documentHash)
            
            // Load existing annotations or create new document annotations
            var documentAnnotations: DocumentAnnotations
            if let existingAnnotations = self.loadDocumentAnnotations(for: documentHash) {
                documentAnnotations = existingAnnotations
            } else {
                documentAnnotations = DocumentAnnotations(
                    documentHash: documentHash,
                    documentName: documentName
                )
            }
            
            // Add or update annotation
            if let existingIndex = documentAnnotations.annotations.firstIndex(where: { $0.id == annotationData.id }) {
                documentAnnotations.annotations[existingIndex] = annotationData
            } else {
                documentAnnotations.annotations.append(annotationData)
            }
            
            // Atomic save to file using temporary file + rename
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(documentAnnotations)
                
                // Write to temporary file first
                let tempURL = fileURL.appendingPathExtension("tmp")
                try data.write(to: tempURL)
                
                // Atomic move to final location
                _ = try FileManager.default.replaceItem(at: fileURL, withItemAt: tempURL, 
                                                     backupItemName: nil, options: [], 
                                                     resultingItemURL: nil)
                
                print("💾 Atomically saved annotation for document: \(documentName) (Hash: \(documentHash))")
            } catch {
                print("❌ Failed to save annotations: \(error)")
            }
        }
    }
    
    // MARK: - Load Annotations
    
    func loadAnnotations(for document: PDFDocument) -> [AnnotationData] {
        guard let documentHash = generateDocumentHash(from: document),
              let documentAnnotations = loadDocumentAnnotations(for: documentHash) else {
            return []
        }
        
        print("📖 Loaded \(documentAnnotations.annotations.count) annotations for document")
        return documentAnnotations.annotations
    }
    
    func loadAnnotations(for documentURL: URL) -> [AnnotationData] {
        print("🔍 Loading annotations for URL: \(documentURL.lastPathComponent)")
        guard let documentHash = generateDocumentHash(from: documentURL) else {
            print("❌ Failed to generate hash for URL: \(documentURL.lastPathComponent)")
            return []
        }
        
        print("🔍 Looking for annotation file with hash: \(documentHash)")
        guard let documentAnnotations = loadDocumentAnnotations(for: documentHash) else {
            print("❌ No saved annotations found for hash: \(documentHash)")
            return []
        }
        
        print("📖 Loaded \(documentAnnotations.annotations.count) annotations for document from URL")
        return documentAnnotations.annotations
    }
    
    private func loadDocumentAnnotations(for documentHash: String) -> DocumentAnnotations? {
        print("🔍 Looking for annotation file with hash: \(documentHash)")
        
        guard let fileURL = findAnnotationFile(for: documentHash) else {
            print("❌ No annotation file found for hash: \(documentHash)")
            return nil
        }
        
        print("✅ Found annotation file at: \(fileURL.path)")
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // Validate JSON before parsing
            if let jsonString = String(data: data, encoding: .utf8) {
                // Check for obvious corruption patterns
                if jsonString.hasSuffix("}") == false {
                    print("⚠️ JSON file appears corrupted (doesn't end with '}'), attempting to repair...")
                    // Try to find the last valid closing brace
                    if let lastBraceIndex = jsonString.lastIndex(of: "}") {
                        let repairedString = String(jsonString[...lastBraceIndex])
                        if let repairedData = repairedString.data(using: .utf8) {
                            return try parseJSON(from: repairedData, fileURL: fileURL)
                        }
                    }
                }
            }
            
            return try parseJSON(from: data, fileURL: fileURL)
        } catch {
            print("❌ Failed to load annotations from \(fileURL.path): \(error)")
            return nil
        }
    }
    
    private func parseJSON(from data: Data, fileURL: URL) throws -> DocumentAnnotations {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(DocumentAnnotations.self, from: data)
        print("✅ Successfully loaded annotation file with \(result.annotations.count) annotations")
        return result
    }
    
    // MARK: - Delete Annotations
    
    func deleteAnnotation(_ annotationId: UUID, for document: PDFDocument) {
        guard let documentHash = generateDocumentHash(from: document) else { return }
        
        var documentAnnotations = loadDocumentAnnotations(for: documentHash)
        documentAnnotations?.annotations.removeAll { $0.id == annotationId }
        
        if let updatedAnnotations = documentAnnotations {
            let fileURL = annotationsFileURL(for: documentHash)
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(updatedAnnotations)
                try data.write(to: fileURL)
                print("🗑️ Deleted annotation \(annotationId)")
            } catch {
                print("❌ Failed to delete annotation: \(error)")
            }
        }
    }
    
    // MARK: - Restore Annotations to PDF
    
    func restoreAnnotationsToPDF(_ document: PDFDocument) {
        let savedAnnotations = loadAnnotations(for: document)
        
        for annotationData in savedAnnotations {
            guard let page = document.page(at: annotationData.pageIndex) else { continue }
            
            let pdfAnnotation = createPDFAnnotation(from: annotationData)
            page.addAnnotation(pdfAnnotation)
            print("✅ Restored \(annotationData.type.rawValue) annotation to page \(annotationData.pageIndex)")
        }
    }
    
    func restoreAnnotationsToPDF(_ document: PDFDocument, fromURL url: URL) {
        print("🔄 Attempting to restore annotations from URL: \(url.lastPathComponent)")
        let savedAnnotations = loadAnnotations(for: url)
        print("📖 Found \(savedAnnotations.count) saved annotations to restore")
        
        for annotationData in savedAnnotations {
            guard let page = document.page(at: annotationData.pageIndex) else { 
                print("❌ Could not get page \(annotationData.pageIndex) for restoration")
                continue 
            }
            
            let pdfAnnotation = createPDFAnnotation(from: annotationData)
            page.addAnnotation(pdfAnnotation)
            print("✅ Restored \(annotationData.type.rawValue) annotation from URL to page \(annotationData.pageIndex)")
        }
    }
    
    private func createPDFAnnotation(from data: AnnotationData) -> PDFAnnotation {
        let bounds = data.bounds.toCGRect()
        let annotationType: PDFAnnotationSubtype
        
        switch data.type {
        case .highlight:
            annotationType = .highlight
        case .underline:
            annotationType = .underline
        case .strikethrough:
            annotationType = .strikeOut
        case .note:
            annotationType = .text
        }
        
        let annotation = PDFAnnotation(bounds: bounds, forType: annotationType, withProperties: nil)
        annotation.color = data.color.toNSColor()
        
        // Set quadrilateral points if available
        if let quadPoints = data.quadrilateralPoints {
            let nsValues = quadPoints.map { NSValue(point: $0.toNSPoint()) }
            annotation.quadrilateralPoints = nsValues
        }
        
        return annotation
    }
    
    // MARK: - Utility Methods
    
    func getAllSavedDocuments() -> [DocumentAnnotations] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: annotationsDirectory, 
                                                                       includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(DocumentAnnotations.self, from: data)
            } catch {
                print("❌ Failed to load document annotations from \(url): \(error)")
                return nil
            }
        }
    }
    
    func clearAllAnnotations() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: annotationsDirectory, 
                                                                   includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            print("🧹 Cleared all saved annotations")
        } catch {
            print("❌ Failed to clear annotations: \(error)")
        }
    }
} 