//
//  RoutineApp.swift
//  Routine
//
//  Created by Kyle on 2026-01-08.
//

import SwiftUI

@main
struct RoutineApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }
    }
}
