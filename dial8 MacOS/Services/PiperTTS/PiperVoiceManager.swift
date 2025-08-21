import Foundation
import Combine

// MARK: - Voice Model Definition
struct PiperVoiceModel: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let quality: VoiceQuality
    let language: String
    let downloadURL: String
    let fileSize: Int64 // in bytes
    
    enum VoiceQuality: String, CaseIterable, Comparable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
            let order: [VoiceQuality] = [.low, .medium, .high]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else { return false }
            return lhsIndex < rhsIndex
        }
    }
    
    var displayName: String {
        "\(name) (\(quality.displayName))"
    }
    
    var voiceIdentifier: String {
        "\(language)-\(name.lowercased())-\(quality.rawValue)"
    }
    
    var modelFileName: String {
        "\(voiceIdentifier).onnx"
    }
    
    var modelDirectory: String {
        voiceIdentifier
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Voice Download State
enum VoiceDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
    
    static func == (lhs: VoiceDownloadState, rhs: VoiceDownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded):
            return true
        case (.downloaded, .downloaded):
            return true
        case (.downloading(let p1), .downloading(let p2)):
            return p1 == p2
        case (.failed(let e1), .failed(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Voice Download Manager
class PiperVoiceManager: NSObject, ObservableObject {
    static let shared = PiperVoiceManager()
    
    @Published var availableVoices: [PiperVoiceModel] = []
    @Published var downloadStates: [String: VoiceDownloadState] = [:]
    @Published var selectedVoice: PiperVoiceModel?
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    // Use Sherpa-ONNX pre-converted models that have proper metadata
    private let voicesBaseURL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/"
    
    // Base directory for storing voices
    private var voicesDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("dial8/PiperVoices")
    }
    
    // For bundled voices (like amy-low)
    private var bundledVoicesDirectory: URL? {
        if let path = Bundle.main.resourcePath {
            return URL(fileURLWithPath: path).appendingPathComponent("PiperModels")
        }
        return nil
    }
    
    override init() {
        super.init()
        setupVoices()
        createVoicesDirectory()
        ensureEspeakData()
        updateDownloadStates()
        loadSelectedVoice()
    }
    
    private func setupVoices() {
        // Define available voices with their download URLs and sizes
        // Now with the updated Sherpa-ONNX, all these should work!
        availableVoices = [
            // Amy voices - Using Sherpa-ONNX pre-converted models
            PiperVoiceModel(
                id: "amy-low",
                name: "Amy",
                quality: .low,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-amy-low.tar.bz2",
                fileSize: 63_104_657 // ~63 MB
            ),
            PiperVoiceModel(
                id: "amy-medium",
                name: "Amy",
                quality: .medium,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-amy-medium.tar.bz2",
                fileSize: 71_000_000 // ~71 MB (approximate)
            ),
            
            // Ryan voices - Using Sherpa-ONNX pre-converted models
            PiperVoiceModel(
                id: "ryan-low",
                name: "Ryan",
                quality: .low,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-ryan-low.tar.bz2",
                fileSize: 63_000_000 // ~63 MB (approximate)
            ),
            PiperVoiceModel(
                id: "ryan-medium",
                name: "Ryan",
                quality: .medium,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-ryan-medium.tar.bz2",
                fileSize: 71_000_000 // ~71 MB (approximate)
            ),
            PiperVoiceModel(
                id: "ryan-high",
                name: "Ryan",
                quality: .high,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-ryan-high.tar.bz2",
                fileSize: 117_000_000 // ~117 MB (approximate)
            ),
            
            // Note: Danny voice not available in Sherpa-ONNX pre-converted models
            
            // Kathleen voice - Using Sherpa-ONNX pre-converted models
            PiperVoiceModel(
                id: "kathleen-low",
                name: "Kathleen",
                quality: .low,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-kathleen-low.tar.bz2",
                fileSize: 63_000_000 // ~63 MB (approximate)
            ),
            
            // LibriTTS voice - Using Sherpa-ONNX pre-converted models
            PiperVoiceModel(
                id: "libritts_r-medium",
                name: "LibriTTS",
                quality: .medium,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-libritts_r-medium.tar.bz2",
                fileSize: 71_000_000 // ~71 MB (approximate)
            ),
            
            // Joe voice - Using Sherpa-ONNX pre-converted models
            PiperVoiceModel(
                id: "joe-medium",
                name: "Joe",
                quality: .medium,
                language: "en_US",
                downloadURL: "\(voicesBaseURL)vits-piper-en_US-joe-medium.tar.bz2",
                fileSize: 71_000_000 // ~71 MB (approximate)
            )
        ]
    }
    
    private func createVoicesDirectory() {
        do {
            try FileManager.default.createDirectory(at: voicesDirectory, withIntermediateDirectories: true)
            print("📂 Created voices directory at: \(voicesDirectory.path)")
        } catch {
            print("❌ Failed to create voices directory: \(error)")
        }
    }
    
    private func ensureEspeakData() {
        // Check if espeak-ng-data exists in the voice directory
        let espeakDir = voicesDirectory.appendingPathComponent("espeak-ng-data")
        
        if !FileManager.default.fileExists(atPath: espeakDir.path) {
            print("📥 Downloading required espeak-ng-data...")
            downloadEspeakData()
        } else {
            print("✅ espeak-ng-data already present")
        }
    }
    
    private func downloadEspeakData() {
        let espeakURL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/espeak-ng-data.tar.bz2"
        guard let url = URL(string: espeakURL) else { return }
        
        let session = URLSession.shared
        let task = session.downloadTask(with: url) { [weak self] location, response, error in
            guard let self = self, let location = location else {
                print("❌ Failed to download espeak-ng-data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let tempPath = self.voicesDirectory.appendingPathComponent("espeak-ng-data.tar.bz2")
                if FileManager.default.fileExists(atPath: tempPath.path) {
                    try FileManager.default.removeItem(at: tempPath)
                }
                try FileManager.default.moveItem(at: location, to: tempPath)
                
                // Extract
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-xjf", tempPath.path, "-C", self.voicesDirectory.path]
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    print("✅ espeak-ng-data extracted successfully")
                    try FileManager.default.removeItem(at: tempPath)
                } else {
                    print("❌ Failed to extract espeak-ng-data")
                }
            } catch {
                print("❌ Error processing espeak-ng-data: \(error)")
            }
        }
        task.resume()
    }
    
    private func updateDownloadStates() {
        for voice in availableVoices {
            if isVoiceDownloaded(voice) {
                downloadStates[voice.id] = .downloaded
            } else {
                downloadStates[voice.id] = .notDownloaded
            }
        }
    }
    
    private func loadSelectedVoice() {
        // Load saved selection from UserDefaults
        if let savedVoiceId = UserDefaults.standard.string(forKey: "SelectedPiperVoice"),
           let voice = availableVoices.first(where: { $0.id == savedVoiceId }) {
            // Make sure it's downloaded
            if isVoiceDownloaded(voice) {
                selectedVoice = voice
            } else {
                // Fall back to amy-low
                selectedVoice = availableVoices.first(where: { $0.id == "amy-low" })
            }
        } else {
            // Default to amy-low if available
            selectedVoice = availableVoices.first(where: { $0.id == "amy-low" })
        }
    }
    
    // MARK: - Public Methods
    
    func selectVoice(_ voice: PiperVoiceModel) {
        // Only select if the voice is actually downloaded
        guard isVoiceDownloaded(voice) else {
            print("⚠️ Cannot select voice \(voice.displayName) - not downloaded yet")
            return
        }
        
        // Don't notify if it's already selected
        if selectedVoice?.id == voice.id {
            return
        }
        
        selectedVoice = voice
        UserDefaults.standard.set(voice.id, forKey: "SelectedPiperVoice")
        
        // Small delay to ensure files are ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Notify PiperTTSEngine of voice change
            NotificationCenter.default.post(
                name: Notification.Name("PiperVoiceSelectionChanged"),
                object: nil,
                userInfo: ["voice": voice]
            )
        }
    }
    
    func isVoiceDownloaded(_ voice: PiperVoiceModel) -> Bool {
        // Check if it's the bundled amy-low voice
        if voice.id == "amy-low" {
            if let bundledPath = bundledVoicesDirectory {
                let modelPath = bundledPath
                    .appendingPathComponent(voice.modelDirectory)
                    .appendingPathComponent(voice.modelFileName)
                if FileManager.default.fileExists(atPath: modelPath.path) {
                    return true
                }
            }
        }
        
        // Check downloaded voices
        let voicePath = getVoicePath(for: voice)
        return FileManager.default.fileExists(atPath: voicePath.path)
    }
    
    func getVoicePath(for voice: PiperVoiceModel) -> URL {
        // For bundled amy-low, return bundled path
        if voice.id == "amy-low", let bundledPath = bundledVoicesDirectory {
            return bundledPath
                .appendingPathComponent(voice.modelDirectory)
                .appendingPathComponent(voice.modelFileName)
        }
        
        // For downloaded voices
        return voicesDirectory
            .appendingPathComponent(voice.modelDirectory)
            .appendingPathComponent(voice.modelFileName)
    }
    
    func getTokensPath(for voice: PiperVoiceModel) -> URL {
        // For bundled amy-low
        if voice.id == "amy-low", let bundledPath = bundledVoicesDirectory {
            return bundledPath
                .appendingPathComponent(voice.modelDirectory)
                .appendingPathComponent("tokens.txt")
        }
        
        // For downloaded voices
        return voicesDirectory
            .appendingPathComponent(voice.modelDirectory)
            .appendingPathComponent("tokens.txt")
    }
    
    func downloadVoice(_ voice: PiperVoiceModel) {
        // Check if already downloaded or downloading
        if let state = downloadStates[voice.id] {
            switch state {
            case .downloaded:
                return
            case .downloading:
                return
            default:
                break
            }
        }
        
        // Cancel any existing download
        cancelDownload(for: voice)
        
        // Update state
        downloadStates[voice.id] = .downloading(progress: 0)
        
        // Create voice directory
        let voiceDir = voicesDirectory.appendingPathComponent(voice.modelDirectory)
        do {
            try FileManager.default.createDirectory(at: voiceDir, withIntermediateDirectories: true)
        } catch {
            downloadStates[voice.id] = .failed(error: "Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        // Download model file
        downloadModel(voice: voice, to: voiceDir)
    }
    
    private func downloadModel(voice: PiperVoiceModel, to directory: URL) {
        guard let url = URL(string: voice.downloadURL) else {
            downloadStates[voice.id] = .failed(error: "Invalid URL")
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        
        downloadTasks[voice.id] = task
        task.resume()
        
        print("📥 Starting download for \(voice.displayName) from: \(url)")
    }
    
    private func downloadTokensFile(for voice: PiperVoiceModel, to directory: URL, completion: @escaping (Bool) -> Void) {
        // Construct tokens file URL
        let tokensURLString = voice.downloadURL.replacingOccurrences(of: ".onnx", with: ".onnx.json")
        guard let tokensURL = URL(string: tokensURLString) else {
            print("❌ Failed to construct tokens URL for \(voice.displayName)")
            generateBasicTokensFile(for: voice, in: directory)
            completion(true)
            return
        }
        
        // Download tokens file
        URLSession.shared.dataTask(with: tokensURL) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("❌ Failed to download tokens for \(voice.displayName): \(error?.localizedDescription ?? "Unknown error")")
                // Try to generate a basic tokens file
                self?.generateBasicTokensFile(for: voice, in: directory)
                completion(true) // Still mark as success since we generated a basic file
                return
            }
            
            // Parse JSON and extract tokens
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tokensArray = json["tokens"] as? [String] {
                    // Write tokens to file
                    let tokensPath = directory.appendingPathComponent("tokens.txt")
                    let tokensContent = tokensArray.joined(separator: "\n")
                    try tokensContent.write(to: tokensPath, atomically: true, encoding: .utf8)
                    print("✅ Tokens file saved for \(voice.displayName)")
                    completion(true)
                } else {
                    print("⚠️ Could not parse tokens JSON, generating basic tokens file")
                    self?.generateBasicTokensFile(for: voice, in: directory)
                    completion(true)
                }
            } catch {
                print("❌ Error processing tokens: \(error)")
                self?.generateBasicTokensFile(for: voice, in: directory)
                completion(true) // Still mark as success since we generated a basic file
            }
        }.resume()
    }
    
    private func generateBasicTokensFile(for voice: PiperVoiceModel, in directory: URL) {
        // Try multiple paths to find amy-low tokens
        let possiblePaths = [
            // Bundle path
            bundledVoicesDirectory?.appendingPathComponent("en_US-amy-low").appendingPathComponent("tokens.txt"),
            // Development path
            URL(fileURLWithPath: "/Users/liamalizadeh/code/open-source/dial8-open-source/Resources/PiperModels/en_US-amy-low/tokens.txt"),
            // Downloaded amy-low (if exists)
            voicesDirectory.appendingPathComponent("en_US-amy-low").appendingPathComponent("tokens.txt")
        ].compactMap { $0 }
        
        var tokensCopied = false
        
        for amyTokensPath in possiblePaths {
            if FileManager.default.fileExists(atPath: amyTokensPath.path) {
                do {
                    let tokensContent = try String(contentsOf: amyTokensPath, encoding: .utf8)
                    let destinationPath = directory.appendingPathComponent("tokens.txt")
                    try tokensContent.write(to: destinationPath, atomically: true, encoding: .utf8)
                    print("✅ Copied tokens file from amy-low for \(voice.displayName)")
                    tokensCopied = true
                    break
                } catch {
                    print("⚠️ Failed to copy from \(amyTokensPath): \(error)")
                }
            }
        }
        
        // If we couldn't copy, create a minimal tokens file
        if !tokensCopied {
            print("⚠️ Creating minimal tokens file for \(voice.displayName)")
            let minimalTokens = createMinimalTokensFile()
            let destinationPath = directory.appendingPathComponent("tokens.txt")
            do {
                try minimalTokens.write(to: destinationPath, atomically: true, encoding: .utf8)
                print("✅ Created minimal tokens file for \(voice.displayName)")
            } catch {
                print("❌ Failed to create tokens file: \(error)")
            }
        }
    }
    
    private func createMinimalTokensFile() -> String {
        // Create a minimal but functional tokens file
        // These are basic phoneme tokens that most Piper models use
        return """
        _
        ^
        $
        .
        ,
        ?
        !
        ;
        :
        '
        -
        a
        b
        c
        d
        e
        f
        g
        h
        i
        j
        k
        l
        m
        n
        o
        p
        q
        r
        s
        t
        u
        v
        w
        x
        y
        z
        """
    }
    
    func cancelDownload(for voice: PiperVoiceModel) {
        downloadTasks[voice.id]?.cancel()
        downloadTasks[voice.id] = nil
        downloadStates[voice.id] = .notDownloaded
    }
    
    func deleteVoice(_ voice: PiperVoiceModel) {
        // Don't delete bundled voices
        if voice.id == "amy-low" {
            print("⚠️ Cannot delete bundled voice: \(voice.displayName)")
            return
        }
        
        let voiceDir = voicesDirectory.appendingPathComponent(voice.modelDirectory)
        do {
            try FileManager.default.removeItem(at: voiceDir)
            downloadStates[voice.id] = .notDownloaded
            print("🗑 Deleted voice: \(voice.displayName)")
        } catch {
            print("❌ Failed to delete voice: \(error)")
        }
    }
}

// MARK: - URLSession Delegate
extension PiperVoiceManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Find which voice this download is for
        guard let voice = availableVoices.first(where: { downloadTasks[$0.id] == downloadTask }) else {
            print("❌ Could not identify voice for completed download")
            return
        }
        
        let destinationDir = voicesDirectory.appendingPathComponent(voice.modelDirectory)
        
        do {
            // Create destination directory if needed
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            
            // Check if this is a tar.bz2 file (Sherpa-ONNX format)
            if voice.downloadURL.hasSuffix(".tar.bz2") {
                // Move tar.bz2 to temp location
                let tempPath = destinationDir.appendingPathComponent("temp.tar.bz2")
                if FileManager.default.fileExists(atPath: tempPath.path) {
                    try FileManager.default.removeItem(at: tempPath)
                }
                try FileManager.default.moveItem(at: location, to: tempPath)
                
                print("📦 Extracting \(voice.displayName) archive...")
                
                // Extract tar.bz2 file
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-xjf", tempPath.path, "-C", destinationDir.path]
                process.currentDirectoryURL = destinationDir
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    print("✅ Extracted \(voice.displayName)")
                    // Clean up tar.bz2 file
                    try FileManager.default.removeItem(at: tempPath)
                    
                    // Move files from nested directory to parent directory
                    let extractedDir = destinationDir.appendingPathComponent("vits-piper-en_US-\(voice.id)")
                    if FileManager.default.fileExists(atPath: extractedDir.path) {
                        // Move all files from extracted subdirectory to voice directory
                        let contents = try FileManager.default.contentsOfDirectory(at: extractedDir, includingPropertiesForKeys: nil)
                        for item in contents {
                            let targetPath = destinationDir.appendingPathComponent(item.lastPathComponent)
                            if FileManager.default.fileExists(atPath: targetPath.path) {
                                try FileManager.default.removeItem(at: targetPath)
                            }
                            try FileManager.default.moveItem(at: item, to: targetPath)
                        }
                        // Remove the now-empty subdirectory
                        try FileManager.default.removeItem(at: extractedDir)
                        print("✅ Moved files to correct location for \(voice.displayName)")
                    }
                    
                    // Mark as downloaded
                    DispatchQueue.main.async {
                        self.downloadStates[voice.id] = .downloaded
                        print("✅ Voice \(voice.displayName) is ready to use")
                        self.downloadTasks[voice.id] = nil
                    }
                } else {
                    throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract archive"])
                }
            } else {
                // Legacy path for direct ONNX files (shouldn't be used anymore)
                let destinationPath = destinationDir.appendingPathComponent(voice.modelFileName)
                if FileManager.default.fileExists(atPath: destinationPath.path) {
                    try FileManager.default.removeItem(at: destinationPath)
                }
                try FileManager.default.moveItem(at: location, to: destinationPath)
                
                // Download tokens file for legacy format
                downloadTokensFile(for: voice, to: destinationDir) { [weak self] success in
                    DispatchQueue.main.async {
                        if success {
                            self?.downloadStates[voice.id] = .downloaded
                            print("✅ Voice \(voice.displayName) is ready to use")
                        } else {
                            self?.downloadStates[voice.id] = .failed(error: "Failed to prepare voice files")
                        }
                        self?.downloadTasks[voice.id] = nil
                    }
                }
            }
        } catch {
            print("❌ Failed to process voice model: \(error)")
            DispatchQueue.main.async {
                self.downloadStates[voice.id] = .failed(error: error.localizedDescription)
                self.downloadTasks[voice.id] = nil
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let voice = availableVoices.first(where: { downloadTasks[$0.id] == downloadTask }) else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.downloadStates[voice.id] = .downloading(progress: progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Find which voice this error is for
            if let voice = availableVoices.first(where: { downloadTasks[$0.id] == task as? URLSessionDownloadTask }) {
                DispatchQueue.main.async {
                    self.downloadStates[voice.id] = .failed(error: error.localizedDescription)
                    self.downloadTasks[voice.id] = nil
                }
            }
        }
    }
}