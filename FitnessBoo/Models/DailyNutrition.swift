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
    var totalCarbs: Double
    var totalFats: Double
    var totalSaturatedFats: Double
    var entries: [FoodEntry]
    var calorieTarget: Double
    var proteinTarget: Double
    var carbsTarget: Double
    var fatsTarget: Double
    var saturatedFatsTarget: Double
    var caloriesFromExercise: Double
    var netCalories: Double
    var waterConsumed: Double // in milliliters

    init(date: Date, calorieTarget: Double, proteinTarget: Double, carbsTarget: Double = 0, fatsTarget: Double = 0, saturatedFatsTarget: Double = 0) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = 0
        self.totalProtein = 0
        self.totalCarbs = 0
        self.totalFats = 0
        self.totalSaturatedFats = 0
        self.entries = []
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatsTarget = fatsTarget
        self.saturatedFatsTarget = saturatedFatsTarget
        self.caloriesFromExercise = 0
        self.netCalories = 0
        self.waterConsumed = 0
    }

    init(id: UUID, date: Date, totalCalories: Double, totalProtein: Double, totalCarbs: Double = 0, totalFats: Double = 0, totalSaturatedFats: Double = 0, entries: [FoodEntry], calorieTarget: Double, proteinTarget: Double, carbsTarget: Double = 0, fatsTarget: Double = 0, saturatedFatsTarget: Double = 0, caloriesFromExercise: Double, netCalories: Double, waterConsumed: Double) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFats = totalFats
        self.totalSaturatedFats = totalSaturatedFats
        self.entries = entries
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatsTarget = fatsTarget
        self.saturatedFatsTarget = saturatedFatsTarget
        self.caloriesFromExercise = caloriesFromExercise
        self.netCalories = netCalories
        self.waterConsumed = waterConsumed

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
    
    /// Recalculate total calories, protein, carbs, fats, and saturated fats from all entries
    mutating func recalculateTotals() {
        totalCalories = entries.reduce(0) { $0 + $1.calories }
        totalProtein = entries.reduce(0) { $0 + ($1.protein ?? 0) }
        totalCarbs = entries.reduce(0) { $0 + ($1.carbs ?? 0) }
        totalFats = entries.reduce(0) { $0 + ($1.fats ?? 0) }
        totalSaturatedFats = entries.reduce(0) { $0 + ($1.saturatedFats ?? 0) }
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

    /// Get remaining carbs to reach target
    var remainingCarbs: Double {
        return carbsTarget - totalCarbs
    }

    /// Get remaining fats to reach target
    var remainingFats: Double {
        return fatsTarget - totalFats
    }

    /// Get remaining saturated fats to reach target
    var remainingSaturatedFats: Double {
        return saturatedFatsTarget - totalSaturatedFats
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

    /// Get carbs progress as percentage (0.0 to 1.0+)
    var carbsProgress: Double {
        guard carbsTarget > 0 else { return 0 }
        return totalCarbs / carbsTarget
    }

    /// Get fats progress as percentage (0.0 to 1.0+)
    var fatsProgress: Double {
        guard fatsTarget > 0 else { return 0 }
        return totalFats / fatsTarget
    }

    /// Get saturated fats progress as percentage (0.0 to 1.0+)
    var saturatedFatsProgress: Double {
        guard saturatedFatsTarget > 0 else { return 0 }
        return totalSaturatedFats / saturatedFatsTarget
    }

    /// Check if daily targets are met
    var isCalorieTargetMet: Bool {
        return totalCalories >= calorieTarget
    }

    var isProteinTargetMet: Bool {
        return totalProtein >= proteinTarget
    }

    var isCarbsTargetMet: Bool {
        return totalCarbs >= carbsTarget
    }

    var isFatsTargetMet: Bool {
        return totalFats >= fatsTarget
    }

    var isSaturatedFatsTargetMet: Bool {
        return totalSaturatedFats >= saturatedFatsTarget
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

    /// Get carbs by meal type
    func carbsByMealType() -> [MealType: Double] {
        let grouped = entriesByMealType
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + ($1.carbs ?? 0) }
        }
    }

    /// Get fats by meal type
    func fatsByMealType() -> [MealType: Double] {
        let grouped = entriesByMealType
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + ($1.fats ?? 0) }
        }
    }

    /// Get saturated fats by meal type
    func saturatedFatsByMealType() -> [MealType: Double] {
        let grouped = entriesByMealType
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + ($1.saturatedFats ?? 0) }
        }
    }

    /// Get summary statistics for the day
    var summary: DailyNutritionSummary {
        return DailyNutritionSummary(
            date: date,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFats: totalFats,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbsTarget: carbsTarget,
            fatsTarget: fatsTarget,
            caloriesFromExercise: caloriesFromExercise,
            netCalories: netCalories,
            entryCount: entries.count,
            calorieProgress: calorieProgress,
            proteinProgress: proteinProgress,
            carbsProgress: carbsProgress,
            fatsProgress: fatsProgress
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
    let totalCarbs: Double
    let totalFats: Double
    let calorieTarget: Double
    let proteinTarget: Double
    let carbsTarget: Double
    let fatsTarget: Double
    let caloriesFromExercise: Double
    let netCalories: Double
    let entryCount: Int
    let calorieProgress: Double
    let proteinProgress: Double
    let carbsProgress: Double
    let fatsProgress: Double
    
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
        return calorieProgress >= 1.0 && proteinProgress >= 1.0 && carbsProgress >= 1.0 && fatsProgress >= 1.0
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