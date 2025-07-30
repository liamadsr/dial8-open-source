import SwiftUI
import AppKit

// MARK: - Unified Toolbar
struct UnifiedToolbar {
    struct Config {
        var title: String
        var leadingItems: [Item]
        var trailingItems: [Item]
        var centerItems: [Item]
        
        struct Item: Identifiable {
            let id = UUID()
            let image: String
            let title: String
            let action: () -> Void
        }
        
        init(
            title: String = "",
            leadingItems: [Item] = [],
            centerItems: [Item] = [],
            trailingItems: [Item] = []
        ) {
            self.title = title
            self.leadingItems = leadingItems
            self.centerItems = centerItems
            self.trailingItems = trailingItems
        }
    }

    struct View: SwiftUI.View {
        let config: Config
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some SwiftUI.View {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Leading items
                    HStack(spacing: 8) {
                        ForEach(config.leadingItems) { item in
                            toolbarButton(item)
                        }
                    }
                    
                    Spacer()
                    
                    // Center items (including title)
                    HStack(spacing: 8) {
                        if !config.title.isEmpty {
                            Text(config.title)
                                .font(.headline)
                        }
                        ForEach(config.centerItems) { item in
                            toolbarButton(item)
                        }
                    }
                    
                    Spacer()
                    
                    // Trailing items
                    HStack(spacing: 8) {
                        ForEach(config.trailingItems) { item in
                            toolbarButton(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    VisualEffectView(
                        material: .titlebar,
                        blendingMode: .behindWindow
                    )
                )
                
                Divider()
            }
        }
        
        private func toolbarButton(_ item: Config.Item) -> some SwiftUI.View {
            Button(action: item.action) {
                Image(systemName: item.image)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(item.title)
        }
    }

    static let shared = UnifiedToolbar()
    
    func settingsConfig(showSettings: Binding<Bool>) -> Config {
        Config(
            title: "Settings",
            trailingItems: [
                .init(
                    image: "gear",
                    title: "Settings",
                    action: { showSettings.wrappedValue.toggle() }
                )
            ]
        )
    }
    
} 