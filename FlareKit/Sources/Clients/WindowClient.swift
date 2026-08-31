import AppKit
import Dependencies

public struct WindowClient: Sendable {
    public var createPanel: @MainActor @Sendable (_ content: NSView) -> Void
    public var isVisible: @MainActor @Sendable () -> Bool
    public var show: @MainActor @Sendable () -> Void
    public var hide: @MainActor @Sendable () -> Void
    public var reposition: @MainActor @Sendable () -> Void
    public var setResignHandler: @MainActor @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void
    public var showSettings: @MainActor @Sendable (_ content: NSView) -> Void
}

extension WindowClient: DependencyKey {
    public static var liveValue: WindowClient {
        WindowClient(
            createPanel: { content in PanelHost.shared.createPanel(content) },
            isVisible: { PanelHost.shared.panel?.isVisible ?? false },
            show: { PanelHost.shared.show() },
            hide: { PanelHost.shared.hide() },
            reposition: { PanelHost.shared.reposition() },
            setResignHandler: { handler in PanelHost.shared.onResign = handler },
            showSettings: { content in PanelHost.shared.showSettings(content) }
        )
    }
}

extension WindowClient: TestDependencyKey {
    public static let testValue = WindowClient(
        createPanel: { _ in },
        isVisible: { false },
        show: {},
        hide: {},
        reposition: {},
        setResignHandler: { _ in },
        showSettings: { _ in }
    )
}

public extension DependencyValues {
    var windowClient: WindowClient {
        get { self[WindowClient.self] }
        set { self[WindowClient.self] = newValue }
    }
}

private final class FlarePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class PanelHost: NSObject, NSWindowDelegate {
    static let shared = PanelHost()

    var panel: NSPanel?
    var settingsWindow: NSWindow?
    var onResign: (@MainActor @Sendable () -> Void)?

    private let panelSize = NSSize(width: 720, height: 560)
    private let radius: CGFloat = 20

    func createPanel(_ content: NSView) {
        let panel = FlarePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.minSize = NSSize(width: 480, height: 360)
        panel.animationBehavior = .utilityWindow

        content.wantsLayer = true
        content.layer?.cornerRadius = radius
        content.layer?.masksToBounds = true

        let glass = NSGlassEffectView()
        glass.contentView = content
        glass.cornerRadius = radius
        // Clip the glass rim and its legibility backing to the rounded shape,
        // otherwise a square-cornered plate peeks out at the window corners.
        glass.wantsLayer = true
        glass.layer?.cornerRadius = radius
        glass.layer?.masksToBounds = true

        panel.contentView = glass
        panel.delegate = self
        self.panel = panel
    }

    func show() {
        guard let panel else { return }
        if !panel.isVisible { reposition() }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Anchors to the screen under the pointer so the panel opens where the user is looking.
    func reposition() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + visible.height * 0.62 - size.height / 2
            )
        )
    }

    func showSettings(_ content: NSView) {
        if let settingsWindow {
            settingsWindow.contentView = content
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Flare Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        // Without a transparent backing, the sidebar and pane materials lose their translucency.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel else { return }
        hide()
        onResign?()
    }
}
