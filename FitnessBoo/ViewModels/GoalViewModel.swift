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
        
        if abs(weightDifference) <= 1.0 { // Within 1kg = maintain
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
        currentWeight = String(user.weight)
        
        do {
            currentGoal = try await dataService.fetchActiveGoal(for: user)
            
            if let goal = currentGoal {
                selectedGoalType = goal.type
                targetWeight = goal.targetWeight != nil ? String(goal.targetWeight!) : ""
                targetDate = goal.targetDate ?? targetDate
                weeklyWeightChangeGoal = goal.weeklyWeightChangeGoal
                dailyWaterTarget = String(goal.dailyWaterTarget)
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
                let weeks = Int(timeInterval / (7 * 24 * 60 * 60))
                estimatedTimeToGoal = "\(weeks) weeks"
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
        
        // Check for reasonable weight change (not more than 50kg difference)
        let weightDifference = abs(targetWeightValue - currentWeightValue)
        if weightDifference > 50 {
            return (false, "Target weight seems unrealistic. Please choose a target within 50kg of your current weight")
        }
        
        return (true, nil)
    }
}