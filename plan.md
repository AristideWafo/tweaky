# Tweaky delivery plan

## Product goal

Deliver a fast native macOS text assistant: select text, invoke a configurable global shortcut, correct or translate it with a user-configured cloud provider, then copy or replace the result.

## Product decisions

- Native Swift 6, SwiftUI, and AppKit; no Electron and no backend for the personal-use MVP.
- Automatic macOS appearance. System materials adopt light/dark mode and accessibility preferences without a custom theme switch.
- Liquid Glass-style system components when available, with system-material fallback for older supported macOS versions.
- A configurable shortcut, rather than reserving Command-T, which conflicts with common app shortcuts.
- API keys live only in macOS Keychain. Provider/model choices are non-secret preferences.
- OCR is explicit, previewed, and local before a user confirms a cloud request.

## Delivery slices

### 1. Native shell — complete

- Menu-bar entry and Spotlight-style floating `NSPanel`.
- Automatic light/dark system material.
- Settings for provider, model, base URL, language, and Keychain API-key management.
- Swift Package, unit tests, and GitHub Actions CI.

### 2. Interaction plumbing — complete

- Implement a configurable global shortcut using the native macOS event API.
- Close with Escape, restore focus to the source app, and support keyboard-only navigation.
- Prompt for Accessibility permission and prefill supported selected text.

### 3. Cloud AI — complete

- Implement OpenAI Responses, Anthropic Messages, and OpenAI-compatible chat completions behind `AIProvider`.
- Add cancellation, timeout, retry guidance, rate-limit messaging, and connection test.
- Release correction first, then translation.

### 4. Capture and output — complete

- Add intentional clipboard capture with careful clipboard restoration.
- Add ScreenCaptureKit source selection and Vision OCR preview.
- Add copy result, then reliable direct replacement where Accessibility permits it.

### 5. Product hardening — partially complete

- Automated provider-contract, prompt, secure-URL, debug-build, release-build, bundle metadata, and ad-hoc-signature checks are in place.
- Manual compatibility checks remain for Mail, Notes, Slack, browser editors, revoked permissions, and direct replacement behavior.
- Developer ID signing and Apple notarization are implemented in the release workflow; running them requires external Apple credentials stored as GitHub Actions secrets.

## Definition of done for the MVP

- The shortcut opens the panel in under 200 ms while another app is active.
- Accessible selection pre-fills the input; unavailable selection never blocks manual input.
- Correction and translation show only the requested text, with copy always working.
- OCR text is visible and editable before leaving the device.
- Keys never appear in logs, source control, preferences, or UI after saving.
- The panel follows macOS light/dark and accessibility appearance automatically.

## Release and rollback

CI verifies every change. Tags matching `v*` publish a Developer ID-signed, Apple-notarized archive and checksum through GitHub Releases. Missing release credentials fail the job before packaging. Rollback means removing the affected release and publishing a corrected signed build; API-provider configuration remains backward compatible.
