import SwiftUI
import Foundation

struct TextReplacementsView: View {
    @StateObject private var replacementService = TextReplacementService.shared
    @State private var showingAddSheet = false
    @State private var editingReplacement: TextReplacement? = nil
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
                        Text("Replace text like PM → product manager or Sean, Shawn → Shaun")
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
                    Button("Add New Replacement") {
                        showingAddSheet = true
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
                            ReplacementRow(
                                replacement: replacement,
                                onEdit: { editingReplacement = replacement },
                                onDelete: { replacementService.removeReplacement(replacement) }
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddSheet) {
            ReplacementEditSheet(replacement: nil) { newReplacement in
                replacementService.addReplacement(newReplacement)
            }
        }
        .sheet(item: $editingReplacement) { replacement in
            ReplacementEditSheet(replacement: replacement) { updatedReplacement in
                replacementService.updateReplacement(updatedReplacement)
            }
        }
    }
}

struct ReplacementRow: View {
    let replacement: TextReplacement
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Trigger texts
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(replacement.triggerTexts.enumerated()), id: \.offset) { index, triggerText in
                    Text(triggerText)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)
                .padding(.top, 2)
            
            // Replacement text
            Text(replacement.replacement)
                .font(.callout)
                .foregroundColor(.primary)
                .padding(.top, 2)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
        .cornerRadius(8)
    }
}

struct ReplacementEditSheet: View {
    let replacement: TextReplacement? // nil for new replacement
    let onSave: (TextReplacement) -> Void
    
    @State private var triggerTexts: [String] = [""]
    @State private var replacementText: String = ""
    @FocusState private var focusedField: FocusedField?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    enum FocusedField: Hashable {
        case triggerText(Int)
        case replacementText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(replacement == nil ? "Add New Replacement" : "Edit Replacement")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color.gray.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Text to Replace Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Text to Replace")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Add multiple variations that should be replaced with the same text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(triggerTexts.enumerated()), id: \.offset) { index, triggerText in
                                HStack {
                                    TextField("e.g., PM, Sean, btw", text: Binding(
                                        get: { triggerTexts[index] },
                                        set: { triggerTexts[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .triggerText(index))
                                    
                                    if triggerTexts.count > 1 {
                                        Button(action: { removeTriggerText(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        Button(action: addTriggerText) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add another trigger text")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Replace With Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replace With")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("e.g., product manager, Shaun, by the way", text: $replacementText)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .replacementText)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            // Footer
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    saveReplacement()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color.gray.opacity(0.1))
        }
        .frame(width: 500, height: 500)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(12)
        .onAppear {
            if let replacement = replacement {
                // Editing existing replacement
                triggerTexts = replacement.triggerTexts.isEmpty ? [""] : replacement.triggerTexts
                replacementText = replacement.replacement
            }
            
            // Auto-focus the first trigger text field when the sheet opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .triggerText(0)
            }
        }
    }
    
    private var canSave: Bool {
        !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        triggerTexts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func addTriggerText() {
        triggerTexts.append("")
        // Focus the newly added text field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .triggerText(triggerTexts.count - 1)
        }
    }
    
    private func removeTriggerText(at index: Int) {
        if triggerTexts.count > 1 {
            triggerTexts.remove(at: index)
        }
    }
    
    private func saveReplacement() {
        let cleanedTriggerTexts = triggerTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let cleanedReplacementText = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedTriggerTexts.isEmpty && !cleanedReplacementText.isEmpty else { return }
        
        let newReplacement: TextReplacement
        if let existingReplacement = replacement {
            // Create updated replacement with same ID and enabled state
            newReplacement = TextReplacement(
                id: existingReplacement.id,
                triggerTexts: cleanedTriggerTexts,
                replacement: cleanedReplacementText,
                enabled: existingReplacement.enabled
            )
        } else {
            // Create new replacement
            newReplacement = TextReplacement(
                triggerTexts: cleanedTriggerTexts,
                replacement: cleanedReplacementText
            )
        }
        
        onSave(newReplacement)
        dismiss()
    }
}