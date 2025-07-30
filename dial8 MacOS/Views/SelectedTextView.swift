/*
 * SelectedTextView.swift
 *
 * A SwiftUI view for displaying selected text in an overlay.
 * This view matches the HUD styling and provides a simple interface
 * for viewing selected text.
 *
 * Key features:
 * - Styled to match the HUD design language
 * - Scrollable text view for longer selections
 * - Supports both light and dark mode
 */

import SwiftUI

struct SelectedTextView: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background with same styling as HUD
            RoundedRectangle(cornerRadius: HUDLayout.SelectedTextOverlay.cornerRadius)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: HUDLayout.SelectedTextOverlay.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: HUDLayout.SelectedTextOverlay.cornerRadius)
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.8)
                )
            
            VStack(spacing: HUDLayout.SelectedTextOverlay.spacing) {
                // Header with adaptive styling for dark/light mode
                HStack {
                    Text("Selected Text")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.top, HUDLayout.SelectedTextOverlay.verticalPadding + 2)
                .padding(.horizontal, HUDLayout.SelectedTextOverlay.horizontalPadding)
                
                // Text content with adaptive styling
                ScrollView {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .padding(.horizontal, HUDLayout.SelectedTextOverlay.horizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140) // Increased height since we removed the button
                .padding(.horizontal, 5)
                .padding(.bottom, HUDLayout.SelectedTextOverlay.verticalPadding + 2) // Add padding at bottom
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            print("📝 SelectedTextView: View appeared with text: \(text.prefix(20))...")
        }
    }
}

// Keep the button style in case it's used elsewhere
struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.7 : 0.9))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    Group {
        SelectedTextView(text: "This is an example of selected text that would appear in the overlay. The text can be longer and will scroll if needed.")
            .frame(width: HUDLayout.SelectedTextOverlay.width, height: 180)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
        SelectedTextView(text: "This is an example of selected text that would appear in the overlay. The text can be longer and will scroll if needed.")
            .frame(width: HUDLayout.SelectedTextOverlay.width, height: 180)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
    }
} 