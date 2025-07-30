import Cocoa
import AVFoundation
import Combine

class HUDSoundEffects: ObservableObject {
    static let shared = HUDSoundEffects()
    
    // Available sound options
    static let availableSounds = [
        "Pop", "Glass", "Tink", "Purr", "Bottle", 
        "Blow", "Breeze", "Bubble", "Frog", "Funk"
    ]
    
    private var openSound: NSSound?
    private var readySound: NSSound?
    private var closeSound: NSSound?
    private var processingSound: NSSound?
    
    // User preferences
    @Published var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: "HUDSoundsEnabled")
        }
    }
    
    @Published var openSoundName: String {
        didSet {
            UserDefaults.standard.set(openSoundName, forKey: "HUDOpenSound")
            setupSounds()
        }
    }
    
    @Published var readySoundName: String {
        didSet {
            UserDefaults.standard.set(readySoundName, forKey: "HUDReadySound")
            setupSounds()
        }
    }
    
    @Published var closeSoundName: String {
        didSet {
            UserDefaults.standard.set(closeSoundName, forKey: "HUDCloseSound")
            setupSounds()
        }
    }
    
    @Published var processingSoundName: String {
        didSet {
            UserDefaults.standard.set(processingSoundName, forKey: "HUDProcessingSound")
            setupSounds()
        }
    }
    
    private init() {
        // Load preferences from UserDefaults
        self.soundsEnabled = UserDefaults.standard.object(forKey: "HUDSoundsEnabled") as? Bool ?? true
        self.openSoundName = UserDefaults.standard.string(forKey: "HUDOpenSound") ?? "Frog"
        self.readySoundName = UserDefaults.standard.string(forKey: "HUDReadySound") ?? "Pop"
        self.closeSoundName = UserDefaults.standard.string(forKey: "HUDCloseSound") ?? "Bottle"
        self.processingSoundName = UserDefaults.standard.string(forKey: "HUDProcessingSound") ?? "Tink"
        
        setupSounds()
    }
    
    private func setupSounds() {
        // Load sounds based on user preferences
        openSound = NSSound(named: openSoundName)
        readySound = NSSound(named: readySoundName)
        closeSound = NSSound(named: closeSoundName)
        processingSound = NSSound(named: processingSoundName)
        
        // Set volume
        openSound?.volume = 0.3
        readySound?.volume = 0.3
        closeSound?.volume = 0.3
        processingSound?.volume = 0.2  // Quieter for processing
    }
    
    func playOpenSound() {
        guard soundsEnabled else { return }
        openSound?.play()
    }
    
    func playReadySound() {
        guard soundsEnabled else { return }
        readySound?.play()
    }
    
    func playCloseSound() {
        guard soundsEnabled else { return }
        closeSound?.play()
    }
    
    func playProcessingSound() {
        guard soundsEnabled else { return }
        processingSound?.play()
    }
    
    // Alternative method using custom sound files
    func loadCustomSound(named name: String, fileExtension: String = "mp3") -> NSSound? {
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            print("Sound file '\(name).\(fileExtension)' not found")
            return nil
        }
        
        let sound = NSSound(contentsOf: soundURL, byReference: true)
        sound?.volume = 0.3
        return sound
    }
}