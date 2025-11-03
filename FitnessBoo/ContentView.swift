//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LiquidGlassTabContainer()
            .preferredColorScheme(.dark) // Always use dark mode
    }
}

#Preview {
    ContentView()
}
