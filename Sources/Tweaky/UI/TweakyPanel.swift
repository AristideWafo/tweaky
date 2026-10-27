import AppKit
import SwiftUI

/// Accent sampled from Resources/AppIcon.png; used sparingly, only for the primary action.
private let brandBlue = Color(red: 0.28, green: 0.42, blue: 0.96)

struct TweakyPanel: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    let openSettings: () -> Void
    @FocusState private var isInputFocused: Bool

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            editor
            actionBar
            if !state.resultText.isEmpty {
                result.transition(.opacity.combined(with: .move(edge: .top)))
            }
            footer
        }
        .animation(.easeOut(duration: 0.2), value: state.resultText.isEmpty)
        .padding(16)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffectBackground().clipShape(shape))
        .tint(brandBlue)
        .onAppear { isInputFocused = true }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
            Text("Tweaky").font(.headline)
            Text(sourceLabel).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Settings", systemImage: "gearshape", action: openSettings)
                .help("Settings")
            Button("Close", systemImage: "xmark", action: dismiss)
                .help("Close (Esc)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }

    /// Grows with its text up to a cap, then scrolls.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Invisible copy of the text drives the height; TextEditor itself has no intrinsic height.
            Text(state.inputText.isEmpty ? " " : state.inputText + "\n")
                .font(.body)
                .padding(.horizontal, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hidden()
            if state.inputText.isEmpty {
                Text("Paste or type text…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $state.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .accessibilityLabel("Text to process")
        }
        .frame(minHeight: 60, maxHeight: 260)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actionBar: some View {
        // Falls back to icon-only secondary buttons when labels would not fit on one line.
        ViewThatFits(in: .horizontal) {
            actionRow(compact: false)
            actionRow(compact: true)
        }
        .controlSize(.large)
    }

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: 8) {
            let isEmpty = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(TextAction.correct.title, systemImage: TextAction.correct.systemImage) { state.process(.correct) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isEmpty || state.isProcessing)
            Button(TextAction.translate.title, systemImage: TextAction.translate.systemImage) { state.process(.translate) }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(isEmpty || state.isProcessing)
            if state.isProcessing {
                Button("Cancel", systemImage: "stop.fill") { state.cancel() }
            }
            Spacer(minLength: 8)
            Group {
                Button("Paste", systemImage: "doc.on.clipboard") { state.paste() }
                    .help("Paste from clipboard")
                Button("Read Screen", systemImage: "viewfinder") { state.readScreen() }
                    .help("Read text on screen")
                    .disabled(state.isProcessing)
            }
            .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

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
            Spacer()
            Text(shortcutSymbol).foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var result: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ScrollView {
                Text(state.resultText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(spacing: 8) {
                Button("Copy", systemImage: "doc.on.doc") { state.copyResult() }
                    .buttonStyle(.bordered)
                Button("Replace Selection", systemImage: "arrow.triangle.2.circlepath") { state.replaceSelection() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canReplaceSelection)
            }
            .buttonBorderShape(.capsule)
        }
    }

    private var sourceLabel: String {
        switch state.captureSource {
        case .accessibility: "Selection"
        case .clipboard: "Clipboard"
        case .ocr: "Screen OCR"
        case .manual: "Manual input"
        }
    }

    private var shortcutSymbol: String {
        switch state.settingsStore.settings.shortcut {
        case .optionSpace: "⌥ Space"
        case .commandShiftT: "⌘ ⇧ T"
        }
    }
}

private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Behind-window blur, the same translucency Spotlight uses.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
