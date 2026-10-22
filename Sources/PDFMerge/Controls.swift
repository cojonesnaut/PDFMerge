import SwiftUI

// MARK: - Dropdown
//
// The open list lives in a borderless child window under the field, so it can overlap
// neighbouring controls and receives clicks like a real menu.

struct DropdownItem: Identifiable {
    let id: String
    let title: String
    var detail: String? = nil
}

/// The closed field: "Standardize page size  ▾".
struct PopupField: View {
    let id: String
    let items: [DropdownItem]
    let selectedID: String
    let onSelect: (String) -> Void
    @StateObject private var presenter = DropdownPresenter()
    @State private var hovering = false

    var body: some View {
        Button {
            presenter.toggle(items: items, selectedID: selectedID, onSelect: onSelect)
        } label: {
            HStack {
                Text(items.first { $0.id == selectedID }?.title ?? "")
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: presenter.isOpen ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 6.5))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 6)
            .frame(height: 32)
            .background(FieldBackground(hovering: hovering || presenter.isOpen))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .background(DropdownAnchor(presenter: presenter))
        .onDisappear { presenter.close() }
    }
}

/// Gives the presenter an AppKit view to position the list against.
private struct DropdownAnchor: NSViewRepresentable {
    let presenter: DropdownPresenter
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        presenter.anchorView = view
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { presenter.anchorView = nsView }
}

@MainActor
final class DropdownPresenter: ObservableObject {
    @Published private(set) var isOpen = false
    weak var anchorView: NSView?
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    func toggle(items: [DropdownItem], selectedID: String, onSelect: @escaping (String) -> Void) {
        if isOpen { close() } else { open(items: items, selectedID: selectedID, onSelect: onSelect) }
    }

    func open(items: [DropdownItem], selectedID: String, onSelect: @escaping (String) -> Void) {
        guard let anchor = anchorView, let window = anchor.window else { return }
        let field = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))

        let menu = DropdownMenu(items: items, selectedID: selectedID) { [weak self] id in
            self?.close()
            onSelect(id)
        }
        .frame(width: field.width)
        let host = FirstMouseHostingView(rootView: menu)
        let size = host.fittingSize

        let panel = DropdownPanel(
            contentRect: NSRect(x: field.minX, y: field.minY - 6 - size.height, width: field.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.appearance = window.effectiveAppearance
        window.addChildWindow(panel, ordered: .above)
        DispatchQueue.main.async { panel.invalidateShadow() }
        self.panel = panel

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.type == .keyDown {
                guard event.keyCode == 53 else { return event } // Escape
                self.close()
                return nil
            }
            if event.window === panel { return event }
            // A click on the field itself only closes; swallow it so the button doesn't reopen the list.
            if let anchor = self.anchorView, event.window === anchor.window,
               anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil)) {
                self.close()
                return nil
            }
            self.close()
            return event
        }
        let center = NotificationCenter.default
        for name in [NSApplication.didResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            })
        }
        for name in [NSWindow.didResizeNotification, NSWindow.didResignKeyNotification] {
            observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            })
        }
        isOpen = true
    }

    func close() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        isOpen = false
    }
}

private final class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The open list. The selected row stays highlighted (as in the reference); other rows get a
/// lighter tint on hover.
struct DropdownMenu: View {
    let items: [DropdownItem]
    let selectedID: String
    let onSelect: (String) -> Void
    @State private var hoveredID: String?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(items) { item in
                let selected = item.id == selectedID
                Button { onSelect(item.id) } label: {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .foregroundStyle(Theme.text)
                        if let detail = item.detail {
                            Text(detail)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .font(Theme.body)
                    .padding(.horizontal, 8)
                    .frame(height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: 4).fill(
                            selected ? Theme.selection
                                : hoveredID == item.id ? Theme.text.opacity(0.07) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { hoveredID = item.id } else if hoveredID == item.id { hoveredID = nil }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.menuBackground))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.menuBorder, lineWidth: 0.5))
    }
}

// MARK: - Fields

struct FieldBackground: View {
    var hovering = false
    var focused = false
    var invalid = false

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(hovering ? Theme.fieldHover : Theme.field)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(invalid ? Theme.danger : focused ? Theme.outline : Theme.fieldBorder,
                                  lineWidth: focused || invalid ? 1.2 : 0.75)
            )
    }
}

struct PlainField: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 32
    var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.mutedText))
            .textFieldStyle(.plain)
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .focused($focused)
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(FieldBackground(focused: focused, invalid: invalid))
    }
}

/// "W [ 8,27  ⇕ ]" — number field in the current unit, with tiny stepper arrows.
struct DimensionField: View {
    let label: String
    let points: Double
    let unit: LengthUnit
    let dimmed: Bool
    let onChange: (Double) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .frame(width: 18, alignment: .leading)
            HStack(spacing: 4) {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .foregroundStyle(dimmed && !focused ? Theme.mutedText : Theme.text)
                    .focused($focused)
                    .onSubmit(commit)
                VStack(spacing: 3) {
                    stepButton("arrowtriangle.up.fill", +1)
                    stepButton("arrowtriangle.down.fill", -1)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .frame(height: 32)
            .background(FieldBackground(focused: focused))
        }
        .onAppear(perform: refresh)
        .onChange(of: points) { refresh() }
        .onChange(of: unit) { refresh() }
        .onChange(of: focused) { if !focused { commit() } }
    }

    private func stepButton(_ symbol: String, _ direction: Double) -> some View {
        Button {
            let current = points / unit.pointsPerUnit
            let next = ((current / unit.step).rounded() + direction) * unit.step
            onChange(max(unit.step, next) * unit.pointsPerUnit)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 5.5))
                .foregroundStyle(Theme.mutedText)
                .frame(width: 12, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refresh() { text = formatLength(points, unit) }

    private func commit() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let normalized = text.trimmingCharacters(in: .whitespaces)
        let value = formatter.number(from: normalized)?.doubleValue
            ?? Double(normalized.replacingOccurrences(of: ",", with: "."))
        if let value, value > 0, abs(value * unit.pointsPerUnit - points) > 0.001 {
            onChange(value * unit.pointsPerUnit)
        } else {
            refresh()
        }
    }
}

// MARK: - Orientation

struct OrientationCard: View {
    let title: String
    let landscape: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(Theme.body).foregroundStyle(Theme.text)
                Spacer()
                PageGlyph(landscape: landscape)
                    .stroke(Theme.text, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                    .overlay(PageCorner(landscape: landscape).fill(Theme.text))
                    .frame(width: landscape ? 21 : 16, height: landscape ? 16 : 21)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .liquidGlass(tint: selected ? Theme.text.opacity(0.14) : hovering ? Theme.text.opacity(0.05) : nil,
                         in: RoundedRectangle(cornerRadius: 12),
                         fallback: selected || hovering ? Theme.selection : Theme.field)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Theme.outline.opacity(0.8) : .clear, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Page outline with a clipped corner (top-right for portrait, top-left for landscape).
struct PageGlyph: Shape {
    let landscape: Bool
    func path(in r: CGRect) -> Path {
        let c: CGFloat = 5, rad: CGFloat = 3
        var p = Path()
        if landscape {
            p.move(to: CGPoint(x: r.minX + c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - rad, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + rad), control: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
            p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        } else {
            p.move(to: CGPoint(x: r.minX + rad, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
            p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
            p.addQuadCurve(to: CGPoint(x: r.minX + rad, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        }
        p.closeSubpath()
        return p
    }
}

struct PageCorner: Shape {
    let landscape: Bool
    func path(in r: CGRect) -> Path {
        let c: CGFloat = 5.5
        var p = Path()
        if landscape {
            p.move(to: CGPoint(x: r.minX, y: r.minY + c))
            p.addLine(to: CGPoint(x: r.minX + c, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + c, y: r.minY + c - 1))
            p.addQuadCurve(to: CGPoint(x: r.minX + c - 1, y: r.minY + c), control: CGPoint(x: r.minX + c, y: r.minY + c))
        } else {
            p.move(to: CGPoint(x: r.maxX - c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
            p.addLine(to: CGPoint(x: r.maxX - c + 1, y: r.minY + c))
            p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.minY + c - 1), control: CGPoint(x: r.maxX - c, y: r.minY + c))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Buttons

extension View {
    /// Applies interactive Liquid Glass on macOS 26+, or a flat fill on older systems.
    @ViewBuilder
    func liquidGlass<S: Shape>(tint: Color? = nil, in shape: S, fallback: Color) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint).interactive(), in: shape)
        } else {
            background(shape.fill(fallback))
        }
    }

    /// Groups nearby glass shapes so they render and morph together on macOS 26+.
    @ViewBuilder
    func glassGroup(spacing: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// Neutral Liquid Glass rounded rectangle (9 pt corners, like the fields and dropdowns), 33 pt tall.
/// Prominent buttons (the main actions) only get a slightly heavier label.
struct GlassRectButtonStyle: ButtonStyle {
    var prominent = false
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        GlassRectBody(configuration: configuration, prominent: prominent, enabled: enabled)
    }

    private struct GlassRectBody: View {
        let configuration: Configuration
        let prominent: Bool
        let enabled: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(prominent ? Theme.body.weight(.medium) : Theme.body)
                .foregroundStyle(enabled ? Theme.text : Theme.disabledButtonText)
                .frame(maxWidth: .infinity)
                .frame(height: 33)
                .background(Theme.text.opacity(!enabled ? 0 : configuration.isPressed ? 0.1 : hovering ? 0.06 : 0))
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .liquidGlass(in: RoundedRectangle(cornerRadius: 9), fallback: Theme.disabledButton)
                .onHover { hovering = $0 }
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.text)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}
