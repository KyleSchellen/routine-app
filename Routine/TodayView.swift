//
//  TodayView.swift
//  Routine
//
//  Created by Kyle on 2026-01-15.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore

    @State private var isCompletedExpanded: Bool = true
    @State private var isMorningExpanded: Bool = true
    @State private var isAnytimeExpanded: Bool = true
    @State private var isEveningExpanded: Bool = true
    @State private var isTodoExpanded: Bool = true
    @State private var isRoutinesExpanded: Bool = true

    var body: some View {
        NavigationStack {
            List {
                routinesGroup()
                todoSectionCollapsible()
                completedSections()
            }
            .navigationTitle("Today")
        }
    }

    // MARK: - Routines

    @ViewBuilder
    private func routinesGroup() -> some View {
        let today = store.todayKey()
        let all = store.routines

        let totalCount = all.count
        let remainingCount = all.filter { $0.lastCompletedDay != today }.count

        if totalCount > 0 {
            Section {
                DisclosureGroup(isExpanded: $isRoutinesExpanded) {
                    routinesSubcategory(category: .morning)
                    routinesSubcategory(category: .anytime)
                    routinesSubcategory(category: .evening)
                } label: {
                    Text("Routines (\(remainingCount)/\(totalCount))")
                }
            }
        }
    }

    @ViewBuilder
    private func routinesSubcategory(category: RoutineCategory) -> some View {
        let today = store.todayKey()
        let items = store.routines(for: category)

        let totalCount = items.count
        let remaining = items.filter { $0.lastCompletedDay != today }
        let remainingCount = remaining.count

        if totalCount > 0 {
            DisclosureGroup(isExpanded: expandedBinding(for: category)) {
                if remaining.isEmpty {
                    Text("All done ✅")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remaining) { item in
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
                        }
                        .toggleStyle(CheckboxToggleStyle())
                    }
                }
            } label: {
                Text("\(category.rawValue) (\(remainingCount)/\(totalCount))")
            }
        }
    }

    private func expandedBinding(for category: RoutineCategory) -> Binding<Bool> {
        switch category {
        case .morning: return $isMorningExpanded
        case .anytime: return $isAnytimeExpanded
        case .evening: return $isEveningExpanded
        }
    }

    // MARK: - Todos

    @ViewBuilder
    private func todoSectionCollapsible() -> some View {
        let active = store.activeTodos
        let remainingCount = active.filter { !$0.isDone }.count
        let totalCount = active.count

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

    @ViewBuilder
    private func todoNotDoneRows() -> some View {
        let notDone = store.activeTodos.filter { !$0.isDone }

        if notDone.isEmpty {
            Text("All done ✅")
                .foregroundStyle(.secondary)
        } else {
            ForEach(notDone) { item in
                Toggle(
                    isOn: Binding(
                        get: { item.isDone },
                        set: { newValue in
                            store.toggleTodoDone(id: item.id, isDone: newValue)
                        }
                    )
                ) {
                    Text(item.title)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - Completed

    @ViewBuilder
    private func completedSections() -> some View {
        let today = store.todayKey()

        let completedRoutines = store.routines.filter { $0.lastCompletedDay == today }
        let completedTodos = store.activeTodos.filter { $0.isDone }

        if !completedRoutines.isEmpty || !completedTodos.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $isCompletedExpanded) {

                    if !completedRoutines.isEmpty {
                        Text("Completed Routines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(completedRoutines) { item in
                            Toggle(
                                isOn: Binding(
                                    get: { item.lastCompletedDay == today },
                                    set: { newValue in
                                        store.toggleRoutineDoneToday(id: item.id, isDone: newValue)
                                    }
                                )
                            ) {
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Text(item.category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    if !completedTodos.isEmpty {
                        Text("Completed To-Dos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)

                        ForEach(completedTodos) { item in
                            Toggle(
                                isOn: Binding(
                                    get: { item.isDone },
                                    set: { newValue in
                                        store.toggleTodoDone(id: item.id, isDone: newValue)
                                    }
                                )
                            ) {
                                Text(item.title)
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
}

#Preview {
    TodayView()
        .environmentObject(AppStore())
}
