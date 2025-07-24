//
//  EnergyViewModelTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 24/7/25.
//

import XCTest
import Combine
@testable import FitnessBoo

@MainActor
final class EnergyViewModelTests: XCTestCase {
    
    var energyViewModel: EnergyViewModel!
    var mockHealthKitService: MockHealthKitService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHealthKitService = MockHealthKitService()
        energyViewModel = EnergyViewModel(healthKitService: mockHealthKitService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        mockHealthKitService?.reset()
        energyViewModel = nil
        mockHealthKitService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(energyViewModel.activeEnergy, 0)
        XCTAssertEqual(energyViewModel.restingEnergy, 0)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 0)
        XCTAssertFalse(energyViewModel.isLoading)
        XCTAssertNil(energyViewModel.errorMessage)
    }
    
    func testFormattedEnergyValues() {
        // Given
        energyViewModel.activeEnergy = 450.7
        energyViewModel.restingEnergy = 1200.3
        energyViewModel.totalEnergyExpended = 1651.0
        
        // Then
        XCTAssertEqual(energyViewModel.formattedActiveEnergy, "451")
        XCTAssertEqual(energyViewModel.formattedRestingEnergy, "1200")
        XCTAssertEqual(energyViewModel.formattedTotalEnergy, "1651")
    }
    
    func testEnergyPercentages() {
        // Given
        energyViewModel.activeEnergy = 400
        energyViewModel.restingEnergy = 1600
        energyViewModel.totalEnergyExpended = 2000
        
        // Then
        XCTAssertEqual(energyViewModel.activeEnergyPercentage, 0.2, accuracy: 0.001)
        XCTAssertEqual(energyViewModel.restingEnergyPercentage, 0.8, accuracy: 0.001)
    }
    
    func testEnergyPercentagesWithZeroTotal() {
        // Given
        energyViewModel.activeEnergy = 0
        energyViewModel.restingEnergy = 0
        energyViewModel.totalEnergyExpended = 0
        
        // Then
        XCTAssertEqual(energyViewModel.activeEnergyPercentage, 0)
        XCTAssertEqual(energyViewModel.restingEnergyPercentage, 0)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadTodaysEnergySuccess() async {
        // Given
        mockHealthKitService.mockActiveEnergy = 350.0
        mockHealthKitService.mockRestingEnergy = 1400.0
        mockHealthKitService.shouldThrowError = false
        
        // When
        energyViewModel.loadTodaysEnergy()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchActiveEnergyCalled)
        XCTAssertTrue(mockHealthKitService.fetchRestingEnergyCalled)
        XCTAssertEqual(energyViewModel.activeEnergy, 350.0)
        XCTAssertEqual(energyViewModel.restingEnergy, 1400.0)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 1750.0)
        XCTAssertFalse(energyViewModel.isLoading)
        XCTAssertNil(energyViewModel.errorMessage)
    }
    
    func testLoadTodaysEnergyError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("Network error")
        
        // When
        energyViewModel.loadTodaysEnergy()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchActiveEnergyCalled)
        XCTAssertTrue(mockHealthKitService.fetchRestingEnergyCalled)
        XCTAssertFalse(energyViewModel.isLoading)
        XCTAssertNotNil(energyViewModel.errorMessage)
        XCTAssertTrue(energyViewModel.errorMessage!.contains("Network error"))
    }
    
    func testRefreshEnergyData() async {
        // Given
        mockHealthKitService.mockActiveEnergy = 275.0
        mockHealthKitService.mockRestingEnergy = 1325.0
        
        // When
        await energyViewModel.refreshEnergyData()
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchActiveEnergyCalled)
        XCTAssertTrue(mockHealthKitService.fetchRestingEnergyCalled)
        XCTAssertEqual(energyViewModel.activeEnergy, 275.0)
        XCTAssertEqual(energyViewModel.restingEnergy, 1325.0)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 1600.0)
    }
    
    // MARK: - Real-time Updates Tests
    
    func testEnergyObservation() {
        // Given
        let expectation = XCTestExpectation(description: "Energy data updated")
        var receivedActiveEnergy: Double?
        var receivedRestingEnergy: Double?
        
        // Observe energy changes
        energyViewModel.$activeEnergy
            .combineLatest(energyViewModel.$restingEnergy)
            .dropFirst() // Skip initial values
            .sink { active, resting in
                receivedActiveEnergy = active
                receivedRestingEnergy = resting
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHealthKitService.simulateEnergyChange(active: 425.0, resting: 1475.0)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedActiveEnergy, 425.0)
        XCTAssertEqual(receivedRestingEnergy, 1475.0)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 1900.0)
    }
    
    func testMultipleEnergyUpdates() {
        // Given
        let expectation = XCTestExpectation(description: "Multiple energy updates")
        expectation.expectedFulfillmentCount = 3
        
        var updateCount = 0
        energyViewModel.$totalEnergyExpended
            .dropFirst() // Skip initial value
            .sink { _ in
                updateCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHealthKitService.simulateEnergyChange(active: 100, resting: 1000)
        mockHealthKitService.simulateEnergyChange(active: 200, resting: 1100)
        mockHealthKitService.simulateEnergyChange(active: 300, resting: 1200)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(updateCount, 3)
        XCTAssertEqual(energyViewModel.activeEnergy, 300)
        XCTAssertEqual(energyViewModel.restingEnergy, 1200)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 1500)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateTransitions() async {
        // Given
        let loadingExpectation = XCTestExpectation(description: "Loading state changes")
        loadingExpectation.expectedFulfillmentCount = 2 // true -> false
        
        var loadingStates: [Bool] = []
        energyViewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    loadingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        energyViewModel.loadTodaysEnergy()
        
        // Wait for completion
        wait(for: [loadingExpectation], timeout: 2.0)
        
        // Then
        XCTAssertEqual(loadingStates.count, 2)
        XCTAssertFalse(loadingStates[0]) // Initial state
        XCTAssertTrue(loadingStates[1])  // Loading state
        XCTAssertFalse(energyViewModel.isLoading) // Final state
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessageClearing() async {
        // Given - Set initial error
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("Initial error")
        
        energyViewModel.loadTodaysEnergy()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotNil(energyViewModel.errorMessage)
        
        // When - Successful retry
        mockHealthKitService.shouldThrowError = false
        mockHealthKitService.mockActiveEnergy = 200
        mockHealthKitService.mockRestingEnergy = 1300
        
        await energyViewModel.refreshEnergyData()
        
        // Then
        XCTAssertNil(energyViewModel.errorMessage)
        XCTAssertEqual(energyViewModel.activeEnergy, 200)
        XCTAssertEqual(energyViewModel.restingEnergy, 1300)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteEnergyWorkflow() async {
        // Given
        mockHealthKitService.mockActiveEnergy = 500
        mockHealthKitService.mockRestingEnergy = 1500
        
        let dataUpdateExpectation = XCTestExpectation(description: "Data updated from both sources")
        var updateCount = 0
        
        energyViewModel.$totalEnergyExpended
            .dropFirst()
            .sink { total in
                updateCount += 1
                if updateCount == 2 { // Initial load + real-time update
                    dataUpdateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Initial load
        energyViewModel.loadTodaysEnergy()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // When - Real-time update
        mockHealthKitService.simulateEnergyChange(active: 600, resting: 1600)
        
        // Then
        wait(for: [dataUpdateExpectation], timeout: 2.0)
        XCTAssertEqual(energyViewModel.activeEnergy, 600)
        XCTAssertEqual(energyViewModel.restingEnergy, 1600)
        XCTAssertEqual(energyViewModel.totalEnergyExpended, 2200)
        XCTAssertTrue(mockHealthKitService.observeEnergyChangesCalled)
    }
}

// MARK: - EnergyData Model Tests

final class EnergyDataTests: XCTestCase {
    
    func testEnergyDataInitialization() {
        // Given
        let date = Date()
        let energyData = EnergyData(
            activeEnergy: 400,
            restingEnergy: 1600,
            totalEnergy: 2000,
            date: date
        )
        
        // Then
        XCTAssertEqual(energyData.activeEnergy, 400)
        XCTAssertEqual(energyData.restingEnergy, 1600)
        XCTAssertEqual(energyData.totalEnergy, 2000)
        XCTAssertEqual(energyData.date, date)
    }
    
    func testEnergyDataFormattedValues() {
        // Given
        let energyData = EnergyData(
            activeEnergy: 425.7,
            restingEnergy: 1574.3,
            totalEnergy: 2000.0,
            date: Date()
        )
        
        // Then
        XCTAssertEqual(energyData.formattedActiveEnergy, "426 kcal")
        XCTAssertEqual(energyData.formattedRestingEnergy, "1574 kcal")
        XCTAssertEqual(energyData.formattedTotalEnergy, "2000 kcal")
    }
    
    func testEnergyDataPercentages() {
        // Given
        let energyData = EnergyData(
            activeEnergy: 300,
            restingEnergy: 1200,
            totalEnergy: 1500,
            date: Date()
        )
        
        // Then
        XCTAssertEqual(energyData.activePercentage, 0.2, accuracy: 0.001)
        XCTAssertEqual(energyData.restingPercentage, 0.8, accuracy: 0.001)
    }
    
    func testEnergyDataPercentagesWithZeroTotal() {
        // Given
        let energyData = EnergyData(
            activeEnergy: 100,
            restingEnergy: 200,
            totalEnergy: 0,
            date: Date()
        )
        
        // Then
        XCTAssertEqual(energyData.activePercentage, 0)
        XCTAssertEqual(energyData.restingPercentage, 0)
    }
}