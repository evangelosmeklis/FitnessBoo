//
//  FoodEntry.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct FoodEntry: Codable, Identifiable {
    let id: UUID
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var timestamp: Date
    var mealType: MealType?
    var notes: String?

    init(calories: Double, protein: Double? = nil, carbs: Double? = nil, fats: Double? = nil, timestamp: Date = Date(), mealType: MealType? = nil, notes: String? = nil) {
        self.id = UUID()
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.timestamp = timestamp
        self.mealType = mealType
        self.notes = notes
    }

    init(id: UUID, calories: Double, protein: Double?, carbs: Double?, fats: Double?, timestamp: Date, mealType: MealType?, notes: String?) {
        self.id = id
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.timestamp = timestamp
        self.mealType = mealType
        self.notes = notes
    }
    
    /// Validate food entry data
    func validate() throws {
        guard calories >= 0 && calories <= 10000 else {
            throw FoodEntryValidationError.invalidCalories
        }

        if let protein = protein {
            guard protein >= 0 && protein <= 1000 else {
                throw FoodEntryValidationError.invalidProtein
            }
        }

        if let carbs = carbs {
            guard carbs >= 0 && carbs <= 1000 else {
                throw FoodEntryValidationError.invalidCarbs
            }
        }

        if let fats = fats {
            guard fats >= 0 && fats <= 500 else {
                throw FoodEntryValidationError.invalidFats
            }
        }

        if let notes = notes, notes.count > 500 {
            throw FoodEntryValidationError.notesTooLong
        }
    }
    
    /// Get formatted timestamp for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Get formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
}

enum MealType: String, CaseIterable, Codable {
    case breakfast, lunch, dinner, snack
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "star.fill"
        }
    }
    
    /// Get typical time range for meal type
    var typicalTimeRange: ClosedRange<Int> {
        switch self {
        case .breakfast: return 6...10 // 6 AM to 10 AM
        case .lunch: return 11...14 // 11 AM to 2 PM
        case .dinner: return 17...21 // 5 PM to 9 PM
        case .snack: return 0...23 // Any time
        }
    }
    
    /// Suggest meal type based on current time
    static func suggestedMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6...10: return .breakfast
        case 11...14: return .lunch
        case 17...21: return .dinner
        default: return .snack
        }
    }
}

enum FoodEntryValidationError: LocalizedError {
    case invalidCalories
    case invalidProtein
    case invalidCarbs
    case invalidFats
    case notesTooLong

    var errorDescription: String? {
        switch self {
        case .invalidCalories:
            return "Calories must be between 0 and 10,000"
        case .invalidProtein:
            return "Protein must be between 0 and 1,000 grams"
        case .invalidCarbs:
            return "Carbs must be between 0 and 1,000 grams"
        case .invalidFats:
            return "Fats must be between 0 and 500 grams"
        case .notesTooLong:
            return "Notes cannot exceed 500 characters"
        }
    }
}