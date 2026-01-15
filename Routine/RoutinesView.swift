//
//  RoutinesView.swift
//  Routine
//
//  Created by Kyle on 2026-01-08.
//

//import SwiftUI
//
//struct RoutinesView: View {
//    var body: some View {
//        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, world!")
//        }
//        .padding()
//    }
//}
//
//#Preview {
//    RoutinesView()
//}

import SwiftUI
import Foundation
import UIKit

enum RoutineCategory: String, CaseIterable, Codable, Hashable {
    case morning = "Morning"
    case evening = "Evening"
    case anytime = "Anytime"
}

struct RoutineItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    // Stores the day (YYYYMMDD) when this item was last completed.
    // nil means "never completed" (or not yet done today).
    var lastCompletedDay: Int?
    var category: RoutineCategory
    
    init(id: UUID = UUID(),
         title: String,
         category: RoutineCategory = .anytime,
         lastCompletedDay: Int? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.lastCompletedDay = lastCompletedDay
    }
}


struct RoutinesView: View {
    private let storageKey = "routine_items_v1"
    
    @State private var morningItems: [RoutineItem] = []
    @State private var anytimeItems: [RoutineItem] = []
    @State private var eveningItems: [RoutineItem] = []

    @State private var saveWorkItem: DispatchWorkItem? = nil
    
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
                // Add new routine item
                HStack(spacing: 8) {
                    TextField("Add a routine…", text: $newItemTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAddFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(RoutineCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Add") {
                        addItem()
                    }
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
            .onTapGesture {
                hideKeyboard()
            }
            .navigationTitle("Routines")
            .toolbar {
                EditButton() // enables swipe-to-delete + edit mode
            }
        }
        .onAppear {
            loadItems()
            isAddFieldFocused = true
        }
        .onChange(of: morningItems) {
            scheduleSave()
        }
        .onChange(of: anytimeItems) {
            scheduleSave()
        }
        .onChange(of: eveningItems) {
            scheduleSave()
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
    
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem {
            saveItems()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func applyLoadedItems(_ loaded: [RoutineItem]) {
        morningItems = loaded.filter { $0.category == .morning }
        anytimeItems = loaded.filter { $0.category == .anytime }
        eveningItems = loaded.filter { $0.category == .evening }
    }

    private func getItems(for category: RoutineCategory) -> [RoutineItem] {
        switch category {
        case .morning: return morningItems
        case .anytime: return anytimeItems
        case .evening: return eveningItems
        }
    }

    private func bindingFor(category: RoutineCategory) -> Binding<[RoutineItem]> {
        switch category {
        case .morning:
            return $morningItems
        case .anytime:
            return $anytimeItems
        case .evening:
            return $eveningItems
        }
    }

    private func appendItem(_ item: RoutineItem, to category: RoutineCategory) {
        switch category {
        case .morning:
            morningItems.append(item)
        case .anytime:
            anytimeItems.append(item)
        case .evening:
            eveningItems.append(item)
        }
    }

    private func removeItem(at index: Int, from category: RoutineCategory) {
        switch category {
        case .morning:
            morningItems.remove(at: index)
        case .anytime:
            anytimeItems.remove(at: index)
        case .evening:
            eveningItems.remove(at: index)
        }
    }

    private func findLocation(of id: UUID) -> (category: RoutineCategory, index: Int)? {
        if let idx = morningItems.firstIndex(where: { $0.id == id }) {
            return (.morning, idx)
        }
        if let idx = anytimeItems.firstIndex(where: { $0.id == id }) {
            return (.anytime, idx)
        }
        if let idx = eveningItems.firstIndex(where: { $0.id == id }) {
            return (.evening, idx)
        }
        return nil
    }

    private func deleteRoutine(id: UUID) {
        if let idx = morningItems.firstIndex(where: { $0.id == id }) {
            morningItems.remove(at: idx)
            return
        }
        if let idx = anytimeItems.firstIndex(where: { $0.id == id }) {
            anytimeItems.remove(at: idx)
            return
        }
        if let idx = eveningItems.firstIndex(where: { $0.id == id }) {
            eveningItems.remove(at: idx)
            return
        }
    }

    private func moveItems(in category: RoutineCategory, from source: IndexSet, to destination: Int) {
        switch category {
        case .morning:
            morningItems.move(fromOffsets: source, toOffset: destination)
        case .anytime:
            anytimeItems.move(fromOffsets: source, toOffset: destination)
        case .evening:
            eveningItems.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    @ViewBuilder
    private func routineSection(category: RoutineCategory) -> some View {
        let today = todayKey()
        let itemsForCategory = getItems(for: category)

        if !itemsForCategory.isEmpty {
            Section(category.rawValue) {
                ForEach(bindingFor(category: category)) { $item in
                    let isDoneToday = ($item.wrappedValue.lastCompletedDay == today)

                    Toggle(
                        isOn: Binding(
                            get: { isDoneToday },
                            set: { newValue in
                                $item.wrappedValue.lastCompletedDay = newValue ? today : nil
                            }
                        )
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: isDoneToday ? "checkmark.circle.fill" : "circle")
                                .imageScale(.medium)

                            Text($item.wrappedValue.title)
                                .opacity(isDoneToday ? 0.5 : 1.0)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteRoutine(id: $item.wrappedValue.id)
                        }
                        Button("Edit") {
                            startEditing(item: $item.wrappedValue)
                        }
                        .tint(.blue)
                    }
                }
                .onMove { source, destination in
                    moveItems(in: category, from: source, to: destination)
                }
            }
        }
    }
    
    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = RoutineItem(title: trimmed, category: selectedCategory, lastCompletedDay: nil)
        appendItem(newItem, to: selectedCategory)
        newItemTitle = "" // reset textfield to empty after adding new item
        isAddFieldFocused = true //guard for future focus stealers
    }
    
    private func startEditing(item: RoutineItem) {
        editingItemID = item.id
        editTitle = item.title
        editCategory = item.category
    }

    private func todayKey() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return (components.year! * 10000) + (components.month! * 100) + components.day!
    }
    
    private func saveItems() {
        do {
            let combined = morningItems + anytimeItems + eveningItems
            let data = try JSONEncoder().encode(combined)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save items:", error)
        }
    }
    
    private func saveEdits() {
        guard let id = editingItemID else { return }

        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let location = findLocation(of: id) else { return }

        let currentCategory = location.category
        let currentIndex = location.index

        // Update the item in-place
        var item = getItems(for: currentCategory)[currentIndex]
        item.title = trimmed
        item.category = editCategory

        // Remove from the old category array
        removeItem(at: currentIndex, from: currentCategory)

        // Add to the new category array
        appendItem(item, to: editCategory)

        editingItemID = nil
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // First run: start with defaults
            let defaults: [RoutineItem] = [
                RoutineItem(title: "Take vitamins (AM)", category: .morning),
                RoutineItem(title: "Wash face (AM)", category: .morning),
                RoutineItem(title: "Wash face (PM)", category: .evening),
                RoutineItem(title: "Shower", category: .anytime),
                RoutineItem(title: "Bed by 10:00", category: .evening)
            ]
            applyLoadedItems(defaults)
            return
        }

        do {
            let loaded = try JSONDecoder().decode([RoutineItem].self, from: data)
            applyLoadedItems(loaded)
        } catch {
            print("Failed to load items:", error)

            let defaults: [RoutineItem] = [
                RoutineItem(title: "Take vitamins (AM)", category: .morning),
                RoutineItem(title: "Wash face (AM)", category: .morning),
                RoutineItem(title: "Wash face (PM)", category: .evening),
                RoutineItem(title: "Shower", category: .anytime),
                RoutineItem(title: "Bed by 10:00", category: .evening)
            ]
            applyLoadedItems(defaults)
        }
    }
}

#Preview {
    RoutinesView()
}
