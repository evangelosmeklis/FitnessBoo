//
//  HealthKitService.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import HealthKit
import Combine

// MARK: - HealthKit Service Protocol
protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData]
    func fetchActiveEnergy(for date: Date) async throws -> Double
    func fetchWeight() async throws -> Double?
    func observeWeightChanges() -> AnyPublisher<Double, Never>
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never>
    var isHealthKitAvailable: Bool { get }
    var authorizationStatus: HKAuthorizationStatus { get }
}

// MARK: - HealthKit Service Implementation
@MainActor
class HealthKitService: HealthKitServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Publishers for reactive updates
    private let weightSubject = PassthroughSubject<Double, Never>()
    private let workoutsSubject = PassthroughSubject<[WorkoutData], Never>()
    
    // MARK: - Public Properties
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    var authorizationStatus: HKAuthorizationStatus {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: bodyMassType)
    }
    
    // MARK: - Data Types
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        // Quantity types
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        
        // Workout type
        types.insert(HKObjectType.workoutType())
        
        return types
    }
    
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        if let dietaryEnergy = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(dietaryEnergy)
        }
        if let dietaryProtein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(dietaryProtein)
        }
        
        return types
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            // Check if we got the required permissions
            guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                throw HealthKitError.dataTypeNotAvailable
            }
            
            let status = healthStore.authorizationStatus(for: bodyMassType)
            if status == .notDetermined {
                throw HealthKitError.authorizationNotDetermined
            }
            
            // Start observing changes after authorization
            startObservingHealthData()
            
        } catch {
            if error is HealthKitError {
                throw error
            } else {
                throw HealthKitError.authorizationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Data Fetching
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataFetchFailed(error.localizedDescription))
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let workoutData = workouts.map { WorkoutData(from: $0) }
                continuation.resume(returning: workoutData)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchActiveEnergy(for date: Date) async throws -> Double {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataFetchFailed(error.localizedDescription))
                    return
                }
                
                let totalEnergy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
                continuation.resume(returning: totalEnergy)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchWeight() async throws -> Double? {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataFetchFailed(error.localizedDescription))
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: weight)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Reactive Observing
    func observeWeightChanges() -> AnyPublisher<Double, Never> {
        return weightSubject.eraseToAnyPublisher()
    }
    
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never> {
        return workoutsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func startObservingHealthData() {
        observeWeightData()
        observeWorkoutData()
    }
    
    private func observeWeightData() {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let query = HKObserverQuery(sampleType: bodyMassType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            
            Task { @MainActor in
                do {
                    if let weight = try await self?.fetchWeight() {
                        self?.weightSubject.send(weight)
                    }
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func observeWorkoutData() {
        let query = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            
            Task { @MainActor in
                do {
                    let today = Date()
                    let startOfDay = Calendar.current.startOfDay(for: today)
                    let workouts = try await self?.fetchWorkouts(from: startOfDay, to: today) ?? []
                    self?.workoutsSubject.send(workouts)
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        healthStore.execute(query)
    }
}

// MARK: - HealthKit Errors
enum HealthKitError: LocalizedError {
    case healthKitNotAvailable
    case authorizationNotDetermined
    case authorizationFailed(String)
    case dataTypeNotAvailable
    case dataFetchFailed(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationNotDetermined:
            return "HealthKit authorization status could not be determined"
        case .authorizationFailed(let message):
            return "HealthKit authorization failed: \(message)"
        case .dataTypeNotAvailable:
            return "Required health data type is not available"
        case .dataFetchFailed(let message):
            return "Failed to fetch health data: \(message)"
        case .permissionDenied:
            return "Health data access permission was denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is only available on iOS devices. Manual data entry is available as an alternative."
        case .authorizationNotDetermined, .authorizationFailed:
            return "Please grant permission to access health data in Settings > Privacy & Security > Health."
        case .dataTypeNotAvailable:
            return "This feature requires a newer version of iOS or is not supported on this device."
        case .dataFetchFailed:
            return "Please try again. If the problem persists, check your internet connection."
        case .permissionDenied:
            return "You can enable health data access in Settings > Privacy & Security > Health > FitnessBoo."
        }
    }
}