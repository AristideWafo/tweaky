# Tweaky

Tweaky is a lightweight, native macOS writing assistant. A global shortcut opens a Spotlight-like panel to correct or translate selected text.

## Status

The MVP is implemented: menu-bar app, global shortcut, Spotlight-style panel, Accessibility selection capture, clipboard input, explicit local OCR, OpenAI/Anthropic/Google Gemini/OpenAI-compatible providers, copy and direct-replacement output, Keychain storage, tests, packaging, CI, security scanning, and tag-based GitHub releases.

The interface follows the system light/dark appearance and uses native macOS materials. The project includes a dedicated Tweaky application icon designed for the same glass-inspired visual language.

## Requirements

- macOS 15 or later
- Xcode 16 or later, or the matching Swift toolchain
- An API key from OpenAI, Anthropic, Google AI Studio, or an OpenAI-compatible provider

## Run locally

```bash
swift run Tweaky
```

For an application bundle:

```bash
Scripts/package-app.sh release
open dist/Tweaky.app
```

Open **Settings** from the menu-bar icon, choose a provider and model, save the API key, and test the connection. The key is stored in the macOS Keychain, not in the repository or `UserDefaults`.

## Use

1. Grant Accessibility access for selected-text capture and direct replacement.
2. Optionally grant Screen Recording access for the explicit **Read Screen** OCR action.
3. Select text in another app and press **Option-Space** (configurable in Settings).
4. Choose **Correct** or **Translate**, then copy or replace the original selection.

OCR runs locally. Recognized text remains editable and is sent to a provider only when the user triggers an AI action.

## Architecture

```text
Sources/Tweaky/
  App/       Application lifecycle and state
  AI/        Provider contract and prompt construction
  Capture/   Accessibility selection and OCR
  Models/    Shared domain types and settings
  System/    Keychain, panel, and global shortcut boundaries
  UI/        SwiftUI panel and settings
Tests/       Unit tests
```

## Security and privacy

- API keys are stored per provider in Keychain.
- User text is not persisted by the app.
- OCR is an explicit action and its text is shown for review before any cloud request.
- Custom remote provider URLs must use HTTPS; plain HTTP is accepted only for localhost.
- Never commit API keys, `.env` files, or local configuration.
- CodeQL scans Swift code, Dependabot monitors dependencies, and GitHub secret scanning protects the public repository.

## CI

GitHub Actions builds, tests, packages, and validates the app on pull requests and pushes to `main`, `master`, or `prod`. CodeQL runs on changes and weekly. Tags matching `v*` create a Developer ID-signed, Apple-notarized GitHub release with a SHA-256 checksum.

The release workflow requires these GitHub Actions secrets: `SIGNING_CERTIFICATE_BASE64`, `SIGNING_CERTIFICATE_PASSWORD`, `SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD`. It fails closed when any credential is absent. The credentials intentionally do not exist in this repository.

## License

No license has been selected yet.
