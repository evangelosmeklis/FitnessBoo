//
//  DataServiceTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import XCTest
import CoreData
@testable import FitnessBoo

final class DataServiceTests: XCTestCase {
    var dataService: DataService!
    var testUser: User!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        dataService = DataService.shared
        setupInMemoryPersistentContainer()
        
        // Create test user
        testUser = User(
            age: 30,
            weight: 70.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive,
            preferredUnits: .metric
        )
        testUser.calculateBMR()
    }
    
    override func tearDownWithError() throws {
        dataService = nil
        testUser = nil
        try super.tearDownWithError()
    }
    
    private func setupInMemoryPersistentContainer() {
        let container = NSPersistentContainer(name: "FitnessBoo")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        dataService.persistentContainer = container
    }
    
    // MARK: - User Tests
    
    func testSaveAndFetchUser() async throws {
        // Save user
        try await dataService.saveUser(testUser)
        
        // Fetch user
        let fetchedUser = try await dataService.fetchUser()
        
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, testUser.id)
        XCTAssertEqual(fetchedUser?.age, testUser.age)
        XCTAssertEqual(fetchedUser?.weight, testUser.weight, accuracy: 0.01)
        XCTAssertEqual(fetchedUser?.height, testUser.height, accuracy: 0.01)
        XCTAssertEqual(fetchedUser?.gender, testUser.gender)
        XCTAssertEqual(fetchedUser?.activityLevel, testUser.activityLevel)
        XCTAssertEqual(fetchedUser?.preferredUnits, testUser.preferredUnits)
        XCTAssertEqual(fetchedUser?.bmr, testUser.bmr, accuracy: 0.01)
    }
    
    func testUpdateUser() async throws {
        // Save initial user
        try await dataService.saveUser(testUser)
        
        // Update user
        testUser.age = 31
        testUser.weight = 72.0
        testUser.calculateBMR()
        
        try await dataService.saveUser(testUser)
        
        // Fetch updated user
        let fetchedUser = try await dataService.fetchUser()
        
        XCTAssertEqual(fetchedUser?.age, 31)
        XCTAssertEqual(fetchedUser?.weight, 72.0, accuracy: 0.01)
        XCTAssertEqual(fetchedUser?.bmr, testUser.bmr, accuracy: 0.01)
    }
    
    func testFetchUserWhenNoneExists() async throws {
        let fetchedUser = try await dataService.fetchUser()
        XCTAssertNil(fetchedUser)
    }
    
    // MARK: - Food Entry Tests
    
    func testSaveAndFetchFoodEntries() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create food entries
        let breakfast = FoodEntry(calories: 300, protein: 20, mealType: .breakfast, notes: "Oatmeal")
        let lunch = FoodEntry(calories: 500, protein: 30, mealType: .lunch, notes: "Chicken salad")
        
        // Save food entries
        try await dataService.saveFoodEntry(breakfast, for: testUser)
        try await dataService.saveFoodEntry(lunch, for: testUser)
        
        // Fetch food entries for today
        let fetchedEntries = try await dataService.fetchFoodEntries(for: Date(), user: testUser)
        
        XCTAssertEqual(fetchedEntries.count, 2)
        
        let fetchedBreakfast = fetchedEntries.first { $0.id == breakfast.id }
        let fetchedLunch = fetchedEntries.first { $0.id == lunch.id }
        
        XCTAssertNotNil(fetchedBreakfast)
        XCTAssertEqual(fetchedBreakfast?.calories, 300, accuracy: 0.01)
        XCTAssertEqual(fetchedBreakfast?.protein, 20, accuracy: 0.01)
        XCTAssertEqual(fetchedBreakfast?.mealType, .breakfast)
        XCTAssertEqual(fetchedBreakfast?.notes, "Oatmeal")
        
        XCTAssertNotNil(fetchedLunch)
        XCTAssertEqual(fetchedLunch?.calories, 500, accuracy: 0.01)
        XCTAssertEqual(fetchedLunch?.protein, 30, accuracy: 0.01)
        XCTAssertEqual(fetchedLunch?.mealType, .lunch)
        XCTAssertEqual(fetchedLunch?.notes, "Chicken salad")
    }
    
    func testFetchFoodEntriesForSpecificDate() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create food entries for different dates
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let today = Date()
        
        var yesterdayEntry = FoodEntry(calories: 200, protein: 15, mealType: .breakfast)
        yesterdayEntry.timestamp = yesterday
        
        let todayEntry = FoodEntry(calories: 300, protein: 20, mealType: .lunch)
        
        try await dataService.saveFoodEntry(yesterdayEntry, for: testUser)
        try await dataService.saveFoodEntry(todayEntry, for: testUser)
        
        // Fetch entries for today only
        let todayEntries = try await dataService.fetchFoodEntries(for: today, user: testUser)
        XCTAssertEqual(todayEntries.count, 1)
        XCTAssertEqual(todayEntries.first?.calories, 300, accuracy: 0.01)
        
        // Fetch entries for yesterday only
        let yesterdayEntries = try await dataService.fetchFoodEntries(for: yesterday, user: testUser)
        XCTAssertEqual(yesterdayEntries.count, 1)
        XCTAssertEqual(yesterdayEntries.first?.calories, 200, accuracy: 0.01)
    }
    
    func testDeleteFoodEntry() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create and save food entry
        let foodEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast)
        try await dataService.saveFoodEntry(foodEntry, for: testUser)
        
        // Verify entry exists
        var fetchedEntries = try await dataService.fetchFoodEntries(for: Date(), user: testUser)
        XCTAssertEqual(fetchedEntries.count, 1)
        
        // Delete entry
        try await dataService.deleteFoodEntry(withId: foodEntry.id)
        
        // Verify entry is deleted
        fetchedEntries = try await dataService.fetchFoodEntries(for: Date(), user: testUser)
        XCTAssertEqual(fetchedEntries.count, 0)
    }
    
    func testUpdateFoodEntry() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create and save food entry
        let foodEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast)
        try await dataService.saveFoodEntry(foodEntry, for: testUser)
        
        // Update food entry
        var updatedEntry = foodEntry
        updatedEntry.calories = 350
        updatedEntry.protein = 25
        updatedEntry.notes = "Updated meal"
        
        try await dataService.saveFoodEntry(updatedEntry, for: testUser)
        
        // Fetch and verify update
        let fetchedEntries = try await dataService.fetchFoodEntries(for: Date(), user: testUser)
        XCTAssertEqual(fetchedEntries.count, 1)
        
        let fetchedEntry = fetchedEntries.first!
        XCTAssertEqual(fetchedEntry.calories, 350, accuracy: 0.01)
        XCTAssertEqual(fetchedEntry.protein, 25, accuracy: 0.01)
        XCTAssertEqual(fetchedEntry.notes, "Updated meal")
    }
    
    // MARK: - Daily Stats Tests
    
    func testSaveAndFetchDailyStats() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create daily stats
        let stats = DailyStats(
            date: Date(),
            totalCaloriesConsumed: 1800,
            totalProtein: 120,
            caloriesFromExercise: 300,
            netCalories: 1500,
            weightRecorded: 70.5
        )
        
        // Save daily stats
        try await dataService.saveDailyStats(stats, for: testUser)
        
        // Fetch daily stats
        let today = Date()
        let fetchedStats = try await dataService.fetchDailyStats(for: today...today, user: testUser)
        
        XCTAssertEqual(fetchedStats.count, 1)
        
        let fetchedStat = fetchedStats.first!
        XCTAssertEqual(fetchedStat.totalCaloriesConsumed, 1800, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.totalProtein, 120, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.caloriesFromExercise, 300, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.netCalories, 1500, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.weightRecorded, 70.5, accuracy: 0.01)
    }
    
    func testFetchDailyStatsForDateRange() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create daily stats for multiple days
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let todayStats = DailyStats(date: today, totalCaloriesConsumed: 1800, totalProtein: 120)
        let yesterdayStats = DailyStats(date: yesterday, totalCaloriesConsumed: 1900, totalProtein: 130)
        let twoDaysAgoStats = DailyStats(date: twoDaysAgo, totalCaloriesConsumed: 1700, totalProtein: 110)
        
        try await dataService.saveDailyStats(todayStats, for: testUser)
        try await dataService.saveDailyStats(yesterdayStats, for: testUser)
        try await dataService.saveDailyStats(twoDaysAgoStats, for: testUser)
        
        // Fetch stats for last 3 days
        let fetchedStats = try await dataService.fetchDailyStats(for: twoDaysAgo...today, user: testUser)
        
        XCTAssertEqual(fetchedStats.count, 3)
        
        // Verify order (should be chronological)
        XCTAssertEqual(fetchedStats[0].totalCaloriesConsumed, 1700, accuracy: 0.01) // Two days ago
        XCTAssertEqual(fetchedStats[1].totalCaloriesConsumed, 1900, accuracy: 0.01) // Yesterday
        XCTAssertEqual(fetchedStats[2].totalCaloriesConsumed, 1800, accuracy: 0.01) // Today
    }
    
    func testUpdateDailyStats() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create and save daily stats
        let stats = DailyStats(date: Date(), totalCaloriesConsumed: 1800, totalProtein: 120)
        try await dataService.saveDailyStats(stats, for: testUser)
        
        // Update stats
        var updatedStats = stats
        updatedStats.totalCaloriesConsumed = 2000
        updatedStats.totalProtein = 140
        updatedStats.caloriesFromExercise = 400
        
        try await dataService.saveDailyStats(updatedStats, for: testUser)
        
        // Fetch and verify update
        let today = Date()
        let fetchedStats = try await dataService.fetchDailyStats(for: today...today, user: testUser)
        
        XCTAssertEqual(fetchedStats.count, 1)
        
        let fetchedStat = fetchedStats.first!
        XCTAssertEqual(fetchedStat.totalCaloriesConsumed, 2000, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.totalProtein, 140, accuracy: 0.01)
        XCTAssertEqual(fetchedStat.caloriesFromExercise, 400, accuracy: 0.01)
    }
    
    // MARK: - Goal Tests
    
    func testSaveAndFetchGoal() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create fitness goal
        var goal = FitnessGoal(type: .loseWeight, targetWeight: 65.0, weeklyWeightChangeGoal: -0.5)
        goal.calculateDailyTargets(for: testUser)
        
        // Save goal
        try await dataService.saveGoal(goal, for: testUser)
        
        // Fetch active goal
        let fetchedGoal = try await dataService.fetchActiveGoal(for: testUser)
        
        XCTAssertNotNil(fetchedGoal)
        XCTAssertEqual(fetchedGoal?.id, goal.id)
        XCTAssertEqual(fetchedGoal?.type, .loseWeight)
        XCTAssertEqual(fetchedGoal?.targetWeight, 65.0, accuracy: 0.01)
        XCTAssertEqual(fetchedGoal?.weeklyWeightChangeGoal, -0.5, accuracy: 0.01)
        XCTAssertEqual(fetchedGoal?.isActive, true)
        XCTAssertGreaterThan(fetchedGoal?.dailyCalorieTarget ?? 0, 0)
        XCTAssertGreaterThan(fetchedGoal?.dailyProteinTarget ?? 0, 0)
    }
    
    func testFetchAllGoals() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create multiple goals
        let goal1 = FitnessGoal(type: .loseWeight, targetWeight: 65.0, weeklyWeightChangeGoal: -0.5)
        var goal2 = FitnessGoal(type: .maintainWeight, weeklyWeightChangeGoal: 0)
        goal2.isActive = false
        
        try await dataService.saveGoal(goal1, for: testUser)
        try await dataService.saveGoal(goal2, for: testUser)
        
        // Fetch all goals
        let allGoals = try await dataService.fetchAllGoals(for: testUser)
        
        XCTAssertEqual(allGoals.count, 2)
        
        let activeGoals = allGoals.filter { $0.isActive }
        let inactiveGoals = allGoals.filter { !$0.isActive }
        
        XCTAssertEqual(activeGoals.count, 1)
        XCTAssertEqual(inactiveGoals.count, 1)
        XCTAssertEqual(activeGoals.first?.type, .loseWeight)
        XCTAssertEqual(inactiveGoals.first?.type, .maintainWeight)
    }
    
    func testFetchActiveGoalWhenNoneExists() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        let activeGoal = try await dataService.fetchActiveGoal(for: testUser)
        XCTAssertNil(activeGoal)
    }
    
    func testUpdateGoal() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create and save goal
        var goal = FitnessGoal(type: .loseWeight, targetWeight: 65.0, weeklyWeightChangeGoal: -0.5)
        try await dataService.saveGoal(goal, for: testUser)
        
        // Update goal
        goal.targetWeight = 63.0
        goal.weeklyWeightChangeGoal = -0.3
        goal.calculateDailyTargets(for: testUser)
        
        try await dataService.saveGoal(goal, for: testUser)
        
        // Fetch and verify update
        let fetchedGoal = try await dataService.fetchActiveGoal(for: testUser)
        
        XCTAssertEqual(fetchedGoal?.targetWeight, 63.0, accuracy: 0.01)
        XCTAssertEqual(fetchedGoal?.weeklyWeightChangeGoal, -0.3, accuracy: 0.01)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveFoodEntryWithoutUser() async throws {
        let foodEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast)
        
        do {
            try await dataService.saveFoodEntry(foodEntry, for: testUser)
            XCTFail("Expected DataServiceError.userNotFound")
        } catch DataServiceError.userNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSaveDailyStatsWithoutUser() async throws {
        let stats = DailyStats(date: Date(), totalCaloriesConsumed: 1800, totalProtein: 120)
        
        do {
            try await dataService.saveDailyStats(stats, for: testUser)
            XCTFail("Expected DataServiceError.userNotFound")
        } catch DataServiceError.userNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSaveGoalWithoutUser() async throws {
        let goal = FitnessGoal(type: .loseWeight, targetWeight: 65.0, weeklyWeightChangeGoal: -0.5)
        
        do {
            try await dataService.saveGoal(goal, for: testUser)
            XCTFail("Expected DataServiceError.userNotFound")
        } catch DataServiceError.userNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSaveMultipleFoodEntries() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        let entries = (1...100).map { i in
            FoodEntry(calories: Double(i * 10), protein: Double(i), mealType: .snack)
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Save multiple food entries")
            
            Task {
                do {
                    for entry in entries {
                        try await dataService.saveFoodEntry(entry, for: testUser)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to save entries: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testPerformanceFetchLargeDateRange() async throws {
        // Save user first
        try await dataService.saveUser(testUser)
        
        // Create daily stats for 365 days
        let calendar = Calendar.current
        for i in 0..<365 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let stats = DailyStats(
                date: date,
                totalCaloriesConsumed: Double(1500 + i),
                totalProtein: Double(100 + i)
            )
            try await dataService.saveDailyStats(stats, for: testUser)
        }
        
        let startDate = calendar.date(byAdding: .day, value: -364, to: Date())!
        let endDate = Date()
        
        measure {
            let expectation = XCTestExpectation(description: "Fetch large date range")
            
            Task {
                do {
                    let stats = try await dataService.fetchDailyStats(for: startDate...endDate, user: testUser)
                    XCTAssertEqual(stats.count, 365)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to fetch stats: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}