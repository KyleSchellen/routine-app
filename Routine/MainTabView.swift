//
//  MainTabView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "checkmark.circle")
                }

            BrainDumpView()
                .tabItem {
                    Label("Brain Dump", systemImage: "brain.head.profile")
                }
            
            TodoView()
                .tabItem {
                    Label("To-do", systemImage: "checklist")
                }
        }
    }
}

#Preview {
    MainTabView()
}
