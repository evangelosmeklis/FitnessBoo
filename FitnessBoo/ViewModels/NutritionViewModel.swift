//
//  NutritionViewModel.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import Combine

@MainActor
class NutritionViewModel: ObservableObject {
    @Published var dailyNutrition: DailyNutrition?
    @Published var todaysNutrition: DailyNutrition?
    @Published var foodEntries: [FoodEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddFood = false
    
    // Real-time calculations
    @Published var totalCalories: Double = 0
    @Published var totalProtein: Double = 0
    @Published var remainingCalories: Double = 0
    @Published var remainingProtein: Double = 0
    @Published var calorieProgress: Double = 0
    @Published var proteinProgress: Double = 0
    @Published var totalWater: Double = 0
    @Published var waterProgress: Double = 0
    @Published var dailyWaterTarget: Double = 2000
    @Published var goalBasedDeficitSurplus: Double = 0
    
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentDate = Date()
    
    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.dataService = dataService
        self.calculationService = calculationService
        self.healthKitService = healthKitService
        setupObservers()
    }
    
    private func setupObservers() {
        // Update calculations when food entries change
        $foodEntries
            .sink { [weak self] entries in
                self?.updateRealTimeCalculations()
            }
            .store(in: &cancellables)
        
        // Update daily nutrition when it changes
        $dailyNutrition
            .sink { [weak self] nutrition in
                if let nutrition = nutrition {
                    self?.foodEntries = nutrition.entries
                } else {
                    self?.foodEntries = []
                }
            }
            .store(in: &cancellables)
        
        // Listen for weight and goal updates to recalculate targets
        NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshTargetsAndNutrition()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshTargetsAndNutrition()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    private func refreshTargetsAndNutrition() async {
        // Reload daily nutrition with updated targets
        await loadDailyNutrition(for: currentDate)
    }
    
    func loadDailyNutrition(for date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        currentDate = date
        
        do {
            // Always get the latest targets from goals
            let targets = try await calculateDailyTargets()
            dailyWaterTarget = targets.water
            
            // Try to load existing daily nutrition
            if let existingNutrition = try await dataService.fetchDailyNutrition(for: date) {
                // Update the targets to match current goals
                var updatedNutrition = existingNutrition
                updatedNutrition.calorieTarget = targets.calories
                updatedNutrition.proteinTarget = targets.protein
                dailyNutrition = updatedNutrition
                
                // Save the updated targets
                try await dataService.saveDailyNutrition(updatedNutrition)
            } else {
                // Create new daily nutrition with targets from user goals
                var newNutrition = DailyNutrition(
                    date: date,
                    calorieTarget: targets.calories,
                    proteinTarget: targets.protein
                )
                
                // Load any existing food entries for this date
                if let user = try await dataService.fetchUser() {
                    let existingEntries = try await dataService.fetchFoodEntries(for: date, user: user)
                    for entry in existingEntries {
                        newNutrition.addEntry(entry)
                    }
                }
                
                dailyNutrition = newNutrition
                
                // Save the daily nutrition if we have entries
                if !newNutrition.entries.isEmpty {
                    try await dataService.saveDailyNutrition(newNutrition)
                }
            }
            
            updateRealTimeCalculations()
        } catch {
            errorMessage = "Failed to load nutrition data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addFoodEntry(_ entry: FoodEntry) async {
        do {
            try entry.validate()
            
            // Save the food entry to the database
            try await dataService.saveFoodEntry(entry)
            
            // Update the local daily nutrition object
            if var currentNutrition = dailyNutrition {
                currentNutrition.addEntry(entry)
                try await dataService.saveDailyNutrition(currentNutrition)
                self.dailyNutrition = currentNutrition
            } else {
                // If no daily nutrition exists, fetch it (which will create it)
                await loadDailyNutrition(for: currentDate)
            }
            
            // Save to HealthKit
            try await healthKitService.saveDietaryEnergy(calories: entry.calories, date: entry.timestamp)
            
            // Post notification for calorie balance update
            NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
            NotificationCenter.default.post(name: .nutritionDataUpdated, object: nil)
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to add food entry: \(error.localizedDescription)"
        }
    }
    
    func addWater(milliliters: Double) async {
        do {
            // Ensure we have daily nutrition loaded
            if dailyNutrition == nil {
                await loadDailyNutrition(for: Date())
            }
            
            if var currentNutrition = dailyNutrition {
                currentNutrition.waterConsumed += milliliters
                try await dataService.saveDailyNutrition(currentNutrition)
                self.dailyNutrition = currentNutrition
                
                // Save to HealthKit
                try await healthKitService.saveWater(milliliters: milliliters, date: Date())
                
                // Update UI calculations
                updateRealTimeCalculations()
                
                print("Water added successfully: \(milliliters)ml, total: \(currentNutrition.waterConsumed)ml")
            } else {
                throw NSError(domain: "NutritionViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create or load daily nutrition"])
            }
            
            errorMessage = nil
        } catch {
            print("Failed to add water: \(error.localizedDescription)")
            errorMessage = "Failed to add water: \(error.localizedDescription)"
        }
    }
    
    func updateFoodEntry(_ entry: FoodEntry) async {
        do {
            try entry.validate()
            
            // Update the food entry in the database
            try await dataService.updateFoodEntry(entry)
            
            // Update the local daily nutrition object
            if var currentNutrition = dailyNutrition {
                currentNutrition.updateEntry(entry)
                try await dataService.saveDailyNutrition(currentNutrition)
                self.dailyNutrition = currentNutrition
            }
            
            // Post notification for calorie balance update
            NotificationCenter.default.post(name: NSNotification.Name("FoodEntryUpdated"), object: nil)
            NotificationCenter.default.post(name: .nutritionDataUpdated, object: nil)
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update food entry: \(error.localizedDescription)"
        }
    }
    
    func deleteFoodEntry(_ entry: FoodEntry) async {
        do {
            // Delete the food entry from the database
            try await dataService.deleteFoodEntry(entry)
            
            // Update the local daily nutrition object
            if var currentNutrition = dailyNutrition {
                currentNutrition.removeEntry(withId: entry.id)
                try await dataService.saveDailyNutrition(currentNutrition)
                self.dailyNutrition = currentNutrition
            }
            
            // Post notification for calorie balance update
            NotificationCenter.default.post(name: NSNotification.Name("FoodEntryDeleted"), object: nil)
            NotificationCenter.default.post(name: .nutritionDataUpdated, object: nil)
            
            // Force immediate UI update
            updateRealTimeCalculations()
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete food entry: \(error.localizedDescription)"
        }
    }
    
    func refreshData() async {
        await loadDailyNutrition(for: currentDate)
    }
    
    func loadTodaysNutrition() {
        Task {
            await loadDailyNutrition(for: Date())
            todaysNutrition = dailyNutrition
        }
    }
    
    // MARK: - Private Methods
    
    private func updateRealTimeCalculations() {
        guard let nutrition = dailyNutrition else {
            resetCalculations()
            return
        }
        
        totalCalories = nutrition.totalCalories
        totalProtein = nutrition.totalProtein
        remainingCalories = nutrition.remainingCalories
        remainingProtein = nutrition.remainingProtein
        calorieProgress = nutrition.calorieProgress
        proteinProgress = nutrition.proteinProgress
        totalWater = nutrition.waterConsumed
        waterProgress = dailyWaterTarget > 0 ? min(totalWater / dailyWaterTarget, 1.0) : 0
        
        // Update goal-based deficit/surplus
        Task {
            await updateGoalBasedDeficitSurplus()
        }
    }
    
    private func resetCalculations() {
        totalCalories = 0
        totalProtein = 0
        remainingCalories = 0
        remainingProtein = 0
        calorieProgress = 0
        proteinProgress = 0
        totalWater = 0
        waterProgress = 0
        goalBasedDeficitSurplus = 0
    }
    
    private func calculateDailyTargets() async throws -> (calories: Double, protein: Double, water: Double) {
        // Get active goal
        guard let goal = try await dataService.fetchActiveGoal() else {
            print("No active goal found, using HealthKit data")
            // Use HealthKit energy data if no goal is set
            let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
            let currentWeight = try await healthKitService.fetchWeight() ?? 70.0 // Default fallback
            let proteinTarget = currentWeight * 1.2 // Basic maintenance protein
            print("Using HealthKit energy: \(totalEnergy), protein: \(proteinTarget)")
            return (calories: totalEnergy > 0 ? totalEnergy : 2000, protein: proteinTarget, water: 2000)
        }
        
        print("Using goal-based targets: calories=\(goal.dailyCalorieTarget), protein=\(goal.dailyProteinTarget), water=\(goal.dailyWaterTarget)")
        return (calories: goal.dailyCalorieTarget, protein: goal.dailyProteinTarget, water: goal.dailyWaterTarget)
    }
    
    private func updateGoalBasedDeficitSurplus() async {
        guard let nutrition = dailyNutrition else { 
            goalBasedDeficitSurplus = 0
            return 
        }
        
        do {
            if let goal = try await dataService.fetchActiveGoal() {
                // Calculate the goal's daily calorie adjustment (e.g., -307)
                let goalAdjustment = goal.weeklyWeightChangeGoal * 7700 / 7
                
                // The target with goal adjustment
                let targetWithGoal = nutrition.calorieTarget + goalAdjustment
                
                // Compare actual consumption vs target with goal adjustment
                goalBasedDeficitSurplus = nutrition.totalCalories - targetWithGoal
            } else {
                // Fallback to basic deficit/surplus if no goal
                goalBasedDeficitSurplus = caloricDeficitSurplus
            }
        } catch {
            print("Error calculating goal-based deficit: \(error)")
            goalBasedDeficitSurplus = caloricDeficitSurplus
        }
    }
    
    var caloricDeficitSurplus: Double {
        guard let nutrition = dailyNutrition else { return 0 }
        return nutrition.totalCalories - nutrition.calorieTarget
    }
    
    var isDeficit: Bool {
        goalBasedDeficitSurplus < 0
    }
    
    var deficitSurplusText: String {
        let value = abs(goalBasedDeficitSurplus)
        let type = isDeficit ? "Deficit" : "Surplus"
        return "\(Int(value)) cal \(type.lowercased())"
    }
}

// MARK: - Convenience Methods

extension NutritionViewModel {
    var isCalorieTargetMet: Bool {
        dailyNutrition?.isCalorieTargetMet ?? false
    }
    
    var isProteinTargetMet: Bool {
        dailyNutrition?.isProteinTargetMet ?? false
    }
    
    var entriesByMealType: [MealType: [FoodEntry]] {
        dailyNutrition?.entriesByMealType ?? [:]
    }
    
    func caloriesByMealType() -> [MealType: Double] {
        dailyNutrition?.caloriesByMealType() ?? [:]
    }
    
    func proteinByMealType() -> [MealType: Double] {
        dailyNutrition?.proteinByMealType() ?? [:]
    }
    
    var dailySummary: DailyNutritionSummary? {
        dailyNutrition?.summary
    }
}

enum NutritionViewModelError: LocalizedError {
    case userNotFound
    case invalidTargets
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User profile not found. Please complete onboarding first."
        case .invalidTargets:
            return "Invalid nutrition targets. Please check your goals."
        case .dataCorruption:
            return "Nutrition data is corrupted. Please restart the app."
        }
    }
}