import SwiftUI

enum AnimationType {
    case iconCarousel
    case typing(text: String)
    case loading
    case success
    case failure
    case pulse
    case wave
    case bounce
    // Add more animation types as needed
}

struct AnimationView: View {
    let type: AnimationType
    var configuration: AnimationConfiguration
    
    // Default initializer with configuration options
    init(type: AnimationType, configuration: AnimationConfiguration = .default) {
        self.type = type
        self.configuration = configuration
    }
    
    var body: some View {
        switch type {
        case .iconCarousel:
            IconCarouselAnimation(configuration: configuration)
        case .typing(let text):
            TypingAnimation(text: text, configuration: configuration)
        case .loading:
            LoadingAnimation(configuration: configuration)
        case .success:
            SuccessAnimation(configuration: configuration)
        case .failure:
            FailureAnimation(configuration: configuration)
        case .pulse:
            PulseAnimation(configuration: configuration)
        case .wave:
            WaveAnimation(configuration: configuration)
        case .bounce:
            BounceAnimation(configuration: configuration)
        }
    }
}

// Configuration struct to customize animations
struct AnimationConfiguration {
    var size: CGFloat = 50
    var speed: Double = 1.0
    var color: Color = .blue
    var secondaryColor: Color = .gray
    var icons: [(String, String)] = [
        ("lock.shield", "Privacy First"),
        ("character.cursor.ibeam", "Text Processing"),
        ("brain.head.profile", "AI Intelligence"),
        ("key.fill", "Encryption"),
        ("waveform.path.ecg", "Voice Recognition")
    ]
    
    static let `default` = AnimationConfiguration()
}

// MARK: - Individual Animation Views

private struct IconCarouselAnimation: View {
    let configuration: AnimationConfiguration
    @State private var currentIconIndex = 0
    @State private var isAnimating = false
    
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            ForEach(0..<configuration.icons.count, id: \.self) { index in
                Image(systemName: configuration.icons[index].0)
                    .font(.system(size: configuration.size))
                    .foregroundStyle(configuration.color)
                    .opacity(currentIconIndex == index ? 1 : 0)
                    .scaleEffect(currentIconIndex == index ? 1 : 0.5)
                    .rotation3DEffect(
                        .degrees(isAnimating ? 360 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                currentIconIndex = (currentIconIndex + 1) % configuration.icons.count
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isAnimating = false
                }
            }
        }
    }
}

private struct TypingAnimation: View {
    let text: String
    let configuration: AnimationConfiguration
    @State private var displayedText = ""
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: configuration.size))
            .foregroundColor(configuration.color)
            .onAppear {
                animateText()
            }
    }
    
    private func animateText() {
        var charIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.05 * configuration.speed, repeats: true) { timer in
            if charIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: charIndex)
                displayedText += String(text[index])
                charIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

private struct LoadingAnimation: View {
    let configuration: AnimationConfiguration
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(configuration.color, lineWidth: 2)
            .frame(width: configuration.size, height: configuration.size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

private struct SuccessAnimation: View {
    let configuration: AnimationConfiguration
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: configuration.size))
            .foregroundColor(configuration.color)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1
                    opacity = 1
                }
            }
    }
}

private struct FailureAnimation: View {
    let configuration: AnimationConfiguration
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: configuration.size))
            .foregroundColor(configuration.color)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rotation = 360
                    scale = 1
                    opacity = 1
                }
            }
    }
}

private struct PulseAnimation: View {
    let configuration: AnimationConfiguration
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Circle()
            .fill(configuration.color)
            .frame(width: configuration.size, height: configuration.size)
            .scaleEffect(scale)
            .opacity(2 - scale)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    scale = 2
                }
            }
    }
}

private struct WaveAnimation: View {
    let configuration: AnimationConfiguration
    @State private var waveOffset = 0.0
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Wave(offset: waveOffset + Double(i) * 0.2)
                    .fill(configuration.color.opacity(1.0 - Double(i) * 0.3))
                    .frame(width: configuration.size, height: configuration.size)
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                waveOffset = 1
            }
        }
    }
}

private struct Wave: Shape {
    var offset: Double
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 + offset * .pi * 2)
            let y = midHeight + sine * midHeight / 3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

private struct BounceAnimation: View {
    let configuration: AnimationConfiguration
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Circle()
            .fill(configuration.color)
            .frame(width: configuration.size, height: configuration.size)
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever()) {
                    offset = -20
                }
            }
    }
}

// MARK: - Preview
struct AnimationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            AnimationView(type: .iconCarousel)
            
            AnimationView(
                type: .typing(text: "Hello, World!"),
                configuration: AnimationConfiguration(size: 24, color: .green)
            )
            
            AnimationView(type: .loading)
            
            // Add more preview examples
        }
        .padding()
    }
}
