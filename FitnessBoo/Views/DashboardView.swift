//
//  DashboardView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI
import Foundation
import Combine
import HealthKit

struct DashboardView: View {
    @StateObject private var dataManager = AppDataManager.shared
    @StateObject private var energyViewModel: EnergyViewModel
    @StateObject private var calorieBalanceService: CalorieBalanceService
    @State private var currentBalance: CalorieBalance?
    @State private var currentUnitSystem: UnitSystem = .metric
    
    init(healthKitService: HealthKitServiceProtocol, dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self._energyViewModel = StateObject(wrappedValue: EnergyViewModel(
            healthKitService: healthKitService
        ))
        
        self._calorieBalanceService = StateObject(wrappedValue: CalorieBalanceService(
            healthKitService: healthKitService,
            calculationService: calculationService,
            dataService: dataService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Welcome Section
                    welcomeSection
                    
                    // Quick Stats Grid
                    quickStatsGrid
                    
                    // Energy Balance Section
                    energyBalanceSection
                    
                    // Calorie Balance Section
                    calorieBalanceSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
            .task {
                await loadData()
                loadUnitSystem()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnitSystemChanged"))) { notification in
                if let unitSystem = notification.object as? UnitSystem {
                    currentUnitSystem = unitSystem
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.8),
                Color.blue.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var welcomeSection: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if let user = dataManager.currentUser {
                        Text("Welcome back!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Let's crush your fitness goals today!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Welcome to FitnessBoo!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start your fitness journey today!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Calories",
                value: "\(Int(dataManager.caloriesConsumed))",
                subtitle: {
                    if let balance = currentBalance {
                        let sign = balance.balance >= 0 ? "+" : ""
                        let type = balance.balance >= 0 ? "surplus" : "deficit"
                        return "\(sign)\(Int(balance.balance)) kcal \(type)"
                    }
                    return "Loading..."
                }(),
                icon: "flame.fill",
                color: (currentBalance?.isPositiveBalance ?? false) ? .green : .red,
                progress: dataManager.calorieProgress
            )
            
            MetricCard(
                title: "Protein",
                value: "\(Int(dataManager.proteinConsumed))g",
                subtitle: "\(Int(dataManager.proteinRemaining))g remaining",
                icon: "leaf.fill",
                color: .green,
                progress: dataManager.proteinProgress
            )
            
            MetricCard(
                title: "Water",
                value: "\(Int(dataManager.waterConsumed))ml",
                subtitle: "\(Int(dataManager.waterTarget - dataManager.waterConsumed))ml remaining",
                icon: "drop.fill",
                color: .blue,
                progress: dataManager.waterProgress
            )
            
            MetricCard(
                title: "Weight",
                value: "\(String(format: "%.1f", dataManager.currentUser?.weight ?? 0))\(weightUnit)",
                subtitle: dataManager.currentGoal?.type.displayName ?? "No goal set",
                icon: "scalemass.fill",
                color: .purple
            )
        }
    }
    

    private var energyBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Energy Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            if energyViewModel.isLoading {
                GlassCard {
                    HStack {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading energy data...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    EnergyCard(
                        title: "Resting Energy",
                        value: "\(Int(energyViewModel.restingEnergy))",
                        unit: "kcal",
                        color: .blue,
                        icon: "bed.double.fill"
                    )
                    
                    EnergyCard(
                        title: "Active Energy",
                        value: "\(Int(energyViewModel.activeEnergy))",
                        unit: "kcal",
                        color: .green,
                        icon: "figure.run"
                    )
                    
                    EnergyCard(
                        title: "Total Burned",
                        value: "\(Int(energyViewModel.totalEnergyExpended))",
                        unit: "kcal",
                        color: .orange,
                        icon: "flame.fill"
                    )
                    
                    EnergyCard(
                        title: "Workouts",
                        value: "\(energyViewModel.workoutCount)",
                        unit: "today",
                        color: .purple,
                        icon: "dumbbell.fill"
                    )
                }
            }
        }
    }
    
    private var calorieBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Caloric Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let balance = currentBalance {
                CalorieBalanceCard(balance: balance)
            } else {
                GlassCard {
                    HStack {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.8)
                        Text("Calculating balance...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        async let dataManagerLoad = dataManager.loadInitialData()
        async let energyData = energyViewModel.refreshEnergyData()
        async let balanceData = loadCalorieBalance()
        
        await dataManagerLoad
        await energyData
        await balanceData
    }
    
    private func refreshData() async {
        await loadData()
    }
    
    private func loadCalorieBalance() async {
        currentBalance = await calorieBalanceService.getCurrentBalance()
    }
    
    private func loadUnitSystem() {
        if let savedUnit = UserDefaults.standard.string(forKey: "UnitSystem"),
           let unitSystem = UnitSystem(rawValue: savedUnit) {
            currentUnitSystem = unitSystem
        }
    }
    
    private var weightUnit: String {
        return currentUnitSystem == .metric ? "kg" : "lbs"
    }
    
}

// MARK: - Supporting Views

struct EnergyCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(color)
                        
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

struct CalorieBalanceCard: View {
    let balance: CalorieBalance
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(balance.balanceDescription)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(balance.isPositiveBalance ? .orange : .green)
                    
                    Spacer()
                    
                    Text(balance.formattedBalance)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(balance.isPositiveBalance ? .orange : .green)
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consumed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(balance.caloriesConsumed))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Burned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(balance.totalEnergyBurned))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                }
                
                Text("Data from \(balance.energySourceDescription)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}




#Preview {
    DashboardView(
        healthKitService: DashboardMockHealthKitService(),
        dataService: DashboardMockDataService(),
        calculationService: DashboardMockCalculationService()
    )
}

// MARK: - Mock Services for Preview

private class DashboardMockDataService: DataServiceProtocol {
    func saveUser(_ user: User) async throws { }
    func fetchUser() async throws -> User? { return nil }
    func createUserFromHealthKit(healthKitService: HealthKitServiceProtocol) async throws -> User {
        return User(weight: 70.0)
    }
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws { }
    func saveFoodEntry(_ entry: FoodEntry) async throws { }
    func updateFoodEntry(_ entry: FoodEntry) async throws { }
    func deleteFoodEntry(_ entry: FoodEntry) async throws { }
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] { return [] }
    func deleteFoodEntry(withId id: UUID) async throws { }
    func saveDailyNutrition(_ nutrition: DailyNutrition) async throws { }
    func fetchDailyNutrition(for date: Date) async throws -> DailyNutrition? { return nil }
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws { }
    func saveDailyStats(_ stats: DailyStats) async throws { }
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats] { return [] }
    func fetchDailyStats(for date: Date) async throws -> DailyStats? { return nil }
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws { }
    func updateGoal(_ goal: FitnessGoal) async throws { }
    func deleteGoal(_ goal: FitnessGoal) async throws { }
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal? { return nil }
    func fetchActiveGoal() async throws -> FitnessGoal? { return nil }
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal] { return [] }
    func resetAllData() async throws { }
}

private class DashboardMockCalculationService: CalculationServiceProtocol {
    func calculateBMR(age: Int, weight: Double, height: Double, gender: Gender) -> Double { return 1500 }
    func calculateDailyCalorieNeeds(bmr: Double, activityLevel: ActivityLevel) -> Double { return 2000 }
    func calculateMaintenanceCalories(bmr: Double, activityLevel: ActivityLevel) -> Double { return 2000 }
    func calculateCalorieTargetForGoal(dailyCalorieNeeds: Double, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double { return 1800 }
    func calculateCalorieTarget(bmr: Double, activityLevel: ActivityLevel, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double { return 1800 }
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double { return 100 }
    func calculateProteinGoal(for user: User?) -> Double { return 100 }
    func calculateCarbGoal(for user: User?) -> Double { return 200 }
    func calculateFatGoal(for user: User?) -> Double { return 65 }
    func calculateWeightLossCalories(maintenanceCalories: Double, weeklyWeightLoss: Double) -> Double { return 1500 }
    func calculateWeightGainCalories(maintenanceCalories: Double, weeklyWeightGain: Double) -> Double { return 2200 }
    func validateUserData(age: Int, weight: Double, height: Double) throws { }
}

private class DashboardMockHealthKitService: HealthKitServiceProtocol {
    var isHealthKitAvailable: Bool = true
    var authorizationStatus: HKAuthorizationStatus = .sharingAuthorized
    var lastSyncDate: Date? = Date()
    var syncStatus: AnyPublisher<SyncStatus, Never> {
        return Just(SyncStatus.success(Date())).eraseToAnyPublisher()
    }
    
    func requestAuthorization() async throws { }
    func saveDietaryEnergy(calories: Double, date: Date) async throws { }
    func saveWater(milliliters: Double, date: Date) async throws { }
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] { return [] }
    func fetchActiveEnergy(for date: Date) async throws -> Double { return 400 }
    func fetchRestingEnergy(for date: Date) async throws -> Double { return 1600 }
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double { return 2000 }
    func fetchWeight() async throws -> Double? { return 70.0 }
    func saveWeight(_ weight: Double, date: Date) async throws { }
    func observeWeightChanges() -> AnyPublisher<Double, Never> {
        return Just(70.0).eraseToAnyPublisher()
    }
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never> {
        return Just([]).eraseToAnyPublisher()
    }
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never> {
        return Just((resting: 1600.0, active: 400.0)).eraseToAnyPublisher()
    }
    func manualRefresh() async throws { }
    func startBackgroundSync() { }
    func stopBackgroundSync() { }
}

