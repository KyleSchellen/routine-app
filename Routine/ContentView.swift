//
//  ContentView.swift
//  Routine
//
//  Created by Kyle on 2026-01-08.
//

//import SwiftUI
//
//struct ContentView: View {
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
//    ContentView()
//}

import SwiftUI
import Foundation

struct RoutineItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    // Stores the day (YYYYMMDD) when this item was last completed.
    // nil means "never completed" (or not yet done today).
    var lastCompletedDay: Int?
    
    init(id: UUID = UUID(), title: String, lastCompletedDay: Int? = nil) {
        self.id = id
        self.title = title
        self.lastCompletedDay = lastCompletedDay
    }
}

struct ContentView: View {
    private let storageKey = "routine_items_v1"
    
    @State private var items: [RoutineItem] = []

    @State private var newItemTitle: String = ""
    
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

                    Button("Add") {
                        addItem()
                    }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                // List of routine items
                List {
                    ForEach($items) { $item in
                        let today = todayKey()
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
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                EditButton() // enables swipe-to-delete + edit mode
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

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(RoutineItem(title: trimmed, lastCompletedDay: nil))
        newItemTitle = "" // reset textfield to empty after adding new item
        isAddFieldFocused = true //guard for future focus stealers
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func todayKey() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return (components.year! * 10000) + (components.month! * 100) + components.day!
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save items:", error)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // First run: start with defaults
            items = [
                RoutineItem(title: "Take vitamins (AM)"),
                RoutineItem(title: "Wash face (AM)"),
                RoutineItem(title: "Wash face (PM)"),
                RoutineItem(title: "Shower"),
                RoutineItem(title: "Bed by 10:00")
            ]
            return
        }

        do {
            items = try JSONDecoder().decode([RoutineItem].self, from: data)
        } catch {
            print("Failed to load items:", error)

            // If decoding fails, fall back to defaults so app still works
            items = [
                RoutineItem(title: "Take vitamins (AM)"),
                RoutineItem(title: "Wash face (AM)"),
                RoutineItem(title: "Wash face (PM)"),
                RoutineItem(title: "Shower"),
                RoutineItem(title: "Bed by 10:00")
            ]
        }
    }
}
