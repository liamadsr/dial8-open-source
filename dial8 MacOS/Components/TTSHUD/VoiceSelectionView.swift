import SwiftUI

struct VoiceSelectionView: View {
    @ObservedObject private var voiceManager = PiperVoiceManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVoice: PiperVoiceModel?
    @State private var groupedVoices: [String: [PiperVoiceModel]] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            voiceListView
        }
        .frame(width: 350, height: 400)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            groupVoices()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Select Voice")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Voice List View
    private var voiceListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sortedVoiceGroups, id: \.key) { groupName, voices in
                    VoiceGroupView(
                        groupName: groupName,
                        voices: voices,
                        voiceManager: voiceManager,
                        onSelect: { voice in
                            if voiceManager.isVoiceDownloaded(voice) {
                                voiceManager.selectVoice(voice)
                                dismiss()
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.6))
    }
    
    private var sortedVoiceGroups: [(key: String, value: [PiperVoiceModel])] {
        groupedVoices.sorted { $0.key < $1.key }
    }
    
    private func groupVoices() {
        groupedVoices = Dictionary(grouping: voiceManager.availableVoices) { voice in
            voice.name
        }
        
        // Sort voices by quality within each group
        for (name, voices) in groupedVoices {
            groupedVoices[name] = voices.sorted { $0.quality < $1.quality }
        }
    }
}

// MARK: - Voice Group View
struct VoiceGroupView: View {
    let groupName: String
    let voices: [PiperVoiceModel]
    let voiceManager: PiperVoiceManager
    let onSelect: (PiperVoiceModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader
            voiceRows
        }
    }
    
    private var groupHeader: some View {
        Text(groupName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.gray)
            .padding(.horizontal)
    }
    
    private var voiceRows: some View {
        ForEach(voices, id: \.id) { voice in
            VoiceRowView(
                voice: voice,
                isSelected: voiceManager.selectedVoice?.id == voice.id,
                downloadState: voiceManager.downloadStates[voice.id] ?? .notDownloaded,
                onSelect: { onSelect(voice) },
                onDownload: { voiceManager.downloadVoice(voice) },
                onCancel: { voiceManager.cancelDownload(for: voice) },
                onDelete: { voiceManager.deleteVoice(voice) }
            )
        }
    }
}

struct VoiceRowView: View {
    let voice: PiperVoiceModel
    let isSelected: Bool
    let downloadState: VoiceDownloadState
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            selectionIndicator
            voiceInfo
            Spacer()
            actionButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundView)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if case .downloaded = downloadState {
                onSelect()
            }
        }
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14))
            .foregroundColor(isSelected ? .green : .gray)
            .frame(width: 20)
    }
    
    private var voiceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(voice.quality.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            
            Text(voice.formattedFileSize)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch downloadState {
        case .notDownloaded:
            downloadButton
        case .downloading(let progress):
            downloadingView(progress: progress)
        case .downloaded:
            downloadedView
        case .failed:
            failedView
        }
    }
    
    private var downloadButton: some View {
        Button(action: onDownload) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
                Text("Download")
                    .font(.system(size: 11))
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func downloadingView(progress: Double) -> some View {
        HStack(spacing: 8) {
            ProgressBarView(progress: progress)
                .frame(width: 60, height: 4)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 30)
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var downloadedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
            
            if !isSelected && voice.id != "amy-low" {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovering ? 1 : 0)
            }
        }
    }
    
    private var failedView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Failed")
                .font(.system(size: 10))
                .foregroundColor(.red)
            
            Button(action: onDownload) {
                Text("Retry")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isHovering ? Color.white.opacity(0.05) : Color.clear)
    }
}

// MARK: - Progress Bar View
struct ProgressBarView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
    }
}

// Preview
struct VoiceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceSelectionView()
            .preferredColorScheme(.dark)
    }
}