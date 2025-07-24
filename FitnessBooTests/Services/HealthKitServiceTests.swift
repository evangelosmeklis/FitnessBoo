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
   
    // MARK: - Background Sync Tests
    
    func testStartBackgroundSync() {
        // Given
        XCTAssertFalse(mockHealthKitService.isBackgroundSyncActive)
        
        // When
        mockHealthKitService.startBackgroundSync()
        
        // Then
        XCTAssertTrue(mockHealthKitService.startBackgroundSyncCalled)
        XCTAssertTrue(mockHealthKitService.isBackgroundSyncActive)
    }
    
    func testStopBackgroundSync() {
        // Given
        mockHealthKitService.startBackgroundSync()
        XCTAssertTrue(mockHealthKitService.isBackgroundSyncActive)
        
        // When
        mockHealthKitService.stopBackgroundSync()
        
        // Then
        XCTAssertTrue(mockHealthKitService.stopBackgroundSyncCalled)
        XCTAssertFalse(mockHealthKitService.isBackgroundSyncActive)
    }
    
    func testManualRefreshSuccess() async throws {
        // Given
        mockHealthKitService.shouldThrowError = false
        XCTAssertNil(mockHealthKitService.lastSyncDate)
        
        // When
        try await mockHealthKitService.manualRefresh()
        
        // Then
        XCTAssertTrue(mockHealthKitService.manualRefreshCalled)
        XCTAssertNotNil(mockHealthKitService.lastSyncDate)
    }
    
    func testManualRefreshError() async {
        // Given
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.syncFailed("Network unavailable")
        
        // When/Then
        do {
            try await mockHealthKitService.manualRefresh()
            XCTFail("Expected sync error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, HealthKitError.syncFailed("Network unavailable"))
            XCTAssertTrue(mockHealthKitService.manualRefreshCalled)
        } catch {
            XCTFail("Expected HealthKitError, got \(error)")
        }
    }
    
    // MARK: - Sync Status Tests
    
    func testSyncStatusObservation() {
        // Given
        let expectation = XCTestExpectation(description: "Sync status observed")
        var receivedStatuses: [SyncStatus] = []
        
        // When
        mockHealthKitService.syncStatus
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate status changes
        mockHealthKitService.simulateSyncStatusChange(.syncing)
        mockHealthKitService.simulateSyncStatusChange(.success(Date()))
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedStatuses.count, 3) // idle (initial) + syncing + success
        
        if case .idle = receivedStatuses[0] {} else {
            XCTFail("Expected initial status to be idle")
        }
        if case .syncing = receivedStatuses[1] {} else {
            XCTFail("Expected second status to be syncing")
        }
        if case .success = receivedStatuses[2] {} else {
            XCTFail("Expected third status to be success")
        }
    }
    
    func testSyncStatusProperties() {
        // Test idle status
        let idleStatus = SyncStatus.idle
        XCTAssertFalse(idleStatus.isActive)
        XCTAssertNil(idleStatus.lastSyncDate)
        XCTAssertNil(idleStatus.error)
        
        // Test syncing status
        let syncingStatus = SyncStatus.syncing
        XCTAssertTrue(syncingStatus.isActive)
        XCTAssertNil(syncingStatus.lastSyncDate)
        XCTAssertNil(syncingStatus.error)
        
        // Test success status
        let successDate = Date()
        let successStatus = SyncStatus.success(successDate)
        XCTAssertFalse(successStatus.isActive)
        XCTAssertEqual(successStatus.lastSyncDate, successDate)
        XCTAssertNil(successStatus.error)
        
        // Test failed status
        let testError = HealthKitError.syncFailed("Test error")
        let failedStatus = SyncStatus.failed(testError)
        XCTAssertFalse(failedStatus.isActive)
        XCTAssertNil(failedStatus.lastSyncDate)
        XCTAssertNotNil(failedStatus.error)
    }
    
    // MARK: - Data Source Priority Tests
    
    func testDataSourcePriorityValues() {
        XCTAssertEqual(DataSourcePriority.healthKit.rawValue, 1)
        XCTAssertEqual(DataSourcePriority.appleWatch.rawValue, 2)
        XCTAssertEqual(DataSourcePriority.thirdPartyApp.rawValue, 3)
        XCTAssertEqual(DataSourcePriority.manualEntry.rawValue, 4)
    }
    
    func testDataSourcePriorityDisplayNames() {
        XCTAssertEqual(DataSourcePriority.healthKit.displayName, "Health App")
        XCTAssertEqual(DataSourcePriority.appleWatch.displayName, "Apple Watch")
        XCTAssertEqual(DataSourcePriority.thirdPartyApp.displayName, "Third Party App")
        XCTAssertEqual(DataSourcePriority.manualEntry.displayName, "Manual Entry")
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolutionStrategy() {
        let strategies: [ConflictResolutionStrategy] = [
            .mostRecentFromHighestPriority,
            .mostRecent,
            .highestPriority,
            .userChoice
        ]
        
        // Ensure all strategies are testable
        XCTAssertEqual(strategies.count, 4)
    }
    
    // MARK: - Background Sync Integration Tests
    
    func testBackgroundSyncDataUpdates() {
        // Given
        let weightExpectation = XCTestExpectation(description: "Weight updated via background sync")
        let workoutExpectation = XCTestExpectation(description: "Workouts updated via background sync")
        
        var receivedWeight: Double?
        var receivedWorkouts: [WorkoutData]?
        
        // Set up observers
        mockHealthKitService.observeWeightChanges()
            .sink { weight in
                receivedWeight = weight
                weightExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        mockHealthKitService.observeWorkouts()
            .sink { workouts in
                receivedWorkouts = workouts
                workoutExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHealthKitService.startBackgroundSync()
        mockHealthKitService.mockWeight = 68.5
        mockHealthKitService.mockWorkouts = MockHealthKitService.createMockWorkouts()
        mockHealthKitService.simulateBackgroundSync()
        
        // Then
        wait(for: [weightExpectation, workoutExpectation], timeout: 2.0)
        XCTAssertEqual(receivedWeight, 68.5)
        XCTAssertEqual(receivedWorkouts?.count, 3)
        XCTAssertNotNil(mockHealthKitService.lastSyncDate)
    }
    
    func testSyncReliabilityWithRetries() async {
        // Given - Service that fails initially but succeeds on retry
        var attemptCount = 0
        mockHealthKitService.shouldThrowError = true
        mockHealthKitService.errorToThrow = HealthKitError.syncFailed("Temporary network error")
        
        // When - First attempt fails
        do {
            try await mockHealthKitService.manualRefresh()
            XCTFail("Expected first attempt to fail")
        } catch {
            attemptCount += 1
        }
        
        // When - Service recovers and retry succeeds
        mockHealthKitService.shouldThrowError = false
        
        do {
            try await mockHealthKitService.manualRefresh()
            attemptCount += 1
        } catch {
            XCTFail("Expected retry to succeed")
        }
        
        // Then
        XCTAssertEqual(attemptCount, 2)
        XCTAssertNotNil(mockHealthKitService.lastSyncDate)
    }
    
    // MARK: - Performance Tests
    
    func testSyncPerformanceWithLargeDataset() {
        // Given
        let largeWorkoutSet = (0..<100).map { index in
            MockHealthKitService.createMockWorkout(
                type: "Running",
                startDate: Date().addingTimeInterval(TimeInterval(-index * 3600)),
                energyBurned: Double(200 + index)
            )
        }
        
        mockHealthKitService.mockWorkouts = largeWorkoutSet
        
        // When - Measure sync performance
        measure {
            mockHealthKitService.simulateBackgroundSync()
        }
        
        // Then - Verify data integrity
        XCTAssertEqual(mockHealthKitService.mockWorkouts.count, 100)
    }
    
    // MARK: - Error Recovery Tests
    
    func testSyncErrorRecovery() {
        // Given
        let errorExpectation = XCTestExpectation(description: "Sync error observed")
        let successExpectation = XCTestExpectation(description: "Sync success observed")
        
        var statusUpdates: [SyncStatus] = []
        
        mockHealthKitService.syncStatus
            .sink { status in
                statusUpdates.append(status)
                
                if case .failed = status {
                    errorExpectation.fulfill()
                } else if case .success = status {
                    successExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Simulate error then recovery
        let testError = HealthKitError.syncFailed("Network timeout")
        mockHealthKitService.simulateSyncStatusChange(.failed(testError))
        
        let successDate = Date()
        mockHealthKitService.simulateSyncStatusChange(.success(successDate))
        
        // Then
        wait(for: [errorExpectation, successExpectation], timeout: 2.0)
        XCTAssertTrue(statusUpdates.count >= 3) // idle + failed + success
        
        // Verify error status
        let failedStatus = statusUpdates.first { status in
            if case .failed = status { return true }
            return false
        }
        XCTAssertNotNil(failedStatus)
        
        // Verify success status
        let successStatus = statusUpdates.first { status in
            if case .success = status { return true }
            return false
        }
        XCTAssertNotNil(successStatus)
    }
    
    // MARK: - Enhanced Error Tests
    
    func testEnhancedHealthKitErrors() {
        let enhancedErrors: [HealthKitError] = [
            .syncFailed("Network error"),
            .conflictResolutionFailed("Multiple sources"),
            .backgroundSyncUnavailable
        ]
        
        for error in enhancedErrors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - Complete Sync Workflow Tests
    
    func testCompleteSyncWorkflow() async throws {
        // Given - Fresh service setup
        mockHealthKitService.reset()
        
        let syncStatusExpectation = XCTestExpectation(description: "Sync status progression")
        var statusProgression: [SyncStatus] = []
        
        mockHealthKitService.syncStatus
            .sink { status in
                statusProgression.append(status)
                if statusProgression.count >= 3 { // idle -> syncing -> success
                    syncStatusExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Complete workflow
        // 1. Request authorization (triggers initial sync)
        try await mockHealthKitService.requestAuthorization()
        
        // 2. Start background sync
        mockHealthKitService.startBackgroundSync()
        
        // 3. Perform manual refresh
        try await mockHealthKitService.manualRefresh()
        
        // Then - Verify workflow completion
        wait(for: [syncStatusExpectation], timeout: 3.0)
        
        XCTAssertTrue(mockHealthKitService.requestAuthorizationCalled)
        XCTAssertTrue(mockHealthKitService.startBackgroundSyncCalled)
        XCTAssertTrue(mockHealthKitService.manualRefreshCalled)
        XCTAssertTrue(mockHealthKitService.isBackgroundSyncActive)
        XCTAssertNotNil(mockHealthKitService.lastSyncDate)
        
        // Verify status progression
        XCTAssertTrue(statusProgression.count >= 3)
        if case .idle = statusProgression[0] {} else {
            XCTFail("Expected initial status to be idle")
        }
    }    

    // MARK: - Energy Fetching Tests
    
    func testFetchRestingEnergySuccess() async throws {
        // Given
        let expectedRestingEnergy = 1600.0
        mockHealthKitService.mockRestingEnergy = expectedRestingEnergy
        
        // When
        let restingEnergy = try await mockHealthKitService.fetchRestingEnergy(for: Date())
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchRestingEnergyCalled)
        XCTAssertEqual(restingEnergy, expectedRestingEnergy)
    }
    
    func testFetchTotalEnergyExpendedSuccess() async throws {
        // Given
        mockHealthKitService.mockActiveEnergy = 400.0
        mockHealthKitService.mockRestingEnergy = 1600.0
        
        // When
        let totalEnergy = try await mockHealthKitService.fetchTotalEnergyExpended(for: Date())
        
        // Then
        XCTAssertTrue(mockHealthKitService.fetchTotalEnergyExpendedCalled)
        XCTAssertEqual(totalEnergy, 2000.0)
    }
    
    func testObserveEnergyChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Energy changes observed")
        var receivedEnergyData: (resting: Double, active: Double)?
        
        // When
        mockHealthKitService.observeEnergyChanges()
            .sink { energyData in
                receivedEnergyData = energyData
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate energy change
        mockHealthKitService.simulateEnergyChange(active: 450.0, resting: 1550.0)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHealthKitService.observeEnergyChangesCalled)
        XCTAssertEqual(receivedEnergyData?.active, 450.0)
        XCTAssertEqual(receivedEnergyData?.resting, 1550.0)
    }
    
    func testEnergyDataIntegration() async throws {
        // Given
        mockHealthKitService.mockActiveEnergy = 350.0
        mockHealthKitService.mockRestingEnergy = 1450.0
        
        // When - Fetch both energy types
        async let activeEnergy = mockHealthKitService.fetchActiveEnergy(for: Date())
        async let restingEnergy = mockHealthKitService.fetchRestingEnergy(for: Date())
        async let totalEnergy = mockHealthKitService.fetchTotalEnergyExpended(for: Date())
        
        let (active, resting, total) = try await (activeEnergy, restingEnergy, totalEnergy)
        
        // Then
        XCTAssertEqual(active, 350.0)
        XCTAssertEqual(resting, 1450.0)
        XCTAssertEqual(total, 1800.0)
        XCTAssertTrue(mockHealthKitService.fetchActiveEnergyCalled)
        XCTAssertTrue(mockHealthKitService.fetchRestingEnergyCalled)
        XCTAssertTrue(mockHealthKitService.fetchTotalEnergyExpendedCalled)
    }