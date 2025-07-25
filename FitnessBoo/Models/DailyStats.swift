//
//  DailyStats.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct DailyStats: Codable, Identifiable {
    let id: UUID
    let date: Date
    var totalCaloriesConsumed: Double
    var totalProtein: Double
    var caloriesFromExercise: Double
    var restingCalories: Double
    var netCalories: Double
    var weightRecorded: Double?
    var workouts: [WorkoutData]
    var createdAt: Date
    var updatedAt: Date
    
    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.totalCaloriesConsumed = 0
        self.totalProtein = 0
        self.caloriesFromExercise = 0
        self.restingCalories = 0
        self.netCalories = 0
        self.weightRecorded = nil
        self.workouts = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var totalCaloriesBurned: Double {
        restingCalories + caloriesFromExercise
    }
    
    var calorieBalance: Double {
        totalCaloriesConsumed - totalCaloriesBurned
    }
    
    var workoutDuration: Double {
        workouts.reduce(0) { $0 + $1.duration }
    }
    
    var workoutCount: Int {
        workouts.count
    }
    
    // MARK: - Mutating Methods
    
    mutating func updateCaloriesConsumed(_ calories: Double) {
        totalCaloriesConsumed = calories
        updateNetCalories()
        updatedAt = Date()
    }
    
    mutating func updateProtein(_ protein: Double) {
        totalProtein = protein
        updatedAt = Date()
    }
    
    mutating func updateExerciseCalories(_ calories: Double) {
        caloriesFromExercise = calories
        updateNetCalories()
        updatedAt = Date()
    }
    
    mutating func updateRestingCalories(_ calories: Double) {
        restingCalories = calories
        updateNetCalories()
        updatedAt = Date()
    }
    
    mutating func updateWeight(_ weight: Double) {
        weightRecorded = weight
        updatedAt = Date()
    }
    
    mutating func addWorkout(_ workout: WorkoutData) {
        workouts.append(workout)
        updatedAt = Date()
    }
    
    mutating func removeWorkout(withId id: UUID) {
        workouts.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    private mutating func updateNetCalories() {
        netCalories = totalCaloriesConsumed - totalCaloriesBurned
    }
    
    // MARK: - Validation
    
    func validate() throws {
        guard totalCaloriesConsumed >= 0 else {
            throw DailyStatsError.invalidCaloriesConsumed
        }
        guard totalProtein >= 0 else {
            throw DailyStatsError.invalidProtein
        }
        guard caloriesFromExercise >= 0 else {
            throw DailyStatsError.invalidExerciseCalories
        }
        guard restingCalories >= 0 else {
            throw DailyStatsError.invalidRestingCalories
        }
        if let weight = weightRecorded {
            guard weight > 0 && weight < 1000 else {
                throw DailyStatsError.invalidWeight
            }
        }
    }
}

// MARK: - Daily Stats Summary

struct DailyStatsSummary {
    let date: Date
    let calorieBalance: Double
    let proteinIntake: Double
    let exerciseMinutes: Double
    let workoutCount: Int
    let weightChange: Double?
    
    init(from stats: DailyStats, previousWeight: Double? = nil) {
        self.date = stats.date
        self.calorieBalance = stats.calorieBalance
        self.proteinIntake = stats.totalProtein
        self.exerciseMinutes = stats.workoutDuration
        self.workoutCount = stats.workoutCount
        
        if let currentWeight = stats.weightRecorded,
           let previousWeight = previousWeight {
            self.weightChange = currentWeight - previousWeight
        } else {
            self.weightChange = nil
        }
    }
}

// MARK: - Errors

enum DailyStatsError: LocalizedError {
    case invalidCaloriesConsumed
    case invalidProtein
    case invalidExerciseCalories
    case invalidRestingCalories
    case invalidWeight
    
    var errorDescription: String? {
        switch self {
        case .invalidCaloriesConsumed:
            return "Calories consumed cannot be negative"
        case .invalidProtein:
            return "Protein intake cannot be negative"
        case .invalidExerciseCalories:
            return "Exercise calories cannot be negative"
        case .invalidRestingCalories:
            return "Resting calories cannot be negative"
        case .invalidWeight:
            return "Weight must be between 1 and 999 kg/lbs"
        }
    }
}

// MARK: - Extensions

extension DailyStats {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    var relativeDateString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return formattedDate
        }
    }
}