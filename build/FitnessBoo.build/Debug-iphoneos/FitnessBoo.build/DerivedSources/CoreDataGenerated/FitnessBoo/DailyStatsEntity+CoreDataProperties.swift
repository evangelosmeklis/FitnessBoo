//
//  DailyStatsEntity+CoreDataProperties.swift
//  
//
//  Created by Evangelos Meklis on 25/7/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension DailyStatsEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyStatsEntity> {
        return NSFetchRequest<DailyStatsEntity>(entityName: "DailyStatsEntity")
    }

    @NSManaged public var caloriesFromExercise: Double
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var netCalories: Double
    @NSManaged public var totalCaloriesConsumed: Double
    @NSManaged public var totalProtein: Double
    @NSManaged public var weightRecorded: Double
    @NSManaged public var user: UserEntity?

}

extension DailyStatsEntity : Identifiable {

}
