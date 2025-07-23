//
//  ContentView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct ContentView: View {
    // Service dependencies - in a real app these would be injected via dependency injection
    private let healthKitService: HealthKitServiceProtocol = HealthKitService()
    private let dataService: DataServiceProtocol = DataService.shared
    private let calculationService: CalculationServiceProtocol = CalculationService()
    
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
    }
}

#Preview {
    ContentView()
}
