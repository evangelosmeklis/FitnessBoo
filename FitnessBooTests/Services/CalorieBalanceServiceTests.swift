//
//  CalorieBalanceServiceTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 24/7/25.
//

import XCTest
import Combine
@testable import FitnessBoo

@MainActor
final class CalorieBalanceServiceTests: XCTestCase {
    
    var calorieBalanceService: CalorieBalanceService!
    var mockHealthKitService: MockHealthKitService!
    var mockCalculationService: MockCalculationService!
    var mockDataService: MockDataService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHealthKitService = MockHealthKitService()
        mockCalculationService = MockCalculationService()
        mockDataService = MockDataService()
        
        calorieBalanceService = CalorieBalanceService(
            healthKitService: mockHealthKitService,
            calculationService: mockCalculationService,
            dataService: mockDataService
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        calorieBalanceService?.stopRealTimeTracking()
        calorieBalanceService = nil
        mockHealthKitService = nil
        mockCalculationService = nil
        mockDataService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Real-Time Tracking Tests
    
    func testStartRealTimeTracking() {
        // Given
        XCTAssertFalse(calorieBalanceService.isTracking)
        
        // When
        calorieBalanceService.startRealTimeTracking()
        
        // Then
        XCTAssertTrue(calorieBalanceService.isTracking)
        XCTAssertTrue(mockHealthKitService.startBackgroundSyncCalled)
    }
    
    func testStopRealTimeTracking() {
        // Given
        calorieBalanceService.startRealTimeTracking()
        XCTAssertTrue(calorieBalanceService.isTracking)
        
        // When
        calorieBalanceService.stopRealTimeTracking()
        
        // Then
        XCTAssertFalse(calorieBalanceService.isTracking)
        XCTAssertTrue(mockHealthKitService.stopBackgroundSyncCalled)
    }
    
    // MARK: - Balance Calculation Tests
    
    func testGetCurrentBalanceWithHealthKitData() async {
        // Given
        mockHealthKitService.mockActiveEnergy = 400
        mockHealthKitService.mockRestingEnergy = 1600
        mockCalculationService.mockBMR = 1650
        mockDataService.mockNutritionEntries = [
            createMockNutritionEntry(calories: 800),
            createMockNutritionEntry(calories: 600)
        ]
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.caloriesConsumed, 1400)
        XCTAssertEqual(balance?.restingEnergyBurned, 1600)
        XCTAssertEqual(balance?.activeEnergyBurned, 400)
        XCTAssertEqual(balance?.totalEnergyExpended, 2000)
        XCTAssertEqual(balance?.balance, -600) // 1400 - 2000
        XCTAssertTrue(balance?.isUsingHealthKitData ?? false)
    }
    
    func testGetCurrentBalanceWithCalculatedBMR() async {
        // Given - No HealthKit data available
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("No data")
        mockCalculationService.mockBMR = 1800
        mockDataService.mockNutritionEntries = [
            createMockNutritionEntry(calories: 2000)
        ]
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.caloriesConsumed, 2000)
        XCTAssertEqual(balance?.restingEnergyBurned, 1800)
        XCTAssertEqual(balance?.activeEnergyBurned, 360) // 20% of BMR
        XCTAssertEqual(balance?.totalEnergyExpended, 2160)
        XCTAssertEqual(balance?.balance, -160) // 2000 - 2160
        XCTAssertFalse(balance?.isUsingHealthKitData ?? true)
    }
    
    func testGetBalanceForSpecificDate() async {
        // Given
        let testDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        mockHealthKitService.mockActiveEnergy = 300
        mockHealthKitService.mockRestingEnergy = 1500
        mockDataService.mockNutritionEntries = [
            createMockNutritionEntry(calories: 1200)
        ]
        
        // When
        let balance = await calorieBalanceService.getBalanceForDate(testDate)
        
        // Then
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.date.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(balance?.caloriesConsumed, 1200)
        XCTAssertEqual(balance?.totalEnergyExpended, 1800)
        XCTAssertEqual(balance?.balance, -600)
    }
    
    // MARK: - Balance Properties Tests
    
    func testCalorieBalanceProperties() {
        // Given
        let balance = CalorieBalance(
            date: Date(),
            caloriesConsumed: 2200,
            restingEnergyBurned: 1600,
            activeEnergyBurned: 400,
            totalEnergyBurned: 2000,
            calculatedBMR: 1650,
            balance: 200,
            isUsingHealthKitData: true
        )
        
        // Then
        XCTAssertEqual(balance.totalEnergyExpended, 2000)
        XCTAssertTrue(balance.isPositiveBalance)
        XCTAssertEqual(balance.formattedBalance, "+200 kcal")
        XCTAssertEqual(balance.balanceDescription, "Caloric Surplus")
        XCTAssertEqual(balance.energySourceDescription, "Health App Data")
    }
    
    func testCalorieBalanceNegativeBalance() {
        // Given
        let balance = CalorieBalance(
            date: Date(),
            caloriesConsumed: 1500,
            restingEnergyBurned: 1600,
            activeEnergyBurned: 400,
            totalEnergyBurned: 2000,
            calculatedBMR: 1650,
            balance: -500,
            isUsingHealthKitData: false
        )
        
        // Then
        XCTAssertFalse(balance.isPositiveBalance)
        XCTAssertEqual(balance.formattedBalance, "-500 kcal")
        XCTAssertEqual(balance.balanceDescription, "Caloric Deficit")
        XCTAssertEqual(balance.energySourceDescription, "Calculated BMR")
    }
    
    func testCalorieBalanceZeroBalance() {
        // Given
        let balance = CalorieBalance(
            date: Date(),
            caloriesConsumed: 2000,
            restingEnergyBurned: 1600,
            activeEnergyBurned: 400,
            totalEnergyBurned: 2000,
            calculatedBMR: 1650,
            balance: 0,
            isUsingHealthKitData: true
        )
        
        // Then
        XCTAssertFalse(balance.isPositiveBalance)
        XCTAssertEqual(balance.formattedBalance, "+0 kcal")
        XCTAssertEqual(balance.balanceDescription, "Balanced")
    }
    
    // MARK: - Real-Time Updates Tests
    
    func testRealTimeBalanceUpdates() {
        // Given
        let expectation = XCTestExpectation(description: "Balance updated")
        var receivedBalance: CalorieBalance?
        
        calorieBalanceService.currentBalance
            .compactMap { $0 }
            .sink { balance in
                receivedBalance = balance
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHealthKitService.mockActiveEnergy = 500
        mockHealthKitService.mockRestingEnergy = 1700
        mockDataService.mockNutritionEntries = [createMockNutritionEntry(calories: 1800)]
        
        calorieBalanceService.startRealTimeTracking()
        
        // Simulate energy update
        mockHealthKitService.simulateEnergyUpdate(resting: 1700, active: 500)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedBalance)
        XCTAssertEqual(receivedBalance?.activeEnergyBurned, 500)
        XCTAssertEqual(receivedBalance?.restingEnergyBurned, 1700)
    }
    
    // MARK: - Energy Source Determination Tests
    
    func testEnergySourcePreferenceHealthKitOverCalculated() async {
        // Given - HealthKit has data
        mockHealthKitService.mockActiveEnergy = 450
        mockHealthKitService.mockRestingEnergy = 1650
        mockCalculationService.mockBMR = 1800 // Different from HealthKit
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then - Should prefer HealthKit data
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.restingEnergyBurned, 1650) // HealthKit value
        XCTAssertEqual(balance?.activeEnergyBurned, 450) // HealthKit value
        XCTAssertTrue(balance?.isUsingHealthKitData ?? false)
    }
    
    func testEnergySourceFallbackToCalculated() async {
        // Given - HealthKit has no data
        mockHealthKitService.mockActiveEnergy = 0
        mockHealthKitService.mockRestingEnergy = 0
        mockCalculationService.mockBMR = 1750
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then - Should use calculated BMR
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.restingEnergyBurned, 1750) // Calculated BMR
        XCTAssertEqual(balance?.activeEnergyBurned, 350) // 20% of BMR
        XCTAssertFalse(balance?.isUsingHealthKitData ?? true)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleHealthKitError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.permissionDenied
        mockCalculationService.mockBMR = 1600
        mockDataService.mockNutritionEntries = [createMockNutritionEntry(calories: 1500)]
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then - Should fallback gracefully
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.caloriesConsumed, 1500)
        XCTAssertEqual(balance?.restingEnergyBurned, 1600) // Fallback to BMR
        XCTAssertFalse(balance?.isUsingHealthKitData ?? true)
    }
    
    func testHandleDataServiceError() async {
        // Given
        mockDataService.shouldThrowError = true
        mockHealthKitService.mockActiveEnergy = 400
        mockHealthKitService.mockRestingEnergy = 1600
        
        // When
        let balance = await calorieBalanceService.getCurrentBalance()
        
        // Then - Should handle missing nutrition data
        XCTAssertNotNil(balance)
        XCTAssertEqual(balance?.caloriesConsumed, 0) // No nutrition data
        XCTAssertEqual(balance?.balance, -2000) // 0 - 2000
    }
    
    // MARK: - Performance Tests
    
    func testBalanceCalculationPerformance() {
        // Given
        mockHealthKitService.mockActiveEnergy = 400
        mockHealthKitService.mockRestingEnergy = 1600
        mockDataService.mockNutritionEntries = Array(0..<100).map { _ in
            createMockNutritionEntry(calories: 50)
        }
        
        // When/Then
        measure {
            Task {
                _ = await calorieBalanceService.getCurrentBalance()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockNutritionEntry(calories: Double) -> NutritionEntry {
        return NutritionEntry(
            id: UUID(),
            date: Date(),
            foodName: "Test Food",
            calories: calories,
            protein: 10,
            carbohydrates: 20,
            fat: 5,
            fiber: 2,
            sugar: 5,
            sodium: 100
        )
    }
}

// MARK: - Mock Services Extensions

extension MockCalculationService {
    var mockBMR: Double {
        get { return 1800 }
        set { /* Mock implementation */ }
    }
}

extension MockDataService {
    var mockNutritionEntries: [NutritionEntry] {
        get { return [] }
        set { /* Mock implementation */ }
    }
}