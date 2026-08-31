import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    static let toggleFlare = Self("toggleFlare", initial: .init(.space, modifiers: [.command, .shift]))
    static let newThread = Self("newThread", initial: .init(.n, modifiers: [.command, .shift, .option]))
}
