import SwiftUI

/// Animated icon component for the HUD
struct HUDAnimatedIcon: View {
    @ObservedObject var animationState: HUDAnimationState
    @ObservedObject var audioManager: AudioManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let size: CGFloat
    
    init(
        icon: String,
        size: CGFloat,
        animationState: HUDAnimationState,
        audioManager: AudioManager
    ) {
        self.icon = icon
        self.size = size
        self.animationState = animationState
        self.audioManager = audioManager
    }
    
    var body: some View {
        ZStack {
            if icon == "character.cursor.ibeam" {
                // First ring with dynamic axis
                animatedRing(
                    axis: animationState.ringAxis1, 
                    rotation: animationState.ringRotation,
                    speed: audioManager.isAudioSetupInProgress ? 3.0 : 1.0
                )
                
                // Second ring with dynamic axis
                animatedRing(
                    axis: animationState.ringAxis2, 
                    rotation: animationState.ringRotation2,
                    speed: audioManager.isAudioSetupInProgress ? 4.0 : 1.0
                )
            } else {
                // Globe ring
                animatedRing(
                    axis: (x: 0.0, y: 1.0, z: 0.0),
                    rotation: animationState.ringRotation,
                    scale: 1.6,
                    speed: audioManager.isAudioSetupInProgress ? 3.0 : 1.0
                )
            }
            
            // Icon with effects
            animatedIcon
        }
        .animation(
            audioManager.isAudioSetupInProgress ? 
                .linear(duration: 0.05) : 
                .easeInOut(duration: 0.2),
            value: audioManager.isSpeechDetected
        )
    }
    
    private func animatedRing(
        axis: (x: CGFloat, y: CGFloat, z: CGFloat),
        rotation: Double,
        scale: CGFloat = 2.0,
        speed: CGFloat = 1.0
    ) -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: ringGradientColors,
                    startPoint: UnitPoint(
                        x: sin(animationState.wavePhase) * 1.2,
                        y: cos(animationState.wavePhase) * 1.2
                    ),
                    endPoint: UnitPoint(
                        x: cos(animationState.wavePhase) * 1.2,
                        y: sin(animationState.wavePhase) * 1.2
                    )
                ),
                lineWidth: 0.6
            )
            .frame(width: size * scale, height: size * scale)
            .blur(radius: animationState.glowIntensity * 3)
            .shadow(
                color: ringGlowColor,
                radius: animationState.glowIntensity * 8
            )
            .rotation3DEffect(
                .degrees(rotation * speed),
                axis: (x: axis.x, y: axis.y, z: axis.z),
                anchor: .center,
                perspective: 0.3
            )
    }
    
    private var animatedIcon: some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .overlay(
                ZStack {
                    // Primary wave gradient
                    LinearGradient(
                        colors: iconGradientColors,
                        startPoint: UnitPoint(x: 0, y: sin(animationState.wavePhase) * 1.2),
                        endPoint: UnitPoint(x: 1, y: cos(animationState.wavePhase) * 1.2)
                    )
                    
                    // Secondary wave gradient
                    LinearGradient(
                        colors: audioManager.isSpeechDetected ? 
                            animationState.modernGreenGradient : 
                            animationState.gradientColors(for: colorScheme).reversed(),
                        startPoint: UnitPoint(
                            x: sin(animationState.wavePhase) * 1.2,
                            y: 0
                        ),
                        endPoint: UnitPoint(
                            x: cos(animationState.wavePhase) * 1.2,
                            y: 1
                        )
                    )
                    .opacity(0.9)
                }
                .mask(
                    Image(systemName: icon)
                        .font(.system(size: size, weight: .semibold))
                )
            )
            .shadow(
                color: iconGlowColor,
                radius: animationState.glowIntensity * 25
            )
            .overlay(iconOverlay(startPoint: UnitPoint(
                x: sin(animationState.wavePhase) * 1.2,
                y: cos(animationState.wavePhase) * 1.2
            )))
            .overlay(iconOverlay(startPoint: UnitPoint(
                x: cos(animationState.wavePhase) * 1.2,
                y: sin(animationState.wavePhase) * 1.2
            )))
            .scaleEffect(animationState.breatheScale)
    }
    
    private func iconOverlay(startPoint: UnitPoint) -> some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(
                .linearGradient(
                    colors: iconGradientColors,
                    startPoint: startPoint,
                    endPoint: UnitPoint(
                        x: startPoint.y,
                        y: startPoint.x
                    )
                )
            )
            .blur(radius: animationState.glowIntensity * 5)
            .opacity(0.8)
    }
    
    // MARK: - Computed Properties for Colors
    
    private var ringGradientColors: [Color] {
        [
            activeColor.opacity(0.2),
            activeColor.opacity(0.8),
            activeColor,
            activeColor.opacity(0.8),
            activeColor.opacity(0.2)
        ]
    }
    
    private var iconGradientColors: [Color] {
        audioManager.isSpeechDetected ? 
            animationState.modernGreenGradient :
            animationState.gradientColors(for: colorScheme)
    }
    
    private var activeColor: Color {
        audioManager.isSpeechDetected ?
            animationState.modernGreenGradient[1] :
            (colorScheme == .dark ? Color.white : Color(white: 0.6))
    }
    
    private var ringGlowColor: Color {
        activeColor.opacity(0.8)
    }
    
    private var iconGlowColor: Color {
        activeColor.opacity(0.9)
    }
} 