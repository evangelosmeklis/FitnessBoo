//
//  GoalViewModel.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import Combine

@MainActor
class GoalViewModel: ObservableObject {
    @Published var selectedGoalType: GoalType = .loseWeight
    @Published var currentWeight: String = ""
    @Published var targetWeight: String = ""
    @Published var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @Published var weeklyWeightChangeGoal: Double = -0.5
    @Published var dailyWaterTarget: String = "2000"
    @Published var dailyProteinTarget: String = ""
    @Published var dailyCarbsTarget: String = ""
    @Published var dailyFatsTarget: String = ""
    @Published var currentGoal: FitnessGoal?
    @Published var activeGoals: [FitnessGoal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // Calculated values
    @Published var estimatedDailyCalories: Double = 0
    @Published var estimatedDailyProtein: Double = 0
    @Published var estimatedTimeToGoal: String = ""
    
    // Computed properties for automatic calculations
    var calculatedGoalType: GoalType {
        guard let targetWeightValue = Double(targetWeight),
              let currentWeightValue = Double(currentWeight) else {
            return .maintainWeight
        }
        
        let weightDifference = targetWeightValue - currentWeightValue
        
        // Only consider differences of 0.5kg or less as "maintain weight"
        if abs(weightDifference) <= 0.5 { // Within 0.5kg = maintain
            return .maintainWeight
        } else if weightDifference < 0 { // Target is less than current = lose
            return .loseWeight
        } else { // Target is more than current = gain
            return .gainWeight
        }
    }
    
    var calculatedWeeklyChange: Double {
        guard let targetWeightValue = Double(targetWeight),
              let currentWeightValue = Double(currentWeight),
              calculatedGoalType != .maintainWeight else {
            return 0
        }
        
        let weightDifference = targetWeightValue - currentWeightValue
        let weeksToTarget = targetDate.timeIntervalSince(Date()) / (7 * 24 * 60 * 60)
        
        guard weeksToTarget > 0 else { return 0 }
        
        return weightDifference / weeksToTarget
    }
    
    var calculatedDailyCalorieAdjustment: Double {
        let weeklyChange = calculatedWeeklyChange
        // 1 kg = ~7700 calories
        return (weeklyChange * 7700) / 7
    }
    
    private let calculationService: CalculationServiceProtocol
    private let dataService: DataServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(calculationService: CalculationServiceProtocol, dataService: DataServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.calculationService = calculationService
        self.dataService = dataService
        self.healthKitService = healthKitService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Auto-update goal type when weights change
        Publishers.CombineLatest($currentWeight, $targetWeight)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] currentWeight, targetWeight in
                guard let self = self else { return }
                
                // Auto-calculate goal type if both weights are provided
                if !currentWeight.isEmpty && !targetWeight.isEmpty {
                    let autoGoalType = self.calculatedGoalType
                    if self.selectedGoalType != autoGoalType {
                        self.selectedGoalType = autoGoalType
                        self.weeklyWeightChangeGoal = self.calculatedWeeklyChange
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update calculations when goal parameters change (with shorter debounce for better responsiveness)
        Publishers.CombineLatest4($selectedGoalType, $currentWeight, $targetWeight, $weeklyWeightChangeGoal)
            .combineLatest($targetDate)
            .combineLatest($dailyWaterTarget)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // Only update calculations if we have meaningful data
                guard let self = self else { return }
                
                // Skip calculations for maintain weight or empty target weight for other goals
                if self.selectedGoalType == .maintainWeight ||
                   (self.selectedGoalType != .maintainWeight && self.targetWeight.isEmpty) {
                    return
                }
                
                Task { @MainActor in
                    await self.updateCalculations()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Goal Creation and Updates
    
    func createGoal(for user: User) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let targetWeightValue = targetWeight.isEmpty ? nil : Double(targetWeight)
            
            var goal = FitnessGoal(
                type: calculatedGoalType,
                targetWeight: targetWeightValue,
                targetDate: targetDate,
                weeklyWeightChangeGoal: calculatedWeeklyChange,
                dailyWaterTarget: Double(dailyWaterTarget) ?? 2000
            )
            
            // Validate the goal
            try goal.validate()
            
            // Get current weight and energy data from HealthKit
            let currentWeightValue = Double(currentWeight) ?? user.weight
            let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
            
            // Update user's weight if it has changed
            var updatedUser = user
            if let newWeight = Double(currentWeight), newWeight != user.weight {
                updatedUser.weight = newWeight
                updatedUser.updatedAt = Date()
                try await dataService.saveUser(updatedUser)
                
                // Update cached user
                cachedUser = updatedUser
            }
            
            // Save weight to Apple Health if it changed
            if let newWeight = Double(currentWeight), newWeight != user.weight {
                do {
                    print("🔄 Attempting to save weight \(newWeight)kg to Apple Health during goal creation...")
                    try await healthKitService.saveWeight(newWeight, date: Date())
                    print("🍎 Weight saved to Apple Health during goal creation successfully: \(newWeight)kg")
                } catch {
                    print("⚠️ Failed to save weight to Apple Health during goal creation: \(error)")
                    if let healthKitError = error as? HealthKitError {
                        print("⚠️ HealthKit Error Details: \(healthKitError.localizedDescription)")
                        if let recovery = healthKitError.recoverySuggestion {
                            print("💡 Recovery suggestion: \(recovery)")
                        }
                    }
                    // Don't fail the entire operation if HealthKit save fails
                }
            }
            
            // Calculate daily targets using HealthKit data
            goal.calculateDailyTargets(totalEnergyExpended: totalEnergy, currentWeight: currentWeightValue)
            
            // Save the goal
            try await dataService.saveGoal(goal, for: updatedUser)
            
            currentGoal = goal
            
            // Notify all tabs that goal data has changed
            NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
            
        } catch let error as GoalValidationError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    func updateGoal(for user: User) async {
        guard var goal = currentGoal else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let targetWeightValue = targetWeight.isEmpty ? nil : Double(targetWeight)
            
            goal.type = calculatedGoalType
            goal.targetWeight = targetWeightValue
            goal.targetDate = targetDate
            goal.weeklyWeightChangeGoal = calculatedWeeklyChange
            goal.dailyWaterTarget = Double(dailyWaterTarget) ?? 2000
            goal.updatedAt = Date()
            
            // Validate the updated goal
            try goal.validate()
            
            // Get current weight and energy data from HealthKit
            let currentWeightValue = Double(currentWeight) ?? user.weight
            let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
            
            // Update user's weight if it has changed
            var updatedUser = user
            if let newWeight = Double(currentWeight), newWeight != user.weight {
                updatedUser.weight = newWeight
                updatedUser.updatedAt = Date()
                try await dataService.saveUser(updatedUser)
                
                // Update cached user
                cachedUser = updatedUser
            }
            
            // Save weight to Apple Health if it changed
            if let newWeight = Double(currentWeight), newWeight != user.weight {
                do {
                    print("🔄 Attempting to save weight \(newWeight)kg to Apple Health during goal update...")
                    try await healthKitService.saveWeight(newWeight, date: Date())
                    print("🍎 Weight saved to Apple Health during goal update successfully: \(newWeight)kg")
                } catch {
                    print("⚠️ Failed to save weight to Apple Health during goal update: \(error)")
                    if let healthKitError = error as? HealthKitError {
                        print("⚠️ HealthKit Error Details: \(healthKitError.localizedDescription)")
                        if let recovery = healthKitError.recoverySuggestion {
                            print("💡 Recovery suggestion: \(recovery)")
                        }
                    }
                    // Don't fail the entire operation if HealthKit save fails
                }
            }
            
            // Recalculate daily targets using HealthKit data
            goal.calculateDailyTargets(totalEnergyExpended: totalEnergy, currentWeight: currentWeightValue)
            
            // Save the updated goal
            try await dataService.saveGoal(goal, for: updatedUser)
            
            currentGoal = goal
            
            // Notify all tabs that goal data has changed
            NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
            
        } catch let error as GoalValidationError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Failed to update goal: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    func loadCurrentGoal(for user: User) async {
        isLoading = true
        
        // Cache the user for calculations
        cachedUser = user
        currentWeight = String(format: "%.1f", user.weight)
        
        do {
            currentGoal = try await dataService.fetchActiveGoal(for: user)
            
            if let goal = currentGoal {
                selectedGoalType = goal.type
                targetWeight = goal.targetWeight != nil ? String(format: "%.1f", goal.targetWeight!) : ""
                targetDate = goal.targetDate ?? targetDate
                weeklyWeightChangeGoal = goal.weeklyWeightChangeGoal
                dailyWaterTarget = String(goal.dailyWaterTarget)
                
                // Initialize macro targets with unit conversion
                let currentUnitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "UnitSystem") ?? "metric") ?? .metric
                let displayProtein = currentUnitSystem == .metric ? goal.dailyProteinTarget : goal.dailyProteinTarget / 28.35
                dailyProteinTarget = String(format: "%.0f", displayProtein)

                let displayCarbs = currentUnitSystem == .metric ? goal.dailyCarbsTarget : goal.dailyCarbsTarget / 28.35
                dailyCarbsTarget = String(format: "%.0f", displayCarbs)

                let displayFats = currentUnitSystem == .metric ? goal.dailyFatsTarget : goal.dailyFatsTarget / 28.35
                dailyFatsTarget = String(format: "%.0f", displayFats)
            }
            
        } catch {
            errorMessage = "Failed to load current goal: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    func updateCurrentWeight(_ newWeightString: String) async {
        print("🔄 Attempting to update weight to: \(newWeightString)")
        
        let user: User
        if let cachedUser = cachedUser {
            user = cachedUser
        } else {
            do {
                guard let fetchedUser = try await dataService.fetchUser() else {
                    print("❌ No user found for weight update")
                    return
                }
                user = fetchedUser
            } catch {
                print("❌ Failed to fetch user: \(error)")
                return
            }
        }
        
        guard let newWeight = Double(newWeightString) else {
            print("❌ Invalid weight string: \(newWeightString)")
            return
        }
        
        print("✅ Parsed weight: \(newWeight)")
        
        guard newWeight != user.weight else {
            print("ℹ️ Weight unchanged: \(newWeight)")
            return
        }
        
        print("💾 Saving weight change: \(user.weight) -> \(newWeight)")
        
        do {
            var updatedUser = user
            updatedUser.weight = newWeight
            updatedUser.updatedAt = Date()
            
            try updatedUser.validate()
            try await dataService.saveUser(updatedUser)
            cachedUser = updatedUser
            
            print("✅ Weight updated successfully to \(newWeight)")
            
            // Save weight to Apple Health
            do {
                print("🔄 Attempting to save weight \(newWeight)kg to Apple Health...")
                try await healthKitService.saveWeight(newWeight, date: Date())
                print("🍎 Weight saved to Apple Health successfully: \(newWeight)kg")
            } catch {
                print("⚠️ Failed to save weight to Apple Health: \(error)")
                if let healthKitError = error as? HealthKitError {
                    print("⚠️ HealthKit Error Details: \(healthKitError.localizedDescription)")
                    if let recovery = healthKitError.recoverySuggestion {
                        print("💡 Recovery suggestion: \(recovery)")
                    }
                }
                // Don't fail the entire operation if HealthKit save fails
            }
            
            // Recalculate current goal with new weight
            if var goal = currentGoal {
                let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
                goal.calculateDailyTargets(totalEnergyExpended: totalEnergy, currentWeight: newWeight)
                
                // Save the updated goal
                try await dataService.saveGoal(goal, for: updatedUser)
                currentGoal = goal
                
                print("🎯 Goal recalculated with new weight - Daily calories: \(goal.dailyCalorieTarget), Daily protein: \(goal.dailyProteinTarget)")
            }
            
            // Notify other components that weight has been updated
            NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
            
        } catch {
            print("❌ Failed to update weight: \(error)")
            errorMessage = "Failed to update weight: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func updateProteinTarget(_ proteinInGrams: Double) async {
        print("🥩 Updating protein target to: \(proteinInGrams)g")

        // Update the display value based on current unit system
        let dataService = DataService.shared
        if let user = try? await dataService.fetchUser() {
            let currentUnitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "UnitSystem") ?? "metric") ?? .metric
            let displayValue = currentUnitSystem == .metric ? proteinInGrams : proteinInGrams / 28.35
            dailyProteinTarget = String(format: "%.0f", displayValue)
        }

        // Update current goal if it exists
        if var goal = currentGoal {
            goal.dailyProteinTarget = proteinInGrams

            do {
                let user = try await dataService.fetchUser()
                if let user = user {
                    try await dataService.saveGoal(goal, for: user)
                    currentGoal = goal
                    print("✅ Protein target updated successfully")

                    // Notify other components
                    NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
                }
            } catch {
                print("❌ Failed to update protein target: \(error)")
                errorMessage = "Failed to update protein target: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    func updateCarbsTarget(_ carbsInGrams: Double) async {
        print("🥕 Updating carbs target to: \(carbsInGrams)g")

        // Update the display value based on current unit system
        let dataService = DataService.shared
        if let user = try? await dataService.fetchUser() {
            let currentUnitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "UnitSystem") ?? "metric") ?? .metric
            let displayValue = currentUnitSystem == .metric ? carbsInGrams : carbsInGrams / 28.35
            dailyCarbsTarget = String(format: "%.0f", displayValue)
        }

        // Update current goal if it exists
        if var goal = currentGoal {
            goal.dailyCarbsTarget = carbsInGrams

            do {
                let user = try await dataService.fetchUser()
                if let user = user {
                    try await dataService.saveGoal(goal, for: user)
                    currentGoal = goal
                    print("✅ Carbs target updated successfully")

                    // Notify other components
                    NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
                }
            } catch {
                print("❌ Failed to update carbs target: \(error)")
                errorMessage = "Failed to update carbs target: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    func updateFatsTarget(_ fatsInGrams: Double) async {
        print("🥑 Updating fats target to: \(fatsInGrams)g")

        // Update the display value based on current unit system
        let dataService = DataService.shared
        if let user = try? await dataService.fetchUser() {
            let currentUnitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "UnitSystem") ?? "metric") ?? .metric
            let displayValue = currentUnitSystem == .metric ? fatsInGrams : fatsInGrams / 28.35
            dailyFatsTarget = String(format: "%.0f", displayValue)
        }

        // Update current goal if it exists
        if var goal = currentGoal {
            goal.dailyFatsTarget = fatsInGrams

            do {
                let user = try await dataService.fetchUser()
                if let user = user {
                    try await dataService.saveGoal(goal, for: user)
                    currentGoal = goal
                    print("✅ Fats target updated successfully")

                    // Notify other components
                    NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
                }
            } catch {
                print("❌ Failed to update fats target: \(error)")
                errorMessage = "Failed to update fats target: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    // MARK: - Calculations and Validation
    
    private var cachedUser: User?
    

    
    private func updateCalculations() async {
        do {
            // Use cached user if available, otherwise fetch
            let user: User
            if let cachedUser = cachedUser {
                user = cachedUser
            } else {
                guard let fetchedUser = try await dataService.fetchUser() else { return }
                cachedUser = fetchedUser
                user = fetchedUser
            }
            
            // Skip calculations for maintain weight
            if selectedGoalType == .maintainWeight {
                estimatedDailyCalories = 0
                estimatedDailyProtein = 0
                estimatedTimeToGoal = "N/A"
                return
            }
            
            // Create a temporary goal for calculations
            let targetWeightValue = targetWeight.isEmpty ? nil : Double(targetWeight)
            var tempGoal = FitnessGoal(
                type: selectedGoalType,
                targetWeight: targetWeightValue,
                targetDate: targetDate,
                weeklyWeightChangeGoal: weeklyWeightChangeGoal,
                dailyWaterTarget: Double(dailyWaterTarget) ?? 2000
            )
            
            // Get current weight and energy data from HealthKit
            let currentWeightValue = Double(currentWeight) ?? user.weight
            let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
            
            // Calculate targets using HealthKit data
            tempGoal.calculateDailyTargets(totalEnergyExpended: totalEnergy, currentWeight: currentWeightValue)
            
            estimatedDailyCalories = tempGoal.dailyCalorieTarget
            estimatedDailyProtein = tempGoal.dailyProteinTarget
            
            // Calculate estimated time to goal
            if let timeInterval = tempGoal.estimatedTimeToGoal(currentWeight: user.weight) {
                let days = Int(timeInterval / (24 * 60 * 60))
                estimatedTimeToGoal = "\(days) days"
            } else {
                estimatedTimeToGoal = "N/A"
            }
            
        } catch {
            // Silently handle calculation errors
            print("Calculation error: \(error)")
        }
    }
    

    
    // MARK: - Helper Methods
    
    func resetToDefaults() {
        selectedGoalType = .loseWeight
        targetWeight = ""
        targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        weeklyWeightChangeGoal = -0.5
        dailyWaterTarget = "2000"
        errorMessage = nil
        showingError = false
        cachedUser = nil // Clear cache
    }
    
    func getRecommendedWeightChangeRange() -> ClosedRange<Double> {
        return selectedGoalType.recommendedWeightChangeRange
    }
    
    func loadGoals() async {
        do {
            guard let user = try await dataService.fetchUser() else { return }
            let goals = try await dataService.fetchAllGoals(for: user)
            activeGoals = goals.filter { $0.isActive }
            currentGoal = activeGoals.first
        } catch {
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Validation Methods
    
    func validateCurrentGoal() -> Bool {
        // For maintain weight, no target weight needed
        if selectedGoalType == .maintainWeight {
            return true
        }
        
        // For other goals, target weight is required
        guard !targetWeight.isEmpty,
              let targetWeightValue = Double(targetWeight),
              targetWeightValue > 0 else {
            return false
        }
        
        return true
    }
    
    func validateTargetWeight(currentWeight: Double) -> (isValid: Bool, errorMessage: String?) {
        // For maintain weight, no validation needed
        if selectedGoalType == .maintainWeight {
            return (true, nil)
        }
        
        guard !targetWeight.isEmpty else {
            return (false, "Target weight is required")
        }
        
        guard let targetWeightValue = Double(targetWeight) else {
            return (false, "Please enter a valid weight")
        }
        
        guard targetWeightValue > 0 else {
            return (false, "Target weight must be greater than 0")
        }
        
        // Validate logical constraints
        let currentWeightValue = Double(self.currentWeight) ?? currentWeight
        switch selectedGoalType {
        case .loseWeight:
            if targetWeightValue >= currentWeightValue {
                return (false, "Target weight must be lower than current weight (\(String(format: "%.1f", currentWeightValue)) kg) for weight loss")
            }
        case .gainWeight:
            if targetWeightValue <= currentWeightValue {
                return (false, "Target weight must be higher than current weight (\(String(format: "%.1f", currentWeightValue)) kg) for weight gain")
            }
        case .maintainWeight:
            break // Already handled above
        }
        
        // Enhanced health-based validation
        let weightDifference = abs(targetWeightValue - currentWeightValue)
        
        // Check for extremely low target weights (potential eating disorder concerns)
        if targetWeightValue < 40 {
            return (false, "Target weight is too low. Please consult with a healthcare professional for safe weight goals.")
        }
        
        // Check for extremely high target weights
        if targetWeightValue > 200 {
            return (false, "Target weight seems unrealistic. Please choose a more moderate target weight.")
        }
        
        // Check for unrealistic weight change (more than 50kg difference)
        if weightDifference > 50 {
            return (false, "Target weight seems unrealistic. Please choose a target within 50kg of your current weight.")
        }
        
        // Calculate time to goal and check for aggressive weight loss/gain
        let daysToGoal = max(1, targetDate.timeIntervalSince(Date()) / (24 * 60 * 60))
        let weeksToGoal = daysToGoal / 7
        let weightChangePerWeek = weightDifference / weeksToGoal
        
        // Check for dangerously aggressive weight loss (more than 1kg per week)
        if selectedGoalType == .loseWeight && weightChangePerWeek > 1.0 {
            return (false, "Weight loss goal is too aggressive. Safe weight loss is 0.5-1kg per week. Try extending your target date or reducing target weight.")
        }
        
        // Check for very aggressive weight gain (more than 0.5kg per week)
        if selectedGoalType == .gainWeight && weightChangePerWeek > 0.5 {
            return (false, "Weight gain goal is too aggressive. Healthy weight gain is 0.2-0.5kg per week. Try extending your target date or reducing target weight.")
        }
        
        // Check for extremely short timeframes (less than 2 weeks)
        if weeksToGoal < 2 && weightDifference > 2 {
            return (false, "Timeframe is too short for safe weight change. Please allow at least 2 weeks for significant weight goals.")
        }
        
        // Warning for moderate weight loss (0.75-1kg per week)
        if selectedGoalType == .loseWeight && weightChangePerWeek >= 0.75 && weightChangePerWeek <= 1.0 {
            // This is still within safe limits but on the upper end
        }
        
        return (true, nil)
    }
    
    func getTargetWeightWarning(currentWeight: Double) -> String? {
        // For maintain weight, no warnings needed
        if selectedGoalType == .maintainWeight {
            return nil
        }
        
        guard !targetWeight.isEmpty,
              let targetWeightValue = Double(targetWeight),
              targetWeightValue > 0 else {
            return nil
        }
        
        let currentWeightValue = Double(self.currentWeight) ?? currentWeight
        let weightDifference = abs(targetWeightValue - currentWeightValue)
        
        // Calculate time to goal and weight change per week
        let daysToGoal = max(1, targetDate.timeIntervalSince(Date()) / (24 * 60 * 60))
        let weeksToGoal = daysToGoal / 7
        let weightChangePerWeek = weightDifference / weeksToGoal
        
        // Warning for aggressive but still safe weight loss (0.75-1kg per week)
        if selectedGoalType == .loseWeight && weightChangePerWeek >= 0.75 && weightChangePerWeek <= 1.0 {
            return "⚠️ This is an aggressive weight loss goal (\(String(format: "%.1f", weightChangePerWeek))kg/week). Consider a more gradual approach for sustainable results."
        }
        
        // Warning for aggressive weight gain (0.3-0.5kg per week)
        if selectedGoalType == .gainWeight && weightChangePerWeek >= 0.3 && weightChangePerWeek <= 0.5 {
            return "⚠️ This is an aggressive weight gain goal (\(String(format: "%.1f", weightChangePerWeek))kg/week). Ensure you're eating nutritious foods and exercising."
        }
        
        // Warning for very small weight changes (less than 2kg total)
        if weightDifference < 2 && weeksToGoal > 8 {
            return "💡 This is a very modest weight change. You might achieve this goal sooner than expected."
        }
        
        // Warning for low target weights (40-50kg)
        if targetWeightValue >= 40 && targetWeightValue <= 50 {
            return "⚠️ This is a low target weight. Please ensure this aligns with your health professional's recommendations."
        }
        
        return nil
    }
}