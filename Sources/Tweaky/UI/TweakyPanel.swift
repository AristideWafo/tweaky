import SwiftUI

struct TweakyPanel: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TextEditor(text: $state.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(9)
                .frame(minHeight: 105)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .focused($isInputFocused)
                .accessibilityLabel("Text to process")
            actionBar
            feedback
            if !state.resultText.isEmpty { result }
        }
        .padding(22)
        .frame(minWidth: 640, minHeight: 430)
        .background(.regularMaterial)
        .onAppear { isInputFocused = true }
        .onExitCommand { state.cancel(); dismiss() }
    }

    private var header: some View {
        HStack {
            Label("Tweaky", systemImage: "text.badge.sparkles").font(.headline)
            Spacer()
            Text(sourceLabel).foregroundStyle(.secondary).font(.caption)
            Text("Esc").foregroundStyle(.tertiary).font(.caption)
        }
    }

    private var actionBar: some View {
        HStack {
            ForEach(TextAction.allCases) { action in
                Button(action.title, systemImage: action.systemImage) { state.process(action) }
                    .keyboardShortcut(action == .correct ? .return : "t", modifiers: [.command])
                    .disabled(state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isProcessing)
            }
            if state.isProcessing {
                Button("Cancel", role: .cancel) { state.cancel() }
            }
            Spacer()
            Button("Paste", systemImage: "doc.on.clipboard") { state.paste() }
            Button("Read Screen", systemImage: "viewfinder") { state.readScreen() }
                .disabled(state.isProcessing)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder private var feedback: some View {
        if state.isProcessing {
            HStack { ProgressView().controlSize(.small); Text(state.statusMessage ?? "Working…") }
                .font(.callout).foregroundStyle(.secondary)
        } else if let error = state.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.red)
        } else if let status = state.statusMessage {
            Text(status).font(.callout).foregroundStyle(.secondary)
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(state.resultText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") { state.copyResult() }
                Button("Replace Selection", systemImage: "arrow.triangle.2.circlepath") { state.replaceSelection() }
                    .disabled(!state.canReplaceSelection)
                    .buttonStyle(.borderedProminent)
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
}
