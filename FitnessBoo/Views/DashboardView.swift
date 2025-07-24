//
//  DashboardView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI
import Foundation
import Combine

struct DashboardView: View {
    private let healthKitService: HealthKitServiceProtocol
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
    
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var goalViewModel: GoalViewModel
    @StateObject private var energyViewModel: EnergyViewModel
    @StateObject private var calorieBalanceService: CalorieBalanceService
    
    init(healthKitService: HealthKitServiceProtocol, dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self.healthKitService = healthKitService
        self.dataService = dataService
        self.calculationService = calculationService
        
        self._userProfileViewModel = StateObject(wrappedValue: UserProfileViewModel(dataService: dataService))
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(dataService: dataService, calculationService: calculationService))
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(calculationService: calculationService, dataService: dataService))
        self._energyViewModel = StateObject(wrappedValue: EnergyViewModel(healthKitService: healthKitService))
        self._calorieBalanceService = StateObject(wrappedValue: CalorieBalanceService(healthKitService: healthKitService, calculationService: calculationService, dataService: dataService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome section
                    welcomeSection
                    
                    // Quick stats cards
                    quickStatsSection
                    
                    // Energy tracking section
                    energyTrackingSection
                    
                    // Caloric balance section
                    caloricBalanceSection
                    
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
            .refreshable {
                await refreshAllData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
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
                title: "Calories Consumed",
                value: "\(Int(nutritionViewModel.todaysNutrition?.totalCalories ?? 0))",
                subtitle: "kcal",
                color: .green
            )
            
            StatCard(
                title: "Calories Burned",
                value: energyViewModel.formattedTotalEnergy,
                subtitle: "kcal",
                color: .red
            )
            
            StatCard(
                title: "Active Energy",
                value: energyViewModel.formattedActiveEnergy,
                subtitle: "kcal",
                color: .orange
            )
            
            StatCard(
                title: "Resting Energy",
                value: energyViewModel.formattedRestingEnergy,
                subtitle: "kcal",
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
                        target: goalViewModel.currentGoal?.dailyCalorieTarget ?? 2000,
                        unit: "kcal",
                        color: .orange
                    )
                    
                    ProgressRow(
                        title: "Protein",
                        current: nutrition.totalProtein,
                        target: goalViewModel.currentGoal?.dailyProteinTarget ?? 100,
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
    
    private var energyTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            if energyViewModel.isLoading {
                ProgressView("Loading energy data...")
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = energyViewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                VStack(spacing: 12) {
                    // Energy breakdown chart
                    EnergyBreakdownView(
                        activeEnergy: energyViewModel.activeEnergy,
                        restingEnergy: energyViewModel.restingEnergy,
                        totalEnergy: energyViewModel.totalEnergyExpended
                    )
                    
                    // Energy details
                    HStack(spacing: 20) {
                        EnergyDetailView(
                            title: "Active",
                            value: energyViewModel.formattedActiveEnergy,
                            color: .orange,
                            percentage: energyViewModel.activeEnergyPercentage
                        )
                        
                        EnergyDetailView(
                            title: "Resting",
                            value: energyViewModel.formattedRestingEnergy,
                            color: .blue,
                            percentage: energyViewModel.restingEnergyPercentage
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var caloricBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Caloric Balance")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: CalorieBalanceView(calorieBalanceService: calorieBalanceService)) {
                    Text("View Details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            CalorieBalanceSummaryView(calorieBalanceService: calorieBalanceService)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func loadData() {
        userProfileViewModel.loadCurrentUser()
        nutritionViewModel.loadTodaysNutrition()
        goalViewModel.loadGoals()
        energyViewModel.loadTodaysEnergy()
        calorieBalanceService.startRealTimeTracking()
    }
    
    private func refreshAllData() async {
        // Refresh HealthKit data first
        do {
            try await healthKitService.manualRefresh()
        } catch {
            print("HealthKit refresh failed: \(error)")
        }
        
        // Refresh all view models
        await MainActor.run {
            userProfileViewModel.loadCurrentUser()
            nutritionViewModel.loadTodaysNutrition()
            goalViewModel.loadGoals()
        }
        
        // Refresh energy data
        await energyViewModel.refreshEnergyData()
        
        // Restart calorie balance tracking to get fresh data
        calorieBalanceService.stopRealTimeTracking()
        calorieBalanceService.startRealTimeTracking()
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

// MARK: - Energy Views

struct EnergyBreakdownView: View {
    let activeEnergy: Double
    let restingEnergy: Double
    let totalEnergy: Double
    
    private var activePercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return activeEnergy / totalEnergy
    }
    
    private var restingPercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return restingEnergy / totalEnergy
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total Energy Burned")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(totalEnergy)) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Energy breakdown bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * activePercentage)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * restingPercentage)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct EnergyDetailView: View {
    let title: String
    let value: String
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("\(Int(percentage * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calorie Balance Summary View

struct CalorieBalanceSummaryView: View {
    @StateObject private var viewModel: CalorieBalanceSummaryViewModel
    
    init(calorieBalanceService: CalorieBalanceServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: CalorieBalanceSummaryViewModel(calorieBalanceService: calorieBalanceService))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let balance = viewModel.currentBalance {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(balance.formattedBalance)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(balance.isPositiveBalance ? .orange : .green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(balance.balanceDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(balance.caloriesConsumed)) - \(Int(balance.totalEnergyExpended))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Simple balance bar
                GeometryReader { geometry in
                    let consumedWidth = min(balance.caloriesConsumed / max(balance.totalEnergyExpended, balance.caloriesConsumed) * geometry.size.width, geometry.size.width)
                    let burnedWidth = min(balance.totalEnergyExpended / max(balance.totalEnergyExpended, balance.caloriesConsumed) * geometry.size.width, geometry.size.width)
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: consumedWidth, height: 6)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: burnedWidth, height: 6)
                            .opacity(0.7)
                    }
                }
                .frame(height: 6)
                .cornerRadius(3)
                
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Calculating balance...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

@MainActor
class CalorieBalanceSummaryViewModel: ObservableObject {
    @Published var currentBalance: CalorieBalance?
    
    private let calorieBalanceService: CalorieBalanceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(calorieBalanceService: CalorieBalanceServiceProtocol) {
        self.calorieBalanceService = calorieBalanceService
        setupObservers()
    }
    
    private func setupObservers() {
        calorieBalanceService.currentBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.currentBalance = balance
            }
            .store(in: &cancellables)
    }
}