import Foundation

extension UserDefaults {
    var hasCompletedOnboarding: Bool {
        get {
            return bool(forKey: "hasCompletedOnboarding")
        }
        set {
            set(newValue, forKey: "hasCompletedOnboarding")
        }
    }
    
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

