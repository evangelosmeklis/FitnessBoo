//
//  HealthKitService.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import HealthKit
import Combine

// MARK: - Sync Status
enum SyncStatus {
    case idle
    case syncing
    case success(Date)
    case failed(Error)
    
    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
    
    var lastSyncDate: Date? {
        if case .success(let date) = self { return date }
        return nil
    }
    
    var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

// MARK: - Data Source Priority
enum DataSourcePriority: Int, CaseIterable {
    case healthKit = 1
    case appleWatch = 2
    case thirdPartyApp = 3
    case manualEntry = 4
    
    var displayName: String {
        switch self {
        case .healthKit: return "Health App"
        case .appleWatch: return "Apple Watch"
        case .thirdPartyApp: return "Third Party App"
        case .manualEntry: return "Manual Entry"
        }
    }
}

// MARK: - Sync Configuration
struct SyncConfiguration {
    let backgroundSyncInterval: TimeInterval = 300 // 5 minutes
    let maxRetryAttempts: Int = 3
    let retryDelay: TimeInterval = 30
    let conflictResolutionStrategy: ConflictResolutionStrategy = .mostRecentFromHighestPriority
}

enum ConflictResolutionStrategy {
    case mostRecentFromHighestPriority
    case mostRecent
    case highestPriority
    case userChoice
}

// MARK: - HealthKit Service Protocol
protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func saveDietaryEnergy(calories: Double, date: Date) async throws
    func saveDietaryProtein(protein: Double, date: Date) async throws
    func saveDietaryCarbs(carbs: Double, date: Date) async throws
    func saveDietaryFats(fats: Double, date: Date) async throws
    func saveWater(milliliters: Double, date: Date) async throws
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData]
    func fetchActiveEnergy(for date: Date) async throws -> Double
    func fetchRestingEnergy(for date: Date) async throws -> Double
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double
    func fetchWeight() async throws -> Double?
    func saveWeight(_ weight: Double, date: Date) async throws
    func fetchDietaryEnergy(from startDate: Date, to endDate: Date) async throws -> Double
    func fetchDietaryProtein(from startDate: Date, to endDate: Date) async throws -> Double
    func fetchDietaryWater(from startDate: Date, to endDate: Date) async throws -> Double
    func observeWeightChanges() -> AnyPublisher<Double, Never>
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never>
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never>
    func manualRefresh() async throws
    func startBackgroundSync()
    func stopBackgroundSync()
    var isHealthKitAvailable: Bool { get }
    var authorizationStatus: HKAuthorizationStatus { get }
    var syncStatus: AnyPublisher<SyncStatus, Never> { get }
    var lastSyncDate: Date? { get }
}

// MARK: - HealthKit Service Implementation
@MainActor
class HealthKitService: HealthKitServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    private let syncConfiguration = SyncConfiguration()
    
    // Publishers for reactive updates
    private let weightSubject = PassthroughSubject<Double, Never>()
    private let workoutsSubject = PassthroughSubject<[WorkoutData], Never>()
    private let energySubject = PassthroughSubject<(resting: Double, active: Double), Never>()
    private let syncStatusSubject = CurrentValueSubject<SyncStatus, Never>(.idle)
    
    // Background sync management
    private var backgroundSyncTimer: Timer?
    private var isBackgroundSyncActive = false
    private var retryCount = 0
    
    // Sync tracking
    @Published private var _lastSyncDate: Date?
    private var observerQueries: [HKObserverQuery] = []
    
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
    
    // MARK: - HealthKit Status Check
    func checkHealthKitStatus() -> (available: Bool, authorized: Bool, message: String) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (false, false, "HealthKit is not available on this device. The app will use calculated values instead.")
        }
        
        // Note: Per Apple docs, we can't determine if read permissions were granted
        // We can only check write permissions and see what data we actually receive
        let writeTypes = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein)
        ]
        
        let writeAuthorized = writeTypes.allSatisfy { type in
            healthStore.authorizationStatus(for: type) == .sharingAuthorized
        }
        
        if writeAuthorized {
            return (true, true, "HealthKit is configured. Energy data will be available if permissions were granted.")
        } else {
            return (true, false, "HealthKit permissions may be limited. Some features may not work optimally.")
        }
    }
    
    // MARK: - Authorization Status Check
    func checkAuthorizationStatus(for sampleType: HKSampleType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: sampleType)
    }
    
    // MARK: - Save Data with Authorization Check
    func saveSample(_ sample: HKSample) async throws {
        let authStatus = healthStore.authorizationStatus(for: sample.sampleType)
        
        print("🔍 HealthKit Authorization Status for \(sample.sampleType): \(authStatus.rawValue)")
        
        switch authStatus {
        case .notDetermined:
            print("❌ HealthKit authorization not determined for \(sample.sampleType)")
            throw HealthKitError.authorizationNotDetermined
        case .sharingDenied:
            print("❌ HealthKit sharing denied for \(sample.sampleType)")
            throw HealthKitError.permissionDenied
        case .sharingAuthorized:
            print("✅ HealthKit sharing authorized for \(sample.sampleType), attempting save...")
            try await healthStore.save(sample)
            print("✅ Sample saved successfully to HealthKit")
        @unknown default:
            print("❓ Unknown HealthKit authorization status for \(sample.sampleType)")
            throw HealthKitError.authorizationNotDetermined
        }
    }
    
    var syncStatus: AnyPublisher<SyncStatus, Never> {
        return syncStatusSubject.eraseToAnyPublisher()
    }
    
    var lastSyncDate: Date? {
        return _lastSyncDate
    }
    
    // MARK: - Data Types
    private var readTypes: Set<HKObjectType> {
        let types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate)
        ]
        return types
    }
    
    private var writeTypes: Set<HKSampleType> {
        let types: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.bodyMass)
        ]
        return types
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        // Check that Health data is available on the device
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        syncStatusSubject.send(.syncing)
        
        do {
            // Asynchronously request authorization to the data
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            // Check authorization status for key data types
            let energyTypes = [
                HKQuantityType(.activeEnergyBurned),
                HKQuantityType(.basalEnergyBurned)
            ]
            
            // Note: Per Apple docs, we can't know if read permission was granted or denied
            // The app will only receive data that it has permission to read
            
            // Start observing changes after authorization request
            startObservingHealthData()
            startBackgroundSync()
            
            // Perform initial sync
            try await performInitialSync()
            
            syncStatusSubject.send(.success(Date()))
            
        } catch {
            // Typically, authorization requests only fail if you haven't set the
            // usage and share descriptions in your app's Info.plist, or if
            // Health data isn't available on the current device.
            let healthKitError = error as? HealthKitError ?? HealthKitError.authorizationFailed(error.localizedDescription)
            syncStatusSubject.send(.failed(healthKitError))
            throw healthKitError
        }
    }
    
    // MARK: - Save to HealthKit
    
    func saveDietaryEnergy(calories: Double, date: Date) async throws {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let energySample = HKQuantitySample(type: energyType, quantity: energyQuantity, start: date, end: date)
        
        try await saveSample(energySample)
    }
    
    func saveDietaryProtein(protein: Double, date: Date) async throws {
        guard let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let proteinQuantity = HKQuantity(unit: .gram(), doubleValue: protein)
        let proteinSample = HKQuantitySample(type: proteinType, quantity: proteinQuantity, start: date, end: date)

        try await saveSample(proteinSample)
    }

    func saveDietaryCarbs(carbs: Double, date: Date) async throws {
        guard let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let carbsQuantity = HKQuantity(unit: .gram(), doubleValue: carbs)
        let carbsSample = HKQuantitySample(type: carbsType, quantity: carbsQuantity, start: date, end: date)

        try await saveSample(carbsSample)
    }

    func saveDietaryFats(fats: Double, date: Date) async throws {
        guard let fatsType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let fatsQuantity = HKQuantity(unit: .gram(), doubleValue: fats)
        let fatsSample = HKQuantitySample(type: fatsType, quantity: fatsQuantity, start: date, end: date)

        try await saveSample(fatsSample)
    }

    func saveWater(milliliters: Double, date: Date) async throws {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let waterQuantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let waterSample = HKQuantitySample(type: waterType, quantity: waterQuantity, start: date, end: date)

        try await saveSample(waterSample)
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
    
    func fetchRestingEnergy(for date: Date) async throws -> Double {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }
        
        guard let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: basalEnergyType,
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
    
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double {
        async let activeEnergy = fetchActiveEnergy(for: date)
        async let restingEnergy = fetchRestingEnergy(for: date)
        
        let (active, resting) = try await (activeEnergy, restingEnergy)
        return active + resting
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
    
    func saveWeight(_ weight: Double, date: Date) async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        // Create weight quantity in kilograms
        let weightQuantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight)

        // Create weight sample
        let weightSample = HKQuantitySample(
            type: bodyMassType,
            quantity: weightQuantity,
            start: date,
            end: date
        )

        // Use the saveSample method which includes authorization checks
        try await saveSample(weightSample)
    }

    // MARK: - Historical Dietary Data Fetching

    func fetchDietaryEnergy(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        return try await fetchDietaryQuantity(type: energyType, unit: .kilocalorie(), from: startDate, to: endDate)
    }

    func fetchDietaryProtein(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        return try await fetchDietaryQuantity(type: proteinType, unit: .gram(), from: startDate, to: endDate)
    }

    func fetchDietaryWater(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        return try await fetchDietaryQuantity(type: waterType, unit: .literUnit(with: .milli), from: startDate, to: endDate)
    }

    private func fetchDietaryQuantity(type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double {
        guard isHealthKitAvailable else {
            return 0.0 // Return 0 instead of throwing for unavailable HealthKit
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                // Silently return 0 for errors (like no data available)
                // This is expected for days with no logged data
                if error != nil {
                    continuation.resume(returning: 0.0)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: 0.0)
                    return
                }

                let value = sum.doubleValue(for: unit)
                continuation.resume(returning: value)
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
    
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never> {
        return energySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Background Sync Management
    func startBackgroundSync() {
        guard !isBackgroundSyncActive else { return }
        
        isBackgroundSyncActive = true
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: syncConfiguration.backgroundSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundSync()
            }
        }
    }
    
    func stopBackgroundSync() {
        isBackgroundSyncActive = false
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
    }
    
    func manualRefresh() async throws {
        syncStatusSubject.send(.syncing)
        
        do {
            try await performFullSync()
            let now = Date()
            _lastSyncDate = now
            syncStatusSubject.send(.success(now))
            retryCount = 0
        } catch {
            syncStatusSubject.send(.failed(error))
            throw error
        }
    }
    
    // MARK: - Private Sync Methods
    private func performInitialSync() async throws {
        try await performFullSync()
        let now = Date()
        _lastSyncDate = now
        syncStatusSubject.send(.success(now))
    }
    
    private func performBackgroundSync() async {
        guard isBackgroundSyncActive else { return }
        
        do {
            try await performIncrementalSync()
            let now = Date()
            _lastSyncDate = now
            syncStatusSubject.send(.success(now))
            retryCount = 0
        } catch {
            retryCount += 1
            syncStatusSubject.send(.failed(error))
            
            if retryCount < syncConfiguration.maxRetryAttempts {
                // Schedule retry
                DispatchQueue.main.asyncAfter(deadline: .now() + syncConfiguration.retryDelay) {
                    Task { @MainActor in
                        await self.performBackgroundSync()
                    }
                }
            }
        }
    }
    
    private func performFullSync() async throws {
        // Sync last 30 days of data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        async let workouts = fetchWorkouts(from: startDate, to: endDate)
        async let weight = fetchWeight()
        async let activeEnergy = fetchActiveEnergy(for: endDate)
        async let restingEnergy = fetchRestingEnergy(for: endDate)
        
        let (fetchedWorkouts, fetchedWeight, fetchedActive, fetchedResting) = try await (workouts, weight, activeEnergy, restingEnergy)
        
        // Process and resolve conflicts
        let resolvedWorkouts = try await resolveWorkoutConflicts(fetchedWorkouts)
        let resolvedWeight = try await resolveWeightConflicts(fetchedWeight)
        
        // Notify observers
        workoutsSubject.send(resolvedWorkouts)
        if let weight = resolvedWeight {
            weightSubject.send(weight)
        }
        energySubject.send((resting: fetchedResting, active: fetchedActive))
    }
    
    private func performIncrementalSync() async throws {
        let endDate = Date()
        let startDate = _lastSyncDate ?? Calendar.current.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        
        // Only sync recent data
        async let recentWorkouts = fetchWorkouts(from: startDate, to: endDate)
        async let currentWeight = fetchWeight()
        async let currentActiveEnergy = fetchActiveEnergy(for: endDate)
        async let currentRestingEnergy = fetchRestingEnergy(for: endDate)
        
        let (workouts, weight, activeEnergy, restingEnergy) = try await (recentWorkouts, currentWeight, currentActiveEnergy, currentRestingEnergy)
        
        if !workouts.isEmpty {
            let resolvedWorkouts = try await resolveWorkoutConflicts(workouts)
            workoutsSubject.send(resolvedWorkouts)
        }
        
        if let weight = weight {
            let resolvedWeight = try await resolveWeightConflicts(weight)
            if let weight = resolvedWeight {
                weightSubject.send(weight)
            }
        }
        
        // Always update energy data for real-time tracking
        energySubject.send((resting: restingEnergy, active: activeEnergy))
    }
    
    // MARK: - Conflict Resolution
    private func resolveWorkoutConflicts(_ newWorkouts: [WorkoutData]) async throws -> [WorkoutData] {
        // For now, implement simple strategy: prefer HealthKit data over manual entries
        // In a real implementation, this would integrate with Core Data to check existing data
        
        var resolvedWorkouts: [WorkoutData] = []
        
        for workout in newWorkouts {
            let priority = getDataSourcePriority(for: workout.source)
            
            // Check for conflicts (workouts at similar times)
            let conflictingWorkouts = newWorkouts.filter { other in
                other.id != workout.id &&
                abs(other.startDate.timeIntervalSince(workout.startDate)) < 300 && // Within 5 minutes
                other.workoutType == workout.workoutType
            }
            
            if conflictingWorkouts.isEmpty {
                resolvedWorkouts.append(workout)
            } else {
                // Apply conflict resolution strategy
                let bestWorkout = applyConflictResolution(workout, conflicts: conflictingWorkouts)
                if !resolvedWorkouts.contains(where: { $0.id == bestWorkout.id }) {
                    resolvedWorkouts.append(bestWorkout)
                }
            }
        }
        
        return resolvedWorkouts
    }
    
    private func resolveWeightConflicts(_ newWeight: Double?) async throws -> Double? {
        // Simple implementation - in real app would check against stored data
        return newWeight
    }
    
    private func applyConflictResolution(_ primary: WorkoutData, conflicts: [WorkoutData]) -> WorkoutData {
        let allWorkouts = [primary] + conflicts
        
        switch syncConfiguration.conflictResolutionStrategy {
        case .mostRecentFromHighestPriority:
            return allWorkouts
                .sorted { getDataSourcePriority(for: $0.source).rawValue < getDataSourcePriority(for: $1.source).rawValue }
                .sorted { $0.startDate > $1.startDate }
                .first ?? primary
            
        case .mostRecent:
            return allWorkouts.max { $0.startDate < $1.startDate } ?? primary
            
        case .highestPriority:
            return allWorkouts.min { getDataSourcePriority(for: $0.source).rawValue < getDataSourcePriority(for: $1.source).rawValue } ?? primary
            
        case .userChoice:
            // For now, default to highest priority - in real app would present UI choice
            return allWorkouts.min { getDataSourcePriority(for: $0.source).rawValue < getDataSourcePriority(for: $1.source).rawValue } ?? primary
        }
    }
    
    private func getDataSourcePriority(for sourceName: String) -> DataSourcePriority {
        if sourceName.lowercased().contains("health") {
            return .healthKit
        } else if sourceName.lowercased().contains("watch") {
            return .appleWatch
        } else if sourceName == "Manual Entry" {
            return .manualEntry
        } else {
            return .thirdPartyApp
        }
    }
    
    // MARK: - Observer Management
    private func startObservingHealthData() {
        // Clear existing observers
        observerQueries.forEach { healthStore.stop($0) }
        observerQueries.removeAll()
        
        observeWeightData()
        observeWorkoutData()
        observeEnergyData()
    }
    
    private func observeWeightData() {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let query = HKObserverQuery(sampleType: bodyMassType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            
            Task { @MainActor in
                do {
                    if let weight = try await self?.fetchWeight() {
                        let resolvedWeight = try await self?.resolveWeightConflicts(weight)
                        if let weight = resolvedWeight {
                            self?.weightSubject.send(weight)
                        }
                    }
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        observerQueries.append(query)
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
                    let resolvedWorkouts = try await self?.resolveWorkoutConflicts(workouts) ?? []
                    self?.workoutsSubject.send(resolvedWorkouts)
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        observerQueries.append(query)
        healthStore.execute(query)
    }
    
    private func observeEnergyData() {
        // Observe active energy changes
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let activeEnergyQuery = HKObserverQuery(sampleType: activeEnergyType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            
            Task { @MainActor in
                do {
                    let today = Date()
                    let activeEnergy = try await self?.fetchActiveEnergy(for: today) ?? 0.0
                    let restingEnergy = try await self?.fetchRestingEnergy(for: today) ?? 0.0
                    self?.energySubject.send((resting: restingEnergy, active: activeEnergy))
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        observerQueries.append(activeEnergyQuery)
        healthStore.execute(activeEnergyQuery)
        
        // Observe resting energy changes
        guard let restingEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }
        
        let restingEnergyQuery = HKObserverQuery(sampleType: restingEnergyType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            
            Task { @MainActor in
                do {
                    let today = Date()
                    let activeEnergy = try await self?.fetchActiveEnergy(for: today) ?? 0.0
                    let restingEnergy = try await self?.fetchRestingEnergy(for: today) ?? 0.0
                    self?.energySubject.send((resting: restingEnergy, active: activeEnergy))
                } catch {
                    // Handle error silently for observer
                }
            }
        }
        
        observerQueries.append(restingEnergyQuery)
        healthStore.execute(restingEnergyQuery)
    }
    
    deinit {
        // Clean up background sync
        isBackgroundSyncActive = false
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
        
        // Stop observer queries
        observerQueries.forEach { healthStore.stop($0) }
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
    case saveFailed(String)
    case syncFailed(String)
    case conflictResolutionFailed(String)
    case backgroundSyncUnavailable
    
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
        case .saveFailed(let message):
            return "Failed to save health data: \(message)"
        case .syncFailed(let message):
            return "Data synchronization failed: \(message)"
        case .conflictResolutionFailed(let message):
            return "Failed to resolve data conflicts: \(message)"
        case .backgroundSyncUnavailable:
            return "Background sync is not available"
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
        case .saveFailed:
            return "Please check that you have granted write permission for health data in Settings."
        case .syncFailed:
            return "Try refreshing manually or check your network connection."
        case .conflictResolutionFailed:
            return "Data conflicts detected. Please review and resolve manually in settings."
        case .backgroundSyncUnavailable:
            return "Enable background app refresh for continuous data sync."
        }
    }
}