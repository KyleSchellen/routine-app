//
//  TodoView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation
import UIKit

// MARK: - Model

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

// MARK: - View

struct TodoView: View {
    private let storageKey = "todo_items_v1"
    private let routineStorageKey = "routine_items_v1"

    @State private var items: [TodoItem] = []
    @State private var newTitle: String = ""
    @State private var editingItemID: UUID? = nil
    @State private var editTitle: String = ""
    @State private var showPromotedAlert: Bool = false
    @State private var lastPromotedTitle: String = ""
    @State private var lastPromotedCategory: RoutineCategory = .anytime

    @State private var showingPromoteSheet: Bool = false
    @State private var promoteTitle: String = ""
    @State private var promoteCategory: RoutineCategory = .anytime
    @State private var promotingTodoID: UUID? = nil
    @State private var showAlreadyInRoutinesAlert: Bool = false

    @State private var isTrashExpanded: Bool = false

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
                    // Only show active (not deleted) items in the main list
                    let activeIndices = items.indices.filter { items[$0].deletedAt == nil }

                    ForEach(activeIndices, id: \.self) { index in
                        let item = items[index]

                        Toggle(isOn: $items[index].isDone) {
                            Text(item.title)
                                .opacity(item.isDone ? 0.5 : 1.0)
                        }
                        .contentShape(Rectangle()) // makes the whole row tappable
                        .onTapGesture {
                            startEditing(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                softDeleteTodo(id: item.id)
                            }

                            Button("Add to Routines") {
                                beginPromote(todo: item)
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        // offsets are relative to activeIndices, so translate them
                        let actualIndices = offsets.map { activeIndices[$0] }
                        softDeleteItems(at: IndexSet(actualIndices))
                    }

                    // Recently Deleted (Trash)
                    let trashIndices = items.indices.filter { items[$0].deletedAt != nil }
                    if !trashIndices.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isTrashExpanded) {
                                ForEach(trashIndices, id: \.self) { index in
                                    let item = items[index]

                                    HStack {
                                        Text(item.title)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Restore") {
                                            restoreTodo(id: item.id)
                                        }
                                        .tint(.blue)

                                        Button("Delete Forever", role: .destructive) {
                                            deleteTodoForever(id: item.id)
                                        }
                                    }
                                }
                            } label: {
                                Text("Recently Deleted (\(trashIndices.count))")
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
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
        .alert("Added to Routines", isPresented: $showPromotedAlert) {
            Button("OK") { }
        } message: {
            Text("\"\(lastPromotedTitle)\" was added to Routines (\(lastPromotedCategory.rawValue)).")
        }
        .alert("Already in Routines", isPresented: $showAlreadyInRoutinesAlert) {
            Button("OK") { }
        } message: {
            Text("That item is already in Routines.")
        }
        .sheet(isPresented: $showingPromoteSheet) {
            NavigationStack {
                Form {
                    Section("Title") {
                        TextField("Routine title", text: $promoteTitle)
                    }

                    Section("Category") {
                        Picker("Category", selection: $promoteCategory) {
                            Text("Morning").tag(RoutineCategory.morning)
                            Text("Anytime").tag(RoutineCategory.anytime)
                            Text("Evening").tag(RoutineCategory.evening)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle("Add to Routines")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingPromoteSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            confirmPromoteToRoutine()
                        }
                        .disabled(promoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
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

    // MARK: - Actions

    private func beginPromote(todo: TodoItem) {
        promotingTodoID = todo.id
        promoteTitle = todo.title
        promoteCategory = .anytime
        showingPromoteSheet = true
    }

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

    private func softDeleteItems(at offsets: IndexSet) {
        for i in offsets {
            items[i].deletedAt = Date()
        }
    }

    private func softDeleteTodo(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].deletedAt = Date()
        }
    }

    private func restoreTodo(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].deletedAt = nil
        }
    }

    private func deleteTodoForever(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
        }
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

    // MARK: - Promote To-Do → Routines

    private func confirmPromoteToRoutine() {
        let trimmed = promoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let didAdd = promoteToRoutine(title: trimmed, category: promoteCategory)

        // Close sheet UI
        showingPromoteSheet = false

        if didAdd {
            lastPromotedTitle = trimmed
            lastPromotedCategory = promoteCategory

            // Remove the original To-Do (move instead of copy)
            if let todoID = promotingTodoID,
               let index = items.firstIndex(where: { $0.id == todoID }) {
                items.remove(at: index)
            }

            showPromotedAlert = true
        } else {
            showAlreadyInRoutinesAlert = true
        }

        // Clear selection at the end
        promotingTodoID = nil
    }

    // Returns true if added, false if it was already in Routines
    private func promoteToRoutine(title: String, category: RoutineCategory) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Load existing routines
        var routines = loadRoutineItems()

        // Duplicate prevention (case-insensitive match on title)
        let newKey = trimmed.lowercased()
        let existingKeys = Set(routines.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        guard !existingKeys.contains(newKey) else {
            return false
        }

        let newRoutine = RoutineItem(title: trimmed, category: category, lastCompletedDay: nil)
        routines.append(newRoutine)

        // Save back to the same storage key used by RoutinesView
        saveRoutineItems(routines)
        return true
    }

    private func loadRoutineItems() -> [RoutineItem] {
        guard let data = UserDefaults.standard.data(forKey: routineStorageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([RoutineItem].self, from: data)
        } catch {
            print("Failed to load routine items for promotion:", error)
            return []
        }
    }

    private func saveRoutineItems(_ items: [RoutineItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: routineStorageKey)
        } catch {
            print("Failed to save routine items for promotion:", error)
        }
    }
}

#Preview {
    TodoView()
}
