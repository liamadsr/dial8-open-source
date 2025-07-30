import SwiftUI

/// A virtual scrolling view that only renders visible items for better performance with large datasets
struct VirtualScrollView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let content: (Item) -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var visibleRange: Range<Int> = 0..<0
    
    private let bufferSize: Int = 5 // Number of items to render outside visible area
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer for items above visible range
                        if visibleRange.lowerBound > 0 {
                            Spacer()
                                .frame(height: CGFloat(visibleRange.lowerBound) * itemHeight)
                        }
                        
                        // Render only visible items (with buffer)
                        ForEach(items[visibleRange], id: \.id) { item in
                            content(item)
                                .frame(height: itemHeight)
                                .id(item.id)
                        }
                        
                        // Spacer for items below visible range
                        if visibleRange.upperBound < items.count {
                            Spacer()
                                .frame(height: CGFloat(items.count - visibleRange.upperBound) * itemHeight)
                        }
                    }
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -scrollGeometry.frame(in: .named("scroll")).origin.y
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    updateVisibleRange(viewHeight: geometry.size.height)
                }
                .onAppear {
                    viewHeight = geometry.size.height
                    updateVisibleRange(viewHeight: geometry.size.height)
                }
                .onChange(of: geometry.size.height) { newHeight in
                    viewHeight = newHeight
                    updateVisibleRange(viewHeight: newHeight)
                }
                .onChange(of: items.count) { _ in
                    updateVisibleRange(viewHeight: viewHeight)
                }
            }
        }
    }
    
    private func updateVisibleRange(viewHeight: CGFloat) {
        let totalHeight = CGFloat(items.count) * itemHeight
        guard totalHeight > 0, itemHeight > 0 else {
            visibleRange = 0..<min(items.count, 50) // Default range
            return
        }
        
        // Calculate visible item indices
        let firstVisibleIndex = max(0, Int(floor(scrollOffset / itemHeight)) - bufferSize)
        let visibleCount = Int(ceil(viewHeight / itemHeight)) + (bufferSize * 2)
        let lastVisibleIndex = min(items.count, firstVisibleIndex + visibleCount)
        
        visibleRange = firstVisibleIndex..<lastVisibleIndex
    }
}

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A more advanced virtual scrolling view with dynamic item heights
struct DynamicVirtualScrollView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let estimatedItemHeight: CGFloat
    let content: (Item, @escaping (CGFloat) -> Void) -> Content
    
    @State private var itemHeights: [String: CGFloat] = [:]
    @State private var scrollOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var visibleIndices: Set<Int> = []
    
    private let bufferSize: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if shouldRenderItem(at: index) {
                            content(item) { height in
                                DispatchQueue.main.async {
                                    itemHeights["\(item.id)"] = height
                                }
                            }
                            .background(
                                GeometryReader { itemGeometry in
                                    Color.clear
                                        .onAppear {
                                            let height = itemGeometry.size.height
                                            if height > 0 {
                                                itemHeights["\(item.id)"] = height
                                            }
                                        }
                                }
                            )
                        } else {
                            // Placeholder for non-visible items
                            Spacer()
                                .frame(height: itemHeights["\(item.id)"] ?? estimatedItemHeight)
                        }
                    }
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: -scrollGeometry.frame(in: .named("scroll")).origin.y
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
                updateVisibleIndices(viewHeight: geometry.size.height)
            }
            .onAppear {
                viewHeight = geometry.size.height
                updateVisibleIndices(viewHeight: geometry.size.height)
            }
            .onChange(of: geometry.size.height) { newHeight in
                viewHeight = newHeight
                updateVisibleIndices(viewHeight: newHeight)
            }
        }
    }
    
    private func shouldRenderItem(at index: Int) -> Bool {
        return visibleIndices.contains(index)
    }
    
    private func updateVisibleIndices(viewHeight: CGFloat) {
        var currentY: CGFloat = 0
        var newVisibleIndices: Set<Int> = []
        
        for (index, item) in items.enumerated() {
            let itemHeight = itemHeights["\(item.id)"] ?? estimatedItemHeight
            
            // Check if item is in visible range (with buffer)
            if currentY + itemHeight >= scrollOffset - (CGFloat(bufferSize) * estimatedItemHeight) &&
               currentY <= scrollOffset + viewHeight + (CGFloat(bufferSize) * estimatedItemHeight) {
                newVisibleIndices.insert(index)
            }
            
            currentY += itemHeight
            
            // Stop checking once we're well past the visible area
            if currentY > scrollOffset + viewHeight + (CGFloat(bufferSize * 2) * estimatedItemHeight) {
                break
            }
        }
        
        visibleIndices = newVisibleIndices
    }
}