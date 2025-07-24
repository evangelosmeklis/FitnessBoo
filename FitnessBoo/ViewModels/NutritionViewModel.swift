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
    
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentDate = Date()
    
    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol) {
        self.dataService = dataService
        self.calculationService = calculationService
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
    }
    
    // MARK: - Public Methods
    
    func loadDailyNutrition(for date: Date = Date()) async {
        print("📊 NutritionViewModel: Loading daily nutrition for date \(date)")
        isLoading = true
        errorMessage = nil
        currentDate = date
        
        do {
            // Try to load existing daily nutrition
            if let existingNutrition = try await dataService.fetchDailyNutrition(for: date) {
                print("📊 NutritionViewModel: Found existing daily nutrition with \(existingNutrition.entries.count) entries")
                dailyNutrition = existingNutrition
            } else {
                print("📊 NutritionViewModel: No existing daily nutrition, creating new one")
                // Create new daily nutrition with targets from user goals
                let targets = try await calculateDailyTargets()
                var newNutrition = DailyNutrition(
                    date: date,
                    calorieTarget: targets.calories,
                    proteinTarget: targets.protein
                )
                
                // Load any existing food entries for this date
                if let user = try await dataService.fetchUser() {
                    let existingEntries = try await dataService.fetchFoodEntries(for: date, user: user)
                    print("📊 NutritionViewModel: Found \(existingEntries.count) existing food entries")
                    for entry in existingEntries {
                        newNutrition.addEntry(entry)
                    }
                } else {
                    print("📊 NutritionViewModel: No user found when loading food entries")
                }
                
                dailyNutrition = newNutrition
                print("📊 NutritionViewModel: Final daily nutrition has \(newNutrition.entries.count) entries")
                
                // Save the daily nutrition if we have entries
                if !newNutrition.entries.isEmpty {
                    try await dataService.saveDailyNutrition(newNutrition)
                }
            }
            
            updateRealTimeCalculations()
            print("📊 NutritionViewModel: Final foodEntries count: \(foodEntries.count)")
        } catch {
            print("📊 NutritionViewModel: Error loading daily nutrition: \(error)")
            errorMessage = "Failed to load nutrition data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addFoodEntry(_ entry: FoodEntry) async {
        print("🍎 NutritionViewModel: Starting to add food entry with \(entry.calories) calories")
        do {
            // Validate the entry
            try entry.validate()
            print("🍎 NutritionViewModel: Entry validated successfully")
            
            // Save to data service first
            try await dataService.saveFoodEntry(entry)
            print("🍎 NutritionViewModel: Entry saved to data service")
            
            // Force reload the data to get the latest from database
            await loadDailyNutrition(for: currentDate)
            print("🍎 NutritionViewModel: Data reloaded, food entries count: \(foodEntries.count)")
            
            errorMessage = nil
        } catch {
            print("🍎 NutritionViewModel: Error adding food entry: \(error)")
            errorMessage = "Failed to add food entry: \(error.localizedDescription)"
        }
    }
    
    func updateFoodEntry(_ entry: FoodEntry) async {
        do {
            // Validate the entry
            try entry.validate()
            
            // Update in data service
            try await dataService.updateFoodEntry(entry)
            
            // Update daily nutrition
            if var nutrition = dailyNutrition {
                nutrition.updateEntry(entry)
                dailyNutrition = nutrition
                
                // Save updated daily nutrition
                try await dataService.saveDailyNutrition(nutrition)
            }
            
            // Refresh data to ensure consistency
            await refreshData()
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update food entry: \(error.localizedDescription)"
        }
    }
    
    func deleteFoodEntry(_ entry: FoodEntry) async {
        do {
            // Delete from data service
            try await dataService.deleteFoodEntry(entry)
            
            // Update daily nutrition
            if var nutrition = dailyNutrition {
                nutrition.removeEntry(withId: entry.id)
                dailyNutrition = nutrition
                
                // Save updated daily nutrition
                try await dataService.saveDailyNutrition(nutrition)
            }
            
            // Refresh data to ensure consistency
            await refreshData()
            
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
    }
    
    private func resetCalculations() {
        totalCalories = 0
        totalProtein = 0
        remainingCalories = 0
        remainingProtein = 0
        calorieProgress = 0
        proteinProgress = 0
    }
    
    private func calculateDailyTargets() async throws -> (calories: Double, protein: Double) {
        // Get user data
        guard let user = try await dataService.fetchUser() else {
            throw NutritionViewModelError.userNotFound
        }
        
        // Get active goal
        guard let goal = try await dataService.fetchActiveGoal() else {
            // Use default targets based on BMR if no goal is set
            let maintenanceCalories = calculationService.calculateMaintenanceCalories(
                bmr: user.bmr,
                activityLevel: user.activityLevel
            )
            let proteinTarget = calculationService.calculateProteinTarget(
                weight: user.weight,
                goalType: .maintainWeight
            )
            return (calories: maintenanceCalories, protein: proteinTarget)
        }
        
        return (calories: goal.dailyCalorieTarget, protein: goal.dailyProteinTarget)
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