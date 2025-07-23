//
//  DashboardView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI
import Foundation

struct DashboardView: View {
    private let healthKitService: HealthKitServiceProtocol
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
    
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var goalViewModel: GoalViewModel
    
    init(healthKitService: HealthKitServiceProtocol, dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self.healthKitService = healthKitService
        self.dataService = dataService
        self.calculationService = calculationService
        
        self._userProfileViewModel = StateObject(wrappedValue: UserProfileViewModel(dataService: dataService))
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(dataService: dataService, calculationService: calculationService))
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(calculationService: calculationService, dataService: dataService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome section
                    welcomeSection
                    
                    // Quick stats cards
                    quickStatsSection
                    
                    // Today's progress
                    todaysProgressSection
                    
                    // Quick actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                loadData()
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let user = userProfileViewModel.currentUser {
                Text("Welcome back!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Let's crush your fitness goals today!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Welcome to FitnessBoo!")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Calories Today",
                value: "\(Int(nutritionViewModel.todaysNutrition?.totalCalories ?? 0))",
                subtitle: "kcal",
                color: .orange
            )
            
            StatCard(
                title: "Active Goals",
                value: "\(goalViewModel.activeGoals.count)",
                subtitle: "goals",
                color: .blue
            )
        }
    }
    
    private var todaysProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let nutrition = nutritionViewModel.todaysNutrition {
                VStack(spacing: 8) {
                    ProgressRow(
                        title: "Calories",
                        current: nutrition.totalCalories,
                        target: userProfileViewModel.currentUser?.dailyCalorieGoal ?? 2000,
                        unit: "kcal",
                        color: .orange
                    )
                    
                    ProgressRow(
                        title: "Protein",
                        current: nutrition.totalProtein,
                        target: calculationService.calculateProteinGoal(for: userProfileViewModel.currentUser),
                        unit: "g",
                        color: .red
                    )
                }
            } else {
                Text("No nutrition data for today")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NavigationLink(destination: FoodEntryView(nutritionViewModel: nutritionViewModel)) {
                    ActionCard(
                        title: "Log Food",
                        icon: "fork.knife",
                        color: .green
                    )
                }
                
                NavigationLink(destination: GoalSettingView(calculationService: calculationService, dataService: dataService)) {
                    ActionCard(
                        title: "Set Goals",
                        icon: "target",
                        color: .blue
                    )
                }
            }
        }
    }
    
    private func loadData() {
        userProfileViewModel.loadCurrentUser()
        nutritionViewModel.loadTodaysNutrition()
        goalViewModel.loadGoals()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressRow: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(current))/\(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView(
        healthKitService: HealthKitService(),
        dataService: DataService.shared,
        calculationService: CalculationService()
    )
}