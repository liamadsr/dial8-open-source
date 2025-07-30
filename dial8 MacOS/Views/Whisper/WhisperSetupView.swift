/// WhisperSetupView provides an initial setup interface for Whisper models.
///
/// This view offers a streamlined interface for model management:
///
/// UI Components:
/// - Model List:
///   • Model name and status
///   • Size information
///   • Download progress
///   • Action buttons
///
/// Features:
/// - Model Status Display:
///   • Available/Not Downloaded status
///   • Selected model indication
///   • Download progress tracking
///   • Error message display
///
/// Actions:
/// - Download Models
/// - Select Active Model
/// - Delete Existing Models
/// - Monitor Download Progress
///
/// Layout:
/// - Compact list presentation
/// - Clear status indicators
/// - Informative help text
/// - Error message handling
///
/// Usage:
/// ```swift
/// // Present setup view
/// WhisperSetupView()
///
/// // In a navigation context
/// NavigationView {
///     WhisperSetupView()
///         .navigationTitle("Setup Whisper")
/// }
/// ```
///
/// Note: This view provides a simpler, list-based alternative to
/// WhisperModelSelectionView for basic model management.

import SwiftUI

struct WhisperSetupView: View {
    @ObservedObject var whisperManager = WhisperManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Whisper Model")
                .font(.headline)

            if let errorMessage = whisperManager.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }

            // Only show the Medium model
            if let mediumModel = whisperManager.availableModels.first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        
                        Text(mediumModel.name)
                            .font(.headline)
                    }
                    
                    Text(mediumModel.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    if mediumModel.isAvailable {
                        HStack {
                            Text("Size: \(mediumModel.size)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Not Downloaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        // Download button
                        Button("Download") {
                            whisperManager.downloadModel(modelSize: "Medium")
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                Text("Loading model information...")
                    .foregroundColor(.secondary)
            }

            if whisperManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: whisperManager.downloadProgress, total: 1.0)
                    Text("\(Int(whisperManager.downloadProgress * 100))%")
                        .font(.caption)
                }
                .padding()
            }
        }
        .padding()
    }
}
