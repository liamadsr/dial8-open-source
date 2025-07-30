/// ProUpgradeOverlay is a celebratory view component that displays when a user upgrades to Pro.
///
/// This file contains several view components that work together to create a delightful
/// upgrade celebration experience:
///
/// 1. ProUpgradeOverlay: The main container view that:
///    - Displays a gradient "Welcome to Pro!" message
///    - Shows an animated confetti explosion
///    - Auto-dismisses after 8 seconds
///    - Handles smooth fade in/out animations
///
/// 2. ConfettiView: A particle system that:
///    - Generates 100 colorful confetti pieces
///    - Creates a radial explosion effect
///    - Uses multiple colors for visual variety
///
/// 3. ConfettiPiece: Individual confetti particle that:
///    - Has random size, angle, and rotation
///    - Animates outward from center
///    - Fades out during animation
///
/// 4. ExplosionAnimation: A custom ViewModifier that:
///    - Handles the physics-like explosion movement
///    - Controls rotation and opacity animations
///    - Adds randomized delay for natural effect
///
/// Usage:
/// ```swift
/// @State private var showUpgradeOverlay = false
///
/// ProUpgradeOverlay(isPresented: $showUpgradeOverlay)
/// ```

import SwiftUI

struct ProUpgradeOverlay: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 0
    @State private var textScale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Confetti explosion
            ConfettiView()
                .opacity(opacity)
            
            // Simple welcome text
            Text("Welcome to Pro!")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.yellow, .orange]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(textScale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                textScale = 1
            }
            
            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.easeIn(duration: 0.6)) {
                    opacity = 0
                    isPresented = false
                }
            }
        }
    }
}

struct ConfettiView: View {
    let colors: [Color] = [.blue, .red, .green, .yellow, .pink, .purple, .orange]
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<100) { index in
                ConfettiPiece(
                    color: colors[index % colors.count],
                    size: CGFloat.random(in: 5...12),
                    startPosition: CGPoint(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    ),
                    isAnimating: $isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    let startPosition: CGPoint
    @Binding var isAnimating: Bool
    
    // Random properties for explosion effect
    private let angle = Double.random(in: 0...360)
    private let distance = CGFloat.random(in: 100...500)
    private let rotation = Double.random(in: 0...720)
    private let delay = Double.random(in: 0...0.3)
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(startPosition)
            .modifier(ExplosionAnimation(
                angle: angle,
                distance: distance,
                rotation: rotation,
                isAnimating: isAnimating,
                delay: delay
            ))
    }
}

struct ExplosionAnimation: ViewModifier {
    let angle: Double
    let distance: CGFloat
    let rotation: Double
    let isAnimating: Bool
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: isAnimating ? cos(angle * .pi / 180) * distance : 0,
                y: isAnimating ? sin(angle * .pi / 180) * distance : 0
            )
            .rotationEffect(.degrees(isAnimating ? rotation : 0))
            .opacity(isAnimating ? 0 : 1)
            .animation(
                Animation.easeOut(duration: 2)
                    .delay(delay),
                value: isAnimating
            )
    }
}
