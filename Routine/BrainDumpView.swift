//
//  BrainDumpView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation

struct BrainDumpView: View {
    // Where we save the big brain dump text
    private let brainDumpStorageKey = "brain_dump_text_v1"

    // Where the To-Do tab saves its list of TodoItem
    private let todoStorageKey = "todo_items_v1"

    @State private var text: String = ""

    @State private var showSentAlert: Bool = false
    @State private var lastSentCount: Int = 0

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

                HStack(spacing: 10) {
                    Button("Send lines to To-Do") {
                        sendLinesToTodo()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(nonEmptyLines().isEmpty)

                    Button("Clear") {
                        text = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(text.isEmpty)
                }
            }
            .padding()
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
            Text("Added \(lastSentCount) item(s).")
        }
    }

    // MARK: - Brain Dump Persistence

    private func saveText() {
        UserDefaults.standard.set(text, forKey: brainDumpStorageKey)
    }

    private func loadText() {
        text = UserDefaults.standard.string(forKey: brainDumpStorageKey) ?? ""
    }

    // MARK: - Promote Brain Dump lines into To-Do

    private func nonEmptyLines() -> [String] {
        return text
            .split(whereSeparator: \.isNewline) // split on each newline
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } // trim spaces
            .filter { !$0.isEmpty } // ignore blank lines
    }

    private func sendLinesToTodo() {
        let lines = nonEmptyLines()
        guard !lines.isEmpty else { return }

        // 1) Load the existing To-Do list from UserDefaults
        var existingTodoItems = loadTodoItems()

        // 2) Convert each line into a TodoItem
        let newTodoItems = lines.map { line in
            TodoItem(title: line)
        }

        // 3) Append and save back to the same storage used by TodoView
        existingTodoItems.append(contentsOf: newTodoItems)
        saveTodoItems(existingTodoItems)

        // 4) UI feedback + clear brain dump
        lastSentCount = newTodoItems.count
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
