import SwiftUI

/// Manages layout constants and configurations for the HUD
struct HUDLayout {
    // MARK: - Window Dimensions
    static let width: CGFloat = 68   // Further reduced for ultra-compact size
    static let expandedWidth: CGFloat = 120  // Width when recording is locked
    static let height: CGFloat = 32  // Reduced by ~10% from 36px
    static let cornerRadius: CGFloat = 16  // Pill-shaped radius
    
    // MARK: - Content Padding
    static let horizontalPadding: CGFloat = 8   // Reduced padding for compact size
    static let verticalPadding: CGFloat = 6    // Reduced padding for compact size
    static let spacing: CGFloat = 12
    
    // MARK: - Icon Section
    static let iconWidth: CGFloat = 34
    static let transcribeIconSize: CGFloat = 17
    
    // MARK: - Button Section
    static let buttonArea: CGRect = CGRect(
        x: width - 110,
        y: 0,
        width: 110,
        height: height
    )
    
    static let buttonPadding = EdgeInsets(
        top: 4,
        leading: 6,
        bottom: 4,
        trailing: 6
    )
    
    // MARK: - Text Styles
    struct TextStyle {
        static let title = Font.system(size: 13, weight: .semibold)
        static let subtitle = Font.system(size: 11, weight: .regular)
        static let status = Font.system(size: 12, weight: .medium)
        static let button = Font.system(size: 11, weight: .medium)
        static let buttonIcon = Font.system(size: 10, weight: .medium)
    }
    
    // MARK: - Animation Timings
    struct AnimationTiming {
        static let buttonHover: TimeInterval = 0.15
        static let stateChange: TimeInterval = 0.2
        static let expand: TimeInterval = 0.3
    }
    
    // MARK: - Colors
    struct Colors {
        static func background(for colorScheme: ColorScheme) -> Color {
            Color(NSColor.windowBackgroundColor)
        }
        
        static func foreground(for colorScheme: ColorScheme) -> Color {
            .primary
        }
        
        static func secondaryForeground(for colorScheme: ColorScheme, opacity: Double = 1.0) -> Color {
            .secondary
        }
    }
    
    // MARK: - Selected Text Overlay dimensions
    struct SelectedTextOverlay {
        static let width: CGFloat = 428
        static let cornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let spacing: CGFloat = 10
    }
} 