import SwiftUI
import Foundation

struct TextReplacementsView: View {
    @StateObject private var replacementService = TextReplacementService.shared
    @State private var showingAddSheet = false
    @State private var editingReplacement: TextReplacement? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    private var mainBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white
    }
    
    private var mainBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Enable/Disable Toggle
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text Replacements")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Automatically replace specific text with your preferred alternatives")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $replacementService.isEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .scaleEffect(0.9)
                        .onChange(of: replacementService.isEnabled) { enabled in
                            replacementService.setEnabled(enabled)
                        }
                }
            }
            
            if replacementService.isEnabled {
                // Add button
                HStack {
                    Button(action: { showingAddSheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Add Replacement")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                
                // List of replacements
                if replacementService.replacements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "textformat.alt")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 4) {
                            Text("No replacements yet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Create your first replacement to get started")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 12) {
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
        .padding(24)
        .background(mainBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(mainBorderColor, lineWidth: 1)
        )
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
    @State private var isHovered = false
    
    private var tagBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    private var tagTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
    }
    
    private var rowBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)
    }
    
    private var rowBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Trigger texts
            HStack(spacing: 6) {
                ForEach(Array(replacement.triggerTexts.enumerated()), id: \.offset) { index, triggerText in
                    Text(triggerText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(tagTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagBackgroundColor)
                        .cornerRadius(4)
                }
            }
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            
            // Replacement text
            Text(replacement.replacement)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isHovered ? Color.red.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
    
    private var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var fieldBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    private var sectionBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
    }
    
    private var sectionBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    
    private var mainBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.95) : Color.white
    }
    
    enum FocusedField: Hashable {
        case triggerText(Int)
        case replacementText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(replacement == nil ? "Add New Replacement" : "Edit Replacement")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Create automatic text replacements for faster typing")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                Divider()
                    .opacity(0.3)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Text to Replace Section
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text to Replace")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Add multiple variations that should be replaced with the same text")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 10) {
                            ForEach(Array(triggerTexts.enumerated()), id: \.offset) { index, triggerText in
                                HStack(spacing: 12) {
                                    TextField("e.g., PM, Sean, btw", text: Binding(
                                        get: { triggerTexts[index] },
                                        set: { triggerTexts[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                    .focused($focusedField, equals: .triggerText(index))
                                    
                                    if triggerTexts.count > 1 {
                                        Button(action: { removeTriggerText(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        Button(action: addTriggerText) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                Text("Add another trigger text")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(20)
                    .background(sectionBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(sectionBorderColor, lineWidth: 1)
                    )
                    .cornerRadius(10)
                    
                    // Replace With Section
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Replace With")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("The text that will replace all the trigger texts above")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        TextField("e.g., product manager, Shaun, by the way", text: $replacementText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .focused($focusedField, equals: .replacementText)
                    }
                    .padding(20)
                    .background(sectionBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(sectionBorderColor, lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            
            // Footer
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.3)
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Save") {
                        saveReplacement()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(canSave ? Color.accentColor : Color.secondary.opacity(0.3))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .disabled(!canSave)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(colorScheme == .dark ? Color.black.opacity(0.02) : Color.white.opacity(0.8))
        }
        .frame(width: 540, height: 560)
        .background(mainBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
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