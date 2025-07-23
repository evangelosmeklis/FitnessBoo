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
    var mockWeight: Double? = nil
    var shouldThrowError = false
    var errorToThrow: Error = HealthKitError.healthKitNotAvailable
    
    // MARK: - Publishers
    private let weightSubject = PassthroughSubject<Double, Never>()
    private let workoutsSubject = PassthroughSubject<[WorkoutData], Never>()
    
    // MARK: - Call Tracking
    var requestAuthorizationCalled = false
    var fetchWorkoutsCalled = false
    var fetchActiveEnergyCalled = false
    var fetchWeightCalled = false
    var observeWeightChangesCalled = false
    var observeWorkoutsCalled = false
    
    // MARK: - Protocol Implementation
    var isHealthKitAvailable: Bool {
        return mockIsHealthKitAvailable
    }
    
    var authorizationStatus: HKAuthorizationStatus {
        return mockAuthorizationStatus
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
    
    // MARK: - Test Helper Methods
    func simulateWeightChange(_ weight: Double) {
        mockWeight = weight
        weightSubject.send(weight)
    }
    
    func simulateWorkoutUpdate(_ workouts: [WorkoutData]) {
        mockWorkouts = workouts
        workoutsSubject.send(workouts)
    }
    
    func reset() {
        mockIsHealthKitAvailable = true
        mockAuthorizationStatus = .notDetermined
        mockWorkouts = []
        mockActiveEnergy = 0
        mockWeight = nil
        shouldThrowError = false
        errorToThrow = HealthKitError.healthKitNotAvailable
        
        requestAuthorizationCalled = false
        fetchWorkoutsCalled = false
        fetchActiveEnergyCalled = false
        fetchWeightCalled = false
        observeWeightChangesCalled = false
        observeWorkoutsCalled = false
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