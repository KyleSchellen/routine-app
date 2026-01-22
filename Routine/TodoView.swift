//
//  TodoView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import UIKit

struct TodoView: View {
    @EnvironmentObject private var store: AppStore

    @State private var newTitle: String = ""

    // Promote sheet state
    @State private var showingPromoteSheet: Bool = false
    @State private var promoteTitle: String = ""
    @State private var promoteCategory: RoutineCategory = .anytime
    @State private var promotingTodoID: UUID? = nil

    // Alerts
    @State private var showPromotedAlert: Bool = false
    @State private var lastPromotedTitle: String = ""
    @State private var lastPromotedCategory: RoutineCategory = .anytime
    @State private var showAlreadyInRoutinesAlert: Bool = false

    // Trash UI
    @State private var isTrashExpanded: Bool = false
    @State private var showEmptyTrashConfirm: Bool = false

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
                        .onSubmit { addItem() }

                    Button("Add") { addItem() }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                List {
                    // Active items (not deleted and not archived)
                    ForEach(store.activeTodos) { item in
                        Toggle(
                            isOn: Binding(
                                get: { item.isDone },
                                set: { newValue in
                                    store.toggleTodoDone(id: item.id, isDone: newValue)
                                }
                            )
                        ) {
                            Text(item.title)
                                .opacity(item.isDone ? 0.5 : 1.0)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                store.softDeleteTodo(id: item.id)
                            }

                            Button("Add to Routines") {
                                beginPromote(todo: item)
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { source, destination in
                        store.moveActiveTodos(from: source, to: destination)
                    }

                    // Trash
                    if !store.trashTodos.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isTrashExpanded) {
                                ForEach(store.trashTodos) { item in
                                    HStack {
                                        Text(item.title)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Restore") {
                                            store.restoreFromTrash(id: item.id)
                                        }
                                        .tint(.blue)

                                        Button("Delete Forever", role: .destructive) {
                                            store.deleteFromTrashForever(id: item.id)
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
                                Text("Recently Deleted (\(store.trashTodos.count))")
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { hideKeyboard() }
            .navigationTitle("To-Do")
            .toolbar { EditButton() }
        }
        .onAppear {
            store.purgeExpiredTrash()
            isAddFieldFocused = true
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
                store.deleteAllTrash()
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

    // MARK: - Keyboard Helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Actions
    private func addItem() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.addTodo(title: trimmed)
        newTitle = ""
        isAddFieldFocused = true
    }

    private func beginPromote(todo: TodoItem) {
        promotingTodoID = todo.id
        promoteTitle = todo.title
        promoteCategory = .anytime
        showingPromoteSheet = true
    }

    private func confirmPromoteToRoutine() {
        let trimmed = promoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let didAdd = store.addRoutineIfNotExists(title: trimmed, category: promoteCategory)

        showingPromoteSheet = false

        if didAdd {
            lastPromotedTitle = trimmed
            lastPromotedCategory = promoteCategory

            // Move instead of copy: remove todo completely (matches your previous behavior)
            if let todoID = promotingTodoID {
                store.removeTodoCompletely(id: todoID)
            }

            showPromotedAlert = true
        } else {
            showAlreadyInRoutinesAlert = true
        }

        promotingTodoID = nil
    }
}

#Preview {
    TodoView()
        .environmentObject(AppStore())
}
