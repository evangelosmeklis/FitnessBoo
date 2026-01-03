//
//  FitnessGoal.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct FitnessGoal: Codable, Identifiable {
    let id: UUID
    var type: GoalType
    var targetWeight: Double?
    var targetDate: Date?
    var weeklyWeightChangeGoal: Double
    var dailyCalorieTarget: Double
    var dailyProteinTarget: Double
    var dailyCarbsTarget: Double
    var dailyFatsTarget: Double
    var dailySaturatedFatsTarget: Double
    var dailyWaterTarget: Double
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(type: GoalType, targetWeight: Double? = nil, targetDate: Date? = nil, weeklyWeightChangeGoal: Double = 0, dailyWaterTarget: Double = 2000) {
        self.id = UUID()
        self.type = type
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.weeklyWeightChangeGoal = weeklyWeightChangeGoal
        self.dailyCalorieTarget = 0 // Will be calculated
        self.dailyProteinTarget = 0 // Will be calculated
        self.dailyCarbsTarget = 0 // Will be calculated
        self.dailyFatsTarget = 0 // Will be calculated
        self.dailySaturatedFatsTarget = 0 // Will be calculated
        self.dailyWaterTarget = dailyWaterTarget
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Calculate daily calorie target based on HealthKit energy data and goal
    mutating func calculateDailyTargets(totalEnergyExpended: Double, currentWeight: Double) {
        // Use actual energy expenditure from HealthKit instead of calculated BMR
        let baseDailyCalories = totalEnergyExpended > 0 ? totalEnergyExpended : 2000 // Fallback if no HealthKit data
        
        // Calculate calorie adjustment based on weight change goal
        // 1 kg of fat = approximately 7700 calories
        let caloriesPerKg = 7700.0
        let dailyCalorieAdjustment = (weeklyWeightChangeGoal * caloriesPerKg) / 7.0
        
        switch type {
        case .loseWeight:
            // For weight loss, the target is the goal-adjusted calories
            let targetCalories = baseDailyCalories + dailyCalorieAdjustment // dailyCalorieAdjustment is negative
            dailyCalorieTarget = targetCalories // Show actual goal target, not minimum
            print("🎯 Weight loss goal calculation: \(baseDailyCalories) + \(dailyCalorieAdjustment) = \(targetCalories)")
        case .gainWeight:
            // For weight gain, add calories
            dailyCalorieTarget = baseDailyCalories + abs(dailyCalorieAdjustment)
        case .maintainWeight:
            dailyCalorieTarget = baseDailyCalories
        }
        
        // Calculate protein target based on goal type and current weight from HealthKit
        // General recommendations: 0.8-2.2g per kg body weight
        switch type {
        case .loseWeight:
            dailyProteinTarget = currentWeight * 1.6 // Higher protein for weight loss
        case .gainWeight:
            dailyProteinTarget = currentWeight * 1.4 // Moderate protein for weight gain
        case .maintainWeight:
            dailyProteinTarget = currentWeight * 1.2 // Maintenance protein
        }

        // Calculate carbs and fats targets based on remaining calories
        // Protein provides 4 calories per gram
        let proteinCalories = dailyProteinTarget * 4
        let remainingCalories = dailyCalorieTarget - proteinCalories

        // Standard macro split: 40-50% carbs, 25-35% fats from remaining calories
        switch type {
        case .loseWeight:
            // Lower carb for weight loss: 35% carbs, 30% fats (rest from protein)
            dailyCarbsTarget = (remainingCalories * 0.45) / 4 // 4 cal/g for carbs
            dailyFatsTarget = (remainingCalories * 0.55) / 9 // 9 cal/g for fats
        case .gainWeight:
            // Higher carb for weight gain: 50% carbs, 25% fats
            dailyCarbsTarget = (remainingCalories * 0.55) / 4
            dailyFatsTarget = (remainingCalories * 0.45) / 9
        case .maintainWeight:
            // Balanced: 45% carbs, 30% fats
            dailyCarbsTarget = (remainingCalories * 0.50) / 4
            dailyFatsTarget = (remainingCalories * 0.50) / 9
        }

        // Saturated fats should be limited to less than 10% of total calories
        // Health guidelines recommend keeping saturated fats to 20-22g per day on a 2000 cal diet
        // We calculate as 10% of total calories in grams
        let saturatedFatsFromCalories = (dailyCalorieTarget * 0.10) / 9 // 9 cal/g for fats
        dailySaturatedFatsTarget = min(saturatedFatsFromCalories, dailyFatsTarget * 0.33) // Max 1/3 of total fats

        updatedAt = Date()
    }
    
    /// Validate goal parameters for health safety
    func validate() throws {
        // Maximum safe weight loss: 1kg (2.2 lbs) per week
        // Maximum safe weight gain: 0.5kg (1.1 lbs) per week
        switch type {
        case .loseWeight:
            guard weeklyWeightChangeGoal <= 0 && weeklyWeightChangeGoal >= -1.0 else {
                throw GoalValidationError.unsafeWeightLoss
            }
        case .gainWeight:
            guard weeklyWeightChangeGoal >= 0 && weeklyWeightChangeGoal <= 0.5 else {
                throw GoalValidationError.unsafeWeightGain
            }
        case .maintainWeight:
            guard abs(weeklyWeightChangeGoal) <= 0.1 else {
                throw GoalValidationError.invalidMaintenanceGoal
            }
        }
        
        if let targetWeight = targetWeight {
            guard targetWeight > 0 && targetWeight < 1000 else {
                throw GoalValidationError.invalidTargetWeight
            }
        }
        
        if let targetDate = targetDate {
            guard targetDate > Date() else {
                throw GoalValidationError.invalidTargetDate
            }
        }
    }
    
    /// Calculate estimated time to reach goal
    func estimatedTimeToGoal(currentWeight: Double) -> TimeInterval? {
        guard let targetWeight = targetWeight, weeklyWeightChangeGoal != 0 else {
            return nil
        }
        
        let weightDifference = abs(targetWeight - currentWeight)
        let weeksToGoal = weightDifference / abs(weeklyWeightChangeGoal)
        return weeksToGoal * 7 * 24 * 60 * 60 // Convert to seconds
    }
}

enum GoalType: String, CaseIterable, Codable {
    case loseWeight, maintainWeight, gainWeight
    
    var displayName: String {
        switch self {
        case .loseWeight: return "Lose Weight"
        case .maintainWeight: return "Maintain Weight"
        case .gainWeight: return "Gain Weight"
        }
    }
    
    var description: String {
        switch self {
        case .loseWeight: return "Create a calorie deficit to lose weight"
        case .maintainWeight: return "Maintain current weight with balanced nutrition"
        case .gainWeight: return "Create a calorie surplus to gain weight"
        }
    }
    
    var recommendedWeightChangeRange: ClosedRange<Double> {
        switch self {
        case .loseWeight: return -1.0...(-0.25) // -1kg to -0.25kg per week
        case .maintainWeight: return -0.1...0.1 // Minimal change
        case .gainWeight: return 0.25...0.5 // 0.25kg to 0.5kg per week
        }
    }
}

enum GoalValidationError: LocalizedError {
    case unsafeWeightLoss
    case unsafeWeightGain
    case invalidMaintenanceGoal
    case invalidTargetWeight
    case invalidTargetDate
    
    var errorDescription: String? {
        switch self {
        case .unsafeWeightLoss:
            return "Weight loss goal exceeds safe limit of 1kg per week"
        case .unsafeWeightGain:
            return "Weight gain goal exceeds safe limit of 0.5kg per week"
        case .invalidMaintenanceGoal:
            return "Maintenance goal should have minimal weight change"
        case .invalidTargetWeight:
            return "Target weight must be between 1 and 999 kg/lbs"
        case .invalidTargetDate:
            return "Target date must be in the future"
        }
    }
}