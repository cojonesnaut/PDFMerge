import SwiftUI

struct OptionsPanel: View {
    @EnvironmentObject private var store: MergeStore
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pageSizeOptions
                    if store.sizeMode == .standardize {
                        divider
                        pageSize
                        orientation
                    }
                    divider
                    fileName
                }
                .padding(.horizontal, 16)
                .padding(.top, 15)
                .animation(.easeInOut(duration: 0.18), value: store.sizeMode)
            }
            .scrollIndicators(.never)

            applyButton
        }
    }

    // MARK: Sections

    private var pageSizeOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                heading("Page Size Options")
                Spacer()
                Button { showInfo.toggle() } label: {
                    Image(systemName: "info.circle").font(.system(size: 15, weight: .light))
                }
                .buttonStyle(IconButtonStyle())
                .popover(isPresented: $showInfo, arrowEdge: .bottom) { infoPopover }
            }
            .frame(height: 16)
            .padding(.bottom, 16)

            PopupField(
                id: "sizeMode",
                items: SizeMode.allCases.map { DropdownItem(id: $0.rawValue, title: $0.title) },
                selectedID: store.sizeMode.rawValue
            ) { store.sizeMode = SizeMode(rawValue: $0) ?? .standardize }
        }
    }

    private var pageSize: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                heading("Page Size")
                Text("(\(store.unit.rawValue))")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Menu {
                    Picker("Unit", selection: $store.unit) {
                        ForEach(LengthUnit.allCases, id: \.self) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Image(systemName: "gearshape").font(.system(size: 17, weight: .light))
                }
                .menuStyle(.button)
                .buttonStyle(IconButtonStyle())
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Measurement unit")
            }
            .frame(height: 16)
            .padding(.bottom, 16)

            PopupField(
                id: "paper",
                items: PaperSize.allCases.map { paper in
                    DropdownItem(id: paper.rawValue, title: paper.rawValue, detail: paper.points.map {
                        "\(formatLength($0.width, store.unit)) × \(formatLength($0.height, store.unit)) \(store.unit.rawValue)"
                    })
                },
                selectedID: store.paper.rawValue
            ) { store.paper = PaperSize(rawValue: $0) ?? .a4 }
            .padding(.bottom, 14)

            HStack(spacing: 16) {
                DimensionField(label: "W", points: store.pageSize.width, unit: store.unit,
                               dimmed: store.paper != .custom) { store.setDimension(width: $0) }
                DimensionField(label: "H", points: store.pageSize.height, unit: store.unit,
                               dimmed: store.paper != .custom) { store.setDimension(height: $0) }
            }
            .padding(.bottom, 24)
        }
    }

    private var orientation: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Orientation").frame(height: 16).padding(.bottom, 16)
            HStack(spacing: 16) {
                OrientationCard(title: "Portrait", landscape: false, selected: store.orientation == .portrait) {
                    store.orientation = .portrait
                }
                OrientationCard(title: "Landscape", landscape: true, selected: store.orientation == .landscape) {
                    store.orientation = .landscape
                }
            }
            .glassGroup(spacing: 16)
        }
    }

    private var fileName: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("File Name").frame(height: 16).padding(.bottom, 17)
            PlainField(placeholder: "Merge.pdf", text: $store.fileName)
        }
    }

    private var applyButton: some View {
        VStack(spacing: 8) {
            if store.isMerging {
                ProgressView(value: store.progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.outline)
            }
            Button(store.isMerging ? "Merging…" : "Apply") { store.apply() }
                .buttonStyle(GlassRectButtonStyle(prominent: true, enabled: store.canApply))
                .disabled(!store.canApply)
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    // MARK: Pieces

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1).padding(.vertical, 16)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.heading).foregroundStyle(Theme.text)
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep original size").font(Theme.heading)
            Text("Every page keeps its own dimensions. Links, annotations and form fields are preserved.")
            Text("Standardize page size").font(Theme.heading).padding(.top, 4)
            Text("Every page is scaled to fit the chosen paper size and centered, so the merged PDF has uniform pages. Text stays selectable.")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.text)
        .frame(width: 260, alignment: .leading)
        .padding(14)
    }
}
