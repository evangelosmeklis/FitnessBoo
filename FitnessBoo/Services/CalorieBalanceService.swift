//
//  CalorieBalanceService.swift
//  FitnessBoo
//
//  Created by Kiro on 24/7/25.
//

import Foundation
import Combine

// MARK: - Calorie Balance Data
struct CalorieBalance {
    let date: Date
    let caloriesConsumed: Double
    let restingEnergyBurned: Double
    let activeEnergyBurned: Double
    let totalEnergyBurned: Double
    let calculatedBMR: Double
    let balance: Double
    let isUsingHealthKitData: Bool
    
    var totalEnergyExpended: Double {
        return restingEnergyBurned + activeEnergyBurned
    }
    
    var isPositiveBalance: Bool {
        return balance > 0
    }
    
    var formattedBalance: String {
        let sign = balance >= 0 ? "+" : ""
        return "\(sign)\(Int(balance)) kcal"
    }
    
    var balanceDescription: String {
        if balance > 0 {
            return "Caloric Surplus"
        } else if balance < 0 {
            return "Caloric Deficit"
        } else {
            return "Balanced"
        }
    }
    
    var energySourceDescription: String {
        return isUsingHealthKitData ? "Health App Data" : "Calculated BMR"
    }
}

// MARK: - Calorie Balance Service Protocol
protocol CalorieBalanceServiceProtocol {
    func startRealTimeTracking()
    func stopRealTimeTracking()
    func getCurrentBalance() async -> CalorieBalance?
    func getBalanceForDate(_ date: Date) async -> CalorieBalance?
    var currentBalance: AnyPublisher<CalorieBalance?, Never> { get }
    var isTracking: Bool { get }
}

// MARK: - Calorie Balance Service Implementation
@MainActor
class CalorieBalanceService: CalorieBalanceServiceProtocol, ObservableObject {
    
    // MARK: - Dependencies
    private let healthKitService: HealthKitServiceProtocol
    private let calculationService: CalculationServiceProtocol
    private let dataService: DataServiceProtocol
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let balanceSubject = CurrentValueSubject<CalorieBalance?, Never>(nil)
    private var trackingTimer: Timer?
    
    @Published private var _isTracking = false
    
    // MARK: - Public Properties
    var currentBalance: AnyPublisher<CalorieBalance?, Never> {
        return balanceSubject.eraseToAnyPublisher()
    }
    
    var isTracking: Bool {
        return _isTracking
    }
    
    // MARK: - Initialization
    init(
        healthKitService: HealthKitServiceProtocol,
        calculationService: CalculationServiceProtocol,
        dataService: DataServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.calculationService = calculationService
        self.dataService = dataService
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    func startRealTimeTracking() {
        guard !_isTracking else { return }
        
        _isTracking = true
        
        // Start immediate calculation
        Task {
            await updateCurrentBalance()
        }
        
        // Set up periodic updates every 5 minutes
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCurrentBalance()
            }
        }
        
        // Start HealthKit background sync for continuous data
        healthKitService.startBackgroundSync()
    }
    
    func stopRealTimeTracking() {
        _isTracking = false
        trackingTimer?.invalidate()
        trackingTimer = nil
        healthKitService.stopBackgroundSync()
    }
    
    func getCurrentBalance() async -> CalorieBalance? {
        return await calculateBalanceForDate(Date())
    }
    
    func getBalanceForDate(_ date: Date) async -> CalorieBalance? {
        return await calculateBalanceForDate(date)
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Observe energy changes from HealthKit
        healthKitService.observeEnergyChanges()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBalance()
                }
            }
            .store(in: &cancellables)
        
        // Observe nutrition changes (when user logs food)
        NotificationCenter.default.publisher(for: .nutritionDataUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBalance()
                }
            }
            .store(in: &cancellables)
        
        // Also listen for food entry updates
        NotificationCenter.default.publisher(for: NSNotification.Name("FoodEntryAdded"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBalance()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("FoodEntryUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBalance()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("FoodEntryDeleted"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBalance()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateCurrentBalance() async {
        let balance = await calculateBalanceForDate(Date())
        balanceSubject.send(balance)
    }
    
    private func calculateBalanceForDate(_ date: Date) async -> CalorieBalance? {
        do {
            // Get calories consumed from nutrition data
            let caloriesConsumed = await getCaloriesConsumedForDate(date)
            
            // Try to get energy data from HealthKit first
            let activeEnergy = try await healthKitService.fetchActiveEnergy(for: date)
            let restingEnergy = try await healthKitService.fetchRestingEnergy(for: date)
            
            // Get resting energy as fallback/comparison
            let fallbackRestingEnergy = await getRestingEnergyForDate(date)
            
            // Determine which energy data to use
            let (finalRestingEnergy, finalActiveEnergy, isUsingHealthKit) = determineEnergySource(
                healthKitResting: restingEnergy,
                healthKitActive: activeEnergy,
                calculatedResting: fallbackRestingEnergy
            )
            
            let totalEnergyBurned = finalRestingEnergy + finalActiveEnergy
            let balance = caloriesConsumed - totalEnergyBurned
            
            return CalorieBalance(
                date: date,
                caloriesConsumed: caloriesConsumed,
                restingEnergyBurned: finalRestingEnergy,
                activeEnergyBurned: finalActiveEnergy,
                totalEnergyBurned: totalEnergyBurned,
                calculatedBMR: fallbackRestingEnergy,
                balance: balance,
                isUsingHealthKitData: isUsingHealthKit
            )
            
        } catch {
            // Fallback to resting energy if HealthKit fails
            let caloriesConsumed = await getCaloriesConsumedForDate(date)
            let restingEnergy = await getRestingEnergyForDate(date)
            
            // Estimate active energy as 20% of resting energy if no HealthKit data
            let estimatedActiveEnergy = restingEnergy * 0.2
            let totalEnergyBurned = restingEnergy + estimatedActiveEnergy
            let balance = caloriesConsumed - totalEnergyBurned
            
            return CalorieBalance(
                date: date,
                caloriesConsumed: caloriesConsumed,
                restingEnergyBurned: restingEnergy,
                activeEnergyBurned: estimatedActiveEnergy,
                totalEnergyBurned: totalEnergyBurned,
                calculatedBMR: restingEnergy,
                balance: balance,
                isUsingHealthKitData: false
            )
        }
    }
    
    private func determineEnergySource(
        healthKitResting: Double,
        healthKitActive: Double,
        calculatedResting: Double
    ) -> (resting: Double, active: Double, isUsingHealthKit: Bool) {
        
        // Prefer HealthKit data if it's available and reasonable
        if healthKitResting > 0 || healthKitActive > 0 {
            // Use HealthKit data as it's more accurate
            let finalResting = healthKitResting > 0 ? healthKitResting : calculatedResting
            let finalActive = healthKitActive
            
            return (resting: finalResting, active: finalActive, isUsingHealthKit: true)
        } else {
            // Fallback to resting energy with estimated active energy
            let estimatedActiveEnergy = calculatedResting * 0.2
            return (resting: calculatedResting, active: estimatedActiveEnergy, isUsingHealthKit: false)
        }
    }
    
    private func getCaloriesConsumedForDate(_ date: Date) async -> Double {
        // Get nutrition data for the date from food entries
        do {
            // First try to get daily nutrition summary
            if let dailyNutrition = try await dataService.fetchDailyNutrition(for: date) {
                return dailyNutrition.totalCalories
            }
            
            // Fallback to calculating from individual food entries
            let user = try await dataService.fetchUser()
            if let user = user {
                let foodEntries = try await dataService.fetchFoodEntries(for: date, user: user)
                return foodEntries.reduce(0) { $0 + $1.calories }
            }
            
            return 0.0
        } catch {
            print("Error fetching calories consumed: \(error)")
            return 0.0
        }
    }
    
    private func getRestingEnergyForDate(_ date: Date) async -> Double {
        do {
            // Use HealthKit resting energy instead of calculated BMR
            let restingEnergy = try await healthKitService.fetchRestingEnergy(for: date)
            return restingEnergy > 0 ? restingEnergy : 1800.0 // Fallback if no HealthKit data
        } catch {
            // Fallback resting energy if HealthKit is not available
            return 1800.0 // Average adult resting energy
        }
    }
    
    deinit {
        Task { @MainActor in
            stopRealTimeTracking()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let nutritionDataUpdated = Notification.Name("nutritionDataUpdated")
}