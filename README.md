# Dial8 - Local Speech-to-Text for macOS

Dial8 is a powerful macOS application that runs Whisper AI locally to provide fast, private speech-to-text transcription. Replace typing with natural speech - just hold a hotkey, speak, and watch your words appear instantly.

## Key Features

### 🎯 Smart Voice Activity Detection
- Only transcribes when you're actually speaking
- Filters out background noise (TV, music, conversations)
- Visual feedback shows when speech is detected via HUD effects

### 🎙️ Two Recording Modes

**Manual Mode**
- Hold hotkey to record
- Release to transcribe and insert text
- Perfect for quick thoughts and commands

**Streaming Mode**
- Toggle recording on/off with hotkey
- Automatically detects pauses in speech
- Configurable pause detection duration
- Inserts text segment-by-segment
- Ideal for quiet environments and longer dictation

### 🤖 AI-Powered Text Processing
- Leverages macOS 15's foundation models
- Rewrite transcribed text in different tones
- Multiple tone options available

### 🔐 Privacy First
- Runs entirely offline using local Whisper models
- No data leaves your device
- Your speech stays private

### ⚡ Native macOS Integration
- Seamless text insertion into any app
- App-aware functionality
- Accessibility API integration
- System-wide hotkey support

## Installation

1. Download the latest release from [Releases](https://github.com/your-username/dial8-open-source/releases)
2. Open the DMG and drag Dial8 to Applications
3. Launch Dial8 and grant necessary permissions:
   - Microphone access
   - Accessibility permissions
   - Dictation permissions

## Usage

1. **Set your hotkey** in Settings (default: Fn key)
2. **Choose your Whisper model** (Base, Small, or Medium)
3. **Select recording mode**:
   - Manual: Hold hotkey → Speak → Release
   - Streaming: Press hotkey → Speak naturally → Press again to stop

## Building from Source

```bash
# Clone the repository
git clone https://github.com/your-username/dial8-open-source.git
cd dial8-open-source

# Open in Xcode
open dial8.xcodeproj

# Build for macOS
xcodebuild -scheme "dial8 MacOS" -configuration Release build
```

See [CLAUDE.md](CLAUDE.md) for detailed build instructions and architecture overview.

## Contributing

We're building a community around Dial8 to take speech-to-text to the next level! Here are some exciting areas for contribution:

### 🚀 Future Features We'd Love Help With

- **Real-time streaming transcription** - Like native macOS dictation
- **App-specific configurations** - Automatically adjust tone/style based on the active app
- **Custom tone profiles** - Define your own rewriting styles
- **Multi-language support** - Expand beyond English
- **Voice commands** - Control formatting and punctuation with speech
- **Integration APIs** - Connect with other productivity tools

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow existing Swift/SwiftUI patterns
- Add tests for new features
- Update documentation
- Keep privacy and offline-first principles

## Technical Stack

- **Language**: Swift/SwiftUI
- **AI Model**: Whisper (via whisper.cpp)
- **Platforms**: macOS 14+, iOS support in progress
- **Key Frameworks**: AVFoundation, Accessibility, Speech

## Community

- [Discord](https://discord.gg/your-invite) - Join our community chat
- [Issues](https://github.com/your-username/dial8-open-source/issues) - Report bugs or request features
- [Discussions](https://github.com/your-username/dial8-open-source/discussions) - Share ideas and get help

## License

[MIT License](LICENSE) - See LICENSE file for details

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) for the amazing speech recognition model
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for the efficient C++ implementation
- All our contributors and community members

---

Built with ❤️ by the Dial8 community. Let's revolutionize how we interact with our computers through speech!