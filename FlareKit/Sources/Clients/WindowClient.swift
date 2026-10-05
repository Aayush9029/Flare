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
    /// Fires when the user finishes resizing the panel, with the nearest width stop and size.
    public var setResizeHandler: @MainActor @Sendable (@escaping @MainActor @Sendable (CGFloat, PanelSize) -> Void) -> Void
    public var setCancelHandler: @MainActor @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void
    public var setStaysOnTop: @MainActor @Sendable (Bool) -> Void
    public var setRemembersPosition: @MainActor @Sendable (Bool) -> Void
    public var setPosition: @MainActor @Sendable (PanelPosition) -> Void
    public var setSize: @MainActor @Sendable (PanelSize) -> Void
    public var setWidth: @MainActor @Sendable (CGFloat) -> Void
    /// A width the ghost shows while a slider knob is still in hand; nil once let go.
    public var previewWidth: @MainActor @Sendable (CGFloat?) -> Void
    /// The ghost's border takes the colour of the control under the pointer.
    public var tintGhost: @MainActor @Sendable (GhostTint) -> Void
    public var showSettings: @MainActor @Sendable (_ content: NSView) -> Void
}

public enum GhostTint: Sendable {
    case standard
    case width
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
            setResizeHandler: { handler in PanelHost.shared.onUserResize = handler },
            setCancelHandler: { handler in PanelHost.shared.setCancelHandler(handler) },
            setStaysOnTop: { PanelHost.shared.staysOnTop = $0 },
            setRemembersPosition: { PanelHost.shared.remembersPosition = $0 },
            setPosition: { PanelHost.shared.position = $0 },
            setSize: { PanelHost.shared.setSize($0) },
            setWidth: { PanelHost.shared.setWidth($0) },
            previewWidth: { PanelHost.shared.previewWidth($0) },
            tintGhost: { PanelHost.shared.tintGhost($0) },
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
        setResizeHandler: { _ in },
        setCancelHandler: { _ in },
        setStaysOnTop: { _ in },
        setRemembersPosition: { _ in },
        setPosition: { _ in },
        setSize: { _ in },
        setWidth: { _ in },
        previewWidth: { _ in },
        tintGhost: { _ in },
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
    var onUserResize: (@MainActor @Sendable (CGFloat, PanelSize) -> Void)?
    private var isMenuTracking = false
    var staysOnTop = false
    var remembersPosition = true
    var position = PanelPosition.bottomRight {
        didSet { if oldValue != position { updateGhost() } }
    }
    private var ghost: NSWindow?
    private var ghostWidth: CGFloat?
    private var ghostFade: Task<Void, Never>?
    private var size = PanelSize.compact
    private var width = PanelSize.defaultWidth
    private var hasAppliedSize = false
    private var hasAppliedWidth = false

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
        // Not movable by window background: WindowDragGesture drags it, and that flag made
        // AppKit rebuild the drag region over every text view on each layout and scroll.
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

    /// A new size takes effect at once; a restored frame keeps the height it saved.
    func setSize(_ size: PanelSize) {
        let changed = self.size != size
        self.size = size
        guard changed, hasAppliedSize else {
            hasAppliedSize = true
            return
        }
        reposition()
        updateGhost()
    }

    func setWidth(_ width: CGFloat) {
        let changed = self.width != width
        self.width = width
        guard changed, hasAppliedWidth else {
            hasAppliedWidth = true
            return
        }
        reposition()
        updateGhost()
    }

    // MARK: Ghost

    func previewWidth(_ width: CGFloat?) {
        ghostWidth = width
        updateGhost()
    }

    /// The pointer over the width slider counts as intent: the ghost comes up in blue.
    func tintGhost(_ tint: GhostTint) {
        if tint != .standard { updateGhost() }
        (ghost?.contentView as? GhostPanelView)?.tint = tint
        if tint == .standard { scheduleGhostFade() }
    }

    /// While Settings has the keyboard, the panel itself steps aside. The ghost only
    /// appears once a position, size or width control is touched.
    private func settingsDidBecomeKey() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            onResign?()
        }
    }

    private func settingsDidResignKey() {
        hideGhost()
    }

    /// A ghost of the panel floats above every window where it would open:
    /// translucent, bordered, deaf to the mouse, and thin enough to read Settings
    /// through. It leaves a few seconds after the last touch.
    private func updateGhost() {
        guard let settingsWindow, settingsWindow.isVisible,
              let screen = settingsWindow.screen ?? screenUnderPointer()
        else { return }
        let window = ghost ?? makeGhost()
        let frame = placementFrame(on: screen, width: ghostWidth ?? width)
        if window.isVisible {
            window.setFrame(frame, display: true, animate: true)
        } else {
            window.setFrame(frame, display: true)
            window.orderFrontRegardless()
        }
        scheduleGhostFade()
    }

    private func scheduleGhostFade() {
        ghostFade?.cancel()
        // A knob still in hand keeps the ghost up.
        guard ghostWidth == nil else { return }
        ghostFade = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.hideGhost()
        }
    }

    private func hideGhost() {
        ghostFade?.cancel()
        ghostFade = nil
        ghost?.orderOut(nil)
    }

    private func makeGhost() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.alphaValue = 0.5
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.animationBehavior = .none
        window.contentView = GhostPanelView(cornerRadius: radius)
        ghost = window
        return window
    }

    /// The frame `reposition()` would give the panel on this screen.
    private func placementFrame(on screen: NSScreen, width: CGFloat? = nil) -> NSRect {
        let visible = screen.visibleFrame
        let minimum = panel?.minSize.height ?? 420
        let frame = NSSize(
            width: min(width ?? self.width, visible.width - 32),
            height: self.size.height(in: visible.height, minimum: minimum)
        )
        let gap: CGFloat = 16
        let origin: NSPoint = switch position {
        case .bottomLeft:
            NSPoint(x: visible.minX + gap, y: visible.minY + gap)
        case .bottomRight:
            NSPoint(x: visible.maxX - frame.width - gap, y: visible.minY + gap)
        case .center:
            NSPoint(x: visible.midX - frame.width / 2, y: visible.maxY - PanelSize.topGap - (visible.height - PanelSize.topGap - gap + frame.height) / 2)
        }
        let x = min(max(origin.x, visible.minX), max(visible.maxX - frame.width, visible.minX))
        let y = min(max(origin.y, visible.minY + gap), max(visible.maxY - PanelSize.topGap - frame.height, visible.minY))
        return NSRect(origin: NSPoint(x: x, y: y), size: frame)
    }

    private func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func reposition() {
        guard let panel, let screen = (panel.isVisible ? panel.screen : nil) ?? screenUnderPointer() else { return }
        panel.setFrame(placementFrame(on: screen), display: true, animate: panel.isVisible)
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
        window.delegate = self
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

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        settingsDidBecomeKey()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            settingsDidResignKey()
            return
        }
        guard window === panel, !isMenuTracking else { return }
        // Pinned: the user asked the panel to survive losing focus.
        guard !staysOnTop else { return }
        // Settings taking the keyboard hides the panel itself, in settingsDidBecomeKey.
        guard settingsWindow?.isKeyWindow != true else { return }
        hide()
        onResign?()
    }

    /// A hand-resized panel keeps its new frame, and Settings moves to the nearest
    /// width stop and size so the cards and slider tell the truth.
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel, let screen = window.screen else { return }
        let frame = window.frame
        let nearestWidth = PanelSize.widths.min { abs($0 - frame.width) < abs($1 - frame.width) } ?? width
        let visible = screen.visibleFrame
        let nearestSize = PanelSize.allCases.min {
            abs($0.height(in: visible.height, minimum: window.minSize.height) - frame.height)
                < abs($1.height(in: visible.height, minimum: window.minSize.height) - frame.height)
        } ?? size
        // Adopted first, so the preference change that follows finds nothing to apply.
        width = nearestWidth
        size = nearestSize
        onUserResize?(nearestWidth, nearestSize)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        hideGhost()
    }
}

/// A see-through stand-in for the panel: the same glass and corners, a border, no content.
private final class GhostPanelView: NSVisualEffectView {
    var tint = GhostTint.standard {
        didSet { applyTint() }
    }

    init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        applyTint()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTint()
    }

    private func applyTint() {
        let color: NSColor = switch tint {
        case .standard: .controlAccentColor
        case .width: NSColor(red: 0.22, green: 0.55, blue: 1.0, alpha: 1)
        }
        layer?.borderWidth = tint == .standard ? 1.5 : 2.5
        layer?.borderColor = color.withAlphaComponent(0.95).cgColor
    }
}
