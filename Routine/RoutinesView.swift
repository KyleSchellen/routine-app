//
//  RoutinesView.swift
//  Routine
//
//  Created by Kyle on 2026-01-08.
//

import SwiftUI
import UIKit

struct RoutinesView: View {
    @EnvironmentObject private var store: AppStore

    @State private var newItemTitle: String = ""
    @State private var selectedCategory: RoutineCategory = .anytime

    // Editing
    @State private var editingItemID: UUID? = nil
    @State private var editTitle: String = ""
    @State private var editCategory: RoutineCategory = .anytime

    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Add a routine…", text: $newItemTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAddFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { addItem() }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(RoutineCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Add") { addItem() }
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                List {
                    routineSection(category: .morning)
                    routineSection(category: .anytime)
                    routineSection(category: .evening)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { hideKeyboard() }
            .navigationTitle("Routines")
            .toolbar { EditButton() }
        }
        .onAppear { isAddFieldFocused = true }
        .sheet(
            isPresented: Binding(
                get: { editingItemID != nil },
                set: { isPresented in
                    if !isPresented { editingItemID = nil }
                }
            )
        ) {
            editSheet()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func routineSection(category: RoutineCategory) -> some View {
        let today = store.todayKey()
        let items = store.routines(for: category)

        if !items.isEmpty {
            Section(category.rawValue) {
                ForEach(items) { item in
                    let isDoneToday = (item.lastCompletedDay == today)

                    Toggle(
                        isOn: Binding(
                            get: { isDoneToday },
                            set: { newValue in
                                store.toggleRoutineDoneToday(id: item.id, isDone: newValue)
                            }
                        )
                    ) {
                        Text(item.title)
                            .opacity(isDoneToday ? 0.5 : 1.0)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            store.deleteRoutine(id: item.id)
                        }
                        Button("Edit") {
                            startEditing(item: item)
                        }
                        .tint(.blue)
                    }
                }
                .onMove { source, destination in
                    store.moveRoutines(in: category, from: source, to: destination)
                }
            }
        }
    }

    // MARK: - Actions

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.addRoutine(title: trimmed, category: selectedCategory)
        newItemTitle = ""
        isAddFieldFocused = true
    }

    private func startEditing(item: RoutineItem) {
        editingItemID = item.id
        editTitle = item.title
        editCategory = item.category
    }

    private func saveEdits() {
        guard let id = editingItemID else { return }
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.updateRoutine(id: id, newTitle: trimmed, newCategory: editCategory)
        editingItemID = nil
    }

    // MARK: - UI helpers

    private func editSheet() -> some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Routine title", text: $editTitle)
                }

                Section("Category") {
                    Picker("Category", selection: $editCategory) {
                        ForEach(RoutineCategory.allCases, id: \.rawValue) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Edit Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingItemID = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

#Preview {
    RoutinesView()
        .environmentObject(AppStore())
}
