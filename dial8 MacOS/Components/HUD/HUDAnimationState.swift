import SwiftUI

/// Manages animation states and configurations for the HUD
class HUDAnimationState: ObservableObject {
    // MARK: - Animation States
    @Published var glowIntensity: CGFloat = 1.5
    @Published var wavePhase: CGFloat = 0
    @Published var breatheScale: CGFloat = 1.0
    @Published var ringRotation: Double = 0
    @Published var ringRotation2: Double = 0
    @Published var shouldAnimate: Bool = true
    @Published var drawerOffset: CGFloat = 0
    
    // MARK: - Folding Animation States
    @Published var foldProgress: CGFloat = 0 // 0 = fully folded, 1 = fully open
    @Published var isVisible: Bool = false
    @Published var scaleY: CGFloat = 0.01
    @Published var opacity: CGFloat = 0
    @Published var rotationAngle: Double = 0 // For 3D book fold effect
    @Published var perspectiveAmount: CGFloat = 0
    
    // MARK: - Ring Axes
    @Published var ringAxis1: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 1, 0)
    @Published var ringAxis2: (x: CGFloat, y: CGFloat, z: CGFloat) = (1, 0, 0)
    
    // MARK: - Animation Configuration
    let breatheDuration: TimeInterval = 4.0
    let glowDuration: TimeInterval = 3.0
    let breatheScale_Target: CGFloat = 1.02
    let glowIntensity_Target: CGFloat = 2.0
    let loadingRotationSpeed: TimeInterval = 0.8 // Fast rotation for loading state
    
    // MARK: - Drawer Animation Configuration
    static let drawerSpringResponse: Double = 0.45
    static let drawerSpringDamping: Double = 0.85
    
    // Modern spring configurations for different states
    static var drawerOpenSpring: Animation {
        .spring(
            response: drawerSpringResponse,
            dampingFraction: drawerSpringDamping,
            blendDuration: 0.1
        )
    }
    
    static var drawerCloseSpring: Animation {
        .spring(
            response: drawerSpringResponse * 0.8, // Slightly faster close
            dampingFraction: drawerSpringDamping + 0.05, // Slightly more damped
            blendDuration: 0.1
        )
    }
    
    // MARK: - Initialization
    init() {
        setupInitialState()
    }
    
    // MARK: - Public Methods
    func setupInitialState() {
        glowIntensity = 1.5
        wavePhase = 0
        breatheScale = 1.0
        ringRotation = 0
        ringRotation2 = 0
        drawerOffset = 0
    }
    
    func updateRotationAxes() {
        ringAxis1 = (
            x: CGFloat.random(in: -1...1),
            y: CGFloat.random(in: -1...1),
            z: CGFloat.random(in: -1...1)
        )
        ringAxis2 = (
            x: CGFloat.random(in: -1...1),
            y: CGFloat.random(in: -1...1),
            z: CGFloat.random(in: -1...1)
        )
    }
    
    func startAnimations() {
        shouldAnimate = true
    }
    
    func stopAnimations() {
        shouldAnimate = false
        setupInitialState()
    }
    
    // MARK: - Folding Animation Methods
    func animateIn() {
        // Start with folded state
        foldProgress = 0
        scaleY = 0.01
        opacity = 0
        rotationAngle = -90
        perspectiveAmount = 1
        isVisible = true
        
        // Play open sound effect
        HUDSoundEffects.shared.playOpenSound()
        
        // Animate to open state with book unfolding effect
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 25)) {
            foldProgress = 1
            scaleY = 1
            opacity = 1
            rotationAngle = 0
            perspectiveAmount = 0
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        // Play close sound effect
        HUDSoundEffects.shared.playCloseSound()
        
        // Animate to folded state with even faster, tighter fold
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 45)) {
            foldProgress = 0
            scaleY = 0.001  // Even thinner
            rotationAngle = -88  // Almost completely edge-on
            perspectiveAmount = 1.5  // More dramatic perspective
        }
        
        // Fade out very quickly while folding
        withAnimation(.easeOut(duration: 0.15)) {
            self.opacity = 0
        }
        
        // Call completion after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isVisible = false
            completion()
        }
    }
    
    // MARK: - Animation Configurations
    var breathingAnimation: Animation {
        .easeInOut(duration: breatheDuration)
            .repeatForever(autoreverses: true)
    }
    
    var glowAnimation: Animation {
        .easeInOut(duration: glowDuration)
            .repeatForever(autoreverses: true)
    }
    
    var loadingAnimation: Animation {
        .linear(duration: loadingRotationSpeed)
            .repeatForever(autoreverses: false)
    }
}

// MARK: - Gradient Configurations
extension HUDAnimationState {
    func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        [
            (colorScheme == .dark ? Color.white : Color.black).opacity(0.7),
            (colorScheme == .dark ? Color.white : Color.black),
            (colorScheme == .dark ? Color.white : Color.black).opacity(0.7)
        ]
    }
    
    var modernGreenGradient: [Color] {
        let vibrantGreen = Color(red: 0.20, green: 0.85, blue: 0.40)
        return [
            vibrantGreen.opacity(0.7),
            vibrantGreen,
            vibrantGreen.opacity(0.7)
        ]
    }
} 