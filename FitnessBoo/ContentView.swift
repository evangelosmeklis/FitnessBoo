//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue

    var body: some View {
        LiquidGlassTabContainer()
            .preferredColorScheme(colorSchemeForAppearanceMode)
    }

    private var colorSchemeForAppearanceMode: ColorScheme? {
        guard let mode = AppearanceMode(rawValue: appearanceMode) else {
            return .dark
        }
        return mode.colorScheme
    }
}

#Preview {
    ContentView()
}
