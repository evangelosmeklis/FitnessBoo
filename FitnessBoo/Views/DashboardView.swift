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
    @StateObject private var nutritionViewModel: NutritionViewModel
    @State private var currentBalance: CalorieBalance?
    @State private var currentUnitSystem: UnitSystem = .metric
    @State private var showingAppInfo = false
    @State private var showingAddFood = false
    @State private var showingWaterOptions = false
    @State private var showingCustomWaterInput = false
    @State private var customWaterAmount = ""
    
    init(healthKitService: HealthKitServiceProtocol, dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self._energyViewModel = StateObject(wrappedValue: EnergyViewModel(
            healthKitService: healthKitService
        ))

        self._calorieBalanceService = StateObject(wrappedValue: CalorieBalanceService(
            healthKitService: healthKitService,
            calculationService: calculationService,
            dataService: dataService
        ))

        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Calorie Balance Section (at the top for prominence)
                    calorieBalanceSection

                    // Quick Actions
                    quickActionsSection

                    // Quick Stats Grid
                    quickStatsGrid

                    // Energy Balance Section
                    energyBalanceSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAppInfo = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                            Text("App Info")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
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
            .sheet(isPresented: $showingAppInfo) {
                AppInfoDetailView()
            }
            .sheet(isPresented: $showingAddFood) {
                FoodEntryView(nutritionViewModel: nutritionViewModel)
            }
            .sheet(isPresented: $showingWaterOptions) {
                WaterOptionsSheet(
                    onWaterAdded: { amount in
                        Task { await nutritionViewModel.addWater(milliliters: amount) }
                        showingWaterOptions = false
                    },
                    onCustomWater: {
                        showingCustomWaterInput = true
                    }
                )
                .presentationDetents([.medium])
            }
            .alert("Add Water", isPresented: $showingCustomWaterInput) {
                TextField("Amount (ml)", text: $customWaterAmount)
                    .keyboardType(.numberPad)
                Button("Add") {
                    if let amount = Double(customWaterAmount), amount > 0 {
                        Task { await nutritionViewModel.addWater(milliliters: amount) }
                    }
                    customWaterAmount = ""
                }
                Button("Cancel", role: .cancel) {
                    customWaterAmount = ""
                }
            } message: {
                Text("Enter the amount of water in milliliters")
            }
        }
    }
    
    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Pure black base
            Color.black
                .ignoresSafeArea()
            
            // Futuristic gradient overlays
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.05),
                    Color.clear,
                    Color.green.opacity(0.03),
                    Color.clear,
                    Color.blue.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle grid pattern effect (optional)
            Color.cyan.opacity(0.01)
                .ignoresSafeArea()
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            // Add Food Button - Futuristic Cyan/Blue
            Button(action: { showingAddFood = true }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.cyan.opacity(0.6), radius: 12, x: 0, y: 4)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("ADD FOOD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.cyan)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    ZStack {
                        // Dark base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.cyan.opacity(0.05))
                        
                        // Border glow
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .shadow(color: Color.cyan.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())

            // Add Water Button - Futuristic Green/Teal
            Button(action: { showingWaterOptions = true }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.green.opacity(0.6), radius: 12, x: 0, y: 4)
                        
                        Image(systemName: "drop.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("ADD WATER")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    ZStack {
                        // Dark base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.05))
                        
                        // Border glow
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.6), Color.cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .shadow(color: Color.green.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            FuturisticMetricCard(
                title: "CALORIES",
                value: "\(Int(dataManager.caloriesConsumed))",
                subtitle: {
                    if let balance = currentBalance {
                        let sign = balance.balance >= 0 ? "+" : ""
                        return "\(sign)\(Int(balance.balance)) kcal"
                    }
                    return "Loading..."
                }(),
                icon: "bolt.fill",
                color: .cyan,
                progress: dataManager.calorieProgress
            )
            
            FuturisticMetricCard(
                title: "PROTEIN",
                value: "\(Int(dataManager.proteinConsumed))g",
                subtitle: "\(Int(dataManager.proteinRemaining))g left",
                icon: "leaf.fill",
                color: .green,
                progress: dataManager.proteinProgress
            )
            
            FuturisticMetricCard(
                title: "WATER",
                value: "\(Int(dataManager.waterConsumed))ml",
                subtitle: "\(Int(dataManager.waterTarget - dataManager.waterConsumed))ml left",
                icon: "drop.fill",
                color: Color(red: 0.0, green: 0.8, blue: 0.8), // Teal
                progress: dataManager.waterProgress
            )
            
            FuturisticMetricCard(
                title: "WEIGHT",
                value: "\(String(format: "%.1f", dataManager.currentUser?.weight ?? 0))\(weightUnit)",
                subtitle: dataManager.currentGoal?.type.displayName ?? "No goal",
                icon: "chart.line.uptrend.xyaxis",
                color: Color(red: 0.5, green: 0.7, blue: 1.0) // Light blue
            )
        }
    }
    

    private var energyBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ENERGY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Text("Today's Breakdown")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }

            if energyViewModel.isLoading {
                GlassCard(cornerRadius: 20) {
                    HStack(spacing: 12) {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.9)
                            .tint(.cyan)
                        Text("Loading energy data...")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FuturisticEnergyCard(
                        title: "RESTING",
                        value: "\(Int(energyViewModel.restingEnergy))",
                        unit: "kcal",
                        color: Color(red: 0.4, green: 0.7, blue: 1.0), // Sky blue
                        icon: "moon.stars.fill"
                    )

                    FuturisticEnergyCard(
                        title: "ACTIVE",
                        value: "\(Int(energyViewModel.activeEnergy))",
                        unit: "kcal",
                        color: .green,
                        icon: "bolt.fill"
                    )

                    FuturisticEnergyCard(
                        title: "TOTAL",
                        value: "\(Int(energyViewModel.totalEnergyExpended))",
                        unit: "kcal",
                        color: .cyan,
                        icon: "flame.fill"
                    )

                    FuturisticEnergyCard(
                        title: "WORKOUTS",
                        value: "\(energyViewModel.workoutCount)",
                        unit: "today",
                        color: Color(red: 0.0, green: 0.9, blue: 0.7), // Turquoise
                        icon: "figure.run"
                    )
                }
            }
        }
    }
    
    private var calorieBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BALANCE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Text("Caloric Status")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }

            if let balance = currentBalance {
                FuturisticCalorieBalanceCard(balance: balance)
            } else {
                GlassCard(cornerRadius: 20) {
                    HStack(spacing: 12) {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.9)
                            .tint(.cyan)
                        Text("Calculating balance...")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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

struct EnhancedEnergyCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.15))
                            .frame(width: 40, height: 40)
                        
                        // Neon glow effect in dark mode
                        if colorScheme == .dark {
                            Circle()
                                .fill(color.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .blur(radius: 8)
                        }

                        Image(systemName: icon)
                            .foregroundStyle(color)
                            .font(.system(size: 18, weight: .bold))
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(color)

                        Text(unit)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct CalorieBalanceCard: View {
    let balance: CalorieBalance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 20) {
                // Main Balance Display
                VStack(spacing: 8) {
                    HStack {
                        Text(balance.balanceDescription.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(1.2)

                        Spacer()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(balance.formattedBalance)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                balance.isPositiveBalance ?
                                    (colorScheme == .dark ? Color.neonOrange : Color.orange) :
                                    (colorScheme == .dark ? Color.neonGreen : Color.green)
                            )
                            .neonGlow(
                                color: balance.isPositiveBalance ? .orange : .green,
                                radius: colorScheme == .dark ? 12 : 4
                            )

                        Text("kcal")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.1))

                // Breakdown
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(colorScheme == .dark ? Color.neonGreen : .green)
                                .font(.caption)
                            Text("CONSUMED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(balance.caloriesConsumed))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()
                        .frame(height: 40)
                        .overlay(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.circle.fill")
                                .foregroundStyle(colorScheme == .dark ? Color.neonOrange : .orange)
                                .font(.caption)
                            Text("BURNED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(balance.totalEnergyBurned))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()
                }

                // Data Source
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Text("Data from \(balance.energySourceDescription)")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
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
    func fetchDietaryEnergy(from startDate: Date, to endDate: Date) async throws -> Double { return 2000 }
    func fetchDietaryProtein(from startDate: Date, to endDate: Date) async throws -> Double { return 120 }
    func fetchDietaryWater(from startDate: Date, to endDate: Date) async throws -> Double { return 2500 }
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

struct AppInfoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    philosophySection
                    balanceExplanationSection
                    benefitsSection
                }
                .padding()
                .padding(.bottom, 50)
            }
            .background(backgroundGradient)
            .navigationTitle("App Philosophy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
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
    
    private var headerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    
                    Text("FitnessBoo Philosophy")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("Most fitness apps tell you to eat a specific number of calories per day. But FitnessBoo takes a different approach - we focus on your **calorie balance**.")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var philosophySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Calorie Balance Works")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                BalanceExplanationCard(
                    title: "Calorie Surplus",
                    description: "When you consume more calories than you burn, you're in a surplus. This leads to weight gain.",
                    icon: "plus.circle.fill",
                    color: .green
                )
                
                BalanceExplanationCard(
                    title: "Calorie Deficit",
                    description: "When you burn more calories than you consume, you're in a deficit. This leads to weight loss.",
                    icon: "minus.circle.fill",
                    color: .red
                )
                
                BalanceExplanationCard(
                    title: "Calorie Balance",
                    description: "When calories in equals calories out, you maintain your current weight.",
                    icon: "equal.circle.fill",
                    color: .blue
                )
            }
        }
    }
    
    private var balanceExplanationSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "equal.square.fill")
                        .foregroundStyle(.purple)
                        .font(.title2)
                    
                    Text("The Simple Formula")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 8) {
                    Text("Calories Consumed - Calories Burned = Balance")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    
                    Text("This simple equation tells you everything you need to know about your energy balance and how it affects your weight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why This Approach?")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                BenefitCard(
                    icon: "leaf.fill",
                    title: "More Flexible",
                    description: "No strict daily calorie limits - focus on overall balance"
                )
                
                BenefitCard(
                    icon: "brain.head.profile",
                    title: "Educational", 
                    description: "Learn how energy balance affects your body"
                )
                
                BenefitCard(
                    icon: "heart.fill",
                    title: "Sustainable",
                    description: "Focus on long-term patterns, not daily perfection"
                )
                
                BenefitCard(
                    icon: "eye.fill",
                    title: "Intuitive",
                    description: "See exactly how your eating and exercise affect your goals"
                )
            }
        }
    }
}

struct BalanceExplanationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(color)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Futuristic Card Components

struct FuturisticMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double?
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, value: String, subtitle: String, icon: String, color: Color, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }
    
    var body: some View {
        ZStack {
            // Outer glow
            RoundedRectangle(cornerRadius: 24)
                .fill(color.opacity(0.1))
                .blur(radius: 20)
            
            // Card base
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            VStack(alignment: .leading, spacing: 12) {
                // Icon and title
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        if colorScheme == .dark {
                            Circle()
                                .fill(color.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .blur(radius: 8)
                        }
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(color)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                // Progress bar if available
                if let progress = progress {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(color.opacity(0.15))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(color)
                                .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(16)
        }
        .frame(height: 160)
    }
}

struct FuturisticEnergyCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Outer glow
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.1))
                .blur(radius: 15)
            
            // Card base
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.6), color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        if colorScheme == .dark {
                            Circle()
                                .fill(color.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .blur(radius: 8)
                        }
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(color)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        
                        Text(unit)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 120)
    }
}

struct FuturisticCalorieBalanceCard: View {
    let balance: CalorieBalance
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let primaryColor: Color = balance.isPositiveBalance ? 
            Color(red: 1.0, green: 0.3, blue: 0.4) : // Tech red for surplus
            .cyan // Cyan for deficit
        
        ZStack {
            // Outer glow
            RoundedRectangle(cornerRadius: 24)
                .fill(primaryColor.opacity(0.15))
                .blur(radius: 25)
            
            // Card base
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.8), primaryColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text(balance.balanceDescription.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Spacer()
                }
                
                // Large balance number
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(balance.formattedBalance)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryColor)
                        .shadow(color: primaryColor.opacity(0.6), radius: 12, x: 0, y: 0)
                    
                    Text("kcal")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
                
                // Breakdown row
                HStack(spacing: 24) {
                    // Consumed
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("IN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(balance.caloriesConsumed))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 40)
                    
                    // Burned
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.circle.fill")
                                .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.4))
                                .font(.caption)
                            Text("OUT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(balance.totalEnergyBurned))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Data source
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Text("Data from \(balance.energySourceDescription)")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(20)
        }
    }
}

