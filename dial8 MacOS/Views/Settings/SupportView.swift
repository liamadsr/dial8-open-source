import SwiftUI

struct SupportView: View {
    @State private var feedbackText = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Support & Feedback")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("We'd love to hear from you!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Contact Cards
            HStack(spacing: 12) {
                // Direct Contact Card
                let directContactCard = HStack(spacing: 12) {
                    // Left side with icon and text
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "envelope")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Direct Contact")
                                .font(.headline)
                            Text("liam@dial8.ai")
                                .font(.system(.body))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Copy button on the right
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("liam@dial8.ai", forType: .string)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy email address")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())

                Button(action: {
                    if let emailURL = URL(string: "mailto:liam@dial8.ai") {
                        NSWorkspace.shared.open(emailURL)
                    }
                }) {
                    directContactCard
                }
                .buttonStyle(HoverButtonStyle())
                
                // Response Time Card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response Time")
                            .font(.headline)
                        Text("24 Hours")
                            .font(.system(.body))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Feedback Form Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Send Feedback")
                    .font(.headline)
                
                Text("Your feedback helps us improve Dial8 for everyone")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $feedbackText)
                    .font(.system(.body))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Button(action: {
                        if let emailURL = URL(string: "mailto:liam@dial8.ai?subject=Dial8%20Feedback&body=\(feedbackText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                            NSWorkspace.shared.open(emailURL)
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Feedback")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct HoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(isHovered ? 0.3 : 0.2), lineWidth: isHovered ? 1.5 : 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
} 