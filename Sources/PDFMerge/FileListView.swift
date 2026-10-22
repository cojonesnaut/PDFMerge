import SwiftUI
import UniformTypeIdentifiers

/// Left panel: header bar plus the drop zone / file list.
struct MergePanel: View {
    @EnvironmentObject private var store: MergeStore
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            dropZone
                .padding(.leading, 18)
                .padding(.trailing, 15)
                .padding(.top, 17)
                .padding(.bottom, 17)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Sort by Name (A–Z)") { store.sortByName(ascending: true) }
                Button("Sort by Name (Z–A)") { store.sortByName(ascending: false) }
                Button("Reverse Order") { store.reverse() }
                Divider()
                Button("Add Folder…") { store.presentOpenPanel(folders: true) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal").font(.system(size: 15, weight: .light))
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
            }
            .menuStyle(.button)
            .buttonStyle(IconButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(store.files.isEmpty)

            Text("PDF Merge")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.leading, 13)

            Spacer()

            Button { store.presentOpenPanel() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .regular))
                    Text("Add Files")
                }
            }
            .buttonStyle(GlassRectButtonStyle(prominent: true))
            .frame(width: 144)

            Button("Clear List") { withAnimation(.easeOut(duration: 0.2)) { store.clear() } }
                .buttonStyle(GlassRectButtonStyle(enabled: !store.files.isEmpty))
                .disabled(store.files.isEmpty)
                .frame(width: 144)
                .padding(.leading, 8)
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.top, 8)
        .foregroundStyle(Theme.text)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(dropTargeted ? Theme.text.opacity(0.04) : .clear)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(dropTargeted ? Theme.outline : Theme.dashed,
                              style: StrokeStyle(lineWidth: dropTargeted ? 1.5 : 1, dash: [3, 3]))
            if store.files.isEmpty {
                EmptyDropContent()
            } else {
                FileList()
                    .padding(8)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            loadURLs(from: providers) { store.add(urls: $0) }
            return true
        }
    }
}

private struct SpacedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) { configuration.icon; configuration.title }
    }
}

private struct EmptyDropContent: View {
    @EnvironmentObject private var store: MergeStore

    var body: some View {
        VStack(spacing: 0) {
            DropIllustration()
                .padding(.leading, 10)
            Text("Drag and drop files here.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 14)
            SplitAddButton()
                .padding(.top, 15)
        }
        .offset(y: -12)
    }
}

/// "+ Add Files | ▾" — one neutral glass rounded rectangle split in two: the main part opens files,
/// the arrow pops up a menu that also offers a folder. Hover highlights the whole button, like the
/// top-bar Add Files.
private struct SplitAddButton: View {
    @EnvironmentObject private var store: MergeStore
    @State private var hovering = false
    @State private var anchor: NSView?

    var body: some View {
        HStack(spacing: 0) {
            Button { store.presentOpenPanel() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .regular))
                    Text("Add Files")
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
            }
            .buttonStyle(SplitSegmentStyle())

            Rectangle()
                .fill(Theme.text.opacity(0.18))
                .frame(width: 1, height: 33)

            Button(action: showMenu) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                    .frame(width: 32)
            }
            .buttonStyle(SplitSegmentStyle())
        }
        .background(Theme.text.opacity(hovering ? 0.06 : 0))
        .background(ViewGrabber(view: $anchor))
        .onHover { hovering = $0 }
        .neutralGlass()
    }

    private func showMenu() {
        guard let anchor else { return }
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("Add Files…") { store.presentOpenPanel() })
        menu.addItem(ClosureMenuItem("Add Folder…") { store.presentOpenPanel(folders: true) })
        let below = anchor.isFlipped ? anchor.bounds.maxY + 4 : anchor.bounds.minY - 4
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: below), in: anchor)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}

/// Exposes the AppKit view behind a SwiftUI view so a menu can be positioned against it.
private struct ViewGrabber: NSViewRepresentable {
    @Binding var view: NSView?
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { view = nsView }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private extension View {
    /// Neutral glass rounded rectangle, matching `GlassRectButtonStyle`.
    func neutralGlass() -> some View {
        font(Theme.body.weight(.medium))
            .foregroundStyle(Theme.text)
            .frame(height: 33)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .liquidGlass(in: RoundedRectangle(cornerRadius: 9), fallback: Theme.disabledButton)
    }
}

/// One half of the split button: full-height hit area with a press highlight; hover is drawn
/// for the whole button by `SplitAddButton`.
private struct SplitSegmentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: 33)
            .background(Theme.text.opacity(configuration.isPressed ? 0.08 : 0))
            .contentShape(Rectangle())
    }
}

// MARK: - List

private struct FileList: View {
    @EnvironmentObject private var store: MergeStore
    @State private var dragging: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(store.files.count) file\(store.files.count == 1 ? "" : "s") · \(store.totalPages) page\(store.totalPages == 1 ? "" : "s")")
                Spacer()
                Text("Page Range").frame(width: 170, alignment: .leading)
                Color.clear.frame(width: 22, height: 1)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach($store.files) { $file in
                        FileRow(file: $file, index: (store.files.firstIndex { $0.id == file.id } ?? 0) + 1)
                            .opacity(dragging == file.id ? 0.4 : 1)
                            .onDrag {
                                dragging = file.id
                                return NSItemProvider(object: file.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text, .fileURL],
                                    delegate: RowDropDelegate(target: file.id, store: store, dragging: $dragging))
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.automatic)

            Text("Drag rows to reorder · Drop more files anywhere in this area")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mutedText)
                .padding(.vertical, 6)
        }
    }
}

private struct FileRow: View {
    @Binding var file: MergeFile
    let index: Int
    @EnvironmentObject private var store: MergeStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mutedText)
            Text("\(index)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .frame(minWidth: 16)
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(details)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 12)
            PlainField(placeholder: file.pageCount > 1 ? "All pages (e.g. 1-3, 5)" : "All pages",
                       text: $file.pageRange, height: 28, invalid: file.selectedPages == nil)
                .frame(width: 170)
                .disabled(file.pageCount <= 1)
                .help("Pages to include. Examples: 1-3, 5, 8-  ·  Leave empty for all pages.")
            Button { withAnimation(.easeOut(duration: 0.15)) { store.remove(file) } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hovering ? Theme.text : Theme.mutedText)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(hovering ? Theme.disabledButton : .clear))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Theme.rowHover : Theme.row))
        .onHover { hovering = $0 }
    }

    private var thumbnail: some View {
        Group {
            if let image = file.thumbnail {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc").foregroundStyle(Theme.mutedText)
            }
        }
        .frame(width: 32, height: 42)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.fieldBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
    }

    private var details: String {
        let pages = file.isImage ? "Image" : "\(file.pageCount) page\(file.pageCount == 1 ? "" : "s")"
        let size = ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file)
        if let selected = file.selectedPages, selected.count != file.pageCount {
            return "\(pages) · \(selected.count) selected · \(size)"
        }
        return "\(pages) · \(size)"
    }
}

/// Live reordering while a row is dragged; external files dropped on a row are inserted before it.
private struct RowDropDelegate: DropDelegate {
    let target: UUID
    let store: MergeStore
    @Binding var dragging: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = store.files.firstIndex(where: { $0.id == dragging }),
              let to = store.files.firstIndex(where: { $0.id == target }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: dragging == nil ? .copy : .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if dragging != nil {
            dragging = nil
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }
        let index = store.files.firstIndex { $0.id == target }
        loadURLs(from: providers) { store.add(urls: $0, at: index) }
        return true
    }
}

/// Resolves dropped file URLs and hands them back on the main actor, in drop order.
func loadURLs(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
    var urls = [URL?](repeating: nil, count: providers.count)
    let group = DispatchGroup()
    for (i, provider) in providers.enumerated() {
        group.enter()
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            DispatchQueue.main.async {
                urls[i] = url
                group.leave()
            }
        }
    }
    group.notify(queue: .main) {
        MainActor.assumeIsolated { completion(urls.compactMap { $0 }) }
    }
}
