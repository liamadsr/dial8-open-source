import SwiftUI

struct UsageView: View {
    @StateObject private var usageManager = UsageManager.shared
    
    private var currentUsage: Int {
        usageManager.currentWeekUsage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Usage")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(currentUsage) words")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar (not needed for unlimited words, but keep a static bar)
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)
            }
            .frame(height: 6)
            
            Text("Unlimited words available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
} 