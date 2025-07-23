//
//  FitnessGoalTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import Testing
@testable import FitnessBoo
import Foundation

struct FitnessGoalTests {
    
    @Test func testFitnessGoalInitialization() async throws {
        let goal = FitnessGoal(
            type: .loseWeight,
            targetWeight: 65.0,
            targetDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days from now
            weeklyWeightChangeGoal: -0.5
        )
        
        #expect(goal.type == .loseWeight)
        #expect(goal.targetWeight == 65.0)
        #expect(goal.weeklyWeightChangeGoal == -0.5)
        #expect(goal.isActive == true)
        #expect(goal.dailyCalorieTarget == 0) // Not calculated yet
        #expect(goal.dailyProteinTarget == 0) // Not calculated yet
    }
    
    @Test func testCalculateDailyTargetsWeightLoss() async throws {
        var user = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        user.calculateBMR()
        
        var goal = FitnessGoal(
            type: .loseWeight,
            weeklyWeightChangeGoal: -0.5
        )
        
        goal.calculateDailyTargets(for: user)
        
        let baseDailyCalories = user.dailyCalorieNeeds
        let expectedCalorieDeficit = (0.5 * 7700) / 7 // 0.5kg * 7700 cal/kg / 7 days
        let expectedDailyCalories = baseDailyCalories - expectedCalorieDeficit
        let expectedProtein = user.weight * 1.6 // Weight loss protein target
        
        #expect(goal.dailyCalorieTarget == expectedDailyCalories)
        #expect(goal.dailyProteinTarget == expectedProtein)
    }
    
    @Test func testCalculateDailyTargetsWeightGain() async throws {
        var user = User(
            age: 25,
            weight: 60.0,
            height: 165.0,
            gender: .female,
            activityLevel: .lightlyActive
        )
        user.calculateBMR()
        
        var goal = FitnessGoal(
            type: .gainWeight,
            weeklyWeightChangeGoal: 0.3
        )
        
        goal.calculateDailyTargets(for: user)
        
        let baseDailyCalories = user.dailyCalorieNeeds
        let expectedCalorieSurplus = (0.3 * 7700) / 7 // 0.3kg * 7700 cal/kg / 7 days
        let expectedDailyCalories = baseDailyCalories + expectedCalorieSurplus
        let expectedProtein = user.weight * 1.4 // Weight gain protein target
        
        #expect(goal.dailyCalorieTarget == expectedDailyCalories)
        #expect(goal.dailyProteinTarget == expectedProtein)
    }
    
    @Test func testCalculateDailyTargetsMuscleGain() async throws {
        var user = User(
            age: 28,
            weight: 75.0,
            height: 180.0,
            gender: .male,
            activityLevel: .veryActive
        )
        user.calculateBMR()
        
        var goal = FitnessGoal(
            type: .gainMuscle,
            weeklyWeightChangeGoal: 0.2
        )
        
        goal.calculateDailyTargets(for: user)
        
        let baseDailyCalories = user.dailyCalorieNeeds
        let expectedCalorieSurplus = (0.2 * 7700) / 7
        let expectedDailyCalories = baseDailyCalories + expectedCalorieSurplus
        let expectedProtein = user.weight * 2.2 // Muscle gain protein target
        
        #expect(goal.dailyCalorieTarget == expectedDailyCalories)
        #expect(goal.dailyProteinTarget == expectedProtein)
    }
    
    @Test func testCalculateDailyTargetsMaintenance() async throws {
        var user = User(
            age: 35,
            weight: 68.0,
            height: 170.0,
            gender: .female,
            activityLevel: .moderatelyActive
        )
        user.calculateBMR()
        
        var goal = FitnessGoal(
            type: .maintainWeight,
            weeklyWeightChangeGoal: 0.0
        )
        
        goal.calculateDailyTargets(for: user)
        
        let expectedDailyCalories = user.dailyCalorieNeeds
        let expectedProtein = user.weight * 1.2 // Maintenance protein target
        
        #expect(goal.dailyCalorieTarget == expectedDailyCalories)
        #expect(goal.dailyProteinTarget == expectedProtein)
    }
    
    @Test func testGoalValidationSafeWeightLoss() async throws {
        let safeGoal = FitnessGoal(
            type: .loseWeight,
            weeklyWeightChangeGoal: -0.5
        )
        
        #expect(throws: Never.self) {
            try safeGoal.validate()
        }
    }
    
    @Test func testGoalValidationUnsafeWeightLoss() async throws {
        let unsafeGoal = FitnessGoal(
            type: .loseWeight,
            weeklyWeightChangeGoal: -1.5 // Too aggressive
        )
        
        #expect(throws: GoalValidationError.self) {
            try unsafeGoal.validate()
        }
    }
    
    @Test func testGoalValidationSafeWeightGain() async throws {
        let safeGoal = FitnessGoal(
            type: .gainWeight,
            weeklyWeightChangeGoal: 0.3
        )
        
        #expect(throws: Never.self) {
            try safeGoal.validate()
        }
    }
    
    @Test func testGoalValidationUnsafeWeightGain() async throws {
        let unsafeGoal = FitnessGoal(
            type: .gainWeight,
            weeklyWeightChangeGoal: 0.8 // Too aggressive
        )
        
        #expect(throws: GoalValidationError.self) {
            try unsafeGoal.validate()
        }
    }
    
    @Test func testGoalValidationInvalidTargetDate() async throws {
        let invalidGoal = FitnessGoal(
            type: .loseWeight,
            targetDate: Date().addingTimeInterval(-24 * 60 * 60), // Yesterday
            weeklyWeightChangeGoal: -0.5
        )
        
        #expect(throws: GoalValidationError.self) {
            try invalidGoal.validate()
        }
    }
    
    @Test func testEstimatedTimeToGoal() async throws {
        let goal = FitnessGoal(
            type: .loseWeight,
            targetWeight: 65.0,
            weeklyWeightChangeGoal: -0.5
        )
        
        let currentWeight = 70.0
        let estimatedTime = goal.estimatedTimeToGoal(currentWeight: currentWeight)
        
        // Expected: 5kg difference / 0.5kg per week = 10 weeks
        let expectedWeeks = 10.0
        let expectedSeconds = expectedWeeks * 7 * 24 * 60 * 60
        
        #expect(estimatedTime == expectedSeconds)
    }
    
    @Test func testEstimatedTimeToGoalNoTarget() async throws {
        let goal = FitnessGoal(
            type: .maintainWeight,
            weeklyWeightChangeGoal: 0.0
        )
        
        let estimatedTime = goal.estimatedTimeToGoal(currentWeight: 70.0)
        #expect(estimatedTime == nil)
    }
    
    @Test func testGoalTypeDisplayNames() async throws {
        #expect(GoalType.loseWeight.displayName == "Lose Weight")
        #expect(GoalType.maintainWeight.displayName == "Maintain Weight")
        #expect(GoalType.gainWeight.displayName == "Gain Weight")
        #expect(GoalType.gainMuscle.displayName == "Gain Muscle")
    }
    
    @Test func testGoalTypeRecommendedRanges() async throws {
        #expect(GoalType.loseWeight.recommendedWeightChangeRange.contains(-0.5))
        #expect(!GoalType.loseWeight.recommendedWeightChangeRange.contains(0.5))
        
        #expect(GoalType.maintainWeight.recommendedWeightChangeRange.contains(0.0))
        #expect(!GoalType.maintainWeight.recommendedWeightChangeRange.contains(0.5))
        
        #expect(GoalType.gainWeight.recommendedWeightChangeRange.contains(0.3))
        #expect(!GoalType.gainWeight.recommendedWeightChangeRange.contains(-0.3))
        
        #expect(GoalType.gainMuscle.recommendedWeightChangeRange.contains(0.2))
        #expect(!GoalType.gainMuscle.recommendedWeightChangeRange.contains(0.6))
    }
}