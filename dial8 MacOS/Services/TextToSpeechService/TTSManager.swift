import Foundation
import Combine

class TTSManager: ObservableObject {
    static let shared = TTSManager()
    
    // MARK: - Published Properties
    @Published private(set) var isActive = false
    @Published private(set) var isTTSEnabled = true
    
    // MARK: - Private Properties
    private let ttsService = TextToSpeechService.shared
    private let selectionMonitor = TextSelectionMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupBindings()
        setupNotifications()
        print("🎯 TTSManager: Initialized")
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard isTTSEnabled else {
            print("🎯 TTSManager: TTS is disabled, not starting")
            return
        }
        
        print("🎯 TTSManager: Starting TTS system")
        isActive = true
        selectionMonitor.startMonitoring()
    }
    
    func stop() {
        print("🎯 TTSManager: Stopping TTS system")
        isActive = false
        selectionMonitor.stopMonitoring()
        ttsService.stop()
    }
    
    func pauseTTSForRecording() {
        print("🎯 TTSManager: Pausing TTS for recording")
        
        // Stop any ongoing TTS
        if ttsService.isSpeaking {
            ttsService.stop()
        }
        
        // Temporarily disable selection monitoring
        selectionMonitor.stopMonitoring()
        
        // Hide any TTS HUD that might be showing
        NotificationCenter.default.post(name: Notification.Name("TTSHUDDismissed"), object: nil)
    }
    
    func resumeTTSAfterRecording() {
        print("🎯 TTSManager: Resuming TTS after recording")
        
        // Resume selection monitoring if TTS was active
        if isActive && isTTSEnabled {
            selectionMonitor.startMonitoring()
        }
    }
    
    func enableTTS() {
        print("🎯 TTSManager: Enabling TTS")
        isTTSEnabled = true
        
        // Start if not already active
        if !isActive {
            start()
        }
    }
    
    func disableTTS() {
        print("🎯 TTSManager: Disabling TTS")
        isTTSEnabled = false
        stop()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor TTS service state changes
        ttsService.$state
            .sink { [weak self] state in
                self?.handleTTSStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotifications() {
        // Listen for recording start notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingStarted),
            name: Notification.Name("RecordingStarted"),
            object: nil
        )
        
        // Listen for recording stop notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingStopped),
            name: Notification.Name("RecordingStopped"),
            object: nil
        )
    }
    
    private func handleTTSStateChange(_ state: TTSState) {
        print("🎯 TTSManager: TTS state changed to \(state)")
    }
    
    @objc private func handleRecordingStarted() {
        print("🎯 TTSManager: Recording started, pausing TTS")
        pauseTTSForRecording()
    }
    
    @objc private func handleRecordingStopped() {
        print("🎯 TTSManager: Recording stopped, resuming TTS")
        resumeTTSAfterRecording()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}