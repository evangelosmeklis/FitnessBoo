//
//  User.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    var weight: Double // From HealthKit
    var preferredUnits: UnitSystem
    var createdAt: Date
    var updatedAt: Date
    
    init(weight: Double, preferredUnits: UnitSystem = .metric) {
        self.id = UUID()
        self.weight = weight
        self.preferredUnits = preferredUnits
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    init(id: UUID, weight: Double, preferredUnits: UnitSystem = .metric, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.weight = weight
        self.preferredUnits = preferredUnits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    

    /// Validate user data
    func validate() throws {
        guard weight > 0 && weight < 1000 else {
            throw ValidationError.invalidWeight
        }
    }
    

}





// Removed Gender and ActivityLevel enums as we'll use HealthKit data instead

enum UnitSystem: String, CaseIterable, Codable {
    case metric, imperial
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidWeight
    
    var errorDescription: String? {
        switch self {
        case .invalidWeight:
            return "Weight must be between 1 and 999 kg/lbs"
        }
    }
}