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
                LazyVStack(spacing: 16) {
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
            .navigationTitle("Home")
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
            // Deep Premium Background
            Color(red: 0.02, green: 0.05, blue: 0.1) // Almost black blue
                .ignoresSafeArea()
            
            // Premium Gradient Overlays
            LinearGradient(
                colors: [
                    Color.premiumIndigo.opacity(0.15),
                    Color.clear,
                    Color.premiumTeal.opacity(0.1),
                    Color.clear,
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            // Add Food Button - Premium Indigo
            Button(action: { showingAddFood = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Add Food")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.premiumIndigo)
                        .shadow(color: Color.premiumIndigo.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Add Water Button - Premium Teal
            Button(action: { showingWaterOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Add Water")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.premiumTeal)
                        .shadow(color: Color.premiumTeal.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "CALORIES",
                value: "\(Int(dataManager.caloriesConsumed))",
                subtitle: "kcal", // Moved unit to subtitle
                icon: "bolt.fill",
                color: .premiumCoral,
                progress: dataManager.calorieProgress
            )
            
            MetricCard(
                title: "PROTEIN",
                value: "\(Int(dataManager.proteinConsumed))g",
                subtitle: "consumed",
                icon: "leaf.fill",
                color: .premiumMint,
                progress: dataManager.proteinProgress
            )
            
            MetricCard(
                title: "WATER",
                value: "\(Int(dataManager.waterConsumed))ml",
                subtitle: "hydrated",
                icon: "drop.fill",
                color: .premiumSky,
                progress: dataManager.waterProgress
            )
            
            MetricCard(
                title: "WEIGHT",
                value: "\(String(format: "%.1f", dataManager.currentUser?.weight ?? 0))",
                subtitle: weightUnit,
                icon: "scalemass.fill", // Changed icon
                color: Color.premiumIndigo,
                progress: nil
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
                    CompactStatCard(
                        title: "RESTING",
                        value: "\(Int(energyViewModel.restingEnergy))",
                        subtitle: "kcal",
                        icon: "moon.stars.fill",
                        color: .premiumSky
                    )

                    CompactStatCard(
                        title: "ACTIVE",
                        value: "\(Int(energyViewModel.activeEnergy))",
                        subtitle: "kcal",
                        icon: "figure.run",
                        color: .premiumMint
                    )

                    CompactStatCard(
                        title: "TOTAL",
                        value: "\(Int(energyViewModel.totalEnergyExpended))",
                        subtitle: "kcal",
                        icon: "flame.fill",
                        color: .premiumCoral
                    )

                    CompactStatCard(
                        title: "WORKOUTS",
                        value: "\(energyViewModel.workoutCount)",
                        subtitle: "today",
                        icon: "dumbbell.fill", // Changed icon
                        color: .premiumTeal
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
                PremiumCalorieBalanceCard(balance: balance)
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
                                    Color.premiumCoral :
                                    Color.premiumMint
                            )
                            .shadow(
                                color: balance.isPositiveBalance ? Color.premiumCoral.opacity(0.3) : Color.premiumMint.opacity(0.3),
                                radius: 8
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
                                .foregroundStyle(Color.premiumMint)
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
                                .foregroundStyle(Color.premiumCoral)
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
    func saveDietaryProtein(protein: Double, date: Date) async throws { }
    func saveDietaryCarbs(carbs: Double, date: Date) async throws { }
    func saveDietaryFats(fats: Double, date: Date) async throws { }
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

struct PremiumCalorieBalanceCard: View {
    let balance: CalorieBalance
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let primaryColor: Color = balance.isPositiveBalance ? 
            .premiumCoral : // Coral for surplus
            .premiumMint // Mint for deficit (good/maintain)
        
        GlassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text(balance.balanceDescription.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Spacer()
                }
                
                // Large balance number
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(balance.formattedBalance)
                        .font(.system(size: 52, weight: .medium, design: .rounded))
                        .foregroundStyle(primaryColor)
                        .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 0) // Soft sheen
                    
                    Text("kcal")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Breakdown row
                HStack(spacing: 0) {
                    // Consumed
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.premiumMint.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.caption2)
                                        .foregroundStyle(Color.premiumMint)
                                )
                            Text("IN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(balance.caloriesConsumed))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 40)
                    
                    // Burned
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.premiumCoral.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.premiumCoral)
                                )
                            Text("OUT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(balance.totalEnergyBurned))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                }
                
                // Data source
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Source: \(balance.energySourceDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
