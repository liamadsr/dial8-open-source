import SwiftUI
import AppKit

struct TranscriptionHistoryView: View {
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @State private var copiedItemId: UUID?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if historyManager.transcriptionHistory.isEmpty {
                    Text("No transcriptions yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(historyManager.transcriptionHistory) { item in
                        TranscriptionHistoryItemView(
                            item: item,
                            isCopied: copiedItemId == item.id,
                            onTap: {
                                copyToClipboard(item)
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 600) // Maximum height before scrolling
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func copyToClipboard(_ item: TranscriptionHistoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        
        // Show copied feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedItemId = item.id
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if copiedItemId == item.id {
                    copiedItemId = nil
                }
            }
        }
    }
}

struct TranscriptionHistoryItemView: View {
    let item: TranscriptionHistoryItem
    let isCopied: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        // Compute background color separately to avoid complex expressions
        let backgroundOpacity: Double = isHovered ? 0.08 : 0.05
        let lightBackgroundOpacity: Double = isHovered ? 0.05 : 0.02
        let backgroundColor = colorScheme == .dark ? 
            Color.white.opacity(backgroundOpacity) : 
            Color.black.opacity(lightBackgroundOpacity)
        
        let borderColor = isCopied ? Color.green.opacity(0.5) : Color.gray.opacity(0.2)
        
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(nil) // No line limit - show full text
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true) // Allow text to expand vertically
                    
                    HStack(spacing: 8) {
                        Text(item.formattedDate)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if let duration = item.duration {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(duration))s")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(isCopied ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}