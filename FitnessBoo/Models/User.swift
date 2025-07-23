//
//  User.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    var age: Int
    var weight: Double
    var height: Double
    var gender: Gender
    var activityLevel: ActivityLevel
    var preferredUnits: UnitSystem
    var bmr: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(age: Int, weight: Double, height: Double, gender: Gender, activityLevel: ActivityLevel, preferredUnits: UnitSystem = .metric) {
        self.id = UUID()
        self.age = age
        self.weight = weight
        self.height = height
        self.gender = gender
        self.activityLevel = activityLevel
        self.preferredUnits = preferredUnits
        self.bmr = 0 // Will be calculated after initialization
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    

    
    /// Calculate BMR using Mifflin-St Jeor Equation
    mutating func calculateBMR() {
        switch gender {
        case .male:
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        case .female:
            bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        case .other:
            // Use average of male and female calculations
            let maleBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
            let femaleBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
            bmr = (maleBMR + femaleBMR) / 2
        }
        updatedAt = Date()
    }
    
    /// Get daily calorie needs based on activity level
    var dailyCalorieNeeds: Double {
        return bmr * activityLevel.multiplier
    }
    
    /// Get daily calorie goal (same as daily calorie needs for now)
    var dailyCalorieGoal: Double {
        return dailyCalorieNeeds
    }
    
    /// Validate user data
    func validate() throws {
        guard age > 0 && age < 150 else {
            throw ValidationError.invalidAge
        }
        guard weight > 0 && weight < 1000 else {
            throw ValidationError.invalidWeight
        }
        guard height > 0 && height < 300 else {
            throw ValidationError.invalidHeight
        }
    }
    

}





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

enum UnitSystem: String, CaseIterable, Codable {
    case metric, imperial
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidAge
    case invalidWeight
    case invalidHeight
    
    var errorDescription: String? {
        switch self {
        case .invalidAge:
            return "Age must be between 1 and 149 years"
        case .invalidWeight:
            return "Weight must be between 1 and 999 kg/lbs"
        case .invalidHeight:
            return "Height must be between 1 and 299 cm/inches"
        }
    }
}