import SwiftUI
import AppKit

// MARK: - Editable Title Component
struct EditableTitle: View {
    @Binding var title: String
    @Binding var isEditing: Bool
    var onSave: (String) -> Void
    
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        if isEditing {
            TextField("Title", text: $editedTitle, onCommit: {
                saveTitle()
            })
            .font(.system(size: 36, weight: .bold))
            .textFieldStyle(PlainTextFieldStyle())
            .background(Color.clear)
            .focused($isTitleFocused)
            .onAppear {
                editedTitle = title
                isTitleFocused = true
            }
            .onSubmit {
                saveTitle()
            }
            .onChange(of: isTitleFocused) { focused in
                if !focused {
                    saveTitle()
                }
            }
        } else {
            Button(action: {
                startEditing()
            }) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TitleButtonStyle())
            .zIndex(100) // Extremely high zIndex to ensure it's above everything
        }
    }
    
    private func startEditing() {
        editedTitle = title
        isEditing = true
        
        // Force first responder to nil before focusing on title
        if let window = NSApplication.shared.keyWindow {
            if let responder = window.firstResponder as? NSTextView {
                window.makeFirstResponder(nil)
            }
            
            // Schedule title focus for next run loop to ensure proper transition
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
    }
    
    private func saveTitle() {
        if !editedTitle.isEmpty {
            title = editedTitle
            onSave(editedTitle)
            isEditing = false
        }
    }
}

// MARK: - Custom Button Style
struct TitleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6) // Add padding to make it easier to click
            .contentShape(Rectangle()) // Ensure entire area is clickable
            .opacity(configuration.isPressed ? 0.8 : 1.0) // Simple press effect
            .background(Color.clear) // Clear background but still captures clicks
    }
}