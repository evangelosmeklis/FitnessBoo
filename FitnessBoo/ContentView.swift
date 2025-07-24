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
            
            HistoryView(dataService: dataService)
                .tabItem {
                    Label("History", systemImage: "calendar")
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
            // Check if the day has changed
            checkForDayChange()
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
    
    private func checkForDayChange() {
        let lastOpened = UserDefaults.standard.object(forKey: "lastOpenedDate") as? Date ?? Date()
        if !Calendar.current.isDateInToday(lastOpened) {
            // Day has changed, reset metrics
            NotificationCenter.default.post(name: NSNotification.Name("DayChanged"), object: nil)
        }
        UserDefaults.standard.set(Date(), forKey: "lastOpenedDate")
    }
}

#Preview {
    ContentView()
}
