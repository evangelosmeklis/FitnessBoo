//
//  NutritionViewModelTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import XCTest
@testable import FitnessBoo

@MainActor
class NutritionViewModelTests: XCTestCase {
    var viewModel: NutritionViewModel!
    var mockDataService: MockDataService!
    var mockCalculationService: MockCalculationService!
    
    override func setUp() {
        super.setUp()
        mockDataService = MockDataService()
        mockCalculationService = MockCalculationService()
        viewModel = NutritionViewModel(
            dataService: mockDataService,
            calculationService: mockCalculationService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockDataService = nil
        mockCalculationService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertNil(viewModel.dailyNutrition)
        XCTAssertTrue(viewModel.foodEntries.isEmpty)
        XCTAssertEqual(viewModel.totalCalories, 0)
        XCTAssertEqual(viewModel.totalProtein, 0)
        XCTAssertEqual(viewModel.remainingCalories, 0)
        XCTAssertEqual(viewModel.remainingProtein, 0)
        XCTAssertEqual(viewModel.calorieProgress, 0)
        XCTAssertEqual(viewModel.proteinProgress, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingAddFood)
    }
    
    // MARK: - Load Daily Nutrition Tests
    
    func testLoadDailyNutritionWithExistingData() async {
        // Given
        let testDate = Date()
        let existingNutrition = DailyNutrition(date: testDate, calorieTarget: 2000, proteinTarget: 150)
        mockDataService.mockDailyNutrition = existingNutrition
        
        // When
        await viewModel.loadDailyNutrition(for: testDate)
        
        // Then
        XCTAssertNotNil(viewModel.dailyNutrition)
        XCTAssertEqual(viewModel.dailyNutrition?.calorieTarget, 2000)
        XCTAssertEqual(viewModel.dailyNutrition?.proteinTarget, 150)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadDailyNutritionWithoutExistingData() async {
        // Given
        let testDate = Date()
        let mockUser = User(age: 30, weight: 70, height: 175, gender: .male, activityLevel: .moderatelyActive, preferredUnits: .metric)
        let mockGoal = FitnessGoal(type: .loseWeight, targetWeight: 65, targetDate: nil, weeklyWeightChangeGoal: 0.5, dailyCalorieTarget: 1800, dailyProteinTarget: 140, isActive: true)
        
        mockDataService.mockUser = mockUser
        mockDataService.mockActiveGoal = mockGoal
        mockDataService.mockDailyNutrition = nil
        
        // When
        await viewModel.loadDailyNutrition(for: testDate)
        
        // Then
        XCTAssertNotNil(viewModel.dailyNutrition)
        XCTAssertEqual(viewModel.dailyNutrition?.calorieTarget, 1800)
        XCTAssertEqual(viewModel.dailyNutrition?.proteinTarget, 140)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadDailyNutritionWithError() async {
        // Given
        mockDataService.shouldThrowError = true
        
        // When
        await viewModel.loadDailyNutrition()
        
        // Then
        XCTAssertNil(viewModel.dailyNutrition)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to load nutrition data"))
    }
    
    // MARK: - Add Food Entry Tests
    
    func testAddValidFoodEntry() async {
        // Given
        let nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        viewModel.dailyNutrition = nutrition
        
        let foodEntry = FoodEntry(calories: 300, protein: 25, mealType: .lunch, notes: "Chicken salad")
        
        // When
        await viewModel.addFoodEntry(foodEntry)
        
        // Then
        XCTAssertTrue(mockDataService.saveFoodEntryCalled)
        XCTAssertTrue(mockDataService.saveDailyNutritionCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testAddInvalidFoodEntry() async {
        // Given
        let nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        viewModel.dailyNutrition = nutrition
        
        let invalidEntry = FoodEntry(calories: -100, protein: 25, mealType: .lunch, notes: nil) // Invalid calories
        
        // When
        await viewModel.addFoodEntry(invalidEntry)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to add food entry"))
    }
    
    // MARK: - Update Food Entry Tests
    
    func testUpdateValidFoodEntry() async {
        // Given
        let nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        viewModel.dailyNutrition = nutrition
        
        let updatedEntry = FoodEntry(calories: 350, protein: 30, mealType: .dinner, notes: "Updated meal")
        
        // When
        await viewModel.updateFoodEntry(updatedEntry)
        
        // Then
        XCTAssertTrue(mockDataService.updateFoodEntryCalled)
        XCTAssertTrue(mockDataService.saveDailyNutritionCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Delete Food Entry Tests
    
    func testDeleteFoodEntry() async {
        // Given
        let nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        viewModel.dailyNutrition = nutrition
        
        let entryToDelete = FoodEntry(calories: 200, protein: 15, mealType: .snack, notes: nil)
        
        // When
        await viewModel.deleteFoodEntry(entryToDelete)
        
        // Then
        XCTAssertTrue(mockDataService.deleteFoodEntryCalled)
        XCTAssertTrue(mockDataService.saveDailyNutritionCalled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Real-time Calculations Tests
    
    func testRealTimeCalculationsUpdate() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let entry1 = FoodEntry(calories: 300, protein: 25, mealType: .breakfast, notes: nil)
        let entry2 = FoodEntry(calories: 450, protein: 35, mealType: .lunch, notes: nil)
        
        nutrition.addEntry(entry1)
        nutrition.addEntry(entry2)
        
        // When
        viewModel.dailyNutrition = nutrition
        
        // Then
        XCTAssertEqual(viewModel.totalCalories, 750)
        XCTAssertEqual(viewModel.totalProtein, 60)
        XCTAssertEqual(viewModel.remainingCalories, 1250)
        XCTAssertEqual(viewModel.remainingProtein, 90)
        XCTAssertEqual(viewModel.calorieProgress, 0.375, accuracy: 0.001)
        XCTAssertEqual(viewModel.proteinProgress, 0.4, accuracy: 0.001)
    }
    
    func testTargetAchievementFlags() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let entry1 = FoodEntry(calories: 1200, protein: 80, mealType: .lunch, notes: nil)
        let entry2 = FoodEntry(calories: 800, protein: 70, mealType: .dinner, notes: nil)
        
        nutrition.addEntry(entry1)
        nutrition.addEntry(entry2)
        
        // When
        viewModel.dailyNutrition = nutrition
        
        // Then
        XCTAssertTrue(viewModel.isCalorieTargetMet)
        XCTAssertTrue(viewModel.isProteinTargetMet)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testEntriesByMealType() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let breakfastEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast, notes: nil)
        let lunchEntry = FoodEntry(calories: 450, protein: 35, mealType: .lunch, notes: nil)
        let snackEntry = FoodEntry(calories: 150, protein: 5, mealType: .snack, notes: nil)
        
        nutrition.addEntry(breakfastEntry)
        nutrition.addEntry(lunchEntry)
        nutrition.addEntry(snackEntry)
        
        viewModel.dailyNutrition = nutrition
        
        // When
        let entriesByMeal = viewModel.entriesByMealType
        
        // Then
        XCTAssertEqual(entriesByMeal[.breakfast]?.count, 1)
        XCTAssertEqual(entriesByMeal[.lunch]?.count, 1)
        XCTAssertEqual(entriesByMeal[.snack]?.count, 1)
        XCTAssertNil(entriesByMeal[.dinner])
    }
    
    func testCaloriesByMealType() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let breakfastEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast, notes: nil)
        let lunchEntry = FoodEntry(calories: 450, protein: 35, mealType: .lunch, notes: nil)
        
        nutrition.addEntry(breakfastEntry)
        nutrition.addEntry(lunchEntry)
        
        viewModel.dailyNutrition = nutrition
        
        // When
        let caloriesByMeal = viewModel.caloriesByMealType()
        
        // Then
        XCTAssertEqual(caloriesByMeal[.breakfast], 300)
        XCTAssertEqual(caloriesByMeal[.lunch], 450)
    }
    
    func testProteinByMealType() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let breakfastEntry = FoodEntry(calories: 300, protein: 20, mealType: .breakfast, notes: nil)
        let lunchEntry = FoodEntry(calories: 450, protein: 35, mealType: .lunch, notes: nil)
        
        nutrition.addEntry(breakfastEntry)
        nutrition.addEntry(lunchEntry)
        
        viewModel.dailyNutrition = nutrition
        
        // When
        let proteinByMeal = viewModel.proteinByMealType()
        
        // Then
        XCTAssertEqual(proteinByMeal[.breakfast], 20)
        XCTAssertEqual(proteinByMeal[.lunch], 35)
    }
    
    func testDailySummary() {
        // Given
        var nutrition = DailyNutrition(date: Date(), calorieTarget: 2000, proteinTarget: 150)
        let entry = FoodEntry(calories: 500, protein: 40, mealType: .lunch, notes: nil)
        nutrition.addEntry(entry)
        
        viewModel.dailyNutrition = nutrition
        
        // When
        let summary = viewModel.dailySummary
        
        // Then
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalCalories, 500)
        XCTAssertEqual(summary?.totalProtein, 40)
        XCTAssertEqual(summary?.calorieTarget, 2000)
        XCTAssertEqual(summary?.proteinTarget, 150)
        XCTAssertEqual(summary?.entryCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testUserNotFoundError() async {
        // Given
        mockDataService.mockUser = nil
        
        // When
        await viewModel.loadDailyNutrition()
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to load nutrition data"))
    }
    
    func testRefreshData() async {
        // Given
        let testDate = Date()
        let nutrition = DailyNutrition(date: testDate, calorieTarget: 2000, proteinTarget: 150)
        mockDataService.mockDailyNutrition = nutrition
        
        // Load initial data
        await viewModel.loadDailyNutrition(for: testDate)
        
        // When
        await viewModel.refreshData()
        
        // Then
        XCTAssertNotNil(viewModel.dailyNutrition)
        XCTAssertEqual(mockDataService.fetchDailyNutritionCallCount, 2) // Called twice
    }
}

// MARK: - Mock Data Service

class MockDataService: DataServiceProtocol {
    var mockUser: User?
    var mockActiveGoal: FitnessGoal?
    var mockDailyNutrition: DailyNutrition?
    var shouldThrowError = false
    
    // Call tracking
    var saveFoodEntryCalled = false
    var updateFoodEntryCalled = false
    var deleteFoodEntryCalled = false
    var saveDailyNutritionCalled = false
    var fetchDailyNutritionCallCount = 0
    
    func saveUser(_ user: User) async throws {
        if shouldThrowError { throw MockError.testError }
    }
    
    func fetchUser() async throws -> User? {
        if shouldThrowError { throw MockError.testError }
        return mockUser
    }
    
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws {
        if shouldThrowError { throw MockError.testError }
        saveFoodEntryCalled = true
    }
    
    func saveFoodEntry(_ entry: FoodEntry) async throws {
        if shouldThrowError { throw MockError.testError }
        try entry.validate() // Validate the entry
        saveFoodEntryCalled = true
    }
    
    func updateFoodEntry(_ entry: FoodEntry) async throws {
        if shouldThrowError { throw MockError.testError }
        try entry.validate() // Validate the entry
        updateFoodEntryCalled = true
    }
    
    func deleteFoodEntry(_ entry: FoodEntry) async throws {
        if shouldThrowError { throw MockError.testError }
        deleteFoodEntryCalled = true
    }
    
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] {
        if shouldThrowError { throw MockError.testError }
        return []
    }
    
    func deleteFoodEntry(withId id: UUID) async throws {
        if shouldThrowError { throw MockError.testError }
        deleteFoodEntryCalled = true
    }
    
    func saveDailyNutrition(_ nutrition: DailyNutrition) async throws {
        if shouldThrowError { throw MockError.testError }
        saveDailyNutritionCalled = true
    }
    
    func fetchDailyNutrition(for date: Date) async throws -> DailyNutrition? {
        if shouldThrowError { throw MockError.testError }
        fetchDailyNutritionCallCount += 1
        return mockDailyNutrition
    }
    
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws {
        if shouldThrowError { throw MockError.testError }
    }
    
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats] {
        if shouldThrowError { throw MockError.testError }
        return []
    }
    
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws {
        if shouldThrowError { throw MockError.testError }
    }
    
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal? {
        if shouldThrowError { throw MockError.testError }
        return mockActiveGoal
    }
    
    func fetchActiveGoal() async throws -> FitnessGoal? {
        if shouldThrowError { throw MockError.testError }
        return mockActiveGoal
    }
    
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal] {
        if shouldThrowError { throw MockError.testError }
        return []
    }
}

// MARK: - Mock Calculation Service

class MockCalculationService: CalculationServiceProtocol {
    func calculateBMR(age: Int, weight: Double, height: Double, gender: Gender) -> Double {
        return 1500
    }
    
    func calculateMaintenanceCalories(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return 2000
    }
    
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double {
        return 100
    }
    
    func calculateCalorieTarget(bmr: Double, activityLevel: ActivityLevel, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double {
        return 1800
    }
    
    func calculateWeightLossCalories(maintenanceCalories: Double, weeklyWeightLoss: Double) -> Double {
        return 1500
    }
    
    func calculateWeightGainCalories(maintenanceCalories: Double, weeklyWeightGain: Double) -> Double {
        return 2200
    }
}

// MARK: - Mock Error

enum MockError: Error {
    case testError
}