//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedAppearance: AppearanceMode = .auto
    @State private var colorScheme: ColorScheme?

    var body: some View {
        LiquidGlassTabContainer()
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
                    }
                }
            }
    }

    private func loadAppearanceMode() {
        if let savedAppearance = UserDefaults.standard.string(forKey: "AppearanceMode"),
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            selectedAppearance = appearance
            colorScheme = appearance.colorScheme
        }
    }
}

#Preview {
    ContentView()
}
