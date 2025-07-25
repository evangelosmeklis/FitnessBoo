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
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var goalViewModel: GoalViewModel
    @StateObject private var energyViewModel: EnergyViewModel
    @StateObject private var calorieBalanceService: CalorieBalanceService
    
    private let healthKitService: HealthKitServiceProtocol
    
    init(healthKitService: HealthKitServiceProtocol, dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self.healthKitService = healthKitService
        
        self._userProfileViewModel = StateObject(wrappedValue: UserProfileViewModel(dataService: dataService))
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(dataService: dataService, calculationService: calculationService, healthKitService: healthKitService))
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(calculationService: calculationService, dataService: dataService, healthKitService: healthKitService))
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
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                userProfileViewModel.loadCurrentUser()
                await nutritionViewModel.loadTodaysNutrition()
                await goalViewModel.loadGoals()
                await energyViewModel.loadTodaysEnergy()
                calorieBalanceService.startRealTimeTracking()
            }
            .refreshable {
                do {
                    try await healthKitService.manualRefresh()
                    userProfileViewModel.loadCurrentUser()
                    await nutritionViewModel.loadTodaysNutrition()
                    await goalViewModel.loadGoals()
                    await energyViewModel.refreshEnergyData()
                } catch {
                    print("HealthKit refresh failed: \(error)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
                Task { await goalViewModel.loadGoals() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DayChanged"))) { _ in
                Task {
                    userProfileViewModel.loadCurrentUser()
                    await nutritionViewModel.loadTodaysNutrition()
                    await goalViewModel.loadGoals()
                    await energyViewModel.loadTodaysEnergy()
                }
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
    

    
    private var energyTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            if energyViewModel.isLoading {
                SwiftUI.ProgressView("Loading energy data...")
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
                    SwiftUI.ProgressView()
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