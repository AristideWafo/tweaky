import AppKit
import SwiftUI

/// Brand indigo #4F3FE6 (see Branding/BRAND.md); only used for the shortcut badge.
private let brandIndigo = Color(red: 0.31, green: 0.25, blue: 0.90)

struct TweakyPanel: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    let openSettings: () -> Void
    @FocusState private var isInputFocused: Bool

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            editor
            actionBar
            if !state.resultText.isEmpty {
                Divider()
                result.transition(.opacity)
            }
            footer
        }
        .animation(.easeOut(duration: 0.2), value: state.resultText.isEmpty)
        .font(.brand(14))
        .padding(20)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background(BrandSurface().clipShape(shape))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
        .background(OverlayScrollers(trigger: state.inputText.count + state.resultText.count))
        .onAppear { isInputFocused = true }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text("Tweaky").font(.brand(22))
            Text(shortcutSymbol)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(brandIndigo)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(brandIndigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Spacer()
            Text(sourceLabel).font(.brand(12)).foregroundStyle(.secondary)
            Group {
                Button("Settings", systemImage: "gearshape", action: openSettings)
                    .help("Settings")
                Button("Close", systemImage: "xmark", action: dismiss)
                    .help("Close (Esc)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    /// Grows with its text up to a cap, then scrolls.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Invisible copy of the text drives the height; TextEditor itself has no intrinsic height.
            Text(state.inputText.isEmpty ? " " : state.inputText + "\n")
                .font(.brand(16))
                .padding(.horizontal, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hidden()
            if state.inputText.isEmpty {
                Text("Paste or type text…")
                    .font(.brand(16))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $state.inputText)
                .font(.brand(16))
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .accessibilityLabel("Text to process")
        }
        .frame(minHeight: 60, maxHeight: 260)
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
    }

    private var actionBar: some View {
        // Falls back to icon-only secondary buttons when labels would not fit on one line.
        ViewThatFits(in: .horizontal) {
            actionRow(compact: false)
            actionRow(compact: true)
        }
    }

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: 8) {
            let isEmpty = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(TextAction.correct.title) { state.process(.correct) }
                .buttonStyle(PillButtonStyle(prominent: true))
                // Once a result can replace the selection, ⌘↩ moves to Replace: select, ⌥Space, ⌘↩, ⌘↩.
                .keyboardShortcut(state.canReplaceSelection ? nil : KeyboardShortcut(.return, modifiers: .command))
                .help("Correct (⌘↩)")
                .disabled(isEmpty || state.isProcessing)
            Button(TextAction.translate.title) { state.process(.translate) }
                .keyboardShortcut("t", modifiers: [.command])
                .help("Translate (⌘T)")
                .disabled(isEmpty || state.isProcessing)
            if state.isProcessing {
                Button("Cancel") { state.cancel() }
            }
            Spacer(minLength: 8)
            Group {
                Button("Paste", systemImage: "doc.on.clipboard") { state.paste() }
                    .help("Paste from clipboard")
                Button("Read Screen", systemImage: "viewfinder") { state.readScreen() }
                    .help("Read text on screen")
                    .disabled(state.isProcessing)
            }
            .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleOnly))
        }
        .buttonStyle(PillButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Status on the left, the keyboard flow on the right (matches the landing page mock).
    private var footer: some View {
        HStack(spacing: 6) {
            if state.isProcessing {
                ProgressView().controlSize(.small)
                Text(state.statusMessage ?? "Working…")
            } else if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let status = state.statusMessage {
                Text(status)
            }
            Spacer(minLength: 12)
            Text("⌘↩ Correct · ⌘↩ Replace · ⇧⌘C Copy")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .layoutPriority(-1)
                .accessibilityLabel("Command Return to correct, then to replace. Shift Command C to copy.")
        }
        .font(.brand(12))
        .foregroundStyle(.secondary)
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result").font(.brand(12, weight: .medium)).foregroundStyle(.secondary)
            ScrollView {
                Text(state.resultText)
                    .font(.brand(16))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer()
                Button("Copy") { state.copyResult() }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .help("Copy (⇧⌘C)")
                    .disabled(state.isProcessing)
                Button("Replace Selection") { state.replaceSelection() }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .keyboardShortcut(state.canReplaceSelection ? KeyboardShortcut(.return, modifiers: .command) : nil)
                    .help("Replace Selection (⌘↩)")
                    .disabled(!state.canReplaceSelection)
            }
        }
    }

    private var sourceLabel: String {
        switch state.captureSource {
        case .accessibility, .copiedSelection: "Selection"
        case .clipboard: "Clipboard"
        case .ocr: "Screen OCR"
        case .manual: "Manual input"
        }
    }

    private var shortcutSymbol: String { state.settingsStore.settings.shortcut.symbol }
}

private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Forces the thin, auto-hiding overlay scrollers (no white track) on every scroll view in the panel,
/// even when System Settings is set to always show scroll bars.
/// shortcut: re-applied on text changes rather than tracking scroll view creation; fine for this small view tree.
private struct OverlayScrollers: NSViewRepresentable {
    let trigger: Int

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let root = nsView.window?.contentView else { return }
            apply(in: root)
        }
    }

    private func apply(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.scrollerStyle = .overlay
            scrollView.drawsBackground = false
        }
        view.subviews.forEach(apply)
    }
}
