import Foundation
import CoreGraphics

struct HotkeyConfiguration: Identifiable, Codable, Equatable {
    let id: String
    var action: HotkeyAction
    var keyCombo: KeyCombo
    var isEnabled: Bool

    init(id: String = UUID().uuidString, action: HotkeyAction, keyCombo: KeyCombo, isEnabled: Bool = true) {
        self.id = id
        self.action = action
        self.keyCombo = keyCombo
        self.isEnabled = isEnabled
    }

    // Equatable conformance
    static func == (lhs: HotkeyConfiguration, rhs: HotkeyConfiguration) -> Bool {
        return lhs.id == rhs.id &&
               lhs.action == rhs.action &&
               lhs.keyCombo == rhs.keyCombo &&
               lhs.isEnabled == rhs.isEnabled
    }
}

struct KeyCombo: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt64
    var additionalKeyCodes: [Int] = []
    
    var hasCommand: Bool { modifiers & CGEventFlags.maskCommand.rawValue != 0 }
    var hasShift: Bool { modifiers & CGEventFlags.maskShift.rawValue != 0 }
    var hasControl: Bool { modifiers & CGEventFlags.maskControl.rawValue != 0 }
    var hasOption: Bool { modifiers & CGEventFlags.maskAlternate.rawValue != 0 }
    var hasFn: Bool { modifiers & CGEventFlags.maskSecondaryFn.rawValue != 0 }
    
    var isValid: Bool {
        let modifierCount = [hasCommand, hasShift, hasControl, hasOption, hasFn].filter { $0 }.count
        let keyCount = (keyCode != -1 ? 1 : 0) + additionalKeyCodes.count
        let totalCount = modifierCount + keyCount
        
        return totalCount > 0 && totalCount <= 4
    }
    
    var description: String {
        if keyCode == -1 && modifiers == 0 && additionalKeyCodes.isEmpty {
            return "Unassigned"
        }
        
        var components: [String] = []
        
        if hasCommand { components.append("⌘") }
        if hasShift { components.append("⇧") }
        if hasControl { components.append("⌃") }
        if hasOption { components.append("⌥") }
        if hasFn { components.append("Fn") }
        
        if keyCode != -1 {
            components.append(KeyCodeMap.description(for: keyCode))
        }
        
        for code in additionalKeyCodes {
            components.append(KeyCodeMap.description(for: code))
        }
        
        return components.joined(separator: " + ")
    }
}

extension KeyCombo {
    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        let equal = lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers && lhs.additionalKeyCodes == rhs.additionalKeyCodes
        // print("🔍 Comparing KeyCombos: \(lhs.description) == \(rhs.description) : \(equal)")
        return equal
    }
}

enum HotkeyAction: String, Codable {
    case transcribe  // Deprecated - will be removed in future
    case pushToTalk
    case toggleMode

    var description: String {
        switch self {
        case .transcribe: return "Transcribe"
        case .pushToTalk: return "Push to Talk"
        case .toggleMode: return "Toggle Mode"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .transcribe: return "Legacy transcribe action"
        case .pushToTalk: return "Hold to record, release to process"
        case .toggleMode: return "Press to start/stop recording"
        }
    }
}

enum KeyCodeMap {
    static func description(for keyCode: Int) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 49: return "Space"
        case 51: return "Delete"
        case 36: return "Return"
        case 53: return "Escape"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 111: return "F12"
        case 48: return "Tab"
        case 50: return "⇥"  // Back tab
        case 55: return "⌘"  // Command
        case 56: return "⇧"  // Shift
        case 57: return "Caps Lock"
        case 58: return "⌥"  // Option/Alt
        case 59: return "⌃"  // Control
        case 63, 179: return "Fn"  // Added 179 as an alternative Fn key code
        case 123: return "←" // Left Arrow
        case 124: return "→" // Right Arrow
        case 125: return "↓" // Down Arrow
        case 126: return "↑" // Up Arrow
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 115: return "Home"
        case 119: return "End"
        default:
            print("Unrecognized key code: \(keyCode)")
            return "Key \(keyCode)"
        }
    }
}
