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
    @Published var targetWeight: String = ""
    @Published var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @Published var weeklyWeightChangeGoal: Double = -0.5
    @Published var currentGoal: FitnessGoal?
    @Published var activeGoals: [FitnessGoal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // Calculated values
    @Published var estimatedDailyCalories: Double = 0
    @Published var estimatedDailyProtein: Double = 0
    @Published var estimatedTimeToGoal: String = ""
    
    private let calculationService: CalculationServiceProtocol
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(calculationService: CalculationServiceProtocol, dataService: DataServiceProtocol) {
        self.calculationService = calculationService
        self.dataService = dataService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Update calculations when goal parameters change
        Publishers.CombineLatest4($selectedGoalType, $targetWeight, $weeklyWeightChangeGoal, $targetDate)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
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
                type: selectedGoalType,
                targetWeight: targetWeightValue,
                targetDate: targetDate,
                weeklyWeightChangeGoal: weeklyWeightChangeGoal
            )
            
            // Validate the goal
            try goal.validate()
            
            // Calculate daily targets
            goal.calculateDailyTargets(for: user)
            
            // Save the goal
            try await dataService.saveGoal(goal, for: user)
            
            currentGoal = goal
            
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
            
            goal.type = selectedGoalType
            goal.targetWeight = targetWeightValue
            goal.targetDate = targetDate
            goal.weeklyWeightChangeGoal = weeklyWeightChangeGoal
            goal.updatedAt = Date()
            
            // Validate the updated goal
            try goal.validate()
            
            // Recalculate daily targets
            goal.calculateDailyTargets(for: user)
            
            // Save the updated goal
            try await dataService.saveGoal(goal, for: user)
            
            currentGoal = goal
            
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
        
        do {
            currentGoal = try await dataService.fetchActiveGoal(for: user)
            
            if let goal = currentGoal {
                selectedGoalType = goal.type
                targetWeight = goal.targetWeight?.formatted() ?? ""
                targetDate = goal.targetDate ?? targetDate
                weeklyWeightChangeGoal = goal.weeklyWeightChangeGoal
            }
            
        } catch {
            errorMessage = "Failed to load current goal: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
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
                weeklyWeightChangeGoal: weeklyWeightChangeGoal
            )
            
            // Calculate targets
            tempGoal.calculateDailyTargets(for: user)
            
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
        errorMessage = nil
        showingError = false
        cachedUser = nil // Clear cache
    }
    
    func getRecommendedWeightChangeRange() -> ClosedRange<Double> {
        return selectedGoalType.recommendedWeightChangeRange
    }
    
    func formatWeightChange(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        let formattedValue = formatter.string(from: NSNumber(value: abs(value))) ?? "0.0"
        
        switch selectedGoalType {
        case .loseWeight:
            return "-\(formattedValue) kg/week"
        case .gainWeight, .gainMuscle:
            return "+\(formattedValue) kg/week"
        case .maintainWeight:
            return "±\(formattedValue) kg/week"
        }
    }
    
    func loadGoals() {
        Task {
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
        switch selectedGoalType {
        case .loseWeight:
            if targetWeightValue >= currentWeight {
                return (false, "Target weight must be lower than current weight (\(String(format: "%.1f", currentWeight)) kg) for weight loss")
            }
        case .gainWeight, .gainMuscle:
            if targetWeightValue <= currentWeight {
                return (false, "Target weight must be higher than current weight (\(String(format: "%.1f", currentWeight)) kg) for weight gain")
            }
        case .maintainWeight:
            break // Already handled above
        }
        
        // Check for reasonable weight change (not more than 50kg difference)
        let weightDifference = abs(targetWeightValue - currentWeight)
        if weightDifference > 50 {
            return (false, "Target weight seems unrealistic. Please choose a target within 50kg of your current weight")
        }
        
        return (true, nil)
    }
}