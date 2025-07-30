# TextProcessingService Requirements

## Overview

The TextProcessingService is a utility layer on top of the existing LLM infrastructure in Dial8. It provides text rewriting capabilities by leveraging the existing `LocalLLMChatService` in utility mode. This service will be initially integrated with the text HUD workflow but designed to be callable from other parts of the application.

## Core Functionality

### Text Rewriting Operations

1. Rewrite selected text in multiple styles:
   - Original (preserved as-is, no LLM processing)
   - Concise
   - Professional
   - Friendly

2. Processing approach:
   - Use `LocalLLMChatService.sendMessage()` with `messageMode: .utility`
   - Process each style sequentially using separate LLM calls
   - Request and parse simple JSON responses
   - Provide progress updates during processing

3. Support both short text fragments and longer paragraphs

## Technical Requirements

### Integration with Existing Infrastructure

1. Leverage `LocalLLMChatService.swift` utility mode
   - Use the existing `sendMessage()` method with `messageMode: .utility`
   - Utilize the existing model loading and inference pipeline
   - Ensure proper cleanup of resources after processing

2. Utilize existing app infrastructure:
   - Integrate with the text HUD via `SelectedTextOverlayController`
   - Use the default LLM model configured in the app
   - Follow existing logging patterns

### Parsing Implementation

1. JSON-based parsing strategy:
   - Parse valid JSON directly when properly formatted
   - Fall back to regex extraction of key fields if JSON is malformed
   - If all else fails, return the raw response with minimal cleaning

2. Always return some result, even when parsing is imperfect

### Error Handling

1. Surface LLM errors from `LocalLLMChatService`
2. Handle timeouts and cancellations gracefully
3. Provide meaningful error messages in the UI

## User Experience Requirements

### Text HUD Interface

1. Styling:
   - Maintain exactly the current styling of the Text HUD
   - No visual changes to the existing design language
   - Preserve all current fonts, spacing, colors, and visual elements

2. Layout:
   - Original text tab on the far left
   - Additional tone tabs (Concise, Professional, Friendly) positioned to the right
   - Content area below tabs displays the selected text
   - Use the existing copy button pattern from the current HUD implementation

3. Tab Design:
   - Use the exact same styling as currently used in the HUD
   - Simple text labels with minimal indicators for the selected state
   - No additional borders or styling that isn't already present

4. Processing States:
   - Tone tabs should be grayed out when processing
   - No spinners, loading animations, or progress bars
   - Tabs transition from gray to normal text when processing completes
   - Tabs become clickable only when their content is available

5. Interaction:
   - Use the existing interaction patterns from the HUD
   - Copying text should use the existing copy button pattern
   - Automatically copy the selected text when the overlay is closed (optional)

6. Integration:
   - The new functionality should feel like a natural extension of the existing HUD
   - No changes to the current look and feel
   - Ensure the existing HUD animations and behaviors are preserved

## Component Architecture

### Core Service Components

1. `TextProcessingService` class
   - Public method: `rewriteText(text:modelName:tone:onUpdate:completion:)`
   - Private parsing methods
   - Error types and handling

2. `TextRewritingModel` class (ObservableObject)
   - Properties for each rewrite style
   - Loading state management
   - Text selection and display logic

3. `SelectedTextRewriteView` struct
   - Style selector UI (tab-like interface)
   - Text display area
   - Copy and close actions

### Data Model

1. `TextRewritingTone` enum
   - `original`
   - `concise`
   - `professional`
   - `friendly`

2. `RewrittenText` struct
   - Properties for each tone
   - Helper method to get text by tone

### Integration Points

1. Update `SelectedTextOverlayController` to:
   - Use `SelectedTextRewriteView` instead of the current view
   - Handle text selection and display
   - Manage window positioning and animations

## Implementation Details

### Prompt Engineering

1. System prompt:
   ```
   You are a text rewriting assistant running in the background of an application.
   You receive:
   1. A tone value (one of "professional", "concise", or "friendly").
   2. A text value to be rewritten in the given tone.

   Your output requirements:
   - Return only a single valid JSON object.
   - Do not include extra text, explanations, or commentary.
   - The JSON object must always have the same keys:
     {
       "tone": "...",
       "rewritten_text": "..."
     }
   ```

2. User prompt (per tone):
   ```
   Below is the text you need to rewrite:
   {{original text}}

   Below is the requested tone:
   {{requested tone}}

   Respond with exactly:

   ```json
   {
     "tone": "<the tone>",
     "rewritten_text": "<the revised text here>"
   }
   ```
   ```

3. Run a separate prompt for each rewriting tone rather than trying to get all in one response

### Detailed Workflow

1. User selects text and presses Fn key
2. Text overlay appears showing original text
3. After a short delay (300ms):
   - `TextProcessingService` processes each tone sequentially
   - UI updates as each tone is processed
4. User can select different tones via tabs
5. User can copy the rewritten text

## Required Files

1. `TextProcessingService.swift`
   - Core service implementation
   - JSON parsing logic
   - LLM integration

2. `TextRewritingModel.swift`
   - Observable state model
   - Tone management
   - Loading states

3. `SelectedTextRewriteView.swift`
   - SwiftUI view implementation
   - Tone selection UI
   - Text display and actions

