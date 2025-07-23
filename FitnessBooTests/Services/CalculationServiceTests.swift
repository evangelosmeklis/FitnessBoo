//
//  CalculationServiceTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import XCTest
@testable import FitnessBoo

final class CalculationServiceTests: XCTestCase {
    
    var calculationService: CalculationService!
    
    override func setUpWithError() throws {
        calculationService = CalculationService()
    }
    
    override func tearDownWithError() throws {
        calculationService = nil
    }
    
    // MARK: - BMR Calculation Tests
    
    func testBMRCalculationMale() throws {
        // Test case: 30-year-old male, 80kg, 180cm
        let bmr = calculationService.calculateBMR(age: 30, weight: 80, height: 180, gender: .male)
        let expectedBMR = (10 * 80) + (6.25 * 180) - (5 * 30) + 5 // = 800 + 1125 - 150 + 5 = 1780
        
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR calculation for male should be accurate")
    }
    
    func testBMRCalculationFemale() throws {
        // Test case: 25-year-old female, 65kg, 165cm
        let bmr = calculationService.calculateBMR(age: 25, weight: 65, height: 165, gender: .female)
        let expectedBMR = (10 * 65) + (6.25 * 165) - (5 * 25) - 161 // = 650 + 1031.25 - 125 - 161 = 1395.25
        
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR calculation for female should be accurate")
    }
    
    func testBMRCalculationOther() throws {
        // Test case: 35-year-old other gender, 70kg, 170cm
        let bmr = calculationService.calculateBMR(age: 35, weight: 70, height: 170, gender: .other)
        
        // Calculate expected average
        let maleBMR = (10 * 70) + (6.25 * 170) - (5 * 35) + 5 // = 700 + 1062.5 - 175 + 5 = 1592.5
        let femaleBMR = (10 * 70) + (6.25 * 170) - (5 * 35) - 161 // = 700 + 1062.5 - 175 - 161 = 1426.5
        let expectedBMR = (maleBMR + femaleBMR) / 2 // = 1509.5
        
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR calculation for other gender should be average of male and female")
    }
    
    func testBMRCalculationEdgeCases() throws {
        // Test very young person
        let youngBMR = calculationService.calculateBMR(age: 18, weight: 60, height: 160, gender: .female)
        XCTAssertGreaterThan(youngBMR, 0, "BMR should be positive for young person")
        
        // Test older person
        let olderBMR = calculationService.calculateBMR(age: 70, weight: 70, height: 170, gender: .male)
        XCTAssertGreaterThan(olderBMR, 0, "BMR should be positive for older person")
        
        // Test very light person
        let lightBMR = calculationService.calculateBMR(age: 25, weight: 45, height: 150, gender: .female)
        XCTAssertGreaterThan(lightBMR, 0, "BMR should be positive for light person")
        
        // Test very heavy person
        let heavyBMR = calculationService.calculateBMR(age: 30, weight: 120, height: 190, gender: .male)
        XCTAssertGreaterThan(heavyBMR, 0, "BMR should be positive for heavy person")
    }
    
    // MARK: - Daily Calorie Needs Tests
    
    func testDailyCalorieNeedsAllActivityLevels() throws {
        let bmr = 1500.0
        
        let sedentaryCalories = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: .sedentary)
        XCTAssertEqual(sedentaryCalories, bmr * 1.2, accuracy: 0.1, "Sedentary calories should be BMR * 1.2")
        
        let lightlyActiveCalories = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: .lightlyActive)
        XCTAssertEqual(lightlyActiveCalories, bmr * 1.375, accuracy: 0.1, "Lightly active calories should be BMR * 1.375")
        
        let moderatelyActiveCalories = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: .moderatelyActive)
        XCTAssertEqual(moderatelyActiveCalories, bmr * 1.55, accuracy: 0.1, "Moderately active calories should be BMR * 1.55")
        
        let veryActiveCalories = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: .veryActive)
        XCTAssertEqual(veryActiveCalories, bmr * 1.725, accuracy: 0.1, "Very active calories should be BMR * 1.725")
        
        let extremelyActiveCalories = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: .extremelyActive)
        XCTAssertEqual(extremelyActiveCalories, bmr * 1.9, accuracy: 0.1, "Extremely active calories should be BMR * 1.9")
    }
    
    // MARK: - Calorie Target for Goals Tests
    
    func testCalorieTargetMaintainWeight() throws {
        let dailyCalorieNeeds = 2000.0
        let target = calculationService.calculateCalorieTargetForGoal(
            dailyCalorieNeeds: dailyCalorieNeeds,
            goalType: .maintainWeight,
            weeklyWeightChangeGoal: 0
        )
        
        XCTAssertEqual(target, dailyCalorieNeeds, "Maintain weight should return same as daily needs")
    }
    
    func testCalorieTargetWeightLoss() throws {
        let dailyCalorieNeeds = 2000.0
        let weeklyWeightLoss = -0.5 // 0.5kg loss per week
        let target = calculationService.calculateCalorieTargetForGoal(
            dailyCalorieNeeds: dailyCalorieNeeds,
            goalType: .loseWeight,
            weeklyWeightChangeGoal: weeklyWeightLoss
        )
        
        let expectedDeficit = (weeklyWeightLoss * 7700) / 7 // Daily deficit
        let expectedTarget = dailyCalorieNeeds + expectedDeficit
        
        XCTAssertEqual(target, expectedTarget, accuracy: 0.1, "Weight loss target should create appropriate deficit")
        XCTAssertLessThan(target, dailyCalorieNeeds, "Weight loss target should be less than maintenance")
    }
    
    func testCalorieTargetWeightGain() throws {
        let dailyCalorieNeeds = 2000.0
        let weeklyWeightGain = 0.25 // 0.25kg gain per week
        let target = calculationService.calculateCalorieTargetForGoal(
            dailyCalorieNeeds: dailyCalorieNeeds,
            goalType: .gainWeight,
            weeklyWeightChangeGoal: weeklyWeightGain
        )
        
        let expectedSurplus = (weeklyWeightGain * 7700) / 7 // Daily surplus
        let expectedTarget = dailyCalorieNeeds + expectedSurplus
        
        XCTAssertEqual(target, expectedTarget, accuracy: 0.1, "Weight gain target should create appropriate surplus")
        XCTAssertGreaterThan(target, dailyCalorieNeeds, "Weight gain target should be more than maintenance")
    }
    
    func testCalorieTargetMuscleGain() throws {
        let dailyCalorieNeeds = 2000.0
        let target = calculationService.calculateCalorieTargetForGoal(
            dailyCalorieNeeds: dailyCalorieNeeds,
            goalType: .gainMuscle,
            weeklyWeightChangeGoal: 0
        )
        
        XCTAssertEqual(target, dailyCalorieNeeds + 300, "Muscle gain should add 300 calories")
    }
    
    // MARK: - Protein Target Tests
    
    func testProteinTargetAllGoalTypes() throws {
        let weight = 70.0 // 70kg
        
        let maintainProtein = calculationService.calculateProteinTarget(weight: weight, goalType: .maintainWeight)
        XCTAssertEqual(maintainProtein, weight * 0.8, accuracy: 0.1, "Maintain weight protein should be 0.8g/kg")
        
        let loseWeightProtein = calculationService.calculateProteinTarget(weight: weight, goalType: .loseWeight)
        XCTAssertEqual(loseWeightProtein, weight * 1.2, accuracy: 0.1, "Lose weight protein should be 1.2g/kg")
        
        let gainWeightProtein = calculationService.calculateProteinTarget(weight: weight, goalType: .gainWeight)
        XCTAssertEqual(gainWeightProtein, weight * 1.0, accuracy: 0.1, "Gain weight protein should be 1.0g/kg")
        
        let gainMuscleProtein = calculationService.calculateProteinTarget(weight: weight, goalType: .gainMuscle)
        XCTAssertEqual(gainMuscleProtein, weight * 1.6, accuracy: 0.1, "Gain muscle protein should be 1.6g/kg")
    }
    
    // MARK: - Validation Tests
    
    func testValidUserData() throws {
        // Should not throw for valid data
        XCTAssertNoThrow(try calculationService.validateUserData(age: 25, weight: 70, height: 175))
        XCTAssertNoThrow(try calculationService.validateUserData(age: 18, weight: 50, height: 150))
        XCTAssertNoThrow(try calculationService.validateUserData(age: 65, weight: 90, height: 185))
    }
    
    func testInvalidAge() throws {
        XCTAssertThrowsError(try calculationService.validateUserData(age: 0, weight: 70, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidAge)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: 150, weight: 70, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidAge)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: -5, weight: 70, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidAge)
        }
    }
    
    func testInvalidWeight() throws {
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: 0, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidWeight)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: 1000, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidWeight)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: -10, height: 175)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidWeight)
        }
    }
    
    func testInvalidHeight() throws {
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: 70, height: 0)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidHeight)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: 70, height: 300)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidHeight)
        }
        
        XCTAssertThrowsError(try calculationService.validateUserData(age: 25, weight: 70, height: -5)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.invalidHeight)
        }
    }
    
    // MARK: - Goal Validation Tests
    
    func testValidateWeightChangeGoal() throws {
        // Valid goals should remain unchanged
        XCTAssertEqual(calculationService.validateWeightChangeGoal(-0.5), -0.5, "Valid weight loss goal should remain unchanged")
        XCTAssertEqual(calculationService.validateWeightChangeGoal(0.25), 0.25, "Valid weight gain goal should remain unchanged")
        XCTAssertEqual(calculationService.validateWeightChangeGoal(0), 0, "Maintenance goal should remain unchanged")
        
        // Invalid goals should be capped
        XCTAssertEqual(calculationService.validateWeightChangeGoal(-2.0), -1.0, "Excessive weight loss should be capped at 1kg/week")
        XCTAssertEqual(calculationService.validateWeightChangeGoal(1.0), 0.5, "Excessive weight gain should be capped at 0.5kg/week")
    }
    
    // MARK: - Unit Conversion Tests
    
    func testPoundsToKilograms() throws {
        let pounds = 154.0 // ~70kg
        let kilograms = calculationService.poundsToKilograms(pounds)
        XCTAssertEqual(kilograms, 69.85, accuracy: 0.1, "Pounds to kg conversion should be accurate")
    }
    
    func testFeetAndInchesToCentimeters() throws {
        let centimeters = calculationService.feetAndInchesToCentimeters(feet: 5, inches: 9)
        let expectedCm = (5 * 12 + 9) * 2.54 // 69 inches * 2.54 = 175.26cm
        XCTAssertEqual(centimeters, expectedCm, accuracy: 0.1, "Feet and inches to cm conversion should be accurate")
    }
    
    func testInchesToCentimeters() throws {
        let inches = 69.0
        let centimeters = calculationService.inchesToCentimeters(inches)
        XCTAssertEqual(centimeters, inches * 2.54, accuracy: 0.1, "Inches to cm conversion should be accurate")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserProfileCalculation() throws {
        // Test a complete user profile calculation workflow
        let age = 30
        let weight = 75.0 // kg
        let height = 175.0 // cm
        let gender = Gender.male
        let activityLevel = ActivityLevel.moderatelyActive
        let goalType = GoalType.loseWeight
        let weeklyWeightChangeGoal = -0.5 // 0.5kg loss per week
        
        // Validate user data
        XCTAssertNoThrow(try calculationService.validateUserData(age: age, weight: weight, height: height))
        
        // Calculate BMR
        let bmr = calculationService.calculateBMR(age: age, weight: weight, height: height, gender: gender)
        XCTAssertGreaterThan(bmr, 0, "BMR should be positive")
        
        // Calculate daily calorie needs
        let dailyCalorieNeeds = calculationService.calculateDailyCalorieNeeds(bmr: bmr, activityLevel: activityLevel)
        XCTAssertGreaterThan(dailyCalorieNeeds, bmr, "Daily calorie needs should be greater than BMR")
        
        // Calculate calorie target for goal
        let calorieTarget = calculationService.calculateCalorieTargetForGoal(
            dailyCalorieNeeds: dailyCalorieNeeds,
            goalType: goalType,
            weeklyWeightChangeGoal: weeklyWeightChangeGoal
        )
        XCTAssertLessThan(calorieTarget, dailyCalorieNeeds, "Weight loss target should be less than maintenance")
        
        // Calculate protein target
        let proteinTarget = calculationService.calculateProteinTarget(weight: weight, goalType: goalType)
        XCTAssertGreaterThan(proteinTarget, 0, "Protein target should be positive")
        
        // Validate goal
        let validatedGoal = calculationService.validateWeightChangeGoal(weeklyWeightChangeGoal)
        XCTAssertEqual(validatedGoal, weeklyWeightChangeGoal, "Valid goal should remain unchanged")
    }
    
    func testImperialUnitWorkflow() throws {
        // Test workflow with imperial units
        let ageYears = 25
        let weightPounds = 140.0
        let heightFeet = 5
        let heightInches = 6.0
        
        // Convert to metric
        let weightKg = calculationService.poundsToKilograms(weightPounds)
        let heightCm = calculationService.feetAndInchesToCentimeters(feet: heightFeet, inches: heightInches)
        
        // Validate converted data
        XCTAssertNoThrow(try calculationService.validateUserData(age: ageYears, weight: weightKg, height: heightCm))
        
        // Calculate BMR with converted values
        let bmr = calculationService.calculateBMR(age: ageYears, weight: weightKg, height: heightCm, gender: .female)
        XCTAssertGreaterThan(bmr, 0, "BMR should be positive for imperial unit conversion")
    }
}