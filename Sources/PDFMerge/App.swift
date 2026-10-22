import SwiftUI
import AppKit

@main
struct PDFMergeApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var store = MergeStore()

    var body: some Scene {
        Window("PDF Merge", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 940, minHeight: 640)
                .onOpenURL { store.add(urls: [$0]) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") { store.presentOpenPanel() }
                    .keyboardShortcut("o")
                Button("Add Folder…") { store.presentOpenPanel(folders: true) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Clear List") { store.clear() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .disabled(store.files.isEmpty)
            }
            CommandMenu("List") {
                Button("Sort by Name (A–Z)") { store.sortByName(ascending: true) }
                Button("Sort by Name (Z–A)") { store.sortByName(ascending: false) }
                Button("Reverse Order") { store.reverse() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceMode.stored?.apply()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @EnvironmentObject private var store: MergeStore

    var body: some View {
        VStack(spacing: 0) {
            TitleStrip()
            HStack(spacing: 6) {
                MergePanel()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
                OptionsPanel()
                    .frame(width: 396)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(Theme.windowBackground)
        .ignoresSafeArea()
        // The custom controls draw their own states; without this the first button (Add Files)
        // gets a rectangular keyboard focus ring at launch.
        .focusEffectDisabled()
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

/// Window top strip: room for the traffic lights, and the light/dark switcher on the right.
private struct TitleStrip: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            AppearanceSwitcher()
                .padding(.trailing, 10)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { NSApp.keyWindow?.performZoom(nil) })
    }
}

enum AppearanceMode: String {
    case light, dark

    private static let key = "appearanceMode"

    /// The user's choice, or nil to follow the system.
    static var stored: AppearanceMode? {
        UserDefaults.standard.string(forKey: key).flatMap(AppearanceMode.init)
    }

    /// The mode currently on screen.
    static var current: AppearanceMode {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    func apply() {
        NSApp.appearance = NSAppearance(named: self == .dark ? .darkAqua : .aqua)
    }

    func select() {
        UserDefaults.standard.set(rawValue, forKey: Self.key)
        apply()
    }
}

/// Sun / moon toggle on a glass rounded rectangle; the selected side slides between the two.
private struct AppearanceSwitcher: View {
    @State private var mode = AppearanceMode.current
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            option(.light, symbol: "sun.max.fill", help: "Light mode")
            option(.dark, symbol: "moon.fill", help: "Dark mode")
        }
        .padding(3)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 9), fallback: Theme.panel)
        .onAppear { mode = .current }
    }

    private func option(_ value: AppearanceMode, symbol: String, help: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = value }
            value.select()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(mode == value ? Theme.text : Theme.secondaryText)
                .frame(width: 30, height: 24)
                .background {
                    if mode == value {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Theme.text.opacity(0.12))
                            .matchedGeometryEffect(id: "selected", in: selection)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
