//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    // Service dependencies - in a real app these would be injected via dependency injection
    private let healthKitService: HealthKitServiceProtocol = HealthKitService()
    private let dataService: DataServiceProtocol = DataService.shared
    private let calculationService: CalculationServiceProtocol = CalculationService()
    
    @State private var hasRequestedHealthKit = false
    
    var body: some View {
        TabView {
            DashboardView(
                healthKitService: healthKitService,
                dataService: dataService,
                calculationService: calculationService
            )
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            
            NutritionDashboardView(
                dataService: dataService,
                calculationService: calculationService
            )
            .tabItem {
                Label("Nutrition", systemImage: "chart.bar.fill")
            }
            
            // Placeholder for Goals view
            GoalSettingView(
                calculationService: calculationService,
                dataService: dataService
            )
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            
            // Placeholder for Settings view
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            requestHealthKitAuthorizationIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func requestHealthKitAuthorizationIfNeeded() {
        guard !hasRequestedHealthKit else { return }
        hasRequestedHealthKit = true
        
        Task {
            do {
                try await healthKitService.requestAuthorization()
                print("HealthKit authorization completed successfully")
            } catch {
                print("HealthKit authorization failed: \(error.localizedDescription)")
                // Continue without HealthKit - the app will use calculated values
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - refresh HealthKit data
            refreshHealthKitData()
        case .inactive:
            // App became inactive - could pause background sync if needed
            break
        case .background:
            // App went to background - background sync will continue
            break
        @unknown default:
            break
        }
    }
    
    private func refreshHealthKitData() {
        Task {
            do {
                // Trigger manual refresh of HealthKit data
                try await healthKitService.manualRefresh()
                print("HealthKit data refreshed successfully")
            } catch {
                print("HealthKit data refresh failed: \(error.localizedDescription)")
                // Continue silently - background sync will retry
            }
        }
    }
}

#Preview {
    ContentView()
}
