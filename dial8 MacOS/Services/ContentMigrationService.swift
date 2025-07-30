import Foundation

/// Service to migrate from old Media/recordings structure to new Content structure
@MainActor
class ContentMigrationService {
    static let shared = ContentMigrationService()
    
    private init() {}
    
    /// Check if migration is needed
    func isMigrationNeeded() -> Bool {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let oldMediaPath = appSupportURL.appendingPathComponent("Dial8/Media")
        let newContentPath = appSupportURL.appendingPathComponent("Dial8/Content")
        
        // Migration is needed if old Media directory exists but new Content directory doesn't
        return FileManager.default.fileExists(atPath: oldMediaPath.path) && 
               !FileManager.default.fileExists(atPath: newContentPath.path)
    }
    
    /// Perform migration from Media to Content structure
    func performMigration() async throws {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ContentMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find application support directory"])
        }
        
        let oldMediaPath = appSupportURL.appendingPathComponent("Dial8/Media")
        let newContentPath = appSupportURL.appendingPathComponent("Dial8/Content")
        
        print("📦 Starting content migration from Media to Content...")
        
        // Create the new Content directory
        try FileManager.default.createDirectory(at: newContentPath, withIntermediateDirectories: true)
        
        // Get all meeting note directories
        let meetingNoteDirs = try FileManager.default.contentsOfDirectory(
            at: oldMediaPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        
        for meetingNoteDir in meetingNoteDirs {
            let meetingNoteId = meetingNoteDir.lastPathComponent
            print("📁 Migrating meeting note: \(meetingNoteId)")
            
            // Create new meeting note directory
            let newMeetingNoteDir = newContentPath.appendingPathComponent(meetingNoteId)
            try FileManager.default.createDirectory(at: newMeetingNoteDir, withIntermediateDirectories: true)
            
            // Check for recordings subdirectory
            let oldRecordingsDir = meetingNoteDir.appendingPathComponent("recordings")
            
            if FileManager.default.fileExists(atPath: oldRecordingsDir.path) {
                // Move all capture directories from recordings/ to the meeting note root
                let captureContents = try FileManager.default.contentsOfDirectory(
                    at: oldRecordingsDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                
                for item in captureContents {
                    let itemName = item.lastPathComponent
                    
                    // Move audio_capture_*, screen_capture_*, mic_capture_* directories and .qma packages
                    if itemName.hasPrefix("audio_capture_") || 
                       itemName.hasPrefix("screen_capture_") || 
                       itemName.hasPrefix("mic_capture_") ||
                       itemName.hasSuffix(".qma") ||
                       itemName.hasSuffix(".mp4") {
                        
                        let newItemPath = newMeetingNoteDir.appendingPathComponent(itemName)
                        
                        print("  📋 Moving \(itemName)")
                        try FileManager.default.moveItem(at: item, to: newItemPath)
                    }
                }
            }
            
            // Move any other files/directories at the meeting note level (like metadata)
            let meetingNoteContents = try FileManager.default.contentsOfDirectory(
                at: meetingNoteDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            for item in meetingNoteContents {
                let itemName = item.lastPathComponent
                
                // Skip the recordings directory (we already processed it)
                if itemName != "recordings" {
                    let newItemPath = newMeetingNoteDir.appendingPathComponent(itemName)
                    
                    print("  📋 Moving \(itemName)")
                    try FileManager.default.moveItem(at: item, to: newItemPath)
                }
            }
        }
        
        // Remove the old Media directory after successful migration
        try FileManager.default.removeItem(at: oldMediaPath)
        
        print("✅ Content migration completed successfully!")
    }
    
    /// Perform migration if needed
    func performMigrationIfNeeded() async {
        if isMigrationNeeded() {
            do {
                try await performMigration()
            } catch {
                print("❌ Content migration failed: \(error)")
            }
        }
    }
}