//
//  DailyNutrition.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct DailyNutrition: Codable, Identifiable {
    let id: UUID
    let date: Date
    var totalCalories: Double
    var totalProtein: Double
    var entries: [FoodEntry]
    var calorieTarget: Double
    var proteinTarget: Double
    var caloriesFromExercise: Double
    var netCalories: Double
    
    init(date: Date, calorieTarget: Double, proteinTarget: Double) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = 0
        self.totalProtein = 0
        self.entries = []
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.caloriesFromExercise = 0
        self.netCalories = 0
    }
    
    init(id: UUID, date: Date, totalCalories: Double, totalProtein: Double, entries: [FoodEntry], calorieTarget: Double, proteinTarget: Double, caloriesFromExercise: Double, netCalories: Double) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.entries = entries
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.caloriesFromExercise = caloriesFromExercise
        self.netCalories = netCalories
        
        recalculateTotals()
    }
    
    /// Add a food entry and recalculate totals
    mutating func addEntry(_ entry: FoodEntry) {
        entries.append(entry)
        recalculateTotals()
    }
    
    /// Remove a food entry and recalculate totals
    mutating func removeEntry(withId id: UUID) {
        entries.removeAll { $0.id == id }
        recalculateTotals()
    }
    
    /// Update an existing food entry and recalculate totals
    mutating func updateEntry(_ updatedEntry: FoodEntry) {
        if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
            entries[index] = updatedEntry
            recalculateTotals()
        }
    }
    
    /// Recalculate total calories and protein from all entries
    mutating func recalculateTotals() {
        totalCalories = entries.reduce(0) { $0 + $1.calories }
        totalProtein = entries.reduce(0) { $0 + ($1.protein ?? 0) }
        calculateNetCalories()
    }
    
    /// Calculate net calories (consumed - burned through exercise)
    private mutating func calculateNetCalories() {
        netCalories = totalCalories - caloriesFromExercise
    }
    
    /// Update exercise calories and recalculate net calories
    mutating func updateExerciseCalories(_ calories: Double) {
        caloriesFromExercise = max(0, calories)
        calculateNetCalories()
    }
    
    /// Get remaining calories to reach target
    var remainingCalories: Double {
        return calorieTarget - totalCalories
    }
    
    /// Get remaining protein to reach target
    var remainingProtein: Double {
        return proteinTarget - totalProtein
    }
    
    /// Get calorie progress as percentage (0.0 to 1.0+)
    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return totalCalories / calorieTarget
    }
    
    /// Get protein progress as percentage (0.0 to 1.0+)
    var proteinProgress: Double {
        guard proteinTarget > 0 else { return 0 }
        return totalProtein / proteinTarget
    }
    
    /// Check if daily targets are met
    var isCalorieTargetMet: Bool {
        return totalCalories >= calorieTarget
    }
    
    var isProteinTargetMet: Bool {
        return totalProtein >= proteinTarget
    }
    
    /// Get entries grouped by meal type
    var entriesByMealType: [MealType: [FoodEntry]] {
        return Dictionary(grouping: entries) { entry in
            entry.mealType ?? .snack
        }
    }
    
    /// Get calories by meal type
    func caloriesByMealType() -> [MealType: Double] {
        let grouped = entriesByMealType
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + $1.calories }
        }
    }
    
    /// Get protein by meal type
    func proteinByMealType() -> [MealType: Double] {
        let grouped = entriesByMealType
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + ($1.protein ?? 0) }
        }
    }
    
    /// Get summary statistics for the day
    var summary: DailyNutritionSummary {
        return DailyNutritionSummary(
            date: date,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            caloriesFromExercise: caloriesFromExercise,
            netCalories: netCalories,
            entryCount: entries.count,
            calorieProgress: calorieProgress,
            proteinProgress: proteinProgress
        )
    }
    
    /// Validate daily nutrition data
    func validate() throws {
        guard calorieTarget > 0 && calorieTarget <= 10000 else {
            throw DailyNutritionValidationError.invalidCalorieTarget
        }
        
        guard proteinTarget >= 0 && proteinTarget <= 1000 else {
            throw DailyNutritionValidationError.invalidProteinTarget
        }
        
        guard caloriesFromExercise >= 0 && caloriesFromExercise <= 10000 else {
            throw DailyNutritionValidationError.invalidExerciseCalories
        }
        
        // Validate all entries
        for entry in entries {
            try entry.validate()
        }
    }
}

struct DailyNutritionSummary: Codable {
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let calorieTarget: Double
    let proteinTarget: Double
    let caloriesFromExercise: Double
    let netCalories: Double
    let entryCount: Int
    let calorieProgress: Double
    let proteinProgress: Double
    
    /// Get formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Check if this is today's summary
    var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /// Check if targets were met
    var targetsAchieved: Bool {
        return calorieProgress >= 1.0 && proteinProgress >= 1.0
    }
}

enum DailyNutritionValidationError: LocalizedError {
    case invalidCalorieTarget
    case invalidProteinTarget
    case invalidExerciseCalories
    
    var errorDescription: String? {
        switch self {
        case .invalidCalorieTarget:
            return "Calorie target must be between 1 and 10,000"
        case .invalidProteinTarget:
            return "Protein target must be between 0 and 1,000 grams"
        case .invalidExerciseCalories:
            return "Exercise calories must be between 0 and 10,000"
        }
    }
}