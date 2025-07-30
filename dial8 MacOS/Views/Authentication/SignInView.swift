//
//  SignInView.swift
//  dial8
//
//  Created by Liam Alizadeh
//

/// SignInView provides the authentication interface for Dial8.
///
/// This view presents a clean, modern authentication screen that:
/// - Offers social sign-in options (currently Google, with Apple sign-in prepared for future)
/// - Maintains a consistent brand experience
/// - Handles user authentication state
/// - Provides terms and conditions acceptance
///
/// Features:
/// - Google OAuth integration
/// - Responsive layout using GeometryReader
/// - Visual feedback for user interactions
/// - Terms and conditions link with hover effects
/// - Accessibility support
/// - macOS-specific UI adaptations
///
/// Dependencies:
/// - AuthenticationManager: Handles authentication logic
/// - VisualEffectView: Provides native macOS window styling
///
/// Usage:
/// ```swift
/// SignInView()
///     .environmentObject(authManager)
/// ```
///
/// Note: The view is designed with future extensibility in mind,
/// with commented code for Apple Sign-In integration.

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isHovering = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer().frame(height: geometry.size.height * 0.2)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Get started with Dial8")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Sign up with your primary email")
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(.gray)
                        .padding(.bottom, 30)

                    // Google Sign-In Button
                    Button(action: {
                        if let window = NSApplication.shared.windows.first {
                            authManager.signInWithGoogle(presentationAnchor: window)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image("google_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                            Text("Continue with Google")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 10)
                    .disabled(authManager.isAuthenticated)

                    // // Sign in with Apple Button
                    // Button(action: {
                    //     // Implement Apple Sign-In
                    // }) {
                    //     HStack {
                    //         Image(systemName: "apple.logo")
                    //             .resizable()
                    //             .frame(width: 20, height: 24)
                    //         Text("Continue with Apple")
                    //             .font(.headline)
                    //             .fontWeight(.regular)
                    //     }
                    //     .frame(maxWidth: .infinity)
                    //     .padding()
                    //     .background(Color.black)
                    //     .foregroundColor(.white)
                    //     .cornerRadius(8)
                    // }
                    // .buttonStyle(PlainButtonStyle())
                    // .padding(.bottom, 20)

                    HStack(spacing: 0) {
                        Text("By signing up you agree to our ")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("terms and conditions")
                            .font(.caption.bold())
                            .foregroundColor(isHovering ? .blue : .primary)
                            .underline(isHovering)
                            .onHover { hovering in
                                isHovering = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onTapGesture {
                                if let url = URL(string: "https://bittersweet-fountain-735.notion.site/Privacy-Policy-for-Dial8-1072b73b992080ca9936d1ca2aa16a11?pvs=4") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 60)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .background(
                VisualEffectView(
                    material: .fullScreenUI,
                    blendingMode: .withinWindow
                )
            )
        }
    }
}
