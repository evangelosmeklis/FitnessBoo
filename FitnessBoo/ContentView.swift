//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedAppearance: AppearanceMode = .dark  // Default to dark mode
    @State private var colorScheme: ColorScheme? = .dark
    @State private var refreshID = UUID()

    var body: some View {
        LiquidGlassTabContainer()
            .id(refreshID) // Force complete redraw on color scheme change
            .preferredColorScheme(colorScheme)
            .onAppear {
                loadAppearanceMode()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppearanceModeChanged"))) { notification in
                if let mode = notification.object as? AppearanceMode {
                    // Use a transaction to disable animations during color scheme change
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selectedAppearance = mode
                        colorScheme = mode.colorScheme
                        // Force complete view refresh to prevent gray flash
                        refreshID = UUID()
                    }
                }
            }
    }

    private func loadAppearanceMode() {
        if let savedAppearance = UserDefaults.standard.string(forKey: "AppearanceMode"),
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            selectedAppearance = appearance
            colorScheme = appearance.colorScheme
        } else {
            // If no saved preference, default to dark mode and save it
            selectedAppearance = .dark
            colorScheme = .dark
            UserDefaults.standard.set(AppearanceMode.dark.rawValue, forKey: "AppearanceMode")
        }
    }
}

#Preview {
    ContentView()
}
