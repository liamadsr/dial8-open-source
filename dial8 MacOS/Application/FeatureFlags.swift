import Foundation

// Notification name for feature flag changes
extension Notification.Name {
    static let featureFlagsChanged = Notification.Name("FeatureFlagsChanged")
}

class FeatureFlags {
    // Call this method during app initialization to set default values if not already set
    static func setupDefaults() {
        // Setup any default feature flags here as needed
    }
}
