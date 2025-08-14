import SwiftUI
import Foundation

struct TextReplacementsView: View {
    @StateObject private var replacementService = TextReplacementService.shared
    @State private var showingAddAlert = false
    @State private var newShortcut = ""
    @State private var newReplacement = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Enable/Disable Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "textformat.alt")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Text Replacements")
                            .font(.system(size: 14, weight: .medium))
                        Text("Replace shortcuts like PM → product manager")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $replacementService.isEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: replacementService.isEnabled) { enabled in
                            replacementService.setEnabled(enabled)
                        }
                }
            }
            
            if replacementService.isEnabled {
                Divider()
                
                // Add button
                HStack {
                    Button("Add Replacement") {
                        showingAddAlert = true
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.small)
                    
                    Spacer()
                }
                
                // List of replacements
                if replacementService.replacements.isEmpty {
                    VStack(spacing: 8) {
                        Text("No replacements yet")
                            .foregroundColor(.secondary)
                        Text("Add your first replacement to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(replacementService.replacements) { replacement in
                            ReplacementRow(replacement: replacement) {
                                replacementService.removeReplacement(replacement)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .alert("Add Text Replacement", isPresented: $showingAddAlert) {
            TextField("Shortcut (e.g., PM)", text: $newShortcut)
            TextField("Replacement (e.g., product manager)", text: $newReplacement)
            Button("Add") {
                if !newShortcut.isEmpty && !newReplacement.isEmpty {
                    let replacement = TextReplacement(shortcut: newShortcut, replacement: newReplacement)
                    replacementService.addReplacement(replacement)
                    newShortcut = ""
                    newReplacement = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newShortcut = ""
                newReplacement = ""
            }
        } message: {
            Text("Create a shortcut that will be automatically replaced when you speak.")
        }
    }
}

struct ReplacementRow: View {
    let replacement: TextReplacement
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Text(replacement.shortcut)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                .cornerRadius(4)
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text(replacement.replacement)
                .font(.callout)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
        .cornerRadius(6)
    }
}