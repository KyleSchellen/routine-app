//
//  TodayView.swift
//  Routine
//
//  Created by Kyle on 2026-01-15.
//


//
//  TodayView.swift
//  Routine
//
//  Created by Kyle on 2026-01-15.
//

import SwiftUI
import Foundation

struct TodayView: View {
    // Reuse the same storage keys as the other tabs
    private let routinesKey = "routine_items_v1"
    private let todoKey = "todo_items_v1"

    @State private var routines: [RoutineItem] = []
    @State private var todos: [TodoItem] = []

    var body: some View {
        NavigationStack {
            List {
                routinesSection(category: .morning)
                routinesSection(category: .anytime)
                routinesSection(category: .evening)

                todoSection()
            }
            .navigationTitle("Today")
        }
        .onAppear {
            loadRoutines()
            loadTodos()
        }
        .onChange(of: routines) {
            saveRoutines()
        }
        .onChange(of: todos) {
            saveTodos()
        }
    }

    // MARK: - Routines (only show not-done-today)

    @ViewBuilder
    private func routinesSection(category: RoutineCategory) -> some View {
        let today = todayKey()

        // Indices in the *master* array that match this category AND are not done today
        let indices = routines.indices.filter { i in
            routines[i].category == category && routines[i].lastCompletedDay != today
        }

        if !indices.isEmpty {
            Section("\(category.rawValue) Routines") {
                ForEach(indices, id: \.self) { index in
                    // Done today if lastCompletedDay matches today's key
                    let isDoneToday = (routines[index].lastCompletedDay == today)

                    Toggle(
                        isOn: Binding(
                            get: { isDoneToday },
                            set: { newValue in
                                routines[index].lastCompletedDay = newValue ? today : nil
                            }
                        )
                    ) {
                        Text(routines[index].title)
                    }
                }
            }
        }
    }

    // MARK: - To-Dos (only show not done)

    @ViewBuilder
    private func todoSection() -> some View {
        // Indices in the *master* array for unfinished todos
        let indices = todos.indices.filter { i in
            todos[i].isDone == false
        }

        if !indices.isEmpty {
            Section("To-Do") {
                ForEach(indices, id: \.self) { index in
                    Toggle(isOn: $todos[index].isDone) {
                        Text(todos[index].title)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func todayKey() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return (components.year! * 10000) + (components.month! * 100) + components.day!
    }

    // MARK: - Persistence (Routines)

    private func saveRoutines() {
        do {
            let data = try JSONEncoder().encode(routines)
            UserDefaults.standard.set(data, forKey: routinesKey)
        } catch {
            print("Failed to save routines:", error)
        }
    }

    private func loadRoutines() {
        guard let data = UserDefaults.standard.data(forKey: routinesKey) else {
            routines = []
            return
        }

        do {
            routines = try JSONDecoder().decode([RoutineItem].self, from: data)
        } catch {
            print("Failed to load routines:", error)
            routines = []
        }
    }

    // MARK: - Persistence (To-Dos)

    private func saveTodos() {
        do {
            let data = try JSONEncoder().encode(todos)
            UserDefaults.standard.set(data, forKey: todoKey)
        } catch {
            print("Failed to save todos:", error)
        }
    }

    private func loadTodos() {
        guard let data = UserDefaults.standard.data(forKey: todoKey) else {
            todos = []
            return
        }

        do {
            todos = try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            print("Failed to load todos:", error)
            todos = []
        }
    }
}

#Preview {
    TodayView()
}
