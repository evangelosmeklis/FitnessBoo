//
//  GoalViewModelTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import XCTest
import Combine
@testable import FitnessBoo

@MainActor
class GoalViewModelTests: XCTestCase {
    var viewModel: GoalViewModel!
    var mockCalculationService: MockCalculationService!
    var mockDataService: MockDataService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCalculationService = MockCalculationService()
        mockDataService = MockDataService()
        viewModel = GoalViewModel(
            calculationService: mockCalculationService,
            dataService: mockDataService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        viewModel = nil
        mockCalculationService = nil
        mockDataService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Goal Creation Tests
    
    func testCreateValidGoal() async {
        // Given
        let user = createTestUser()
        mockDataService.userToReturn = user
        
        viewModel.selectedGoalType = .loseWeight
        viewModel.targetWeight = "70.0"
        viewModel.weeklyWeightChangeGoal = -0.5
        
        // When
        await viewModel.createGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNotNil(viewModel.currentGoal)
        XCTAssertEqual(viewModel.currentGoal?.type, .loseWeight)
        XCTAssertEqual(viewModel.currentGoal?.targetWeight, 70.0)
        XCTAssertEqual(viewModel.currentGoal?.weeklyWeightChangeGoal, -0.5)
    }
    
    func testCreateGoalWithInvalidWeightLoss() async {
        // Given
        let user = createTestUser()
        viewModel.selectedGoalType = .loseWeight
        viewModel.weeklyWeightChangeGoal = -1.5 // Exceeds safe limit
        
        // When
        await viewModel.createGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showingError)
        XCTAssertTrue(viewModel.errorMessage?.contains("safe limit") ?? false)
    }
    
    func testCreateGoalWithInvalidWeightGain() async {
        // Given
        let user = createTestUser()
        viewModel.selectedGoalType = .gainWeight
        viewModel.weeklyWeightChangeGoal = 1.0 // Exceeds safe limit
        
        // When
        await viewModel.createGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showingError)
        XCTAssertTrue(viewModel.errorMessage?.contains("safe limit") ?? false)
    }
    
    func testCreateGoalWithInvalidTargetWeight() async {
        // Given
        let user = createTestUser()
        viewModel.selectedGoalType = .loseWeight
        viewModel.targetWeight = "1500" // Invalid weight
        viewModel.weeklyWeightChangeGoal = -0.5
        
        // When
        await viewModel.createGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showingError)
    }
    
    // MARK: - Goal Update Tests
    
    func testUpdateExistingGoal() async {
        // Given
        let user = createTestUser()
        let existingGoal = createTestGoal()
        viewModel.currentGoal = existingGoal
        
        viewModel.selectedGoalType = .gainMuscle
        viewModel.weeklyWeightChangeGoal = 0.2
        
        // When
        await viewModel.updateGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertEqual(viewModel.currentGoal?.type, .gainMuscle)
        XCTAssertEqual(viewModel.currentGoal?.weeklyWeightChangeGoal, 0.2)
    }
    
    func testUpdateGoalWithoutExistingGoal() async {
        // Given
        let user = createTestUser()
        viewModel.currentGoal = nil
        
        // When
        await viewModel.updateGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        // Should not crash or throw error, just return early
    }
    
    // MARK: - Goal Loading Tests
    
    func testLoadCurrentGoal() async {
        // Given
        let user = createTestUser()
        let goal = createTestGoal()
        mockDataService.goalToReturn = goal
        
        // When
        await viewModel.loadCurrentGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.currentGoal?.id, goal.id)
        XCTAssertEqual(viewModel.selectedGoalType, goal.type)
        XCTAssertEqual(viewModel.weeklyWeightChangeGoal, goal.weeklyWeightChangeGoal)
    }
    
    func testLoadCurrentGoalWhenNoneExists() async {
        // Given
        let user = createTestUser()
        mockDataService.goalToReturn = nil
        
        // When
        await viewModel.loadCurrentGoal(for: user)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentGoal)
    }
    
    // MARK: - Validation Tests
    
    func testValidateCurrentGoalValid() {
        // Given
        viewModel.selectedGoalType = .loseWeight
        viewModel.targetWeight = "70.0"
        viewModel.weeklyWeightChangeGoal = -0.5
        viewModel.targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        
        // When
        let isValid = viewModel.validateCurrentGoal()
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateCurrentGoalInvalid() {
        // Given
        viewModel.selectedGoalType = .loseWeight
        viewModel.targetWeight = "70.0"
        viewModel.weeklyWeightChangeGoal = -2.0 // Invalid
        viewModel.targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        
        // When
        let isValid = viewModel.validateCurrentGoal()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Calculation Tests
    
    func testCalculationsUpdateWhenParametersChange() async {
        // Given
        let user = createTestUser()
        mockDataService.userToReturn = user
        
        let expectation = XCTestExpectation(description: "Calculations updated")
        
        viewModel.$estimatedDailyCalories
            .dropFirst() // Skip initial value
            .sink { calories in
                if calories > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.selectedGoalType = .loseWeight
        viewModel.weeklyWeightChangeGoal = -0.5
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(viewModel.estimatedDailyCalories, 0)
        XCTAssertGreaterThan(viewModel.estimatedDailyProtein, 0)
    }
    
    // MARK: - Helper Methods Tests
    
    func testResetToDefaults() {
        // Given
        viewModel.selectedGoalType = .gainMuscle
        viewModel.targetWeight = "80.0"
        viewModel.weeklyWeightChangeGoal = 0.3
        viewModel.errorMessage = "Some error"
        viewModel.showingError = true
        
        // When
        viewModel.resetToDefaults()
        
        // Then
        XCTAssertEqual(viewModel.selectedGoalType, .loseWeight)
        XCTAssertEqual(viewModel.targetWeight, "")
        XCTAssertEqual(viewModel.weeklyWeightChangeGoal, -0.5)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
    }
    
    func testGetRecommendedWeightChangeRange() {
        // Given
        viewModel.selectedGoalType = .loseWeight
        
        // When
        let range = viewModel.getRecommendedWeightChangeRange()
        
        // Then
        XCTAssertEqual(range, -1.0...(-0.25))
    }
    
    func testFormatWeightChangeForLoss() {
        // Given
        viewModel.selectedGoalType = .loseWeight
        
        // When
        let formatted = viewModel.formatWeightChange(-0.5)
        
        // Then
        XCTAssertEqual(formatted, "-0.5 kg/week")
    }
    
    func testFormatWeightChangeForGain() {
        // Given
        viewModel.selectedGoalType = .gainWeight
        
        // When
        let formatted = viewModel.formatWeightChange(0.3)
        
        // Then
        XCTAssertEqual(formatted, "+0.3 kg/week")
    }
    
    func testFormatWeightChangeForMaintenance() {
        // Given
        viewModel.selectedGoalType = .maintainWeight
        
        // When
        let formatted = viewModel.formatWeightChange(0.1)
        
        // Then
        XCTAssertEqual(formatted, "±0.1 kg/week")
    }
    
    // MARK: - Test Helpers
    
    private func createTestUser() -> User {
        var user = User(
            age: 30,
            weight: 75.0,
            height: 175.0,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        user.calculateBMR()
        return user
    }
    
    private func createTestGoal() -> FitnessGoal {
        var goal = FitnessGoal(
            type: .loseWeight,
            targetWeight: 70.0,
            targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
            weeklyWeightChangeGoal: -0.5
        )
        
        let user = createTestUser()
        goal.calculateDailyTargets(for: user)
        
        return goal
    }
}

// MARK: - Mock Services

class MockCalculationService: CalculationServiceProtocol {
    func calculateBMR(age: Int, weight: Double, height: Double, gender: Gender) -> Double {
        return 1800.0 // Mock BMR
    }
    
    func calculateDailyCalorieNeeds(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return bmr * activityLevel.multiplier
    }
    
    func calculateCalorieTargetForGoal(dailyCalorieNeeds: Double, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double {
        let dailyCalorieAdjustment = (weeklyWeightChangeGoal * 7700) / 7
        return dailyCalorieNeeds + dailyCalorieAdjustment
    }
    
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double {
        switch goalType {
        case .maintainWeight: return weight * 0.8
        case .loseWeight: return weight * 1.2
        case .gainWeight: return weight * 1.0
        case .gainMuscle: return weight * 1.6
        }
    }
    
    func validateUserData(age: Int, weight: Double, height: Double) throws {
        // Mock validation - always passes
    }
}

class MockDataService: DataServiceProtocol {
    var userToReturn: User?
    var goalToReturn: FitnessGoal?
    var shouldThrowError = false
    var savedGoals: [FitnessGoal] = []
    
    func saveUser(_ user: User) async throws {
        if shouldThrowError {
            throw DataServiceError.saveFailed
        }
        userToReturn = user
    }
    
    func fetchUser() async throws -> User? {
        if shouldThrowError {
            throw DataServiceError.fetchFailed
        }
        return userToReturn
    }
    
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws {
        if shouldThrowError {
            throw DataServiceError.saveFailed
        }
    }
    
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] {
        if shouldThrowError {
            throw DataServiceError.fetchFailed
        }
        return []
    }
    
    func deleteFoodEntry(withId id: UUID) async throws {
        if shouldThrowError {
            throw DataServiceError.saveFailed
        }
    }
    
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws {
        if shouldThrowError {
            throw DataServiceError.saveFailed
        }
    }
    
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats] {
        if shouldThrowError {
            throw DataServiceError.fetchFailed
        }
        return []
    }
    
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws {
        if shouldThrowError {
            throw DataServiceError.saveFailed
        }
        savedGoals.append(goal)
    }
    
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal? {
        if shouldThrowError {
            throw DataServiceError.fetchFailed
        }
        return goalToReturn
    }
    
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal] {
        if shouldThrowError {
            throw DataServiceError.fetchFailed
        }
        return savedGoals
    }
}