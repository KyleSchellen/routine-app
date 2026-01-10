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

struct RoutineItem: Identifiable {
    let id = UUID()
    var title: String
    // Stores the day (YYYYMMDD) when this item was last completed.
    // nil means "never completed" (or not yet done today).
    var lastCompletedDay: Int?
}

struct ContentView: View {
    @State private var items: [RoutineItem] = [
        RoutineItem(title: "Take vitamins (AM)", lastCompletedDay: nil),
        RoutineItem(title: "Wash face (AM)", lastCompletedDay: nil),
        RoutineItem(title: "Wash face (PM)", lastCompletedDay: nil),
        RoutineItem(title: "Shower", lastCompletedDay: nil),
        RoutineItem(title: "Bed by 10:00", lastCompletedDay: nil)
    ]

    @State private var newItemTitle: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Add new routine item
                HStack(spacing: 8) {
                    TextField("Add a routine…", text: $newItemTitle)
                        .textFieldStyle(.roundedBorder)

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
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(RoutineItem(title: trimmed, lastCompletedDay: nil))
        newItemTitle = "" // reset textfield to empty after adding new item
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func todayKey() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return (components.year! * 10000) + (components.month! * 100) + components.day!
    }
}
