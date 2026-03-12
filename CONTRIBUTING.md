# Contributing to Arcade

Thanks for your interest in contributing! Arcade is a native macOS app built with SwiftUI. Here's how to get started.

## Getting started

```bash
git clone https://github.com/ajot/arcade.git
cd arcade
open arcade.xcodeproj
```

Build and run with `Cmd+R`. No external dependencies — just Xcode 16+ and macOS 15+.

## Adding or updating definitions

The easiest way to contribute is adding support for a new AI provider or updating an existing definition. No Swift code changes needed — just a JSON file.

1. Create or edit a file in `arcade/Resources/Definitions/` named `{provider}-{type}.json` (e.g., `anthropic-chat-completions.json`)
2. Follow the definition schema documented in the [README](README.md#definitions)
3. Test it locally — click the folder icon in the sidebar to open your definitions directory, drop the file there, and click refresh
4. Submit a PR with the new or updated file in `arcade/Resources/Definitions/`

Look at existing definitions for reference. The DigitalOcean and OpenAI definitions cover the most patterns (streaming, polling, sync).

Common contributions:
- **Adding a new model** to an existing definition — add the model ID to the `options` array
- **Adding a new endpoint** — create a new JSON file for the provider
- **Adding a new provider** — create a new JSON file with a new `provider` slug

### Checklist for new definitions

- [ ] `id` is unique and follows the `{provider}-{type}` pattern
- [ ] `provider` and `provider_display_name` are set correctly
- [ ] `env_key` follows the `{PROVIDER}_API_KEY` convention
- [ ] At least one example is included
- [ ] `provider_icon_url` points to the provider's favicon
- [ ] Tested with a real API key — the request succeeds and the response renders correctly

## Working on the app

### Architecture

Arcade is a single-window app using `@Observable` for state management. `AppState` is the root object — it owns all services and state. See [CLAUDE.md](CLAUDE.md) for a detailed architecture overview.

### Conventions

- Use `@Observable` (not `ObservableObject`). Views take `@Bindable var state: AppState`.
- Use native macOS SwiftUI controls — no custom replacements for system components.
- Use system colors (`.primary`, `.secondary`, `.tertiary`) — no hardcoded color values.
- Use materials (`.regularMaterial`, `.bar`) for translucent backgrounds.
- Keep animations using spring physics for interactions.

### Project structure

```
arcade/Models/       — Data models and app state
arcade/Services/     — Network, keychain, definitions, bookmarks, sounds
arcade/Views/        — All SwiftUI views
arcade/Resources/    — Bundled JSON definitions and assets
```

## Submitting a PR

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Verify the app builds: `xcodebuild -scheme arcade -destination 'platform=macOS' build`
4. Test your changes by running the app
5. Submit a PR with:
   - What you changed and why
   - Screenshots if it's a UI change
   - Steps to test

## Reporting issues

Open an issue with:
- What you expected vs. what happened
- macOS version
- Steps to reproduce
- Screenshots if applicable
