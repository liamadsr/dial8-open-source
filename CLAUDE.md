# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the Application

```bash
# Open in Xcode
open dial8.xcodeproj

# Build macOS app via command line
xcodebuild -scheme "dial8 MacOS" -configuration Release build

# Build iOS app via command line  
xcodebuild -scheme "dial8" -configuration Release build
```

### Building Whisper Executable

The app uses a custom-built Whisper executable. To rebuild it:

```bash
# Clone whisper.cpp
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build for Apple Silicon
make clean
WHISPER_STATIC=1 make -j

# Copy to project
cp main /path/to/native-whisper/Resources/Whisper/whisper

# Code sign (required for distribution)
codesign --force --options runtime --sign "Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)" /path/to/native-whisper/Resources/Whisper/whisper
```

### Distribution and Notarization

```bash
# Store notarization credentials (one-time setup)
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "your-app-specific-password"

# After exporting from Xcode, notarize the app
xcrun notarytool submit "Dial8.zip" --wait --keychain-profile "AC_PASSWORD"

# Staple the notarization ticket
xcrun stapler staple "Dial8.app"

# Sign update for Sparkle
cd ~/Library/Developer/Xcode/DerivedData/dial8-*/SourcePackages/artifacts/sparkle/Sparkle/bin
./sign_update --ed-key-file /path/to/your/private/key.pem /path/to/Dial8.zip
```

## Architecture Overview

### Core Services Architecture

The app follows a singleton service pattern with the following key managers:

- **AudioManager** (`dial8 MacOS/Services/AudioManager.swift`) - Coordinates audio recording and manages recording state
- **WhisperManager** (`dial8 MacOS/Services/WhisperManager.swift`) - Handles Whisper model downloads and transcription
- **AudioTranscriptionService** (`dial8 MacOS/Services/AudioTranscriptionService.swift`) - Main service coordinating audio capture and transcription
- **TextInsertionService** (`dial8 MacOS/Services/TextInsertionService.swift`) - Handles inserting transcribed text using multiple strategies (clipboard, typing, accessibility)
- **GlobalHotkeyManager** (`dial8 MacOS/Services/GlobalHotkeyManager.swift`) - Manages system-wide Fn key detection
- **AuthenticationManager** (`dial8 MacOS/Services/AuthenticationManager.swift`) - OAuth authentication with Google
- **TextProcessingService** (`dial8 MacOS/Services/TextProcessingService.swift`) - AI-powered text rewriting with tone options

### UI Architecture

The app uses SwiftUI with a floating HUD interface:

- **HUDMainComponent** (`dial8 MacOS/HUD Components/HUDMainComponent.swift`) - Main floating window interface
- **SettingsView** (`dial8 MacOS/View/SettingsView.swift`) - App preferences and configuration
- **TranscriptionView** (`dial8 MacOS/View/TranscriptionView.swift`) - Real-time transcription display

### Key Design Patterns

1. **State Management**: Uses `@Published` properties in ObservableObject services
2. **Audio Pipeline**: 
   - AudioSessionManager → AudioBufferManager → WhisperManager
   - Supports both streaming and standard transcription modes
3. **Text Insertion Strategy Pattern**: Multiple methods for inserting text into other apps
4. **Auto-update**: Sparkle framework integration for seamless updates

### Platform-Specific Code

- macOS-specific code in `dial8 MacOS/` directory
- iOS-specific code in `dial8 iOS/` directory
- Shared services and models between platforms where applicable

### Whisper Model Management

The app downloads and manages Whisper models dynamically:
- Models stored in `~/Documents/dial8/models/`
- Supports Base, Small, and Medium models
- Automatic model download on first use

### Permissions and Security

The app requires several system permissions:
- Microphone access for audio recording
- Accessibility permissions for text insertion
- Screen recording permissions (for certain features)

All handled through the standard macOS permission system with appropriate Info.plist entries.