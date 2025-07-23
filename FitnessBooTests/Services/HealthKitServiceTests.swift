//
//  HealthKitServiceTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import XCTest
import Combine
import HealthKit
@testable import FitnessBoo

@MainActor
final class HealthKitServiceTests: XCTestCase {
    
    var mockHealthKitService: MockHealthKitService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHealthKitService = MockHealthKitService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        mockHealthKitService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Authorization Tests
    
    func testRequestAuthorizationSuccess() async throws {
        // Given
        mockHealthKitService.mockIsHealthKitAvailable = true
        mockHealthKitService.shouldThrowError = false
        
        // When
        try await mockHealthKitService.requestAuthorization()
        
        // Then
        XCTAssertTrue(mockHealthKitService.requestAuthorizationCalled)
        XCTAssertEqual(mockHealthKitService.authorizationStatus, .sharingAuthorized)
    }
    
    func testRequestAuthorizationHealthKitNotAvailable() async {
        // Given
        mockHealthKitService.mockIsHealthKitAvailable = false
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.healthKitNotAvailable
        
        // When/Then
        do {
            try await mockHealthKitService.requestAuthorization()
            XCTFail("Expected HealthKitError.healthKitNotAvailable to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.healthKitNotAvailable)
            XCTAssertTrue(mockHealthKitService.requestAuthorizationCalled)
        } catch {
            XCTFail("Expected HealthKitError.healthKitNotAvailable, got \(error)")
        }
    }
    
    func testRequestAuthorizationPermissionDenied() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.permissionDenied
        
        // When/Then
        do {
            try await mockHealthKitService.requestAuthorization()
            XCTFail("Expected HealthKitError.permissionDenied to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.permissionDenied)
        } catch {
            XCTFail("Expected HealthKitError.permissionDenied, got \(error)")
        }
    }
    
    // MARK: - Workout Data Tests
    
    func testFetchWorkoutsSuccess() async throws {
        // Given
        let mockWorkouts = MockHealthKitService.createMockWorkouts()
        mockHealthKitService.mockWorkouts = mockWorkouts
        
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        
        // When
        let workouts = try await mockHealthKitService.fetchWorkouts(from: startDate, to: endDate)
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchWorkoutsCalled)
        XCTAssertEqual(workouts.count, mockWorkouts.count)
        
        // Verify workout data
        let runningWorkout = workouts.first { $0.workoutType == "Running" }
        XCTAssertNotNil(runningWorkout)
        XCTAssertEqual(runningWorkout?.totalEnergyBurned, 350)
        XCTAssertEqual(runningWorkout?.distance, 5000)
    }
    
    func testFetchWorkoutsWithDateFiltering() async throws {
        // Given
        let now = Date()
        let calendar = Calendar.current
        
        let recentWorkout = MockHealthKitService.createMockWorkout(
            type: "Running",
            startDate: calendar.date(byAdding: .hour, value: -1, to: now)!
        )
        
        let oldWorkout = MockHealthKitService.createMockWorkout(
            type: "Cycling",
            startDate: calendar.date(byAdding: .day, value: -10, to: now)!
        )
        
        mockHealthKitService.mockWorkouts = [recentWorkout, oldWorkout]
        
        let startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let endDate = now
        
        // When
        let workouts = try await mockHealthKitService.fetchWorkouts(from: startDate, to: endDate)
        
        // Then
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.workoutType, "Running")
    }
    
    func testFetchWorkoutsError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("Network error")
        
        // When/Then
        do {
            _ = try await mockHealthKitService.fetchWorkouts(from: Date(), to: Date())
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.dataFetchFailed("Network error"))
        } catch {
            XCTFail("Expected HealthKitError, got \(error)")
        }
    }
    
    // MARK: - Active Energy Tests
    
    func testFetchActiveEnergySuccess() async throws {
        // Given
        let expectedEnergy = 450.0
        mockHealthKitService.mockActiveEnergy = expectedEnergy
        
        // When
        let energy = try await mockHealthKitService.fetchActiveEnergy(for: Date())
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchActiveEnergyCalled)
        XCTAssertEqual(energy, expectedEnergy)
    }
    
    func testFetchActiveEnergyError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("Permission denied")
        
        // When/Then
        do {
            _ = try await mockHealthKitService.fetchActiveEnergy(for: Date())
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.dataFetchFailed("Permission denied"))
        } catch {
            XCTFail("Expected HealthKitError, got \(error)")
        }
    }
    
    // MARK: - Weight Data Tests
    
    func testFetchWeightSuccess() async throws {
        // Given
        let expectedWeight = 70.5
        mockHealthKitService.mockWeight = expectedWeight
        
        // When
        let weight = try await mockHealthKitService.fetchWeight()
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchWeightCalled)
        XCTAssertEqual(weight, expectedWeight)
    }
    
    func testFetchWeightNoData() async throws {
        // Given
        mockHealthKitService.mockWeight = nil
        
        // When
        let weight = try await mockHealthKitService.fetchWeight()
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchWeightCalled)
        XCTAssertNil(weight)
    }
    
    func testFetchWeightError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataTypeNotAvailable
        
        // When/Then
        do {
            _ = try await mockHealthKitService.fetchWeight()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.dataTypeNotAvailable)
        } catch {
            XCTFail("Expected HealthKitError, got \(error)")
        }
    }
    
    // MARK: - Reactive Observing Tests
    
    func testObserveWeightChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Weight change observed")
        var receivedWeight: Double?
        
        // When
        mockHealthKitService.observeWeightChanges()
            .sink { weight in
                receivedWeight = weight
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate weight change
        let newWeight = 72.0
        mockHealthKitService.simulateWeightChange(newWeight)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHealthKitService.observeWeightChangesCalled)
        XCTAssertEqual(receivedWeight, newWeight)
    }
    
    func testObserveWorkouts() {
        // Given
        let expectation = XCTestExpectation(description: "Workouts observed")
        var receivedWorkouts: [WorkoutData]?
        
        // When
        mockHealthKitService.observeWorkouts()
            .sink { workouts in
                receivedWorkouts = workouts
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate workout update
        let newWorkouts = MockHealthKitService.createMockWorkouts()
        mockHealthKitService.simulateWorkoutUpdate(newWorkouts)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHealthKitService.observeWorkoutsCalled)
        XCTAssertEqual(receivedWorkouts?.count, newWorkouts.count)
    }
    
    // MARK: - Properties Tests
    
    func testIsHealthKitAvailable() {
        // Given
        mockHealthKitService.mockIsHealthKitAvailable = true
        
        // When/Then
        XCTAssertTrue(mockHealthKitService.isHealthKitAvailable)
        
        // Given
        mockHealthKitService.mockIsHealthKitAvailable = false
        
        // When/Then
        XCTAssertFalse(mockHealthKitService.isHealthKitAvailable)
    }
    
    func testAuthorizationStatus() {
        // Given
        mockHealthKitService.mockAuthorizationStatus = .sharingAuthorized
        
        // When/Then
        XCTAssertEqual(mockHealthKitService.authorizationStatus, .sharingAuthorized)
        
        // Given
        mockHealthKitService.mockAuthorizationStatus = .sharingDenied
        
        // When/Then
        XCTAssertEqual(mockHealthKitService.authorizationStatus, .sharingDenied)
    }
    
    // MARK: - Error Handling Tests
    
    func testHealthKitErrorDescriptions() {
        let errors: [HealthKitError] = [
            .healthKitNotAvailable,
            .authorizationNotDetermined,
            .authorizationFailed("Test failure"),
            .dataTypeNotAvailable,
            .dataFetchFailed("Test fetch failure"),
            .permissionDenied
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - Mock Data Tests
    
    func testMockWorkoutCreation() {
        // Given
        let startDate = Date()
        let duration: TimeInterval = 1800 // 30 minutes
        let energyBurned = 300.0
        let distance = 5000.0
        
        // When
        let workout = MockHealthKitService.createMockWorkout(
            type: "Running",
            startDate: startDate,
            duration: duration,
            energyBurned: energyBurned,
            distance: distance
        )
        
        // Then
        XCTAssertEqual(workout.workoutType, "Running")
        XCTAssertEqual(workout.startDate, startDate)
        XCTAssertEqual(workout.duration, duration)
        XCTAssertEqual(workout.totalEnergyBurned, energyBurned)
        XCTAssertEqual(workout.distance, distance)
        XCTAssertEqual(workout.source, "Mock Fitness App")
    }
    
    func testMockWorkoutsCreation() {
        // When
        let workouts = MockHealthKitService.createMockWorkouts()
        
        // Then
        XCTAssertEqual(workouts.count, 3)
        
        let workoutTypes = workouts.map { $0.workoutType }
        XCTAssertTrue(workoutTypes.contains("Running"))
        XCTAssertTrue(workoutTypes.contains("Cycling"))
        XCTAssertTrue(workoutTypes.contains("Strength Training"))
    }
    
    // MARK: - Integration Scenario Tests
    
    func testCompleteHealthKitWorkflow() async throws {
        // Given - Fresh service
        mockHealthKitService.reset()
        
        // When - Request authorization
        try await mockHealthKitService.requestAuthorization()
        
        // Then - Authorization should be granted
        XCTAssertEqual(mockHealthKitService.authorizationStatus, .sharingAuthorized)
        
        // When - Set up mock data
        mockHealthKitService.mockWeight = 75.0
        mockHealthKitService.mockActiveEnergy = 400.0
        mockHealthKitService.mockWorkouts = MockHealthKitService.createMockWorkouts()
        
        // Then - Fetch all data types
        let weight = try await mockHealthKitService.fetchWeight()
        let energy = try await mockHealthKitService.fetchActiveEnergy(for: Date())
        let workouts = try await mockHealthKitService.fetchWorkouts(from: Date().addingTimeInterval(-86400), to: Date())
        
        XCTAssertEqual(weight, 75.0)
        XCTAssertEqual(energy, 400.0)
        XCTAssertEqual(workouts.count, 3)
    }
    
    func testErrorRecoveryScenario() async {
        // Given - Service that initially fails
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.dataFetchFailed("Network error")
        
        // When - First attempt fails
        do {
            _ = try await mockHealthKitService.fetchWeight()
            XCTFail("Expected error")
        } catch {
            // Expected failure
        }
        
        // When - Service recovers
        mockHealthKitService.shouldThrowError = false
        mockHealthKitService.mockWeight = 70.0
        
        // Then - Second attempt succeeds
        do {
            let weight = try await mockHealthKitService.fetchWeight()
            XCTAssertEqual(weight, 70.0)
        } catch {
            XCTFail("Expected success after recovery")
        }
    }
}