# Configuration Guide

This guide helps you configure Dial8 for development and distribution.

## Backend Configuration

The app requires a backend API for authentication and user management. You'll need to configure the following:

### 1. AppConfig.swift

Edit `dial8 MacOS/Application/AppConfig.swift` and set your backend URLs:

```swift
static let BACKEND_API_URL = "https://your-backend-url.com"
static let API_KEY = "your-api-key"
static let STT_WEBSOCKET_URL = "wss://your-websocket-url.com"
```

### 2. Info-macOS.plist

For app distribution with Sparkle auto-updates, configure:

```xml
<key>SUFeedURL</key>
<string>https://your-update-server.com/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>your-sparkle-public-key</string>
```

### 3. Code Signing (CLAUDE.md)

Update the code signing information in build scripts:

```bash
# Replace with your Developer ID
codesign --force --options runtime --sign "Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)" /path/to/whisper

# Update notarization credentials
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "your-app-specific-password"
```

## OAuth Configuration

The app uses Google OAuth for authentication. The OAuth flow is handled by the backend, so no client secrets are stored in the app.

## Whisper Models

Whisper models are downloaded from the public Hugging Face repository. No configuration needed.

## Development vs Production

Use Xcode build configurations to manage different environments:
- Development: Local testing with development backend
- Release: Production backend for distribution

## Security Notes

- Never commit actual API keys or secrets to the repository
- Use environment-specific configuration files
- Keep sensitive credentials in a secure password manager
- For production, use proper secret management services