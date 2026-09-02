import SwiftUI

/// One namespace for the panel, so a control and the surface it grows into can
/// share a matched geometry across view hierarchies.
extension EnvironmentValues {
    @Entry var panelNamespace: Namespace.ID?
    /// Room the transcript keeps clear at its foot for whatever floats over it.
    @Entry var transcriptBottomInset: CGFloat = 0
}

enum Morph {
    static let modelPicker = "modelPicker"
    static func thoughts(_ id: some Hashable) -> String { "thoughts-\(id)" }
    static let animation = Animation.snappy(duration: 0.34, extraBounce: 0.04)
}

extension View {
    /// Matched geometry when the panel namespace is present; a no-op elsewhere.
    @ViewBuilder
    func morph(_ id: String, in namespace: Namespace.ID?, isSource: Bool) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            self
        }
    }
}
