//
//  GoalEntity+CoreDataProperties.swift
//  
//
//  Created by Evangelos Meklis on 25/7/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension GoalEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GoalEntity> {
        return NSFetchRequest<GoalEntity>(entityName: "GoalEntity")
    }

    @NSManaged public var dailyCalorieTarget: Double
    @NSManaged public var dailyProteinTarget: Double
    @NSManaged public var id: UUID?
    @NSManaged public var isActive: Bool
    @NSManaged public var targetDate: Date?
    @NSManaged public var targetWeight: Double
    @NSManaged public var type: String?
    @NSManaged public var weeklyWeightChangeGoal: Double
    @NSManaged public var user: UserEntity?

}

extension GoalEntity : Identifiable {

}
