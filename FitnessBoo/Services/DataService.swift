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
}

class DataService: DataServiceProtocol {
    static let shared = DataService()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FitnessBoo")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
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
        print("💾 DataService: Starting to save user \(user.id) with weight \(user.weight)")
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Check if user already exists
                    let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    let existingUsers = try self.context.fetch(request)
                    let userEntity: UserEntity
                    
                    if let existing = existingUsers.first {
                        userEntity = existing
                        print("💾 DataService: Updating existing user")
                    } else {
                        userEntity = UserEntity(context: self.context)
                        userEntity.id = user.id
                        userEntity.createdAt = user.createdAt
                        print("💾 DataService: Creating new user entity")
                    }
                    
                    // Update user properties
                    userEntity.age = Int16(user.age)
                    userEntity.weight = user.weight
                    userEntity.height = user.height
                    userEntity.gender = user.gender.rawValue
                    userEntity.activityLevel = user.activityLevel.rawValue
                    userEntity.preferredUnits = user.preferredUnits.rawValue
                    userEntity.bmr = user.bmr
                    userEntity.updatedAt = user.updatedAt
                    
                    print("💾 DataService: Saving user context...")
                    try self.context.save()
                    print("💾 DataService: User saved successfully!")
                    continuation.resume()
                } catch {
                    print("💾 DataService: Error saving user: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchUser() async throws -> User? {
        print("👤 DataService: Fetching user...")
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \UserEntity.createdAt, ascending: false)]
                    request.fetchLimit = 1
                    
                    let userEntities = try self.context.fetch(request)
                    print("👤 DataService: Found \(userEntities.count) user entities")
                    
                    if let userEntity = userEntities.first {
                        let user = self.convertToUser(from: userEntity)
                        print("👤 DataService: Converted user with ID \(user.id) and weight \(user.weight)")
                        continuation.resume(returning: user)
                    } else {
                        print("👤 DataService: No user entities found")
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("👤 DataService: Error fetching user: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Food Entry Operations
    
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws {
        print("💾 DataService: Starting to save food entry for user \(user.id)")
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    let userEntities = try self.context.fetch(userRequest)
                    print("💾 DataService: Found \(userEntities.count) user entities")
                    
                    guard let userEntity = userEntities.first else {
                        print("💾 DataService: No user entity found!")
                        throw DataServiceError.userNotFound
                    }
                    
                    print("💾 DataService: Creating new food entry entity")
                    // Always create a new food entry (don't check for existing)
                    let foodEntryEntity = FoodEntryEntity(context: self.context)
                    foodEntryEntity.id = entry.id
                    foodEntryEntity.user = userEntity
                    foodEntryEntity.calories = entry.calories
                    foodEntryEntity.protein = entry.protein ?? 0
                    foodEntryEntity.timestamp = entry.timestamp
                    foodEntryEntity.mealType = entry.mealType?.rawValue
                    foodEntryEntity.notes = entry.notes
                    
                    print("💾 DataService: Saving context...")
                    // Force save the context
                    try self.context.save()
                    print("💾 DataService: Food entry saved successfully!")
                    continuation.resume()
                } catch {
                    print("💾 DataService: Error saving food entry: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] {
        print("📖 DataService: Fetching food entries for user \(user.id) on date \(date)")
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    print("📖 DataService: Date range: \(startOfDay) to \(endOfDay)")
                    
                    let request: NSFetchRequest<FoodEntryEntity> = FoodEntryEntity.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "user.id == %@", user.id as CVarArg),
                        NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate)
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodEntryEntity.timestamp, ascending: true)]
                    
                    let foodEntryEntities = try self.context.fetch(request)
                    print("📖 DataService: Found \(foodEntryEntities.count) food entry entities")
                    
                    let foodEntries = foodEntryEntities.compactMap { self.convertToFoodEntry(from: $0) }
                    print("📖 DataService: Converted to \(foodEntries.count) food entries")
                    
                    continuation.resume(returning: foodEntries)
                } catch {
                    print("📖 DataService: Error fetching food entries: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteFoodEntry(withId id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
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
        print("🔄 DataService: Simplified saveFoodEntry called")
        guard let user = try await fetchUser() else {
            print("🔄 DataService: No user found!")
            throw DataServiceError.userNotFound
        }
        print("🔄 DataService: Found user \(user.id), calling full saveFoodEntry")
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
        
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Find the user entity
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    guard let userEntity = try self.context.fetch(userRequest).first else {
                        throw DataServiceError.userNotFound
                    }
                    
                    // Check if daily nutrition already exists for this date
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: nutrition.date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    let request: NSFetchRequest<DailyNutritionEntity> = DailyNutritionEntity.fetchRequest()
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
                        dailyNutritionEntity.id = nutrition.id
                        dailyNutritionEntity.user = userEntity
                    }
                    
                    // Update daily nutrition properties
                    dailyNutritionEntity.date = startOfDay
                    dailyNutritionEntity.totalCalories = nutrition.totalCalories
                    dailyNutritionEntity.totalProtein = nutrition.totalProtein
                    dailyNutritionEntity.calorieTarget = nutrition.calorieTarget
                    dailyNutritionEntity.proteinTarget = nutrition.proteinTarget
                    dailyNutritionEntity.caloriesFromExercise = nutrition.caloriesFromExercise
                    dailyNutritionEntity.netCalories = nutrition.netCalories
                    
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
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    // Always fetch food entries for this date
                    let foodRequest: NSFetchRequest<FoodEntryEntity> = FoodEntryEntity.fetchRequest()
                    foodRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@ AND user.id == %@", 
                                                      startOfDay as NSDate, endOfDay as NSDate, user.id as CVarArg)
                    foodRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FoodEntryEntity.timestamp, ascending: true)]
                    
                    let foodEntities = try self.context.fetch(foodRequest)
                    let foodEntries = foodEntities.compactMap { self.convertToFoodEntry(from: $0) }
                    
                    // Try to fetch existing daily nutrition
                    let request: NSFetchRequest<DailyNutritionEntity> = DailyNutritionEntity.fetchRequest()
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
                        
                        let nutrition = DailyNutrition(
                            id: UUID(),
                            date: startOfDay,
                            totalCalories: totalCalories,
                            totalProtein: totalProtein,
                            entries: foodEntries,
                            calorieTarget: 2000, // Default target, will be updated
                            proteinTarget: 100,   // Default target, will be updated
                            caloriesFromExercise: 0,
                            netCalories: totalCalories
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
        try await withCheckedThrowingContinuation { continuation in
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
        return try await withCheckedThrowingContinuation { continuation in
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
        try await withCheckedThrowingContinuation { continuation in
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
        return try await withCheckedThrowingContinuation { continuation in
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
        return try await withCheckedThrowingContinuation { continuation in
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
        try await withCheckedThrowingContinuation { continuation in
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
}

// MARK: - Conversion Methods

extension DataService {
    private func convertToUser(from entity: UserEntity) -> User {
        var user = User(
            age: Int(entity.age),
            weight: entity.weight,
            height: entity.height,
            gender: Gender(rawValue: entity.gender ?? "other") ?? .other,
            activityLevel: ActivityLevel(rawValue: entity.activityLevel ?? "sedentary") ?? .sedentary,
            preferredUnits: UnitSystem(rawValue: entity.preferredUnits ?? "metric") ?? .metric
        )
        
        // Update with stored values including the ID
        if let storedId = entity.id {
            user = User(
                id: storedId,
                age: Int(entity.age),
                weight: entity.weight,
                height: entity.height,
                gender: Gender(rawValue: entity.gender ?? "other") ?? .other,
                activityLevel: ActivityLevel(rawValue: entity.activityLevel ?? "sedentary") ?? .sedentary,
                preferredUnits: UnitSystem(rawValue: entity.preferredUnits ?? "metric") ?? .metric,
                bmr: entity.bmr,
                createdAt: entity.createdAt ?? Date(),
                updatedAt: entity.updatedAt ?? Date()
            )
        } else {
            user.bmr = entity.bmr
            if let createdAt = entity.createdAt {
                user.createdAt = createdAt
            }
            if let updatedAt = entity.updatedAt {
                user.updatedAt = updatedAt
            }
        }
        
        return user
    }
    
    private func convertToFoodEntry(from entity: FoodEntryEntity) -> FoodEntry? {
        guard let id = entity.id,
              let timestamp = entity.timestamp else {
            return nil
        }
        
        return FoodEntry(
            id: id,
            calories: entity.calories,
            protein: entity.protein == 0 ? nil : entity.protein,
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
        
        var nutrition = DailyNutrition(
            date: date,
            calorieTarget: entity.calorieTarget,
            proteinTarget: entity.proteinTarget
        )
        
        // Override the generated ID with the stored one
        nutrition = DailyNutrition(
            id: id,
            date: date,
            totalCalories: entity.totalCalories,
            totalProtein: entity.totalProtein,
            entries: entries,
            calorieTarget: entity.calorieTarget,
            proteinTarget: entity.proteinTarget,
            caloriesFromExercise: entity.caloriesFromExercise,
            netCalories: entity.netCalories
        )
        
        return nutrition
    }
}

// MARK: - Error Types







// MARK: - FitnessGoal Model Extensions

extension FitnessGoal {
    init(id: UUID, type: GoalType, targetWeight: Double?, targetDate: Date?, weeklyWeightChangeGoal: Double, dailyCalorieTarget: Double, dailyProteinTarget: Double, isActive: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.type = type
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.weeklyWeightChangeGoal = weeklyWeightChangeGoal
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyProteinTarget = dailyProteinTarget
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}