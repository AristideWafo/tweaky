import SwiftUI

struct TweakyPanel: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    let openSettings: () -> Void
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TextField("Paste or type text…", text: $state.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(3...8)
                .padding(14)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.35)))
                .focused($isInputFocused)
                .accessibilityLabel("Text to process")
            actionBar
            if !state.resultText.isEmpty { result }
            footer
        }
        .padding(20)
        .frame(width: 540)
        .frame(maxHeight: 620)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.3)))
        .onAppear { isInputFocused = true }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text("Tweaky").font(.title2.weight(.semibold))
            Spacer()
            Label(sourceLabel, systemImage: sourceIcon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.background.opacity(0.5), in: Capsule())
            Divider().frame(height: 22)
            Button("Settings", systemImage: "gearshape", action: openSettings)
                .labelStyle(.iconOnly)
                .font(.title3)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Settings")
            Button("Close", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .font(.callout.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.secondary.opacity(0.15), in: Circle())
                .help("Close")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            ForEach(TextAction.allCases) { action in
                pillButton(action.title, systemImage: action.systemImage, prominent: action == .correct) {
                    state.process(action)
                }
                .keyboardShortcut(action == .correct ? .return : "t", modifiers: [.command])
                .disabled(state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isProcessing)
            }
            if state.isProcessing {
                pillButton("Cancel", systemImage: "stop.circle") { state.cancel() }
            }
            Spacer()
            pillButton("Paste", systemImage: "doc.on.clipboard") { state.paste() }
            pillButton("Read Screen", systemImage: "viewfinder") { state.readScreen() }
                .disabled(state.isProcessing)
        }
    }

    private func pillButton(_ title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(prominent ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.background.opacity(0.55)), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if state.isProcessing {
                ProgressView().controlSize(.small)
                Text(state.statusMessage ?? "Working…")
            } else if let error = state.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(error).foregroundStyle(.red).lineLimit(2)
            } else {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text(state.statusMessage ?? "Ready")
            }
            Spacer()
            Text(shortcutSymbol).foregroundStyle(.tertiary)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                Text(state.resultText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(spacing: 8) {
                Spacer()
                pillButton("Copy", systemImage: "doc.on.doc") { state.copyResult() }
                pillButton("Replace Selection", systemImage: "arrow.triangle.2.circlepath", prominent: true) {
                    state.replaceSelection()
                }
                .disabled(!state.canReplaceSelection)
            }
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

    private var sourceIcon: String {
        switch state.captureSource {
        case .accessibility: "selection.pin.in.out"
        case .clipboard: "doc.on.clipboard"
        case .ocr: "viewfinder"
        case .manual: "doc.text"
        }
    }

    private var shortcutSymbol: String {
        switch state.settingsStore.settings.shortcut {
        case .optionSpace: "⌥ Space"
        case .commandShiftT: "⌘ ⇧ T"
        }
    }
}
