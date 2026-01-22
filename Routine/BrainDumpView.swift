//
//  BrainDumpView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import UIKit

struct BrainDumpView: View {
    @EnvironmentObject private var store: AppStore

    // MARK: - Storage Keys
    private let brainDumpStorageKey = "brain_dump_text_v1"

    // MARK: - View State
    @State private var text: String = ""

    @State private var showSentAlert = false
    @State private var lastAddedCount = 0
    @State private var lastSkippedCount = 0
    @State private var lastBrainDumpDuplicateCount = 0

    /// Used to debounce saves while typing
    @State private var saveWorkItem: DispatchWorkItem?

    var body: some View {
        // Parse ONCE per render so we don’t repeat work everywhere
        let parsed = parseBrainDump(text)

        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    .frame(minHeight: 300)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tip: Put one thought per line. Each line becomes a To-Do item.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Ready: \(parsed.lines.count) item(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Send to To-Do") {
                        hideKeyboard()
                        sendLinesToTodo(parse: parsed)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsed.lines.isEmpty)

                    Button("Clear") {
                        hideKeyboard()
                        text = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(text.isEmpty)
                }
                .padding(.bottom, 40)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { hideKeyboard() }
            .navigationTitle("Brain Dump")
        }
        .onAppear {
            loadText()
        }
        .onChange(of: text) {
            scheduleSaveText()
        }
        .alert("Sent to To-Do", isPresented: $showSentAlert) {
            Button("OK") { }
        } message: {
            Text(
                "Added \(lastAddedCount). " +
                "Removed duplicates: \(lastBrainDumpDuplicateCount). " +
                "Already in To-Do: \(lastSkippedCount)."
            )
        }
    }

    // MARK: - Keyboard Helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    // MARK: - Brain Dump Parsing
    private struct ParseResult {
        let lines: [String]
        let removedDuplicates: Int
    }

    private func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func parseBrainDump(_ rawText: String) -> ParseResult {
        let cleanedLines = rawText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var unique: [String] = []
        var removed = 0

        for line in cleanedLines {
            let key = normalized(line)

            if seen.contains(key) {
                removed += 1
            } else {
                seen.insert(key)
                unique.append(line)
            }
        }

        return ParseResult(lines: unique, removedDuplicates: removed)
    }

    // MARK: - Promote Brain Dump to To-Do
    private func sendLinesToTodo(parse: ParseResult) {
        let lines = parse.lines
        guard !lines.isEmpty else { return }

        var added = 0
        var skipped = 0

        for line in lines {
            let key = normalized(line)
            guard !key.isEmpty else { continue }

            if store.todoTitleExists(line) {
                skipped += 1
            } else {
                store.addTodo(title: line)
                added += 1
            }
        }

        lastAddedCount = added
        lastBrainDumpDuplicateCount = parse.removedDuplicates
        lastSkippedCount = skipped
        showSentAlert = true
        text = ""
    }

    // MARK: - Persistence (Brain dump text only)
    private func loadText() {
        text = UserDefaults.standard.string(forKey: brainDumpStorageKey) ?? ""
    }

    private func saveText() {
        UserDefaults.standard.set(text, forKey: brainDumpStorageKey)
    }

    private func scheduleSaveText() {
        saveWorkItem?.cancel()

        let work = DispatchWorkItem {
            saveText()
        }

        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}

#Preview {
    BrainDumpView()
        .environmentObject(AppStore())
}
