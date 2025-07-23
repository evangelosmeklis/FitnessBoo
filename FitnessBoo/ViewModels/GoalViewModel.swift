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
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                Task { @MainActor in
                    await self?.updateCalculations()
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
    
    private func updateCalculations() async {
        do {
            guard let user = try await dataService.fetchUser() else { return }
            
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
        }
    }
    
    func validateCurrentGoal() -> Bool {
        do {
            let targetWeightValue = targetWeight.isEmpty ? nil : Double(targetWeight)
            let tempGoal = FitnessGoal(
                type: selectedGoalType,
                targetWeight: targetWeightValue,
                targetDate: targetDate,
                weeklyWeightChangeGoal: weeklyWeightChangeGoal
            )
            
            try tempGoal.validate()
            return true
            
        } catch {
            return false
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
}