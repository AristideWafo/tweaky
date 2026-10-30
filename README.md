<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Tweaky logo">
</p>

<h1 align="center">Tweaky</h1>

<p align="center">Select text anywhere on your Mac, press a shortcut, and get it corrected or translated in place.</p>

Tweaky is a lightweight, native macOS writing assistant that lives in the menu bar. Select text in any app
(Gmail, WhatsApp, Notes, Slack…), press **Option-Space**, and a small Spotlight-like panel opens with your text
already in it. Correct or translate it with the AI provider of your choice, then copy the result or replace the
original selection directly.

## Features

- **Works in any app**: reads the selection through Accessibility, with a clipboard fallback for apps that do not expose it.
- **Correct and translate** with OpenAI, Anthropic, Google Gemini, or any OpenAI-compatible endpoint.
- **Replace in place**: writes the result straight into the original field through Accessibility when the app allows it,
  otherwise pastes it and restores your clipboard.
- **Correct in place**: press **Option-Shift-Space** on a selection to correct it without opening the panel; the
  menu-bar icon pulses while it works. Suspicious results are copied instead of replaced.
- **Fast**: replies stream in as they are generated, and models are asked for minimal reasoning (about 1 s on Gemini).
- **Keyboard flow**: **⌘↩** corrects, then **⌘↩** again replaces the selection; **⇧⌘C** copies the result.
- **Spotlight-like panel**: opens empty or pre-filled, sizes to its content, and disappears when you click elsewhere.
- **Read Screen**: optional local OCR for text you cannot select.
- **Private by design**: API keys in the macOS Keychain, no text stored, nothing sent until you trigger an action.
- **Menu-bar app**: no Dock icon; the menu-bar glyph shows Tweaky is running and opens the panel or Settings.

## Design

The interface is calm and monochrome: ink on a lightly translucent surface, hairline borders, pill buttons, and
[Google Sans](https://github.com/googlefonts/googlesans) (SIL Open Font License, bundled in `Resources/Fonts`).
It follows the system light and dark appearance. Indigo `#4F3FE6` is the single accent.

The logo is a lowercase *t* whose crossbar is a tilde (~), the sign for "adjust": Tweaky tweaks your text. Masters,
colours, and usage rules live in [`Branding/`](Branding/BRAND.md).

## Status

Version 0.2.0. Menu-bar app, global shortcut, Spotlight-style panel, selection capture and replacement, clipboard
input, local OCR, four provider types, Keychain storage, tests, packaging, CI, security scanning, and tag-based
GitHub releases are implemented.

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
  UI/        SwiftUI panel, settings, typography
Resources/   Info.plist, app and menu-bar icons, bundled font
Branding/    Logo masters and brand guide
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

No license has been selected yet for the code. Google Sans is distributed under the SIL Open Font License
(`Resources/Fonts/OFL.txt`).
