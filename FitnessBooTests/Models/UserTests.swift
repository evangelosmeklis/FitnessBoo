//
//  UserTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import Testing
@testable import FitnessBoo

struct UserTests {
    
    @Test func testUserInitialization() async throws {
        let user = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        #expect(user.age == 30)
        #expect(user.weight == 70.0)
        #expect(user.height == 175.0)
        #expect(user.gender == .male)
        #expect(user.activityLevel == .moderatelyActive)
        #expect(user.preferredUnits == .metric)
        #expect(user.bmr == 0) // Not calculated yet
    }
    
    @Test func testBMRCalculationMale() async throws {
        var user = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        user.calculateBMR()
        
        // Expected BMR for male: (10 * 70) + (6.25 * 175) - (5 * 30) + 5 = 1643.75
        let expectedBMR = (10 * 70.0) + (6.25 * 175.0) - (5 * 30.0) + 5
        #expect(user.bmr == expectedBMR)
    }
    
    @Test func testBMRCalculationFemale() async throws {
        var user = User(
            age: 25,
            weight: 60.0,
            height: 165.0,
            gender: .female,
            activityLevel: .lightlyActive
        )
        
        user.calculateBMR()
        
        // Expected BMR for female: (10 * 60) + (6.25 * 165) - (5 * 25) - 161 = 1406.25
        let expectedBMR = (10 * 60.0) + (6.25 * 165.0) - (5 * 25.0) - 161
        #expect(user.bmr == expectedBMR)
    }
    
    @Test func testBMRCalculationOther() async throws {
        var user = User(
            age: 35,
            weight: 75.0,
            height: 180.0,
            gender: .other,
            activityLevel: .veryActive
        )
        
        user.calculateBMR()
        
        // Expected BMR for other: average of male and female calculations
        let maleBMR = (10 * 75.0) + (6.25 * 180.0) - (5 * 35.0) + 5
        let femaleBMR = (10 * 75.0) + (6.25 * 180.0) - (5 * 35.0) - 161
        let expectedBMR = (maleBMR + femaleBMR) / 2
        #expect(user.bmr == expectedBMR)
    }
    
    @Test func testDailyCalorieNeeds() async throws {
        var user = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        user.calculateBMR()
        let expectedDailyCalories = user.bmr * user.activityLevel.multiplier
        #expect(user.dailyCalorieNeeds == expectedDailyCalories)
    }
    
    @Test func testActivityLevelMultipliers() async throws {
        #expect(ActivityLevel.sedentary.multiplier == 1.2)
        #expect(ActivityLevel.lightlyActive.multiplier == 1.375)
        #expect(ActivityLevel.moderatelyActive.multiplier == 1.55)
        #expect(ActivityLevel.veryActive.multiplier == 1.725)
        #expect(ActivityLevel.extremelyActive.multiplier == 1.9)
    }
    
    @Test func testUserValidation() async throws {
        let validUser = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        #expect(throws: Never.self) {
            try validUser.validate()
        }
    }
    
    @Test func testUserValidationInvalidAge() async throws {
        let invalidUser = User(
            age: 0,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        #expect(throws: ValidationError.self) {
            try invalidUser.validate()
        }
    }
    
    @Test func testUserValidationInvalidWeight() async throws {
        let invalidUser = User(
            age: 30,
            weight: 0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        #expect(throws: ValidationError.self) {
            try invalidUser.validate()
        }
    }
    
    @Test func testUserValidationInvalidHeight() async throws {
        let invalidUser = User(
            age: 30,
            weight: 70.0,
            height: 0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        
        #expect(throws: ValidationError.self) {
            try invalidUser.validate()
        }
    }
    
    @Test func testGenderDisplayNames() async throws {
        #expect(Gender.male.displayName == "Male")
        #expect(Gender.female.displayName == "Female")
        #expect(Gender.other.displayName == "Other")
    }
    
    @Test func testActivityLevelDisplayNames() async throws {
        #expect(ActivityLevel.sedentary.displayName == "Sedentary")
        #expect(ActivityLevel.lightlyActive.displayName == "Lightly Active")
        #expect(ActivityLevel.moderatelyActive.displayName == "Moderately Active")
        #expect(ActivityLevel.veryActive.displayName == "Very Active")
        #expect(ActivityLevel.extremelyActive.displayName == "Extremely Active")
    }
    
    @Test func testUnitSystemDisplayNames() async throws {
        #expect(UnitSystem.metric.displayName == "Metric")
        #expect(UnitSystem.imperial.displayName == "Imperial")
    }
}