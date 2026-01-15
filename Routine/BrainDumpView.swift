//
//  BrainDumpView.swift
//  Routine
//
//  Created by Kyle on 2026-01-14.
//

import SwiftUI
import Foundation

struct BrainDumpView: View {
    private let storageKey = "brain_dump_text_v1"

    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    .frame(minHeight: 300)

                Button("Clear") {
                    text = ""
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Brain Dump")
        }
        .onAppear {
            loadText()
        }
        .onChange(of: text) {
            saveText()
        }
    }

    private func saveText() {
        UserDefaults.standard.set(text, forKey: storageKey)
    }

    private func loadText() {
        text = UserDefaults.standard.string(forKey: storageKey) ?? ""
    }
}

#Preview {
    BrainDumpView()
}
