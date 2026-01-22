//
//  MainTabView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation
import UIKit
import Combine

// MARK: - Shared Toggle Style (checkbox look)
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

// MARK: - Models (kept beginner-friendly + local)
enum RoutineCategory: String, CaseIterable, Codable, Hashable {
    case morning = "Morning"
    case evening = "Evening"
    case anytime = "Anytime"
}

struct RoutineItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
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

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    var deletedAt: Date?

    // Added to match your project overview + avoid the “archivedAt missing” issue.
    // Optional means old saved data will still decode fine.
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        deletedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.archivedAt = archivedAt
    }
}

// MARK: - Shared Store (one source of truth)
@MainActor
final class AppStore: ObservableObject {
    // Storage keys (single source of truth)
    private let routinesKey = "routine_items_v1"
    private let todosKey = "todo_items_v1"

    private let trashRetentionDays: Int = 7

    @Published private(set) var routines: [RoutineItem] = []
    @Published private(set) var todos: [TodoItem] = []

    private var saveWorkItem: DispatchWorkItem?

    init() {
        loadAll()
        purgeExpiredTrash()
    }

    // MARK: - Date helper
    func todayKey() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return (components.year! * 10000) + (components.month! * 100) + components.day!
    }

    // MARK: - Public derived lists
    var activeTodos: [TodoItem] {
        // Active = not in trash and not archived
        todos.filter { $0.deletedAt == nil && $0.archivedAt == nil }
    }

    var trashTodos: [TodoItem] {
        todos.filter { $0.deletedAt != nil }
    }

    // MARK: - Routines
    func routines(for category: RoutineCategory) -> [RoutineItem] {
        routines.filter { $0.category == category }
    }

    func addRoutine(title: String, category: RoutineCategory) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        routines.append(RoutineItem(title: trimmed, category: category))
        scheduleSave()
    }

    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        scheduleSave()
    }

    func toggleRoutineDoneToday(id: UUID, isDone: Bool) {
        let today = todayKey()
        guard let idx = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[idx].lastCompletedDay = isDone ? today : nil
        scheduleSave()
    }

    func updateRoutine(id: UUID, newTitle: String, newCategory: RoutineCategory) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = routines.firstIndex(where: { $0.id == id }) else { return }

        routines[idx].title = trimmed
        routines[idx].category = newCategory
        scheduleSave()
    }

    func moveRoutines(in category: RoutineCategory, from source: IndexSet, to destination: Int) {
        // Reorder only within a category, keeping other categories stable.
        let idsInCategory = routines.enumerated()
            .filter { $0.element.category == category }
            .map { $0.element.id }

        var mutableIDs = idsInCategory
        mutableIDs.move(fromOffsets: source, toOffset: destination)

        // Rebuild routines by category order:
        var rebuilt: [RoutineItem] = []
        for cat in [RoutineCategory.morning, .anytime, .evening] {
            if cat == category {
                for id in mutableIDs {
                    if let item = routines.first(where: { $0.id == id }) {
                        rebuilt.append(item)
                    }
                }
            } else {
                rebuilt.append(contentsOf: routines.filter { $0.category == cat })
            }
        }

        routines = rebuilt
        scheduleSave()
    }

    // Prevent duplicates by case-insensitive title
    func addRoutineIfNotExists(title: String, category: RoutineCategory) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let key = trimmed.lowercased()
        let existing = Set(routines.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        guard !existing.contains(key) else { return false }

        routines.append(RoutineItem(title: trimmed, category: category))
        scheduleSave()
        return true
    }

    // MARK: - Todos
    func addTodo(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        todos.append(TodoItem(title: trimmed))
        scheduleSave()
    }

    func toggleTodoDone(id: UUID, isDone: Bool) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].isDone = isDone
        scheduleSave()
    }

    func moveActiveTodos(from source: IndexSet, to destination: Int) {
        let activeIDs = activeTodos.map(\.id)
        var mutableIDs = activeIDs
        mutableIDs.move(fromOffsets: source, toOffset: destination)

        // Rebuild todos: active (reordered) + archived + trash (keep order)
        let archived = todos.filter { $0.archivedAt != nil && $0.deletedAt == nil }
        let trash = todos.filter { $0.deletedAt != nil }

        var rebuiltActive: [TodoItem] = []
        for id in mutableIDs {
            if let item = todos.first(where: { $0.id == id }) {
                rebuiltActive.append(item)
            }
        }

        todos = rebuiltActive + archived + trash
        scheduleSave()
    }

    func softDeleteTodo(id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].deletedAt = Date()
        scheduleSave()
    }

    func restoreFromTrash(id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].deletedAt = nil
        scheduleSave()
    }

    func deleteFromTrashForever(id: UUID) {
        todos.removeAll { $0.id == id }
        scheduleSave()
    }

    func deleteAllTrash() {
        todos.removeAll { $0.deletedAt != nil }
        scheduleSave()
    }

    func archiveCompletedTodos() {
        let now = Date()
        for i in todos.indices {
            if todos[i].deletedAt == nil, todos[i].archivedAt == nil, todos[i].isDone == true {
                todos[i].archivedAt = now
            }
        }
        scheduleSave()
    }

    func purgeExpiredTrash() {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -trashRetentionDays, to: now) ?? now

        todos.removeAll { item in
            guard let deletedAt = item.deletedAt else { return false }
            return deletedAt < cutoff
        }
        scheduleSave()
    }
    
    func removeTodoCompletely(id: UUID) {
        todos.removeAll { $0.id == id }
        scheduleSave()
    }

    func todoTitleExists(_ title: String) -> Bool {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return false }
        return todos.contains { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
    }

    // MARK: - Persistence
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveAll()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func saveAll() {
        do {
            let routinesData = try JSONEncoder().encode(routines)
            UserDefaults.standard.set(routinesData, forKey: routinesKey)
        } catch {
            print("Failed to save routines:", error)
        }

        do {
            let todosData = try JSONEncoder().encode(todos)
            UserDefaults.standard.set(todosData, forKey: todosKey)
        } catch {
            print("Failed to save todos:", error)
        }
    }

    private func loadAll() {
        // Routines
        if let data = UserDefaults.standard.data(forKey: routinesKey),
           let decoded = try? JSONDecoder().decode([RoutineItem].self, from: data) {
            routines = decoded
        } else {
            // Defaults on first run
            routines = [
                RoutineItem(title: "Take vitamins (AM)", category: .morning),
                RoutineItem(title: "Wash face (AM)", category: .morning),
                RoutineItem(title: "Wash face (PM)", category: .evening),
                RoutineItem(title: "Shower", category: .anytime),
                RoutineItem(title: "Bed by 10:00", category: .evening)
            ]
        }

        // Todos
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = decoded
        } else {
            todos = []
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            
            TodoView()
                .tabItem { Label("To-Do", systemImage: "checklist") }

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "checkmark.circle") }

            BrainDumpView()
                .tabItem { Label("Brain Dump", systemImage: "brain.head.profile") }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStore())
}
