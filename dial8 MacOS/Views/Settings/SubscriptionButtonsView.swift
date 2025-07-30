import SwiftUI

struct SubscriptionButtonsView: View {
    @StateObject private var usageManager = UsageManager.shared
    @State private var isProcessingCheckout = false
    
    var body: some View {
        VStack {
            if usageManager.accountType.lowercased() == "pro" {
                // Manage Subscription button for Pro users
                Button(action: {
                    Task {
                        await handleManageSubscription()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard")
                        Text("Manage Subscription")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, Color(red: 0.3, green: 0.5, blue: 1.0)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: 200)
            } else {
                // Upgrade button for non-pro accounts
                Button(action: {
                    Task {
                        await handleUpgrade()
                    }
                }) {
                    Text("Upgrade to Dial8 Pro for premium features")
                        .fontWeight(.medium)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(height: 32)
                        .frame(maxWidth: 220)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, Color(red: 0.3, green: 0.5, blue: 1.0)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessingCheckout)
            }
        }
    }
    
    private func handleUpgrade() async {
        guard !isProcessingCheckout else { return }
        
        isProcessingCheckout = true
        defer { isProcessingCheckout = false }
        
        do {
            let checkoutURL = try await StripeService.shared.createCheckoutSession()
            
            #if os(macOS)
            if let url = URL(string: checkoutURL) {
                NSWorkspace.shared.open(url)
            }
            #endif
        } catch {
            print("❌ Checkout error: \(error)")
        }
    }
    
    private func handleManageSubscription() async {
        do {
            let portalURL = try await StripeService.shared.createPortalSession()
            #if os(macOS)
            if let url = URL(string: portalURL) {
                NSWorkspace.shared.open(url)
            }
            #endif
        } catch {
            print("❌ Portal session error: \(error)")
        }
    }
} 