//
//  AppDataManager.swift
//  FitnessBoo
//
//  Created by Kiro on 26/7/25.
//

import Foundation
import Combine

@MainActor
class AppDataManager: ObservableObject {
    static let shared = AppDataManager()
    
    // Published properties for reactive UI updates
    @Published var currentUser: User?
    @Published var currentGoal: FitnessGoal?
    @Published var todayNutrition: DailyNutrition?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    // Services
    private let dataService: DataServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let calculationService: CalculationServiceProtocol
    
    // Cache management
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    private init() {
        self.dataService = DataService.shared
        self.healthKitService = HealthKitService()
        self.calculationService = CalculationService()
        
        setupNotificationObservers()
        startPeriodicRefresh()
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        async let user = loadUser()
        async let goal = loadCurrentGoal()
        async let nutrition = loadTodayNutrition()
        
        let (loadedUser, loadedGoal, loadedNutrition) = await (user, goal, nutrition)
        
        currentUser = loadedUser
        currentGoal = loadedGoal
        todayNutrition = loadedNutrition
        lastUpdated = Date()
        isLoading = false
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func updateUserWeight(_ newWeight: Double) async -> Bool {
        guard var user = currentUser else { return false }
        
        user.weight = newWeight
        user.updatedAt = Date()
        
        do {
            try await dataService.saveUser(user)
            currentUser = user
            
            // Recalculate goal if exists
            if var goal = currentGoal {
                let totalEnergy = try await healthKitService.fetchTotalEnergyExpended(for: Date())
                goal.calculateDailyTargets(totalEnergyExpended: totalEnergy, currentWeight: newWeight)
                try await dataService.saveGoal(goal, for: user)
                currentGoal = goal
            }
            
            // Refresh nutrition with new targets
            await loadTodayNutrition()
            
            return true
        } catch {
            print("Failed to update weight: \(error)")
            return false
        }
    }
    
    func addFoodEntry(_ entry: FoodEntry) async -> Bool {
        do {
            try await dataService.saveFoodEntry(entry)
            await loadTodayNutrition() // Refresh nutrition data
            return true
        } catch {
            print("Failed to add food entry: \(error)")
            return false
        }
    }
    
    func updateGoal(_ goal: FitnessGoal) async -> Bool {
        guard let user = currentUser else { return false }
        
        do {
            try await dataService.saveGoal(goal, for: user)
            currentGoal = goal
            await loadTodayNutrition() // Refresh nutrition with new targets
            return true
        } catch {
            print("Failed to update goal: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUser() async -> User? {
        do {
            return try await dataService.fetchUser()
        } catch {
            print("Failed to load user: \(error)")
            return nil
        }
    }
    
    private func loadCurrentGoal() async -> FitnessGoal? {
        do {
            return try await dataService.fetchActiveGoal()
        } catch {
            print("Failed to load goal: \(error)")
            return nil
        }
    }
    
    private func loadTodayNutrition() async -> DailyNutrition? {
        do {
            let nutrition = try await dataService.fetchDailyNutrition(for: Date())
            return nutrition
        } catch {
            print("Failed to load nutrition: \(error)")
            return nil
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for data changes
        NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadCurrentGoal()
                    await self?.loadTodayNutrition()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadUser()
                    await self?.loadCurrentGoal()
                    await self?.loadTodayNutrition()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .nutritionDataUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadTodayNutrition()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - Computed Properties for UI
extension AppDataManager {
    var caloriesConsumed: Double {
        todayNutrition?.totalCalories ?? 0
    }
    
    var calorieTarget: Double {
        currentGoal?.dailyCalorieTarget ?? 2000
    }
    
    var caloriesRemaining: Double {
        calorieTarget - caloriesConsumed
    }
    
    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(caloriesConsumed / calorieTarget, 1.0)
    }
    
    var proteinConsumed: Double {
        todayNutrition?.totalProtein ?? 0
    }
    
    var proteinTarget: Double {
        currentGoal?.dailyProteinTarget ?? 100
    }
    
    var proteinRemaining: Double {
        proteinTarget - proteinConsumed
    }
    
    var proteinProgress: Double {
        guard proteinTarget > 0 else { return 0 }
        return min(proteinConsumed / proteinTarget, 1.0)
    }
    
    var waterConsumed: Double {
        todayNutrition?.waterConsumed ?? 0
    }
    
    var waterTarget: Double {
        2000 // 2L default
    }
    
    var waterProgress: Double {
        min(waterConsumed / waterTarget, 1.0)
    }
}