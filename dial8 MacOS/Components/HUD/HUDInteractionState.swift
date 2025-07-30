import SwiftUI

/// Manages interaction states and events for the HUD
class HUDInteractionState: ObservableObject {
    // MARK: - Published Properties
    @Published var isModeButtonHovered = false
    @Published var isClearButtonHovered = false
    @Published var isCopyButtonHovered = false
    @Published var isWindowHovered = false
    @Published var activeInteractionArea: InteractionArea?
    
    // MARK: - Types
    enum InteractionArea: Equatable {
        case modeButton
        case dragArea
        case iconArea
        case textArea
        case clearButton
        case clearButtonBackground
        case copyButton
        case copyButtonBackground
        case none
        
        var allowsHover: Bool {
            switch self {
            case .modeButton, .iconArea, .clearButton, .copyButton:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Handle mouse enter for a specific interaction area
    func handleMouseEnter(_ area: InteractionArea) {
        withAnimation(.easeInOut(duration: HUDLayout.AnimationTiming.buttonHover)) {
            switch area {
            case .modeButton:
                isModeButtonHovered = true
            case .clearButton, .clearButtonBackground:
                isClearButtonHovered = true
            case .copyButton, .copyButtonBackground:
                isCopyButtonHovered = true
            case .dragArea, .iconArea, .textArea:
                isWindowHovered = true
            case .none:
                break
            }
            activeInteractionArea = area
        }
    }
    
    /// Handle mouse exit for a specific interaction area
    func handleMouseExit(_ area: InteractionArea) {
        withAnimation(.easeInOut(duration: HUDLayout.AnimationTiming.buttonHover)) {
            switch area {
            case .modeButton:
                isModeButtonHovered = false
            case .clearButton, .clearButtonBackground:
                isClearButtonHovered = false
            case .copyButton, .copyButtonBackground:
                isCopyButtonHovered = false
            case .dragArea, .iconArea, .textArea:
                isWindowHovered = false
            case .none:
                break
            }
            if activeInteractionArea == area {
                activeInteractionArea = .none
            }
        }
    }
    
    /// Reset all interaction states
    func resetStates() {
        withAnimation(.easeInOut(duration: HUDLayout.AnimationTiming.buttonHover)) {
            isModeButtonHovered = false
            isClearButtonHovered = false
            isCopyButtonHovered = false
            isWindowHovered = false
            activeInteractionArea = .none
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get the opacity for a specific interaction area
    func opacity(for area: InteractionArea) -> Double {
        switch area {
        case .modeButton:
            return isModeButtonHovered ? 0.2 : 0.0
        case .clearButton:
            return isClearButtonHovered ? 0.2 : 0.0
        case .copyButton:
            return isCopyButtonHovered ? 0.2 : 0.0
        case .dragArea:
            return isWindowHovered ? 0.1 : 0.0
        case .iconArea:
            return isWindowHovered ? 0.15 : 0.0
        case .textArea:
            return isWindowHovered ? 0.1 : 0.0
        case .clearButtonBackground, .copyButtonBackground:
            return 0.0
        case .none:
            return 0.0
        }
    }
    
    /// Get the scale for a specific interaction area
    func scale(for area: InteractionArea) -> CGFloat {
        switch area {
        case .modeButton:
            return isModeButtonHovered ? 1.05 : 1.0
        case .clearButton:
            return isClearButtonHovered ? 1.05 : 1.0
        case .copyButton:
            return isCopyButtonHovered ? 1.05 : 1.0
        case .iconArea:
            return isWindowHovered ? 1.1 : 1.0
        default:
            return 1.0
        }
    }
    
    /// Get the cursor for a specific interaction area
    func cursor(for area: InteractionArea) -> NSCursor {
        switch area {
        case .modeButton, .clearButton:
            return .pointingHand
        case .dragArea:
            return .openHand
        case .iconArea:
            return .pointingHand
        default:
            return .arrow
        }
    }
} 