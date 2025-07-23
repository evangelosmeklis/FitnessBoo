//
//  DailyNutritionTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import Testing
@testable import FitnessBoo
import Foundation

struct DailyNutritionTests {
    
    @Test func testDailyNutritionInitialization() async throws {
        let date = Date()
        let nutrition = DailyNutrition(
            date: date,
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        #expect(nutrition.date == Calendar.current.startOfDay(for: date))
        #expect(nutrition.calorieTarget == 2000.0)
        #expect(nutrition.proteinTarget == 150.0)
        #expect(nutrition.totalCalories == 0)
        #expect(nutrition.totalProtein == 0)
        #expect(nutrition.entries.isEmpty)
        #expect(nutrition.caloriesFromExercise == 0)
        #expect(nutrition.netCalories == 0)
    }
    
    @Test func testAddEntry() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 300.0, protein: 20.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.entries.count == 1)
        #expect(nutrition.totalCalories == 300.0)
        #expect(nutrition.totalProtein == 20.0)
    }
    
    @Test func testAddMultipleEntries() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry1 = FoodEntry(calories: 300.0, protein: 20.0)
        let entry2 = FoodEntry(calories: 250.0, protein: 15.0)
        let entry3 = FoodEntry(calories: 400.0) // No protein
        
        nutrition.addEntry(entry1)
        nutrition.addEntry(entry2)
        nutrition.addEntry(entry3)
        
        #expect(nutrition.entries.count == 3)
        #expect(nutrition.totalCalories == 950.0)
        #expect(nutrition.totalProtein == 35.0)
    }
    
    @Test func testRemoveEntry() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry1 = FoodEntry(calories: 300.0, protein: 20.0)
        let entry2 = FoodEntry(calories: 250.0, protein: 15.0)
        
        nutrition.addEntry(entry1)
        nutrition.addEntry(entry2)
        
        #expect(nutrition.totalCalories == 550.0)
        #expect(nutrition.totalProtein == 35.0)
        
        nutrition.removeEntry(withId: entry1.id)
        
        #expect(nutrition.entries.count == 1)
        #expect(nutrition.totalCalories == 250.0)
        #expect(nutrition.totalProtein == 15.0)
    }
    
    @Test func testUpdateEntry() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let originalEntry = FoodEntry(calories: 300.0, protein: 20.0)
        nutrition.addEntry(originalEntry)
        
        var updatedEntry = originalEntry
        updatedEntry.calories = 350.0
        updatedEntry.protein = 25.0
        
        nutrition.updateEntry(updatedEntry)
        
        #expect(nutrition.entries.count == 1)
        #expect(nutrition.totalCalories == 350.0)
        #expect(nutrition.totalProtein == 25.0)
    }
    
    @Test func testUpdateExerciseCalories() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 500.0)
        nutrition.addEntry(entry)
        
        nutrition.updateExerciseCalories(300.0)
        
        #expect(nutrition.caloriesFromExercise == 300.0)
        #expect(nutrition.netCalories == 200.0) // 500 - 300
    }
    
    @Test func testUpdateExerciseCaloriesNegative() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        nutrition.updateExerciseCalories(-100.0)
        
        #expect(nutrition.caloriesFromExercise == 0.0) // Should not allow negative
    }
    
    @Test func testRemainingCalories() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 800.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.remainingCalories == 1200.0) // 2000 - 800
    }
    
    @Test func testRemainingProtein() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 300.0, protein: 50.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.remainingProtein == 100.0) // 150 - 50
    }
    
    @Test func testCalorieProgress() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 1000.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.calorieProgress == 0.5) // 1000 / 2000
    }
    
    @Test func testProteinProgress() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 300.0, protein: 75.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.proteinProgress == 0.5) // 75 / 150
    }
    
    @Test func testTargetsMet() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 2100.0, protein: 160.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.isCalorieTargetMet == true)
        #expect(nutrition.isProteinTargetMet == true)
    }
    
    @Test func testTargetsNotMet() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 1500.0, protein: 100.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.isCalorieTargetMet == false)
        #expect(nutrition.isProteinTargetMet == false)
    }
    
    @Test func testEntriesByMealType() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let breakfast = FoodEntry(calories: 300.0, mealType: .breakfast)
        let lunch = FoodEntry(calories: 400.0, mealType: .lunch)
        let dinner = FoodEntry(calories: 500.0, mealType: .dinner)
        let snack = FoodEntry(calories: 150.0, mealType: .snack)
        
        nutrition.addEntry(breakfast)
        nutrition.addEntry(lunch)
        nutrition.addEntry(dinner)
        nutrition.addEntry(snack)
        
        let grouped = nutrition.entriesByMealType
        
        #expect(grouped[.breakfast]?.count == 1)
        #expect(grouped[.lunch]?.count == 1)
        #expect(grouped[.dinner]?.count == 1)
        #expect(grouped[.snack]?.count == 1)
    }
    
    @Test func testCaloriesByMealType() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let breakfast1 = FoodEntry(calories: 200.0, mealType: .breakfast)
        let breakfast2 = FoodEntry(calories: 150.0, mealType: .breakfast)
        let lunch = FoodEntry(calories: 400.0, mealType: .lunch)
        
        nutrition.addEntry(breakfast1)
        nutrition.addEntry(breakfast2)
        nutrition.addEntry(lunch)
        
        let caloriesByMeal = nutrition.caloriesByMealType()
        
        #expect(caloriesByMeal[.breakfast] == 350.0) // 200 + 150
        #expect(caloriesByMeal[.lunch] == 400.0)
    }
    
    @Test func testProteinByMealType() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let breakfast = FoodEntry(calories: 300.0, protein: 20.0, mealType: .breakfast)
        let lunch = FoodEntry(calories: 400.0, protein: 30.0, mealType: .lunch)
        let snack = FoodEntry(calories: 150.0, mealType: .snack) // No protein
        
        nutrition.addEntry(breakfast)
        nutrition.addEntry(lunch)
        nutrition.addEntry(snack)
        
        let proteinByMeal = nutrition.proteinByMealType()
        
        #expect(proteinByMeal[.breakfast] == 20.0)
        #expect(proteinByMeal[.lunch] == 30.0)
        #expect(proteinByMeal[.snack] == 0.0)
    }
    
    @Test func testSummary() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 1000.0, protein: 75.0)
        nutrition.addEntry(entry)
        nutrition.updateExerciseCalories(200.0)
        
        let summary = nutrition.summary
        
        #expect(summary.totalCalories == 1000.0)
        #expect(summary.totalProtein == 75.0)
        #expect(summary.calorieTarget == 2000.0)
        #expect(summary.proteinTarget == 150.0)
        #expect(summary.caloriesFromExercise == 200.0)
        #expect(summary.netCalories == 800.0)
        #expect(summary.entryCount == 1)
        #expect(summary.calorieProgress == 0.5)
        #expect(summary.proteinProgress == 0.5)
    }
    
    @Test func testValidation() async throws {
        let validNutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        #expect(throws: Never.self) {
            try validNutrition.validate()
        }
    }
    
    @Test func testValidationInvalidCalorieTarget() async throws {
        let invalidNutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 0,
            proteinTarget: 150.0
        )
        
        #expect(throws: DailyNutritionValidationError.self) {
            try invalidNutrition.validate()
        }
    }
    
    @Test func testValidationInvalidProteinTarget() async throws {
        let invalidNutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: -50.0
        )
        
        #expect(throws: DailyNutritionValidationError.self) {
            try invalidNutrition.validate()
        }
    }
    
    @Test func testSummaryIsToday() async throws {
        let todayNutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let yesterdayNutrition = DailyNutrition(
            date: Date().addingTimeInterval(-24 * 60 * 60),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        #expect(todayNutrition.summary.isToday == true)
        #expect(yesterdayNutrition.summary.isToday == false)
    }
    
    @Test func testSummaryTargetsAchieved() async throws {
        var nutrition = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry = FoodEntry(calories: 2100.0, protein: 160.0)
        nutrition.addEntry(entry)
        
        #expect(nutrition.summary.targetsAchieved == true)
        
        // Test with targets not achieved
        var nutrition2 = DailyNutrition(
            date: Date(),
            calorieTarget: 2000.0,
            proteinTarget: 150.0
        )
        
        let entry2 = FoodEntry(calories: 1500.0, protein: 100.0)
        nutrition2.addEntry(entry2)
        
        #expect(nutrition2.summary.targetsAchieved == false)
    }
}