import Foundation
import PDFKit

/// Writes the merged PDF. Runs off the main thread.
struct MergeJob: @unchecked Sendable {
    struct Source {
        let document: PDFDocument
        let pages: [Int]
    }

    enum Failure: LocalizedError {
        case cannotCreate(URL)
        case cannotWrite(URL)
        var errorDescription: String? {
            switch self {
            case .cannotCreate(let url): "Couldn't create “\(url.lastPathComponent)”."
            case .cannotWrite(let url): "Couldn't write “\(url.lastPathComponent)”."
            }
        }
    }

    let sources: [Source]
    /// nil keeps every page at its original size.
    let pageSize: CGSize?
    let output: URL

    func run(progress: @escaping @Sendable (Double) -> Void) async throws {
        try await Task.detached(priority: .userInitiated) {
            if let pageSize {
                try writeStandardized(size: pageSize, progress: progress)
            } else {
                try writeOriginal(progress: progress)
            }
        }.value
    }

    private var total: Double { Double(max(1, sources.reduce(0) { $0 + $1.pages.count })) }

    /// Copies pages as-is, keeping links, annotations and outlines intact.
    private func writeOriginal(progress: (Double) -> Void) throws {
        let out = PDFDocument()
        var done = 0.0
        for source in sources {
            for index in source.pages {
                guard let page = source.document.page(at: index)?.copy() as? PDFPage else { continue }
                out.insert(page, at: out.pageCount)
                done += 1
                progress(done / total)
            }
        }
        guard out.write(to: output) else { throw Failure.cannotWrite(output) }
    }

    /// Re-draws every page as vector content scaled to fit and centered on `size`.
    private func writeStandardized(size: CGSize, progress: (Double) -> Void) throws {
        var mediaBox = CGRect(origin: .zero, size: size)
        let info = [kCGPDFContextCreator: "PDF Merge"] as CFDictionary
        guard let ctx = CGContext(output as CFURL, mediaBox: &mediaBox, info) else {
            throw Failure.cannotCreate(output)
        }
        var done = 0.0
        for source in sources {
            for index in source.pages {
                guard let page = source.document.page(at: index) else { continue }
                let box = page.bounds(for: .cropBox)
                let rotated = page.rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
                let scale = min(size.width / rotated.width, size.height / rotated.height)
                let drawn = CGSize(width: rotated.width * scale, height: rotated.height * scale)

                ctx.beginPDFPage([kCGPDFContextMediaBox: NSData(bytes: &mediaBox, length: MemoryLayout<CGRect>.size)] as CFDictionary)
                ctx.saveGState()
                ctx.translateBy(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
                ctx.scaleBy(x: scale, y: scale)
                // PDFPage.draw applies the page's rotation and crop-box origin itself.
                page.draw(with: .cropBox, to: ctx)
                ctx.restoreGState()
                ctx.endPDFPage()

                done += 1
                progress(done / total)
            }
        }
        ctx.closePDF()
    }
}
