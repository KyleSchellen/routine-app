//
//  TodayView.swift
//  Routine
//
//  Created by Kyle on 2026-01-15.
//

import SwiftUI
import Foundation

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .imageScale(.medium)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

struct TodayView: View {
    // Reuse the same storage keys as the other tabs
    private let routinesKey = "routine_items_v1"
    private let todoKey = "todo_items_v1"

    @State private var routines: [RoutineItem] = []
    @State private var todos: [TodoItem] = []
    @State private var isCompletedExpanded: Bool = true

    @State private var isMorningExpanded: Bool = true
    @State private var isAnytimeExpanded: Bool = true
    @State private var isEveningExpanded: Bool = true
    @State private var isTodoExpanded: Bool = true

    var body: some View {
        NavigationStack {
            List {
                routinesCategorySection(category: .morning)
                routinesCategorySection(category: .anytime)
                routinesCategorySection(category: .evening)

                todoSectionCollapsible()

                completedSections()
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

    // MARK: - Routines (not done today, grouped by category)

    @ViewBuilder
    private func routinesCategorySection(category: RoutineCategory) -> some View {
        let today = todayKey()

        let totalIndices = routines.indices.filter { i in
            routines[i].category == category
        }

        let remainingIndices = totalIndices.filter { i in
            routines[i].lastCompletedDay != today
        }

        let remainingCount = remainingIndices.count
        let totalCount = totalIndices.count

        // If the user has no routines in this category at all, hide the section.
        if totalCount > 0 {
            Section {
                DisclosureGroup(
                    isExpanded: expandedBinding(for: category)
                ) {
                    if remainingIndices.isEmpty {
                        Text("All done ✅")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(remainingIndices, id: \.self) { index in
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
                            .toggleStyle(CheckboxToggleStyle())
                        }
                    }
                } label: {
                    Text("\(category.rawValue) (\(remainingCount)/\(totalCount))")
                }
            }
        }
    }

    private func expandedBinding(for category: RoutineCategory) -> Binding<Bool> {
        switch category {
        case .morning:
            return $isMorningExpanded
        case .anytime:
            return $isAnytimeExpanded
        case .evening:
            return $isEveningExpanded
        }
    }

    // MARK: - To-Dos (collapsible)

    @ViewBuilder
    private func todoSectionCollapsible() -> some View {
        let remainingCount = todos.filter { !$0.isDone }.count
        let totalCount = todos.count

        // Hide the section entirely if there are no To-Dos at all.
        if totalCount > 0 {
            Section {
                DisclosureGroup(isExpanded: $isTodoExpanded) {
                    todoNotDoneRows()
                } label: {
                    Text("To-Do (\(remainingCount)/\(totalCount))")
                }
            }
        }
    }

    // MARK: - To-Dos (not done)

    @ViewBuilder
    private func todoNotDoneRows() -> some View {
        let notDoneIndices = todos.indices.filter { i in
            todos[i].isDone == false
        }

        if notDoneIndices.isEmpty {
            Text("All done ✅")
                .foregroundStyle(.secondary)
        } else {
            ForEach(notDoneIndices, id: \.self) { index in
                Toggle(isOn: $todos[index].isDone) {
                    Text(todos[index].title)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - Completed (global bucket, collapsible)

    @ViewBuilder
    private func completedSections() -> some View {
        let today = todayKey()

        let completedRoutineIndices = routines.indices.filter { i in
            routines[i].lastCompletedDay == today
        }

        let completedTodoIndices = todos.indices.filter { i in
            todos[i].isDone == true
        }

        // Only show the group if there is anything completed
        if !completedRoutineIndices.isEmpty || !completedTodoIndices.isEmpty {
            Section {
                DisclosureGroup(
                    isExpanded: $isCompletedExpanded
                ) {
                    // Content shown when expanded
                    if !completedRoutineIndices.isEmpty {
                        Text("Completed Routines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(completedRoutineIndices, id: \.self) { index in
                            let isDoneToday = (routines[index].lastCompletedDay == today)

                            Toggle(
                                isOn: Binding(
                                    get: { isDoneToday },
                                    set: { newValue in
                                        routines[index].lastCompletedDay = newValue ? today : nil
                                    }
                                )
                            ) {
                                HStack {
                                    Text(routines[index].title)
                                    Spacer()
                                    Text(routines[index].category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    if !completedTodoIndices.isEmpty {
                        Text("Completed To-Dos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)

                        ForEach(completedTodoIndices, id: \.self) { index in
                            Toggle(isOn: $todos[index].isDone) {
                                Text(todos[index].title)
                                    .foregroundStyle(.secondary)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                        }
                    }
                } label: {
                    Text("Completed")
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
