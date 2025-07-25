//
//  FitnessBooApp.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

@main
struct FitnessBooApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            handleAppLifecycle(newPhase)
        }
    }
    
    private func handleAppLifecycle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - could trigger additional refresh logic here if needed
            print("App became active")
        case .background:
            // App went to background - HealthKit background sync will continue
            print("App went to background")
        case .inactive:
            print("App became inactive")
        @unknown default:
            break
        }
    }
}
