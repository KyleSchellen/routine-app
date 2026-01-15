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
    private let trashRetentionDays: Int = 7 // auto-delete todos in this number of days

    @State private var activeItems: [TodoItem] = []
    @State private var trashItems: [TodoItem] = []
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
    @State private var showEmptyTrashConfirm: Bool = false
    @State private var saveWorkItem: DispatchWorkItem? = nil

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
                    // Active (not deleted) items
                    ForEach($activeItems) { $item in
                        Toggle(isOn: $item.isDone) {
                            Text(item.title)
                                .opacity(item.isDone ? 0.5 : 1.0)
                        }
                        .contentShape(Rectangle())
                    }
                    .onMove { source, destination in
                        moveActiveItems(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        softDeleteActiveItems(at: offsets)
                    }

                    // Recently Deleted (Trash)
                    if !trashItems.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isTrashExpanded) {
                                ForEach(trashItems) { item in
                                    HStack {
                                        Text(item.title)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Restore") {
                                            restoreFromTrash(id: item.id)
                                        }
                                        .tint(.blue)

                                        Button("Delete Forever", role: .destructive) {
                                            deleteFromTrashForever(id: item.id)
                                        }
                                    }
                                }

                                Button {
                                    showEmptyTrashConfirm = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete All Recently Deleted")
                                        Spacer()
                                    }
                                }
                                .foregroundStyle(.red)
                                .buttonStyle(.plain)
                                .padding(.top, 8)
                            } label: {
                                Text("Recently Deleted (\(trashItems.count))")
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
            purgeExpiredTrash()
            isAddFieldFocused = true
        }
        .onChange(of: activeItems) {
            scheduleSave()
        }
        .onChange(of: trashItems) {
            scheduleSave()
        }
        .onDisappear {
            saveWorkItem?.cancel()
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
        .alert("Delete all recently deleted items?", isPresented: $showEmptyTrashConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllTrash()
            }
        } message: {
            Text("This will permanently remove everything in Recently Deleted.")
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

        if let index = activeItems.firstIndex(where: { $0.id == id }) {
            activeItems[index].title = trimmed
        }

        editingItemID = nil
    }

    private func addItem() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeItems.append(TodoItem(title: trimmed))
        newTitle = ""
        isAddFieldFocused = true
    }

    private func softDeleteActiveItems(at offsets: IndexSet) {
        // Move the selected active items into Trash and mark deletedAt.
        let now = Date()
        let moving = offsets.map { activeItems[$0] }

        // Remove from active starting from the end so indices don’t shift.
        for i in offsets.sorted(by: >) {
            activeItems.remove(at: i)
        }

        // Append to trash in the same order the user selected.
        for var item in moving {
            item.deletedAt = now
            trashItems.append(item)
        }
    }

    private func restoreFromTrash(id: UUID) {
        guard let index = trashItems.firstIndex(where: { $0.id == id }) else { return }
        var item = trashItems[index]
        item.deletedAt = nil

        trashItems.remove(at: index)
        activeItems.append(item)
    }

    private func deleteFromTrashForever(id: UUID) {
        guard let index = trashItems.firstIndex(where: { $0.id == id }) else { return }
        trashItems.remove(at: index)
    }

    private func deleteAllTrash() {
        trashItems.removeAll()
    }

    private func moveActiveItems(from source: IndexSet, to destination: Int) {
        activeItems.move(fromOffsets: source, toOffset: destination)
    }

    // Permanently remove items that have been in Trash longer than `trashRetentionDays`.
    private func purgeExpiredTrash() {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -trashRetentionDays, to: now) ?? now

        trashItems.removeAll { item in
            guard let deletedAt = item.deletedAt else { return false }
            return deletedAt < cutoff
        }
    }

    // MARK: - Persistence

    // Debounce saving so we don’t JSON-encode on every tiny change (like during drag reordering).
    private func scheduleSave() {
        saveWorkItem?.cancel()

        let work = DispatchWorkItem {
            saveItems()
        }

        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func saveItems() {
        do {
            let combined = activeItems + trashItems
            let data = try JSONEncoder().encode(combined)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save To-Do items:", error)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            activeItems = []
            trashItems = []
            return
        }

        do {
            let combined = try JSONDecoder().decode([TodoItem].self, from: data)
            activeItems = combined.filter { $0.deletedAt == nil }
            trashItems = combined.filter { $0.deletedAt != nil }
        } catch {
            print("Failed to load To-Do items:", error)
            activeItems = []
            trashItems = []
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
               let index = activeItems.firstIndex(where: { $0.id == todoID }) {
                activeItems.remove(at: index)
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
