# arcade

> One playground for every AI model. Text, image, audio, video — any provider, one native macOS app.

Arcade is a local, definition-driven playground for testing AI inference endpoints. Instead of bouncing between provider dashboards or writing throwaway curl commands, you pick a model, fill in a form tailored to that model's actual inputs, and see the result — rendered inline as text, image, audio, or video, not a raw JSON blob.

Built natively with SwiftUI. No Electron. No browser. No server.

### Why

Generic API tools show you every possible field regardless of the model you're testing. But an image generation model has completely different inputs than a chat model, and those inputs vary between providers. You end up ignoring half the form and guessing which fields matter.

Arcade solves this with **JSON definition files**. Each file describes one model endpoint — its parameters, auth, request format, and response structure. Arcade reads the definition and generates the right form with the right controls. Add a new provider by adding a file. No code changes. Definitions are portable and can be contributed by anyone.

### What makes it different

- **Multimodal in one place** — text, image, audio, and video generation across 17 providers
- **Adaptive UI** — each model gets a form built from its definition, showing only relevant inputs
- **Full transparency** — curl commands, raw request/response JSON, latency metrics on every call
- **BYOK** — bring your own API keys. Keys are stored in macOS Keychain, sent only to the provider's API, never persisted elsewhere
- **Extensible by design** — add a provider by dropping in a JSON file, no code changes needed
- **Native macOS** — pure SwiftUI + Foundation, keyboard-driven, fast

## Features

### Command palette

Hit `Cmd+K` to open the command palette. Search across all endpoints, bookmarks, and saved configurations. Select an endpoint to see available models, then pick one to load the form.

### Play mode

Pick any endpoint, click an example chip to pre-fill the prompt, and hit Generate. Streaming endpoints show tokens as they arrive with TTFT and tokens/sec metrics.

### Curl preview

Inspect the exact HTTP request before or after sending. Toggle "Include API key" to copy a ready-to-run curl command.

### JSON inspector

Open the inspector (`Cmd+I`) to see the full request and response payloads with redacted auth headers.

### Log panel

Toggle the log drawer (`Cmd+L`) to see raw HTTP request/response history.

### Everything else

- **Streaming, polling, and sync** — three interaction patterns, chosen per-definition
- **Output renderers** — text (with streaming tokens), images, audio player, and video player
- **System prompt** — inject a system message on any chat-completions endpoint
- **Latency metrics** — time-to-first-token and tokens/sec for streaming; total duration for sync
- **Bookmarks** — save and restore endpoint + param combinations (`Cmd+D`)
- **Advanced params** — collapsible section for sliders (temperature, max tokens, etc.)
- **API key management** — stored in macOS Keychain, status shown per provider in Settings (`Cmd+,`)
- **Sound effects** — semantic system sounds for actions, toggleable in Settings

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+K` | Command Palette |
| `Cmd+0` | Toggle Sidebar |
| `Cmd+L` | Toggle Log Panel |
| `Cmd+I` | Toggle Inspector |
| `Cmd+D` | Save Bookmark |
| `Cmd+,` | Settings |

## Providers

| Provider | Definitions | Types |
|---|---|---|
| Baseten | 1 | chat |
| Berget | 1 | chat |
| Cerebras | 1 | chat |
| DeepInfra | 2 | chat, image |
| DeepSeek | 1 | chat |
| DigitalOcean | 3 | chat, image, TTS |
| Fireworks | 3 | chat, image |
| Google | 2 | chat, image |
| Groq | 1 | chat |
| Hugging Face | 1 | chat |
| Mistral | 1 | chat |
| OpenAI | 3 | chat, image |
| OpenRouter | 3 | chat, image, audio |
| Perplexity | 1 | chat |
| SambaNova | 1 | chat |
| Together | 4 | chat, image, TTS, video |

**17 providers, 29 definitions.**

## Quick start

```bash
git clone https://github.com/ajot/arcade.git
cd arcade
open arcade.xcodeproj
```

Build and run (`Cmd+R`). Add your API keys in Settings (`Cmd+,`). You only need keys for the providers you want to test.

## Adding a provider

Create a JSON file in `arcade/Resources/Definitions/`. The definition has four sections:

| Section | Purpose |
|---|---|
| `auth` | How to attach the API key (header name, prefix, Keychain key) |
| `request` | URL, method, body template, and parameter definitions |
| `interaction` | Pattern (`streaming`, `polling`, or `sync`) and related config |
| `response` | Output extraction paths and types (`text`, `image`, `audio`, `video`) |

Minimal example — a streaming chat endpoint:

```json
{
  "schema_version": 1,
  "id": "myprovider-chat",
  "provider": "myprovider",
  "provider_display_name": "MyProvider",
  "name": "MyProvider Chat",
  "description": "Chat completions via MyProvider",
  "auth": {
    "type": "header",
    "header": "Authorization",
    "prefix": "Bearer ",
    "env_key": "MYPROVIDER_API_KEY"
  },
  "request": {
    "method": "POST",
    "url": "https://api.myprovider.com/v1/chat/completions",
    "content_type": "application/json",
    "body_template": { "stream": true },
    "params": [
      {
        "name": "model",
        "type": "enum",
        "options": ["model-a", "model-b"],
        "default": "model-a",
        "ui": "dropdown",
        "required": true
      },
      {
        "name": "prompt",
        "type": "string",
        "ui": "textarea",
        "required": true,
        "placeholder": "Ask anything...",
        "body_path": "_chat_message"
      }
    ]
  },
  "interaction": {
    "pattern": "streaming",
    "stream_format": "sse",
    "stream_path": "$.choices[0].delta.content"
  },
  "response": {
    "outputs": [
      { "path": "$.choices[0].message.content", "type": "text", "source": "inline" }
    ],
    "error": { "path": "$.error.message" }
  },
  "examples": [
    {
      "label": "Hello world",
      "params": { "prompt": "Say hello in 5 languages.", "model": "model-a" }
    }
  ]
}
```

Each parameter in `request.params` needs a `ui` type that tells Arcade how to render the form control:

| UI type | Param type | Renders as | Key fields |
|---|---|---|---|
| `textarea` | `string` | Multi-line text input | `placeholder`, `required`, `body_path` |
| `text` | `string` | Single-line text input | `placeholder`, `required` |
| `dropdown` | `enum` | Select menu | `options` (required), `default` |
| `slider` | `integer` or `float` | Range slider with numeric display | `min`, `max`, `default` |

User-added definitions are loaded from the app's Application Support directory alongside bundled ones. Because the app is sandboxed, the path is:

```
~/Library/Containers/me.ajot.arcade/Data/Library/Application Support/Arcade/Definitions/
```

The directory is created automatically on first launch. Drop a JSON file there and relaunch to pick it up.

## Project structure

```
arcade/
├── arcade.xcodeproj
├── arcade/
│   ├── arcadeApp.swift              # App entry point, window config, keyboard shortcuts
│   ├── Models/
│   │   ├── AppState.swift           # Root @Observable state — owns services and navigation
│   │   ├── Definition.swift         # Endpoint schema, params, interaction patterns
│   │   ├── JSONValue.swift          # Type-erased JSON with nested path mutation
│   │   └── Bookmark.swift           # Saved endpoint + param combinations
│   ├── Services/
│   │   ├── NetworkService.swift     # HTTP execution — streaming, polling, sync
│   │   ├── RequestBuilder.swift     # Merges params into body templates
│   │   ├── DefinitionLoader.swift   # Loads bundled + user JSON definitions
│   │   ├── JSONPathExtractor.swift  # $.foo.bar, $..key, $.foo[0] extraction
│   │   ├── KeychainService.swift    # API key storage via macOS Keychain
│   │   ├── BookmarkStore.swift      # Persists bookmarks to Application Support
│   │   └── SoundService.swift       # Semantic system sounds
│   ├── Views/
│   │   ├── PlayView.swift           # Main endpoint interaction UI
│   │   ├── CommandPalette.swift     # Cmd+K search and selection
│   │   ├── WelcomeView.swift        # Home screen
│   │   ├── SettingsView.swift       # API key management, preferences
│   │   ├── SidebarView.swift        # Provider/endpoint navigation
│   │   ├── LogPanel.swift           # HTTP request/response log
│   │   ├── DesignSystem.swift       # Color tokens, typography, component styles
│   │   ├── AudioPlayerView.swift    # Inline audio playback
│   │   ├── VideoPlayerView.swift    # Inline video playback
│   │   ├── ImageZoomOverlay.swift   # Full-size image preview
│   │   └── MarkdownTextView.swift   # Rendered markdown output
│   ├── Resources/
│   │   └── Definitions/             # 29 bundled endpoint definitions
│   └── Assets.xcassets/
└── CLAUDE.md
```

## How it works

1. On launch, `DefinitionLoader` reads every JSON file from `Resources/Definitions/` (bundled) and `~/Library/Application Support/Arcade/Definitions/` (user-added) into `Definition` structs.
2. The command palette (`Cmd+K`) searches all loaded definitions. Picking one calls `AppState.selectEndpoint()`, which configures the form.
3. `PlayView` reads `Definition.regularParams` to build form fields — textareas, dropdowns, sliders — based on each parameter's `ui` type.
4. On Generate, `RequestBuilder.buildRequest()` takes the definition's `bodyTemplate` and injects form values using each param's `bodyPath` (dot notation like `input.prompt`).
5. `NetworkService` executes based on `InteractionConfig.pattern`:
   - **streaming** — SSE via `URLSession.bytes`, extracts tokens via JSONPath, accumulates in real time
   - **sync** — single request, parses response via JSONPath output extraction
   - **polling** — submit → poll status URL → fetch result URL when complete
6. The response is rendered inline using the appropriate output type — text with markdown, zoomable images, audio player, or video player.
