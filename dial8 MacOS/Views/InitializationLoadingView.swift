import SwiftUI

struct ModernLoader: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                Color.primary.opacity(0.8),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct InitializationLoadingView: View {
    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Modern loader
                ModernLoader()
                
                // Loading text
                Text("Getting everything ready...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    InitializationLoadingView()
} 