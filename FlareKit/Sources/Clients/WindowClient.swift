import AppKit
import Dependencies

public struct WindowClient: Sendable {
    public var createPanel: @MainActor @Sendable (_ content: NSView) -> Void
    public var isVisible: @MainActor @Sendable () -> Bool
    public var isKey: @MainActor @Sendable () -> Bool
    public var show: @MainActor @Sendable () -> Void
    public var hide: @MainActor @Sendable () -> Void
    public var reposition: @MainActor @Sendable () -> Void
    public var setResignHandler: @MainActor @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void
    public var setCancelHandler: @MainActor @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void
    public var setStaysOnTop: @MainActor @Sendable (Bool) -> Void
    public var setRemembersPosition: @MainActor @Sendable (Bool) -> Void
    public var showSettings: @MainActor @Sendable (_ content: NSView) -> Void
}

extension WindowClient: DependencyKey {
    public static var liveValue: WindowClient {
        WindowClient(
            createPanel: { content in PanelHost.shared.createPanel(content) },
            isVisible: { PanelHost.shared.panel?.isVisible ?? false },
            isKey: { PanelHost.shared.panel?.isKeyWindow ?? false },
            show: { PanelHost.shared.show() },
            hide: { PanelHost.shared.hide() },
            reposition: { PanelHost.shared.reposition() },
            setResignHandler: { handler in PanelHost.shared.onResign = handler },
            setCancelHandler: { handler in PanelHost.shared.setCancelHandler(handler) },
            setStaysOnTop: { PanelHost.shared.staysOnTop = $0 },
            setRemembersPosition: { PanelHost.shared.remembersPosition = $0 },
            showSettings: { content in PanelHost.shared.showSettings(content) }
        )
    }
}

extension WindowClient: TestDependencyKey {
    public static let testValue = WindowClient(
        createPanel: { _ in },
        isVisible: { false },
        isKey: { false },
        show: {},
        hide: {},
        reposition: {},
        setResignHandler: { _ in },
        setCancelHandler: { _ in },
        setStaysOnTop: { _ in },
        setRemembersPosition: { _ in },
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
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    // A focused TextField swallows Escape before any SwiftUI keyboardShortcut sees
    // it, so the dismissal is handled here where nothing can intercept it first.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
private final class PanelHost: NSObject, NSWindowDelegate {
    static let shared = PanelHost()

    override init() {
        super.init()
        // A Menu or Picker inside the panel takes key status away from it. Without
        // this the panel would hide itself the moment the model picker opened.
        let center = NotificationCenter.default
        center.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { PanelHost.shared.isMenuTracking = true } }
        center.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { PanelHost.shared.isMenuTracking = false } }
    }

    var panel: FlarePanel?
    var settingsWindow: NSWindow?
    var onResign: (@MainActor @Sendable () -> Void)?
    private var isMenuTracking = false
    var staysOnTop = false
    var remembersPosition = true

    private let panelSize = NSSize(width: 470, height: 660)
    private let radius: CGFloat = 20
    private let frameName = "FlarePanel"

    func createPanel(_ content: NSView) {
        let panel = FlarePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // .floating, not .popUpMenu: a Menu opened inside the panel draws at
        // popUpMenu level and would otherwise appear behind its own window.
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.minSize = NSSize(width: 420, height: 420)
        panel.animationBehavior = .utilityWindow

        content.wantsLayer = true
        content.layer?.cornerRadius = radius
        content.layer?.masksToBounds = true

        let glass = NSGlassEffectView()
        glass.contentView = content
        glass.cornerRadius = radius
        // The glass view needs its own radius and mask, or a square plate shows at the corners.
        glass.wantsLayer = true
        glass.layer?.cornerRadius = radius
        glass.layer?.masksToBounds = true

        panel.contentView = glass
        panel.delegate = self
        self.panel = panel
    }

    func setCancelHandler(_ handler: @escaping @MainActor @Sendable () -> Void) {
        panel?.onCancel = { MainActor.assumeIsolated { handler() } }
    }

    func show() {
        guard let panel else { return }
        if !panel.isVisible {
            if !(remembersPosition && panel.setFrameUsingName(frameName)) { reposition() }
            // Named only now: naming the panel at creation would save its empty
            // starting frame, and the first show would restore that instead.
            panel.setFrameAutosaveName(frameName)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func reposition() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        // Bottom-right of the screen under the pointer, a hand's width in from the
        // edges. Clamped so a short display or an enlarged panel stays on screen.
        let gap: CGFloat = 16
        let x = max(visible.maxX - size.width - gap, visible.minX)
        let y = min(max(visible.minY + gap, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
        guard !isMenuTracking else { return }
        // Pinned: the user asked the panel to survive losing focus.
        guard !staysOnTop else { return }
        // Opening Settings from inside the panel steals key status; hiding there
        // would also discard the untouched thread the user was about to use.
        guard settingsWindow?.isKeyWindow != true else { return }
        hide()
        onResign?()
    }
}
