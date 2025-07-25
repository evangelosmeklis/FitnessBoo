//
//  UserEntity+CoreDataProperties.swift
//  
//
//  Created by Evangelos Meklis on 25/7/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension UserEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var activityLevel: String?
    @NSManaged public var age: Int16
    @NSManaged public var bmr: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var gender: String?
    @NSManaged public var height: Double
    @NSManaged public var id: UUID?
    @NSManaged public var preferredUnits: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var weight: Double
    @NSManaged public var dailyNutrition: NSSet?
    @NSManaged public var dailyStats: NSSet?
    @NSManaged public var foodEntries: NSSet?
    @NSManaged public var goals: NSSet?

}

// MARK: Generated accessors for dailyNutrition
extension UserEntity {

    @objc(addDailyNutritionObject:)
    @NSManaged public func addToDailyNutrition(_ value: DailyNutritionEntity)

    @objc(removeDailyNutritionObject:)
    @NSManaged public func removeFromDailyNutrition(_ value: DailyNutritionEntity)

    @objc(addDailyNutrition:)
    @NSManaged public func addToDailyNutrition(_ values: NSSet)

    @objc(removeDailyNutrition:)
    @NSManaged public func removeFromDailyNutrition(_ values: NSSet)

}

// MARK: Generated accessors for dailyStats
extension UserEntity {

    @objc(addDailyStatsObject:)
    @NSManaged public func addToDailyStats(_ value: DailyStatsEntity)

    @objc(removeDailyStatsObject:)
    @NSManaged public func removeFromDailyStats(_ value: DailyStatsEntity)

    @objc(addDailyStats:)
    @NSManaged public func addToDailyStats(_ values: NSSet)

    @objc(removeDailyStats:)
    @NSManaged public func removeFromDailyStats(_ values: NSSet)

}

// MARK: Generated accessors for foodEntries
extension UserEntity {

    @objc(addFoodEntriesObject:)
    @NSManaged public func addToFoodEntries(_ value: FoodEntryEntity)

    @objc(removeFoodEntriesObject:)
    @NSManaged public func removeFromFoodEntries(_ value: FoodEntryEntity)

    @objc(addFoodEntries:)
    @NSManaged public func addToFoodEntries(_ values: NSSet)

    @objc(removeFoodEntries:)
    @NSManaged public func removeFromFoodEntries(_ values: NSSet)

}

// MARK: Generated accessors for goals
extension UserEntity {

    @objc(addGoalsObject:)
    @NSManaged public func addToGoals(_ value: GoalEntity)

    @objc(removeGoalsObject:)
    @NSManaged public func removeFromGoals(_ value: GoalEntity)

    @objc(addGoals:)
    @NSManaged public func addToGoals(_ values: NSSet)

    @objc(removeGoals:)
    @NSManaged public func removeFromGoals(_ values: NSSet)

}

extension UserEntity : Identifiable {

}
