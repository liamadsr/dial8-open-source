import Foundation

enum AppConfig {
    // Base URLs
//    #if DEVELOPMENT
//    static let BACKEND_API_URL = ""
//    static let API_KEY = ""
//    static let STT_WEBSOCKET_URL = ""
//    #else
    static let BACKEND_API_URL = ""
    static let API_KEY = ""
    static let STT_WEBSOCKET_URL = ""
//    #endif

    // You can also add computed properties that use the DEVELOPMENT flag
    static var isDebugMode: Bool {
        #if DEVELOPMENT
        return true
        #else
        return false
        #endif
    }
    
    // Window dimensions
    struct WindowDimensions {
        static let minWidth: CGFloat = 1150
        static let idealWidth: CGFloat = 1300
        static let maxWidth: CGFloat = CGFloat.infinity
        
        static let minHeight: CGFloat = 600
        static let idealHeight: CGFloat = 800
        static let maxHeight: CGFloat = CGFloat.infinity
        
        // Initial window size (can be larger than min, smaller than max)
        static let initialWidth: CGFloat = 1300
        static let initialHeight: CGFloat = 800
    }
}
