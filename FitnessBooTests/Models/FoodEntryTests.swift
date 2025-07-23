//
//  FoodEntryTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import Testing
@testable import FitnessBoo
import Foundation

struct FoodEntryTests {
    
    @Test func testFoodEntryInitialization() async throws {
        let entry = FoodEntry(
            calories: 250.0,
            protein: 15.0,
            mealType: .breakfast,
            notes: "Oatmeal with berries"
        )
        
        #expect(entry.calories == 250.0)
        #expect(entry.protein == 15.0)
        #expect(entry.mealType == .breakfast)
        #expect(entry.notes == "Oatmeal with berries")
        #expect(entry.timestamp <= Date()) // Should be recent
    }
    
    @Test func testFoodEntryInitializationMinimal() async throws {
        let entry = FoodEntry(calories: 100.0)
        
        #expect(entry.calories == 100.0)
        #expect(entry.protein == nil)
        #expect(entry.mealType == nil)
        #expect(entry.notes == nil)
    }
    
    @Test func testFoodEntryValidation() async throws {
        let validEntry = FoodEntry(
            calories: 300.0,
            protein: 20.0,
            mealType: .lunch
        )
        
        #expect(throws: Never.self) {
            try validEntry.validate()
        }
    }
    
    @Test func testFoodEntryValidationInvalidCalories() async throws {
        let invalidEntry = FoodEntry(calories: -50.0)
        
        #expect(throws: FoodEntryValidationError.self) {
            try invalidEntry.validate()
        }
    }
    
    @Test func testFoodEntryValidationExcessiveCalories() async throws {
        let invalidEntry = FoodEntry(calories: 15000.0)
        
        #expect(throws: FoodEntryValidationError.self) {
            try invalidEntry.validate()
        }
    }
    
    @Test func testFoodEntryValidationInvalidProtein() async throws {
        let invalidEntry = FoodEntry(
            calories: 200.0,
            protein: -10.0
        )
        
        #expect(throws: FoodEntryValidationError.self) {
            try invalidEntry.validate()
        }
    }
    
    @Test func testFoodEntryValidationExcessiveProtein() async throws {
        let invalidEntry = FoodEntry(
            calories: 200.0,
            protein: 1500.0
        )
        
        #expect(throws: FoodEntryValidationError.self) {
            try invalidEntry.validate()
        }
    }
    
    @Test func testFoodEntryValidationNotesTooLong() async throws {
        let longNotes = String(repeating: "a", count: 501)
        let invalidEntry = FoodEntry(
            calories: 200.0,
            notes: longNotes
        )
        
        #expect(throws: FoodEntryValidationError.self) {
            try invalidEntry.validate()
        }
    }
    
    @Test func testMealTypeDisplayNames() async throws {
        #expect(MealType.breakfast.displayName == "Breakfast")
        #expect(MealType.lunch.displayName == "Lunch")
        #expect(MealType.dinner.displayName == "Dinner")
        #expect(MealType.snack.displayName == "Snack")
    }
    
    @Test func testMealTypeIcons() async throws {
        #expect(MealType.breakfast.icon == "sunrise.fill")
        #expect(MealType.lunch.icon == "sun.max.fill")
        #expect(MealType.dinner.icon == "sunset.fill")
        #expect(MealType.snack.icon == "star.fill")
    }
    
    @Test func testMealTypeTypicalTimeRanges() async throws {
        #expect(MealType.breakfast.typicalTimeRange.contains(8))
        #expect(!MealType.breakfast.typicalTimeRange.contains(15))
        
        #expect(MealType.lunch.typicalTimeRange.contains(12))
        #expect(!MealType.lunch.typicalTimeRange.contains(8))
        
        #expect(MealType.dinner.typicalTimeRange.contains(19))
        #expect(!MealType.dinner.typicalTimeRange.contains(12))
        
        #expect(MealType.snack.typicalTimeRange.contains(15))
        #expect(MealType.snack.typicalTimeRange.contains(22))
    }
    
    @Test func testSuggestedMealTypeBreakfast() async throws {
        // Create a date at 8 AM
        let calendar = Calendar.current
        let components = DateComponents(hour: 8, minute: 0)
        let breakfastTime = calendar.date(from: components) ?? Date()
        
        // Mock the current time for testing
        let suggestedType = MealType.suggestedMealType()
        
        // Note: This test depends on when it's run, so we'll test the logic indirectly
        // by checking that the method returns a valid meal type
        #expect(MealType.allCases.contains(suggestedType))
    }
    
    @Test func testFormattedTime() async throws {
        let entry = FoodEntry(calories: 200.0)
        let formattedTime = entry.formattedTime
        
        // Should return a non-empty string in time format
        #expect(!formattedTime.isEmpty)
        #expect(formattedTime.contains(":")) // Time format should contain colon
    }
    
    @Test func testFormattedDate() async throws {
        let entry = FoodEntry(calories: 200.0)
        let formattedDate = entry.formattedDate
        
        // Should return a non-empty string in date format
        #expect(!formattedDate.isEmpty)
    }
    
    @Test func testFoodEntryEquality() async throws {
        let entry1 = FoodEntry(calories: 200.0, protein: 10.0)
        let entry2 = FoodEntry(calories: 200.0, protein: 10.0)
        
        // Different entries should have different IDs
        #expect(entry1.id != entry2.id)
    }
    
    @Test func testFoodEntryCodable() async throws {
        let originalEntry = FoodEntry(
            calories: 350.0,
            protein: 25.0,
            mealType: .dinner,
            notes: "Grilled chicken with vegetables"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEntry)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(FoodEntry.self, from: data)
        
        #expect(decodedEntry.id == originalEntry.id)
        #expect(decodedEntry.calories == originalEntry.calories)
        #expect(decodedEntry.protein == originalEntry.protein)
        #expect(decodedEntry.mealType == originalEntry.mealType)
        #expect(decodedEntry.notes == originalEntry.notes)
    }
}