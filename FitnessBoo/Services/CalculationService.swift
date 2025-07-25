//
//  CalculationService.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

enum Gender: String, CaseIterable, Codable {
    case male, female, other
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary, lightlyActive, moderatelyActive, veryActive, extremelyActive
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extremelyActive: return "Extremely Active"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extremelyActive: return "Very hard exercise, physical job"
        }
    }
}

/// Protocol defining calculation service interface
protocol CalculationServiceProtocol {
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double
    func calculateProteinGoal(for user: User?) -> Double
    func calculateCarbGoal(for user: User?) -> Double
    func calculateFatGoal(for user: User?) -> Double
    func calculateWeightLossCalories(maintenanceCalories: Double, weeklyWeightLoss: Double) -> Double
    func calculateWeightGainCalories(maintenanceCalories: Double, weeklyWeightGain: Double) -> Double
}

/// Service responsible for all fitness and nutrition calculations
class CalculationService: CalculationServiceProtocol {
    
    // MARK: - BMR Calculations
    
    /// Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation
    /// - Parameters:
    ///   - age: Age in years
    ///   - weight: Weight in kilograms
    ///   - height: Height in centimeters
    ///   - gender: User's gender
    /// - Returns: BMR in calories per day
    func calculateBMR(age: Int, weight: Double, height: Double, gender: Gender) -> Double {
        let baseCalculation = (10 * weight) + (6.25 * height) - (5 * Double(age))
        
        switch gender {
        case .male:
            return baseCalculation + 5
        case .female:
            return baseCalculation - 161
        case .other:
            // Use average of male and female calculations for inclusive approach
            let maleBMR = baseCalculation + 5
            let femaleBMR = baseCalculation - 161
            return (maleBMR + femaleBMR) / 2
        }
    }
    
    // MARK: - Daily Calorie Calculations
    
    /// Calculate daily calorie needs based on BMR and activity level
    /// - Parameters:
    ///   - bmr: Basal Metabolic Rate
    ///   - activityLevel: User's activity level
    /// - Returns: Total daily energy expenditure in calories
    func calculateDailyCalorieNeeds(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return bmr * activityLevel.multiplier
    }
    
    /// Calculate maintenance calories (same as daily calorie needs)
    /// - Parameters:
    ///   - bmr: Basal Metabolic Rate
    ///   - activityLevel: User's activity level
    /// - Returns: Maintenance calories per day
    func calculateMaintenanceCalories(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return calculateDailyCalorieNeeds(bmr: bmr, activityLevel: activityLevel)
    }
    
    /// Calculate daily calorie target based on fitness goals
    /// - Parameters:
    ///   - dailyCalorieNeeds: Maintenance calories
    ///   - goalType: Type of fitness goal
    ///   - weeklyWeightChangeGoal: Target weight change per week in kg (positive for gain, negative for loss)
    /// - Returns: Daily calorie target
    func calculateCalorieTargetForGoal(dailyCalorieNeeds: Double, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double {
        switch goalType {
        case .maintainWeight:
            return dailyCalorieNeeds
        case .loseWeight, .gainWeight:
            // 1 kg of body weight ≈ 7700 calories
            let dailyCalorieAdjustment = (weeklyWeightChangeGoal * 7700) / 7
            return dailyCalorieNeeds + dailyCalorieAdjustment
        }
    }
    
    // MARK: - Protein Calculations
    
    /// Calculate daily protein target based on weight and goals
    /// - Parameters:
    ///   - weight: Body weight in kilograms
    ///   - goalType: Type of fitness goal
    /// - Returns: Daily protein target in grams
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double {
        switch goalType {
        case .maintainWeight:
            return weight * 0.8 // 0.8g per kg for maintenance
        case .loseWeight:
            return weight * 1.2 // Higher protein to preserve muscle during weight loss
        case .gainWeight:
            return weight * 1.0 // 1.0g per kg for healthy weight gain
        }
    }
    
    func calculateProteinGoal(for user: User?) -> Double {
        guard let user = user else { return 50.0 } // Default protein goal
        return calculateProteinTarget(weight: user.weight, goalType: .maintainWeight)
    }
    
    func calculateCarbGoal(for user: User?) -> Double {
        // Use a default daily calorie target since we no longer calculate from user profile
        let dailyCalories = 2000.0 // Default daily calories
        // Carbs should be about 45-65% of total calories, using 50% as default
        return (dailyCalories * 0.5) / 4 // 4 calories per gram of carbs
    }
    
    func calculateFatGoal(for user: User?) -> Double {
        // Use a default daily calorie target since we no longer calculate from user profile
        let dailyCalories = 2000.0 // Default daily calories
        // Fat should be about 20-35% of total calories, using 30% as default
        return (dailyCalories * 0.3) / 9 // 9 calories per gram of fat
    }
    
    /// Calculate calorie target combining BMR, activity level, and goals
    /// - Parameters:
    ///   - bmr: Basal Metabolic Rate
    ///   - activityLevel: User's activity level
    ///   - goalType: Type of fitness goal
    ///   - weeklyWeightChangeGoal: Target weight change per week in kg
    /// - Returns: Daily calorie target
    func calculateCalorieTarget(bmr: Double, activityLevel: ActivityLevel, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double {
        let maintenanceCalories = calculateMaintenanceCalories(bmr: bmr, activityLevel: activityLevel)
        return calculateCalorieTargetForGoal(dailyCalorieNeeds: maintenanceCalories, goalType: goalType, weeklyWeightChangeGoal: weeklyWeightChangeGoal)
    }
    
    /// Calculate calories for weight loss
    /// - Parameters:
    ///   - maintenanceCalories: Daily maintenance calories
    ///   - weeklyWeightLoss: Target weight loss per week in kg
    /// - Returns: Daily calorie target for weight loss
    func calculateWeightLossCalories(maintenanceCalories: Double, weeklyWeightLoss: Double) -> Double {
        let dailyDeficit = (weeklyWeightLoss * 7700) / 7 // 7700 calories per kg
        return maintenanceCalories - dailyDeficit
    }
    
    /// Calculate calories for weight gain
    /// - Parameters:
    ///   - maintenanceCalories: Daily maintenance calories
    ///   - weeklyWeightGain: Target weight gain per week in kg
    /// - Returns: Daily calorie target for weight gain
    func calculateWeightGainCalories(maintenanceCalories: Double, weeklyWeightGain: Double) -> Double {
        let dailySurplus = (weeklyWeightGain * 7700) / 7 // 7700 calories per kg
        return maintenanceCalories + dailySurplus
    }
    
    // MARK: - Validation
    
    /// Validate user input data for calculations
    /// - Parameters:
    ///   - age: Age in years
    ///   - weight: Weight in kg
    ///   - height: Height in cm
    /// - Throws: ValidationError if data is invalid
    func validateUserData(age: Int, weight: Double, height: Double) throws {
        guard weight > 0 && weight < 1000 else {
            throw ValidationError.invalidWeight
        }
    }
    
    // MARK: - Goal Validation
    
    /// Validate weight change goals for health safety
    /// - Parameter weeklyWeightChangeGoal: Target weight change per week in kg
    /// - Returns: Validated and potentially adjusted goal
    func validateWeightChangeGoal(_ weeklyWeightChangeGoal: Double) -> Double {
        let maxWeeklyLoss = -1.0 // Maximum 1kg loss per week
        let maxWeeklyGain = 0.5  // Maximum 0.5kg gain per week
        
        if weeklyWeightChangeGoal < maxWeeklyLoss {
            return maxWeeklyLoss
        } else if weeklyWeightChangeGoal > maxWeeklyGain {
            return maxWeeklyGain
        }
        
        return weeklyWeightChangeGoal
    }
}

// MARK: - Extensions for Unit Conversions

extension CalculationService {
    
    /// Convert weight from pounds to kilograms
    /// - Parameter pounds: Weight in pounds
    /// - Returns: Weight in kilograms
    func poundsToKilograms(_ pounds: Double) -> Double {
        return pounds * 0.453592
    }
    
    /// Convert height from feet and inches to centimeters
    /// - Parameters:
    ///   - feet: Height in feet
    ///   - inches: Additional inches
    /// - Returns: Height in centimeters
    func feetAndInchesToCentimeters(feet: Int, inches: Double) -> Double {
        let totalInches = Double(feet) * 12 + inches
        return totalInches * 2.54
    }
    
    /// Convert height from inches to centimeters
    /// - Parameter inches: Height in inches
    /// - Returns: Height in centimeters
    func inchesToCentimeters(_ inches: Double) -> Double {
        return inches * 2.54
    }
}