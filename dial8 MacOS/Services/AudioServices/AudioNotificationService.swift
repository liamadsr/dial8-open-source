import SwiftUI
import Combine

class AudioNotificationService: ObservableObject {
    // MARK: - Published Properties
    @Published var whisperModelIsReady: Bool = false
    @Published var useLocalWhisperModel: Bool = true
    
    // MARK: - Callbacks
    var onUseLocalWhisperModelChanged: ((Bool) -> Void)?
    var onLanguageChanged: (() -> Void)?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Force useLocalWhisperModel to always be true
        self.useLocalWhisperModel = true
        UserDefaults.standard.set(true, forKey: "useLocalWhisperModel")
        
        // Set up notification observers
        setupNotificationObservers()
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationObservers() {
        // Observe changes to the 'useLocalWhisperModel' key in UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Add observer for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: NSNotification.Name("SelectedLanguageChanged"),
            object: nil
        )
        
        // Bind WhisperManager's isReady property
        WhisperManager.shared.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelIsReady)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleUserDefaultsChanged(_ notification: Notification) {
        let newValue = UserDefaults.standard.bool(forKey: "useLocalWhisperModel")
        if newValue != self.useLocalWhisperModel {
            self.useLocalWhisperModel = newValue
            
            if newValue {
                // Start setup of WhisperManager
                WhisperManager.shared.startSetup()
            } else {
                // If local model is disabled, set isReady to false
                WhisperManager.shared.isReady = false
            }
            
            // Notify listeners about the change
            onUseLocalWhisperModelChanged?(newValue)
        }
    }
    
    @objc private func handleStreamingModeToggled() {
        // Ensure streaming mode is always enabled
        UserDefaults.standard.set(true, forKey: "streamingModeEnabled")
    }
    
    @objc private func handleLanguageChanged(_ notification: Notification) {
        // Notify listeners about the language change
        onLanguageChanged?()
    }
    
    // MARK: - Public Methods
    
    func bindWhisperModelReadyState(to publisher: inout Published<Bool>.Publisher) {
        $whisperModelIsReady
            .receive(on: DispatchQueue.main)
            .assign(to: &publisher)
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Cancel any subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
} 
