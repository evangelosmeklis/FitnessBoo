//
//  DailyNutritionEntity+CoreDataProperties.swift
//  
//
//  Created by Evangelos Meklis on 25/7/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension DailyNutritionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyNutritionEntity> {
        return NSFetchRequest<DailyNutritionEntity>(entityName: "DailyNutritionEntity")
    }

    @NSManaged public var calorieTarget: Double
    @NSManaged public var caloriesFromExercise: Double
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var netCalories: Double
    @NSManaged public var proteinTarget: Double
    @NSManaged public var totalCalories: Double
    @NSManaged public var totalProtein: Double
    @NSManaged public var waterConsumed: Double
    @NSManaged public var user: UserEntity?

}

extension DailyNutritionEntity : Identifiable {

}
