//
//  BrainDumpView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation
import UIKit

struct BrainDumpView: View {
    // Where we save the big brain dump text
    private let brainDumpStorageKey = "brain_dump_text_v1"

    // Where the To-Do tab saves its list of TodoItem
    private let todoStorageKey = "todo_items_v1"

    @State private var text: String = ""

    @State private var showSentAlert: Bool = false
    @State private var lastAddedCount: Int = 0
    @State private var lastSkippedCount: Int = 0
    @State private var lastBrainDumpDuplicateCount: Int = 0

    var body: some View {
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

                    let readyCount = uniqueLinesFromBrainDump().lines.count
                    Text("Ready: \(readyCount) item(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Send to To-Do") {
                        hideKeyboard()
                        sendLinesToTodo()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(uniqueLinesFromBrainDump().lines.isEmpty)

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
            .onTapGesture {
                hideKeyboard()
            }
            .navigationTitle("Brain Dump")
        }
        .onAppear {
            loadText()
        }
        .onChange(of: text) {
            saveText()
        }
        .alert("Sent to To-Do", isPresented: $showSentAlert) {
            Button("OK") { }
        } message: {
            Text("Added \(lastAddedCount). Removed duplicates: \(lastBrainDumpDuplicateCount). Already in To-Do: \(lastSkippedCount).")
        }
    }

    // Simple helper to hide the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    // MARK: - Brain Dump Persistence

    private func saveText() {
        UserDefaults.standard.set(text, forKey: brainDumpStorageKey)
    }

    private func loadText() {
        text = UserDefaults.standard.string(forKey: brainDumpStorageKey) ?? ""
    }

    // MARK: - Promote Brain Dump lines into To-Do

    private func uniqueLinesFromBrainDump() -> (lines: [String], removedDuplicates: Int) {
        let cleanedLines = text
            .split(whereSeparator: \.isNewline) // split on each newline
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } // trim spaces
            .filter { !$0.isEmpty } // ignore blank lines

        // Deduplicate within the brain dump (case-insensitive).
        // We keep the first original version of the line that appears.
        var seen = Set<String>()
        var unique: [String] = []
        var removed = 0

        for line in cleanedLines {
            let key = line.lowercased()
            if seen.contains(key) {
                removed += 1
            } else {
                seen.insert(key)
                unique.append(line)
            }
        }

        return (unique, removed)
    }

    private func sendLinesToTodo() {
        let result = uniqueLinesFromBrainDump()
        let lines = result.lines
        guard !lines.isEmpty else { return }

        // 1) Load the existing To-Do list from UserDefaults
        var existingTodoItems = loadTodoItems()

        // Build a set of existing titles (case-insensitive) so we can skip duplicates
        let existingTitleKeys = Set(existingTodoItems.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        // 2) Convert each NEW line into a TodoItem (skip duplicates that already exist)
        var newTodoItems: [TodoItem] = []
        var skipped = 0

        for line in lines {
            let key = line.lowercased()
            if existingTitleKeys.contains(key) {
                skipped += 1
            } else {
                newTodoItems.append(TodoItem(title: line))
            }
        }

        // 3) Append and save back to the same storage used by TodoView
        existingTodoItems.append(contentsOf: newTodoItems)
        saveTodoItems(existingTodoItems)

        // 4) UI feedback + clear brain dump
        lastAddedCount = newTodoItems.count
        lastBrainDumpDuplicateCount = result.removedDuplicates
        lastSkippedCount = skipped
        showSentAlert = true
        text = ""
    }

    private func loadTodoItems() -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: todoStorageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            print("Failed to load To-Do items for promotion:", error)
            return []
        }
    }

    private func saveTodoItems(_ items: [TodoItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: todoStorageKey)
        } catch {
            print("Failed to save To-Do items for promotion:", error)
        }
    }
}

#Preview {
    BrainDumpView()
}
