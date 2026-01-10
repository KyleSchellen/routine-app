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

struct RoutineItem: Identifiable {
    let id = UUID()
    var title: String
    var isDone: Bool
}

struct ContentView: View {
    @State private var items: [RoutineItem] = [
        RoutineItem(title: "Take vitamins (AM)", isDone: false),
        RoutineItem(title: "Wash face (AM)", isDone: false),
        RoutineItem(title: "Wash face (PM)", isDone: false),
        RoutineItem(title: "Shower", isDone: false),
        RoutineItem(title: "Bed by 10:00", isDone: false)
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
                        Toggle(item.title, isOn: $item.isDone)
                    }
                    .onDelete(perform: deleteItems)
                }

                // Reset button
                Button("Reset all for tomorrow") {
                    resetAll()
                }
                .padding(.bottom, 8)
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
        items.append(RoutineItem(title: trimmed, isDone: false))
        newItemTitle = "" // reset textfield to empty afer adding new item
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func resetAll() {
        for i in items.indices {
            items[i].isDone = false
        }
    }
}
