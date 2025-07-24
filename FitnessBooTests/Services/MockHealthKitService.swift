//
//  MockHealthKitService.swift
//  FitnessBooTests
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import Combine
import HealthKit
@testable import FitnessBoo

class MockHealthKitService: HealthKitServiceProtocol {
    
    // MARK: - Mock Properties
    var mockIsHealthKitAvailable = true
    var mockAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    var mockWorkouts: [WorkoutData] = []
    var mockActiveEnergy: Double = 0
    var mockRestingEnergy: Double = 0
    var mockWeight: Double? = nil
    var shouldThrowError = false
    var errorToThrow: Error = HealthKitError.healthKitNotAvailable
    var mockLastSyncDate: Date?
    var isBackgroundSyncActive = false
    
    // MARK: - Publishers
    private let weightSubject = PassthroughSubject<Double, Never>()
    private let workoutsSubject = PassthroughSubject<[WorkoutData], Never>()
    private let energySubject = PassthroughSubject<(resting: Double, active: Double), Never>()
    private let syncStatusSubject = CurrentValueSubject<SyncStatus, Never>(.idle)
    
    // MARK: - Call Tracking
    var requestAuthorizationCalled = false
    var fetchWorkoutsCalled = false
    var fetchActiveEnergyCalled = false
    var fetchRestingEnergyCalled = false
    var fetchTotalEnergyExpendedCalled = false
    var fetchWeightCalled = false
    var observeWeightChangesCalled = false
    var observeWorkoutsCalled = false
    var observeEnergyChangesCalled = false
    var manualRefreshCalled = false
    var startBackgroundSyncCalled = false
    var stopBackgroundSyncCalled = false
    
    // MARK: - Protocol Implementation
    var isHealthKitAvailable: Bool {
        return mockIsHealthKitAvailable
    }
    
    var authorizationStatus: HKAuthorizationStatus {
        return mockAuthorizationStatus
    }
    
    var syncStatus: AnyPublisher<SyncStatus, Never> {
        return syncStatusSubject.eraseToAnyPublisher()
    }
    
    var lastSyncDate: Date? {
        return mockLastSyncDate
    }
    
    func requestAuthorization() async throws {
        requestAuthorizationCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Simulate successful authorization
        mockAuthorizationStatus = .sharingAuthorized
    }
    
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] {
        fetchWorkoutsCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Filter mock workouts by date range
        return mockWorkouts.filter { workout in
            workout.startDate >= startDate && workout.startDate <= endDate
        }
    }
    
    func fetchActiveEnergy(for date: Date) async throws -> Double {
        fetchActiveEnergyCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockActiveEnergy
    }
    
    func fetchRestingEnergy(for date: Date) async throws -> Double {
        fetchRestingEnergyCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockRestingEnergy
    }
    
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double {
        fetchTotalEnergyExpendedCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockActiveEnergy + mockRestingEnergy
    }
    
    func fetchWeight() async throws -> Double? {
        fetchWeightCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockWeight
    }
    
    func observeWeightChanges() -> AnyPublisher<Double, Never> {
        observeWeightChangesCalled = true
        return weightSubject.eraseToAnyPublisher()
    }
    
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never> {
        observeWorkoutsCalled = true
        return workoutsSubject.eraseToAnyPublisher()
    }
    
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never> {
        observeEnergyChangesCalled = true
        return energySubject.eraseToAnyPublisher()
    }
    
    func manualRefresh() async throws {
        manualRefreshCalled = true
        
        if shouldThrowError {
            syncStatusSubject.send(.failed(errorToThrow))
            throw errorToThrow
        }
        
        // Simulate successful sync
        mockLastSyncDate = Date()
        syncStatusSubject.send(.success(mockLastSyncDate!))
    }
    
    func startBackgroundSync() {
        startBackgroundSyncCalled = true
        isBackgroundSyncActive = true
    }
    
    func stopBackgroundSync() {
        stopBackgroundSyncCalled = true
        isBackgroundSyncActive = false
    }
    
    // MARK: - Test Helper Methods
    func simulateWeightChange(_ weight: Double) {
        mockWeight = weight
        weightSubject.send(weight)
    }
    
    func simulateWorkoutUpdate(_ workouts: [WorkoutData]) {
        mockWorkouts = workouts
        workoutsSubject.send(workouts)
    }
    
    func simulateEnergyUpdate(resting: Double, active: Double) {
        mockRestingEnergy = resting
        mockActiveEnergy = active
        energySubject.send((resting: resting, active: active))
    }
    
    func simulateSyncStatusChange(_ status: SyncStatus) {
        syncStatusSubject.send(status)
    }
    
    func simulateBackgroundSync() {
        guard isBackgroundSyncActive else { return }
        
        // Simulate successful background sync
        mockLastSyncDate = Date()
        syncStatusSubject.send(.success(mockLastSyncDate!))
        
        // Trigger data updates
        if let weight = mockWeight {
            weightSubject.send(weight)
        }
        workoutsSubject.send(mockWorkouts)
        energySubject.send((resting: mockRestingEnergy, active: mockActiveEnergy))
    }
    
    func reset() {
        mockIsHealthKitAvailable = true
        mockAuthorizationStatus = .notDetermined
        mockWorkouts = []
        mockActiveEnergy = 0
        mockRestingEnergy = 0
        mockWeight = nil
        shouldThrowError = false
        errorToThrow = HealthKitError.healthKitNotAvailable
        mockLastSyncDate = nil
        isBackgroundSyncActive = false
        
        requestAuthorizationCalled = false
        fetchWorkoutsCalled = false
        fetchActiveEnergyCalled = false
        fetchRestingEnergyCalled = false
        fetchTotalEnergyExpendedCalled = false
        fetchWeightCalled = false
        observeWeightChangesCalled = false
        observeWorkoutsCalled = false
        observeEnergyChangesCalled = false
        manualRefreshCalled = false
        startBackgroundSyncCalled = false
        stopBackgroundSyncCalled = false
        
        syncStatusSubject.send(.idle)
    }
    
    // MARK: - Mock Data Generators
    static func createMockWorkout(
        type: String = "Running",
        startDate: Date = Date().addingTimeInterval(-3600), // 1 hour ago
        duration: TimeInterval = 1800, // 30 minutes
        energyBurned: Double = 300,
        distance: Double = 5000 // 5km
    ) -> WorkoutData {
        let endDate = startDate.addingTimeInterval(duration)
        return WorkoutData(
            workoutType: type,
            startDate: startDate,
            endDate: endDate,
            totalEnergyBurned: energyBurned,
            distance: distance,
            source: "Mock Fitness App"
        )
    }
    
    static func createMockWorkouts() -> [WorkoutData] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            createMockWorkout(
                type: "Running",
                startDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
                duration: 1800,
                energyBurned: 350,
                distance: 5000
            ),
            createMockWorkout(
                type: "Cycling",
                startDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                duration: 3600,
                energyBurned: 500,
                distance: 15000
            ),
            createMockWorkout(
                type: "Strength Training",
                startDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                duration: 2700,
                energyBurned: 250,
                distance: nil
            )
        ]
    }
}