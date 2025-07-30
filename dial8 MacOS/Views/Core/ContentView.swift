//
//  ContentView.swift
//  thinking aloud
//
//  Created by Liam Alizadeh on 9/11/24.
//

import SwiftUI
import AVFoundation

#if os(macOS)
import AppKit
#endif

// Main view structure for the app
struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager
    
    var body: some View {
        UnifiedSettingsView()
            .frame(minWidth: 600, minHeight: 500)
    }
}

// Custom toolbar view modifier for macOS
extension View {
    func safeToolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.toolbar {
            ToolbarItem(placement: .automatic) {
                content()
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let windowManager = WindowManager()
        
        return ContentView()
            .environmentObject(windowManager)
    }
}
