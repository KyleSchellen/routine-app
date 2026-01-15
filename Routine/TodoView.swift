//
//  TodoView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation

// MARK: - Model

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

// MARK: - View

struct TodoView: View {
    private let storageKey = "todo_items_v1"

    @State private var items: [TodoItem] = []
    @State private var newTitle: String = ""
    @State private var editingItemID: UUID? = nil
    @State private var editTitle: String = ""

    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Add new To-Do item
                HStack(spacing: 8) {
                    TextField("Add to To-Do…", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAddFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }

                    Button("Add") {
                        addItem()
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                // List of To-Do items
                List {
                    ForEach($items) { $item in
                        Toggle(isOn: $item.isDone) {
                            Text(item.title)
                                .opacity(item.isDone ? 0.5 : 1.0)
                        }
                        .contentShape(Rectangle()) // makes the whole row tappable
                        .onTapGesture {
                            startEditing(item: item)
                        }
                    }
                    .onDelete { offsets in
                        deleteItems(offsets: offsets)
                    }
                }
            }
            .navigationTitle("To-Do")
            .toolbar {
                EditButton()
            }
            .sheet(
                isPresented: Binding(
                    get: { editingItemID != nil },
                    set: { isPresented in
                        if !isPresented {
                            editingItemID = nil
                        }
                    }
                )
            ) {
                NavigationStack {
                    Form {
                        Section("Title") {
                            TextField("To-Do title", text: $editTitle)
                        }
                    }
                    .navigationTitle("Edit To-Do")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                editingItemID = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEdits()
                            }
                            .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadItems()
            isAddFieldFocused = true
        }
        .onChange(of: items) {
            saveItems()
        }
    }

    // MARK: - Actions

    private func startEditing(item: TodoItem) {
        editingItemID = item.id
        editTitle = item.title
    }

    private func saveEdits() {
        guard let id = editingItemID else { return }

        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = trimmed
        }

        editingItemID = nil
    }

    private func addItem() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items.append(TodoItem(title: trimmed))
        newTitle = ""
        isAddFieldFocused = true
    }

    private func deleteItems(offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save To-Do items:", error)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            items = [] // start empty
            return
        }

        do {
            items = try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            print("Failed to load To-Do items:", error)
            items = []
        }
    }
}

#Preview {
    TodoView()
}
