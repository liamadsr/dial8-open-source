# Contributing to Dial8

First off, thank you for considering contributing to Dial8! It's people like you that make Dial8 such a great tool.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed after following the steps**
* **Explain which behavior you expected to see instead and why**
* **Include screenshots if possible**
* **Include your system information** (macOS version, hardware specs)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a step-by-step description of the suggested enhancement**
* **Provide specific examples to demonstrate the steps**
* **Describe the current behavior and explain which behavior you expected to see instead**
* **Explain why this enhancement would be useful**

### Pull Requests

* Fill in the required template
* Do not include issue numbers in the PR title
* Follow the Swift style guide
* Include thoughtfully-worded, well-structured tests
* Document new code
* End all files with a newline

## Development Setup

1. Fork the repo and create your branch from `main`
2. Clone your fork locally
3. Open `dial8.xcodeproj` in Xcode
4. Configure your backend (see [CONFIGURATION.md](CONFIGURATION.md))
5. Build and run the project

### Building the Project

```bash
# Build for macOS
xcodebuild -scheme "dial8 MacOS" -configuration Debug build

# Run tests (when available)
xcodebuild -scheme "dial8 MacOS" test
```

## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

### Swift Styleguide

* Use 4 spaces for indentation
* Prefer `let` over `var` whenever possible
* Use descriptive variable names
* Follow Apple's Swift API Design Guidelines
* Use `// MARK: -` comments to organize code
* Keep functions focused and small
* Write self-documenting code, add comments only when necessary

### Documentation Styleguide

* Use Markdown for documentation
* Reference functions as `functionName()`
* Reference classes as `ClassName`
* Use code blocks for examples

## Project Structure

```
dial8/
├── dial8 MacOS/          # macOS app source code
│   ├── Application/      # App entry points and configuration
│   ├── Services/         # Core services (Audio, Whisper, etc.)
│   ├── Views/           # SwiftUI views
│   ├── Components/      # Reusable UI components
│   └── Models/          # Data models
├── Resources/           # App resources and frameworks
└── build/              # Build artifacts (gitignored)
```

## Key Areas for Contribution

We're particularly interested in contributions in these areas:

1. **Real-time streaming transcription** - Implementing true streaming support
2. **Multi-language support** - Adding support for more languages
3. **Performance optimization** - Making transcription faster
4. **UI/UX improvements** - Making the app more intuitive
5. **Testing** - Adding unit and integration tests
6. **Documentation** - Improving code and user documentation

## Questions?

Feel free to open an issue with your question or join our community discussions.