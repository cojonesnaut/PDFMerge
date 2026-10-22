import AppKit
import PDFKit
import UniformTypeIdentifiers

enum SizeMode: String, CaseIterable {
    case keepOriginal, standardize

    var title: String {
        switch self {
        case .keepOriginal: "Keep original size"
        case .standardize: "Standardize page size"
        }
    }
}

enum Orientation { case portrait, landscape }

enum LengthUnit: String, CaseIterable {
    case inches = "in", millimeters = "mm", centimeters = "cm", points = "pt"

    var pointsPerUnit: Double {
        switch self {
        case .inches: 72
        case .millimeters: 72 / 25.4
        case .centimeters: 72 / 2.54
        case .points: 1
        }
    }

    var step: Double {
        switch self {
        case .inches, .centimeters: 0.1
        case .millimeters, .points: 1
        }
    }

    var name: String {
        switch self {
        case .inches: "Inches (in)"
        case .millimeters: "Millimeters (mm)"
        case .centimeters: "Centimeters (cm)"
        case .points: "Points (pt)"
        }
    }
}

enum PaperSize: String, CaseIterable {
    case letter = "Letter", legal = "Legal", tabloid = "Tabloid"
    case a4 = "A4", a3 = "A3", a5 = "A5", b5 = "B5", custom = "Custom"

    /// Portrait size in points.
    var points: CGSize? {
        switch self {
        case .letter: CGSize(width: 612, height: 792)
        case .legal: CGSize(width: 612, height: 1008)
        case .tabloid: CGSize(width: 792, height: 1224)
        case .a4: CGSize(width: 595.28, height: 841.89)
        case .a3: CGSize(width: 841.89, height: 1190.55)
        case .a5: CGSize(width: 419.53, height: 595.28)
        case .b5: CGSize(width: 498.9, height: 708.66)
        case .custom: nil
        }
    }
}

func formatLength(_ points: Double, _ unit: LengthUnit) -> String {
    (points / unit.pointsPerUnit).formatted(.number.precision(.fractionLength(0...2)))
}

// MARK: - Files

struct MergeFile: Identifiable {
    let id = UUID()
    let url: URL
    let document: PDFDocument
    let isImage: Bool
    let fileSize: Int64
    var thumbnail: NSImage?
    var pageRange: String = ""

    init(url: URL, document: PDFDocument, isImage: Bool) {
        self.url = url
        self.document = document
        self.isImage = isImage
        self.fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        if let page = document.page(at: 0) {
            thumbnail = page.thumbnail(of: CGSize(width: 96, height: 128), for: .cropBox)
        }
    }

    var name: String { url.lastPathComponent }
    var pageCount: Int { document.pageCount }

    /// Zero-based page indexes chosen by `pageRange`; nil when the range text is invalid.
    var selectedPages: [Int]? { PageRangeParser.parse(pageRange, pageCount: pageCount) }
}

enum PageRangeParser {
    /// Accepts "", "all", "1-3, 5, 8-", "-4", "7-2" (descending). Pages are 1-based in the text.
    static func parse(_ text: String, pageCount: Int) -> [Int]? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "all" { return Array(0..<pageCount) }
        var result: [Int] = []
        for part in trimmed.split(separator: ",") {
            let token = part.trimmingCharacters(in: .whitespaces)
            if token.isEmpty { continue }
            if token.contains("-") {
                let bounds = token.split(separator: "-", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2 else { return nil }
                let lo = bounds[0].isEmpty ? 1 : Int(bounds[0])
                let hi = bounds[1].isEmpty ? pageCount : Int(bounds[1])
                guard let lo, let hi, (1...pageCount).contains(lo), (1...pageCount).contains(hi) else { return nil }
                let range = lo <= hi ? Array(lo...hi) : Array((hi...lo).reversed())
                result += range.map { $0 - 1 }
            } else {
                guard let n = Int(token), (1...pageCount).contains(n) else { return nil }
                result.append(n - 1)
            }
        }
        return result.isEmpty ? nil : result
    }
}

// MARK: - Store

@MainActor
final class MergeStore: ObservableObject {
    @Published var files: [MergeFile] = []
    @Published var sizeMode: SizeMode = .standardize
    @Published var paper: PaperSize = .a4 {
        didSet { if let size = paper.points { pageSize = oriented(size) } }
    }
    /// Output page size in points, orientation applied: what W/H show and what pages are fitted to.
    @Published var pageSize = PaperSize.a4.points!
    @Published var orientation: Orientation = .portrait {
        didSet { pageSize = oriented(pageSize) }
    }
    @Published var unit: LengthUnit = .inches
    @Published var fileName = ""
    @Published var isMerging = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    static let acceptedTypes: [UTType] = [.pdf, .png, .jpeg, .tiff, .heic, .gif, .bmp, .webP]

    var totalPages: Int {
        files.reduce(0) { $0 + ($1.selectedPages?.count ?? 0) }
    }

    var canApply: Bool {
        !files.isEmpty && !isMerging && files.allSatisfy { $0.selectedPages != nil }
            && pageSize.width >= 1 && pageSize.height >= 1
    }

    /// `size` with its long side vertical for portrait, horizontal for landscape.
    private func oriented(_ size: CGSize) -> CGSize {
        let short = min(size.width, size.height), long = max(size.width, size.height)
        return orientation == .portrait ? CGSize(width: short, height: long) : CGSize(width: long, height: short)
    }

    /// Typing a width or height makes the size custom; a wider-than-tall size switches to landscape.
    func setDimension(width: Double? = nil, height: Double? = nil) {
        paper = .custom
        var size = pageSize
        if let width { size.width = max(1, width) }
        if let height { size.height = max(1, height) }
        pageSize = size
        if size.width != size.height {
            orientation = size.width > size.height ? .landscape : .portrait
        }
    }

    // MARK: Adding

    func add(urls: [URL], at index: Int? = nil) {
        var expanded: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                expanded += contents(ofFolder: url)
            } else {
                expanded.append(url)
            }
        }
        var newFiles: [MergeFile] = []
        var skipped: [String] = []
        for url in expanded {
            if let file = load(url) { newFiles.append(file) } else { skipped.append(url.lastPathComponent) }
        }
        let insertAt = min(index ?? files.count, files.count)
        files.insert(contentsOf: newFiles, at: insertAt)
        if !skipped.isEmpty {
            errorMessage = "Couldn't add: " + skipped.joined(separator: ", ")
        }
    }

    private func contents(ofFolder folder: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { url in
                guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
                return Self.acceptedTypes.contains { type.conforms(to: $0) }
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func load(_ url: URL) -> MergeFile? {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            guard let doc = PDFDocument(url: url) else { return nil }
            if doc.isLocked, !unlock(doc, name: url.lastPathComponent) { return nil }
            guard doc.pageCount > 0 else { return nil }
            return MergeFile(url: url, document: doc, isImage: false)
        }
        guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { return nil }
        let doc = PDFDocument()
        doc.insert(page, at: 0)
        return MergeFile(url: url, document: doc, isImage: true)
    }

    private func unlock(_ doc: PDFDocument, name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "“\(name)” is password protected"
        alert.informativeText = "Enter the password to add this file to the merge list."
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Skip")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        while alert.runModal() == .alertFirstButtonReturn {
            if doc.unlock(withPassword: field.stringValue) { return true }
            alert.informativeText = "Incorrect password. Try again."
            field.stringValue = ""
        }
        return false
    }

    // MARK: Editing

    func remove(_ file: MergeFile) { files.removeAll { $0.id == file.id } }
    func clear() { files.removeAll() }
    func move(from source: IndexSet, to destination: Int) { files.move(fromOffsets: source, toOffset: destination) }

    func sortByName(ascending: Bool) {
        files.sort {
            let r = $0.name.localizedStandardCompare($1.name)
            return ascending ? r == .orderedAscending : r == .orderedDescending
        }
    }

    func reverse() { files.reverse() }

    // MARK: Panels

    func presentOpenPanel(folders: Bool = false) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = folders
        panel.canChooseFiles = !folders
        panel.allowedContentTypes = folders ? [.folder] : Self.acceptedTypes
        panel.prompt = "Add"
        panel.message = folders ? "Choose folders — PDFs and images inside will be added." : nil
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func apply() {
        guard canApply else { return }
        var name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Merge.pdf" }
        if !name.lowercased().hasSuffix(".pdf") { name += ".pdf" }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = name
        panel.directoryURL = files.first?.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let output = panel.url else { return }

        let jobs = files.map { MergeJob.Source(document: $0.document, pages: $0.selectedPages ?? []) }
        let job = MergeJob(sources: jobs,
                           pageSize: sizeMode == .standardize ? pageSize : nil,
                           output: output)
        isMerging = true
        progress = 0
        Task {
            do {
                try await job.run { value in
                    Task { @MainActor in self.progress = value }
                }
                isMerging = false
                NSWorkspace.shared.activateFileViewerSelecting([output])
            } catch {
                isMerging = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
