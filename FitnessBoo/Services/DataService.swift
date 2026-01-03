//
//  DataService.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import CoreData

enum DataServiceError: LocalizedError {
    case userNotFound
    case dataCorruption
    case saveFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User profile not found"
        case .dataCorruption:
            return "Data corruption detected"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        }
    }
}

protocol DataServiceProtocol {
    func saveUser(_ user: User) async throws
    func fetchUser() async throws -> User?
    func createUserFromHealthKit(healthKitService: HealthKitServiceProtocol) async throws -> User
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws
    func saveFoodEntry(_ entry: FoodEntry) async throws
    func updateFoodEntry(_ entry: FoodEntry) async throws
    func deleteFoodEntry(_ entry: FoodEntry) async throws
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry]
    func deleteFoodEntry(withId id: UUID) async throws
    func saveDailyNutrition(_ nutrition: DailyNutrition) async throws
    func fetchDailyNutrition(for date: Date) async throws -> DailyNutrition?
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws
    func saveDailyStats(_ stats: DailyStats) async throws
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats]
    func fetchDailyStats(for date: Date) async throws -> DailyStats?
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws
    func updateGoal(_ goal: FitnessGoal) async throws
    func deleteGoal(_ goal: FitnessGoal) async throws
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal?
    func fetchActiveGoal() async throws -> FitnessGoal?
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal]
    func resetAllData() async throws
}

class DataService: DataServiceProtocol {
    static let shared = DataService()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FitnessBoo")

        // Enable lightweight migration for Core Data schema changes
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // If migration fails, try to delete the old store and create a new one
                print("⚠️ Core Data migration failed: \(error)")
                print("🗑️ Attempting to delete old persistent store and create a new one...")

                if let storeURL = storeDescription.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        print("✅ Old store deleted successfully")

                        // Try loading again with the fresh store
                        container.loadPersistentStores { _, secondError in
                            if let secondError = secondError as NSError? {
                                // If it still fails, this is a critical error
                                fatalError("Failed to create new persistent store: \(secondError), \(secondError.userInfo)")
                            } else {
                                print("✅ New persistent store created successfully")
                            }
                        }
                    } catch {
                        print("❌ Failed to delete old store: \(error)")
                        fatalError("Unresolved error \(error)")
                    }
                } else {
                    fatalError("Could not locate persistent store URL")
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - User Operations
    
    func saveUser(_ user: User) async throws {
        print("💾 DataService.saveUser called with weight: \(user.weight)")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Check if user already exists
                    let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    let existingUsers = try self.context.fetch(request)
                    let userEntity: UserEntity
                    
                    if let existing = existingUsers.first {
                        print("📝 Updating existing user entity")
                        userEntity = existing
                    } else {
                        print("🆕 Creating new user entity")
                        userEntity = UserEntity(context: self.context)
                        userEntity.id = user.id
                        userEntity.createdAt = user.createdAt
                    }
                    
                    // Update user properties
                    print("⚖️ Setting weight from \(userEntity.weight) to \(user.weight)")
                    userEntity.weight = user.weight
                    userEntity.preferredUnits = user.preferredUnits.rawValue
                    userEntity.updatedAt = user.updatedAt
                    
                    try self.context.save()
                    print("✅ User saved successfully with weight: \(userEntity.weight)")
                    continuation.resume()
                } catch {
                    print("❌ Failed to save user: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchUser() async throws -> User? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User?, Error>) in
            context.perform {
                do {
                    let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \UserEntity.createdAt, ascending: false)]
                    request.fetchLimit = 1
                    
                    let userEntities = try self.context.fetch(request)
                    
                    if let userEntity = userEntities.first {
                        let user = self.convertToUser(from: userEntity)
                        print("📖 Fetched user with weight: \(user.weight)")
                        continuation.resume(returning: user)
                    } else {
                        print("❌ No user found in database")
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("❌ Failed to fetch user: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createUserFromHealthKit(healthKitService: HealthKitServiceProtocol) async throws -> User {
        // Get weight from HealthKit, fallback to default if not available
        let weight = try await healthKitService.fetchWeight() ?? 70.0 // Default 70kg
        
        let user = User(weight: weight)
        try await saveUser(user)
        return user
    }
    
    // MARK: - Food Entry Operations
    
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    let userEntities = try self.context.fetch(userRequest)
                    
                    guard let userEntity = userEntities.first else {
                        throw DataServiceError.userNotFound
                    }
                    
                    // Check if food entry already exists (for updates)
                    let request: NSFetchRequest<FoodEntryEntity> = FoodEntryEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
                    
                    let existingEntries = try self.context.fetch(request)
                    let foodEntryEntity: FoodEntryEntity
                    
                    if let existing = existingEntries.first {
                        // Update existing entry
                        foodEntryEntity = existing
                    } else {
                        // Create new entry
                        foodEntryEntity = FoodEntryEntity(context: self.context)
                        foodEntryEntity.id = entry.id
                        foodEntryEntity.user = userEntity
                    }
                    
                    // Update properties
                    foodEntryEntity.calories = entry.calories
                    foodEntryEntity.protein = entry.protein ?? 0
                    foodEntryEntity.setValue(entry.carbs ?? 0, forKey: "carbs")
                    foodEntryEntity.setValue(entry.fats ?? 0, forKey: "fats")
                    foodEntryEntity.timestamp = entry.timestamp
                    foodEntryEntity.mealType = entry.mealType?.rawValue
                    foodEntryEntity.notes = entry.notes
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FoodEntry], Error>) in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    let request: NSFetchRequest<FoodEntryEntity> = FoodEntryEntity.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodEntryEntity.timestamp, ascending: true)]
                    
                    let foodEntryEntities = try self.context.fetch(request)
                    let foodEntries = foodEntryEntities.compactMap { self.convertToFoodEntry(from: $0) }
                    
                    continuation.resume(returning: foodEntries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteFoodEntry(withId id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let request: NSFetchRequest<FoodEntryEntity> = FoodEntryEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    let foodEntryEntities = try self.context.fetch(request)
                    
                    for entity in foodEntryEntities {
                        self.context.delete(entity)
                    }
                    
                    try self.saveContext()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Simplified Food Entry Operations (for NutritionViewModel)
    
    func saveFoodEntry(_ entry: FoodEntry) async throws {
        guard let user = try await fetchUser() else {
            throw DataServiceError.userNotFound
        }
        try await saveFoodEntry(entry, for: user)
    }
    
    func updateFoodEntry(_ entry: FoodEntry) async throws {
        guard let user = try await fetchUser() else {
            throw DataServiceError.userNotFound
        }
        try await saveFoodEntry(entry, for: user) // Same as save since we upsert
    }
    
    func deleteFoodEntry(_ entry: FoodEntry) async throws {
        try await deleteFoodEntry(withId: entry.id)
    }
    
    // MARK: - Daily Nutrition Operations
    
    func saveDailyNutrition(_ nutrition: DailyNutrition) async throws {
        guard let user = try await fetchUser() else {
            throw DataServiceError.userNotFound
        }
        
        var nutritionToSave = nutrition
        nutritionToSave.recalculateTotals()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    guard let userEntity = try self.context.fetch(userRequest).first else {
                        throw DataServiceError.userNotFound
                    }
                    
                    // Check if daily nutrition already exists for this date
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: nutritionToSave.date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    let request = NSFetchRequest<DailyNutritionEntity>(entityName: "DailyNutritionEntity")
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
                    ])
                    
                    let existingNutrition = try self.context.fetch(request)
                    let dailyNutritionEntity: DailyNutritionEntity
                    
                    if let existing = existingNutrition.first {
                        dailyNutritionEntity = existing
                    } else {
                        dailyNutritionEntity = DailyNutritionEntity(context: self.context)
                        dailyNutritionEntity.id = nutritionToSave.id
                        dailyNutritionEntity.user = userEntity
                    }
                    
                    // Update daily nutrition properties
                    dailyNutritionEntity.date = startOfDay
                    dailyNutritionEntity.totalCalories = nutritionToSave.totalCalories
                    dailyNutritionEntity.totalProtein = nutritionToSave.totalProtein
                    dailyNutritionEntity.setValue(nutritionToSave.totalCarbs, forKey: "totalCarbs")
                    dailyNutritionEntity.setValue(nutritionToSave.totalFats, forKey: "totalFats")
                    dailyNutritionEntity.calorieTarget = nutritionToSave.calorieTarget
                    dailyNutritionEntity.proteinTarget = nutritionToSave.proteinTarget
                    dailyNutritionEntity.setValue(nutritionToSave.carbsTarget, forKey: "carbsTarget")
                    dailyNutritionEntity.setValue(nutritionToSave.fatsTarget, forKey: "fatsTarget")
                    dailyNutritionEntity.caloriesFromExercise = nutritionToSave.caloriesFromExercise
                    dailyNutritionEntity.netCalories = nutritionToSave.netCalories
                    dailyNutritionEntity.setValue(nutritionToSave.waterConsumed, forKey: "waterConsumed")
                    
                    try self.saveContext()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchDailyNutrition(for date: Date) async throws -> DailyNutrition? {
        guard let user = try await fetchUser() else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DailyNutrition?, Error>) in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    // Always fetch food entries for this date
                    let foodRequest = NSFetchRequest<FoodEntryEntity>(entityName: "FoodEntryEntity")
                    foodRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@ AND user.id == %@", 
                                                      startOfDay as NSDate, endOfDay as NSDate, user.id as CVarArg)
                    foodRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FoodEntryEntity.timestamp, ascending: true)]
                    
                    let foodEntities = try self.context.fetch(foodRequest)
                    let foodEntries = foodEntities.compactMap { self.convertToFoodEntry(from: $0) }
                    
                    // Try to fetch existing daily nutrition
                    let request = NSFetchRequest<DailyNutritionEntity>(entityName: "DailyNutritionEntity")
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
                    ])
                    request.fetchLimit = 1
                    
                    let nutritionEntities = try self.context.fetch(request)
                    
                    if let nutritionEntity = nutritionEntities.first {
                        let nutrition = self.convertToDailyNutrition(from: nutritionEntity, with: foodEntries)
                        continuation.resume(returning: nutrition)
                    } else if !foodEntries.isEmpty {
                        // If we have food entries but no daily nutrition record, create one
                        let totalCalories = foodEntries.reduce(0) { $0 + $1.calories }
                        let totalProtein = foodEntries.reduce(0) { $0 + ($1.protein ?? 0) }
                        let totalCarbs = foodEntries.reduce(0) { $0 + ($1.carbs ?? 0) }
                        let totalFats = foodEntries.reduce(0) { $0 + ($1.fats ?? 0) }

                        let nutrition = DailyNutrition(
                            id: UUID(),
                            date: startOfDay,
                            totalCalories: totalCalories,
                            totalProtein: totalProtein,
                            totalCarbs: totalCarbs,
                            totalFats: totalFats,
                            entries: foodEntries,
                            calorieTarget: 2000, // Default target, will be updated
                            proteinTarget: 100,   // Default target, will be updated
                            carbsTarget: 200,     // Default target, will be updated
                            fatsTarget: 65,       // Default target, will be updated
                            caloriesFromExercise: 0,
                            netCalories: totalCalories,
                            waterConsumed: 0 // Default value
                        )
                        continuation.resume(returning: nutrition)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Daily Stats Operations
    
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    guard let userEntity = try self.context.fetch(userRequest).first else {
                        throw DataServiceError.userNotFound
                    }
                    
                    // Check if daily stats already exist for this date
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: stats.date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    let request: NSFetchRequest<DailyStatsEntity> = DailyStatsEntity.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
                    ])
                    
                    let existingStats = try self.context.fetch(request)
                    let dailyStatsEntity: DailyStatsEntity
                    
                    if let existing = existingStats.first {
                        dailyStatsEntity = existing
                    } else {
                        dailyStatsEntity = DailyStatsEntity(context: self.context)
                        dailyStatsEntity.id = stats.id
                        dailyStatsEntity.user = userEntity
                    }
                    
                    // Update daily stats properties
                    dailyStatsEntity.date = startOfDay
                    dailyStatsEntity.totalCaloriesConsumed = stats.totalCaloriesConsumed
                    dailyStatsEntity.totalProtein = stats.totalProtein
                    dailyStatsEntity.setValue(stats.totalCarbs, forKey: "totalCarbs")
                    dailyStatsEntity.setValue(stats.totalFats, forKey: "totalFats")
                    dailyStatsEntity.caloriesFromExercise = stats.caloriesFromExercise
                    dailyStatsEntity.netCalories = stats.netCalories
                    dailyStatsEntity.weightRecorded = stats.weightRecorded ?? 0
                    
                    try self.saveContext()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DailyStats], Error>) in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startDate = calendar.startOfDay(for: dateRange.lowerBound)
                    let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dateRange.upperBound))!
                    
                    let request: NSFetchRequest<DailyStatsEntity> = DailyStatsEntity.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyStatsEntity.date, ascending: true)]
                    
                    let dailyStatsEntities = try self.context.fetch(request)
                    let dailyStats = dailyStatsEntities.compactMap { self.convertToDailyStats(from: $0) }
                    
                    continuation.resume(returning: dailyStats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Goal Operations
    
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    guard let userEntity = try self.context.fetch(userRequest).first else {
                        throw DataServiceError.userNotFound
                    }
                    
                    // Check if goal already exists
                    let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", goal.id as CVarArg)
                    
                    let existingGoals = try self.context.fetch(request)
                    let goalEntity: GoalEntity
                    
                    if let existing = existingGoals.first {
                        goalEntity = existing
                    } else {
                        goalEntity = GoalEntity(context: self.context)
                        goalEntity.id = goal.id
                        goalEntity.user = userEntity
                    }
                    
                    // Update goal properties
                    goalEntity.type = goal.type.rawValue
                    goalEntity.targetWeight = goal.targetWeight ?? 0
                    goalEntity.targetDate = goal.targetDate
                    goalEntity.weeklyWeightChangeGoal = goal.weeklyWeightChangeGoal
                    goalEntity.dailyCalorieTarget = goal.dailyCalorieTarget
                    goalEntity.dailyProteinTarget = goal.dailyProteinTarget
                    goalEntity.setValue(goal.dailyCarbsTarget, forKey: "dailyCarbsTarget")
                    goalEntity.setValue(goal.dailyFatsTarget, forKey: "dailyFatsTarget")
                    goalEntity.setValue(goal.dailyWaterTarget, forKey: "dailyWaterTarget")
                    goalEntity.isActive = goal.isActive
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FitnessGoal?, Error>) in
            context.perform {
                do {
                    let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "isActive == YES")
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.targetDate, ascending: true)]
                    request.fetchLimit = 1
                    
                    let goalEntities = try self.context.fetch(request)
                    
                    if let goalEntity = goalEntities.first {
                        let goal = self.convertToFitnessGoal(from: goalEntity)
                        continuation.resume(returning: goal)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchActiveGoal() async throws -> FitnessGoal? {
        guard let user = try await fetchUser() else {
            return nil
        }
        return try await fetchActiveGoal(for: user)
    }
    
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FitnessGoal], Error>) in
            context.perform {
                do {
                    let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "user.id == %@", user.id as CVarArg)
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.targetDate, ascending: false)]
                    
                    let goalEntities = try self.context.fetch(request)
                    let goals = goalEntities.compactMap { self.convertToFitnessGoal(from: $0) }
                    
                    continuation.resume(returning: goals)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateGoal(_ goal: FitnessGoal) async throws {
        // Implementation would update existing goal
        // For now, we'll treat it as a save operation
        guard let user = try await fetchUser() else {
            throw DataServiceError.userNotFound
        }
        try await saveGoal(goal, for: user)
    }
    
    func deleteGoal(_ goal: FitnessGoal) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", goal.id as CVarArg)
                    
                    let entities = try self.context.fetch(request)
                    for entity in entities {
                        self.context.delete(entity)
                    }
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Additional Protocol Methods
    
    func saveDailyStats(_ stats: DailyStats) async throws {
        guard let user = try await fetchUser() else {
            throw DataServiceError.userNotFound
        }
        try await saveDailyStats(stats, for: user)
    }
    
    func fetchDailyStats(for date: Date) async throws -> DailyStats? {
        guard let user = try await fetchUser() else {
            return nil
        }
        let stats = try await fetchDailyStats(for: date...date, user: user)
        return stats.first
    }
    
    func resetAllData() async throws {
        let context = persistentContainer.viewContext
        
        // Delete all entities
        let entityNames = ["User", "FitnessGoal", "FoodEntry", "DailyNutrition"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
                // Continue with other entities even if one fails
            }
        }
        
        // Save the context to persist the deletions
        try context.save()
        
        print("All app data has been reset")
    }
}

// MARK: - Conversion Methods

extension DataService {
    private func convertToUser(from entity: UserEntity) -> User {
        // Update with stored values including the ID
        if let storedId = entity.id {
            return User(
                id: storedId,
                weight: entity.weight,
                preferredUnits: UnitSystem(rawValue: entity.preferredUnits ?? "metric") ?? .metric,
                createdAt: entity.createdAt ?? Date(),
                updatedAt: entity.updatedAt ?? Date()
            )
        } else {
            var user = User(
                weight: entity.weight,
                preferredUnits: UnitSystem(rawValue: entity.preferredUnits ?? "metric") ?? .metric
            )
            if let createdAt = entity.createdAt {
                user.createdAt = createdAt
            }
            if let updatedAt = entity.updatedAt {
                user.updatedAt = updatedAt
            }
            return user
        }
    }
    
    private func convertToFoodEntry(from entity: FoodEntryEntity) -> FoodEntry? {
        guard let id = entity.id,
              let timestamp = entity.timestamp else {
            return nil
        }

        let carbs = entity.value(forKey: "carbs") as? Double
        let fats = entity.value(forKey: "fats") as? Double

        return FoodEntry(
            id: id,
            calories: entity.calories,
            protein: entity.protein == 0 ? nil : entity.protein,
            carbs: (carbs == 0 || carbs == nil) ? nil : carbs,
            fats: (fats == 0 || fats == nil) ? nil : fats,
            timestamp: timestamp,
            mealType: entity.mealType != nil ? MealType(rawValue: entity.mealType!) : nil,
            notes: entity.notes
        )
    }
    
    private func convertToDailyStats(from entity: DailyStatsEntity) -> DailyStats? {
        guard let date = entity.date else {
            return nil
        }

        var stats = DailyStats(date: date)
        stats.totalCaloriesConsumed = entity.totalCaloriesConsumed
        stats.totalProtein = entity.totalProtein
        stats.totalCarbs = entity.value(forKey: "totalCarbs") as? Double ?? 0
        stats.totalFats = entity.value(forKey: "totalFats") as? Double ?? 0
        stats.caloriesFromExercise = entity.caloriesFromExercise
        // bmrCalories is not in Core Data entity, keep default value of 0
        stats.netCalories = entity.netCalories
        stats.weightRecorded = entity.weightRecorded == 0 ? nil : entity.weightRecorded
        stats.workouts = [] // Workouts would need separate handling
        // createdAt and updatedAt are not in Core Data entity, keep default values

        return stats
    }
    
    private func convertToFitnessGoal(from entity: GoalEntity) -> FitnessGoal? {
        guard let id = entity.id,
              let typeString = entity.type,
              let type = GoalType(rawValue: typeString) else {
            return nil
        }
        
        return FitnessGoal(
            id: id,
            type: type,
            targetWeight: entity.targetWeight == 0 ? nil : entity.targetWeight,
            targetDate: entity.targetDate,
            weeklyWeightChangeGoal: entity.weeklyWeightChangeGoal,
            dailyCalorieTarget: entity.dailyCalorieTarget,
            dailyProteinTarget: entity.dailyProteinTarget,
            dailyCarbsTarget: entity.value(forKey: "dailyCarbsTarget") as? Double ?? 0.0,
            dailyFatsTarget: entity.value(forKey: "dailyFatsTarget") as? Double ?? 0.0,
            dailyWaterTarget: entity.value(forKey: "dailyWaterTarget") as? Double ?? 2000.0,
            isActive: entity.isActive,
            createdAt: Date(), // Core Data entities don't store creation date for goals
            updatedAt: Date()
        )
    }
    
    private func convertToDailyNutrition(from entity: DailyNutritionEntity, with entries: [FoodEntry]) -> DailyNutrition? {
        guard let id = entity.id,
              let date = entity.date else {
            return nil
        }

        let totalCarbs = entity.value(forKey: "totalCarbs") as? Double ?? 0.0
        let totalFats = entity.value(forKey: "totalFats") as? Double ?? 0.0
        let carbsTarget = entity.value(forKey: "carbsTarget") as? Double ?? 0.0
        let fatsTarget = entity.value(forKey: "fatsTarget") as? Double ?? 0.0

        var nutrition = DailyNutrition(
            date: date,
            calorieTarget: entity.calorieTarget,
            proteinTarget: entity.proteinTarget,
            carbsTarget: carbsTarget,
            fatsTarget: fatsTarget
        )

        // Override the generated ID with the stored one
        nutrition = DailyNutrition(
            id: id,
            date: date,
            totalCalories: entity.totalCalories,
            totalProtein: entity.totalProtein,
            totalCarbs: totalCarbs,
            totalFats: totalFats,
            entries: entries,
            calorieTarget: entity.calorieTarget,
            proteinTarget: entity.proteinTarget,
            carbsTarget: carbsTarget,
            fatsTarget: fatsTarget,
            caloriesFromExercise: entity.caloriesFromExercise,
            netCalories: entity.netCalories,
            waterConsumed: entity.value(forKey: "waterConsumed") as? Double ?? 0.0
        )

        return nutrition
    }
}

// MARK: - Error Types







// MARK: - FitnessGoal Model Extensions

extension FitnessGoal {
    init(id: UUID, type: GoalType, targetWeight: Double?, targetDate: Date?, weeklyWeightChangeGoal: Double, dailyCalorieTarget: Double, dailyProteinTarget: Double, dailyCarbsTarget: Double, dailyFatsTarget: Double, dailyWaterTarget: Double, isActive: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.type = type
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.weeklyWeightChangeGoal = weeklyWeightChangeGoal
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyProteinTarget = dailyProteinTarget
        self.dailyCarbsTarget = dailyCarbsTarget
        self.dailyFatsTarget = dailyFatsTarget
        self.dailyWaterTarget = dailyWaterTarget
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}