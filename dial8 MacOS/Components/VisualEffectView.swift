import SwiftUI

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        // Add this line to make the background less transparent
        visualEffectView.alphaValue = 1.0  // Adjust this value between 0.0 and 1.0
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        // Update alpha value when view updates
        visualEffectView.alphaValue = 1.0  // Keep the same value as above
    }
}
#endif
