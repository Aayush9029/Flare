import AppKit

let args = CommandLine.arguments
let wallpaper = NSImage(contentsOfFile: args[1])!
let overlay = args.count > 2 ? NSImage(contentsOfFile: args[2]) : nil

final class Delegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ note: Notification) {
        let screen = NSScreen.main!
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = true
        let root = NSImageView(frame: screen.frame)
        root.image = wallpaper
        root.imageScaling = .scaleAxesIndependently
        window.contentView = root
        if let overlay {
            let size = NSSize(width: overlay.size.width / 2, height: overlay.size.height / 2)
            let view = NSImageView(frame: NSRect(x: (screen.frame.width - size.width) / 2 + 120, y: (screen.frame.height - size.height) / 2 + 10, width: size.width, height: size.height))
            view.image = overlay
            view.imageScaling = .scaleProportionallyUpOrDown
            root.addSubview(view)
        }
        window.orderFrontRegardless()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = Delegate()
app.delegate = delegate
app.run()
