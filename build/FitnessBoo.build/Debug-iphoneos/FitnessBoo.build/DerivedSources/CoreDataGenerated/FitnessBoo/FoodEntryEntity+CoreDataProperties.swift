//
//  FoodEntryEntity+CoreDataProperties.swift
//  
//
//  Created by Evangelos Meklis on 25/7/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension FoodEntryEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodEntryEntity> {
        return NSFetchRequest<FoodEntryEntity>(entityName: "FoodEntryEntity")
    }

    @NSManaged public var calories: Double
    @NSManaged public var id: UUID?
    @NSManaged public var mealType: String?
    @NSManaged public var notes: String?
    @NSManaged public var protein: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var user: UserEntity?

}

extension FoodEntryEntity : Identifiable {

}
