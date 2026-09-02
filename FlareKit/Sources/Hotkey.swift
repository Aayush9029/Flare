import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    static let toggleFlare = Self("toggleFlare", initial: .init(.space, modifiers: [.command, .shift]))
    static let captureToChat = Self("captureToChat", initial: .init(.c, modifiers: [.command, .shift]))
}
