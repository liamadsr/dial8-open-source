import Foundation
import SwiftUI

#if DEVELOPMENT
struct DevModeOverlay: View {
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    @AppStorage("showOnboardingInDevMode") private var showOnboardingInDevMode = false
    var showControls: Bool

    var body: some View {
        if showControls {
            VStack {
                Toggle("Dev Mode", isOn: $devModeEnabled)
                if devModeEnabled {
                    Toggle("Show Onboarding", isOn: $showOnboardingInDevMode)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.3))
            .cornerRadius(8)
            .padding()
        } else if devModeEnabled {
            Text("Dev Mode On")
                .padding(8)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(8)
                .padding(8)
        } else {
            EmptyView()
        }
    }
}
#endif
