//
//  WorkoutData.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import HealthKit
import SwiftUI

struct WorkoutData: Codable, Identifiable {
    let id: UUID
    let workoutType: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double? // in calories
    let distance: Double? // in meters
    let source: String
    
    init(from workout: HKWorkout) {
        self.id = UUID()
        self.workoutType = workout.workoutActivityType.displayName
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        self.totalEnergyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.distance = workout.totalDistance?.doubleValue(for: .meter())
        self.source = workout.sourceRevision.source.name
    }
    
    init(workoutType: String, startDate: Date, endDate: Date, totalEnergyBurned: Double?, distance: Double? = nil, source: String = "Manual Entry") {
        self.id = UUID()
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.totalEnergyBurned = totalEnergyBurned
        self.distance = distance
        self.source = source
    }
    
    /// Get formatted duration for display
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
    
    /// Get formatted energy burned for display
    var formattedEnergyBurned: String {
        guard let energy = totalEnergyBurned else { return "N/A" }
        return String(format: "%.0f cal", energy)
    }
    
    /// Get formatted distance for display
    var formattedDistance: String {
        guard let distance = distance else { return "N/A" }
        let kilometers = distance / 1000
        return String(format: "%.2f km", kilometers)
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .dance: return "Dance"
        case .hiking: return "Hiking"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .americanFootball: return "American Football"
        case .baseball: return "Baseball"
        case .golf: return "Golf"
        case .rowing: return "Rowing"
        case .boxing: return "Boxing"
        case .martialArts: return "Martial Arts"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"

        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .coreTraining: return "Core Training"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .stepTraining: return "Step Training"
        case .fitnessGaming: return "Fitness Gaming"
        default: return "Other"
        }
    }
}

extension WorkoutData {
    /// Get formatted start time for display
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    /// Get activity type enum for UI purposes
    var activityType: WorkoutActivityType {
        return WorkoutActivityType(from: workoutType)
    }
}

// MARK: - Workout Activity Type

enum WorkoutActivityType: String, CaseIterable {
    case running = "Running"
    case walking = "Walking"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case yoga = "Yoga"
    case strengthTraining = "Strength Training"
    case functionalStrengthTraining = "Functional Strength Training"
    case traditionalStrengthTraining = "Traditional Strength Training"
    case dance = "Dance"
    case hiking = "Hiking"
    case tennis = "Tennis"
    case basketball = "Basketball"
    case soccer = "Soccer"
    case americanFootball = "American Football"
    case baseball = "Baseball"
    case golf = "Golf"
    case rowing = "Rowing"
    case boxing = "Boxing"
    case martialArts = "Martial Arts"
    case pilates = "Pilates"
    case crossTraining = "Cross Training"
    case coreTraining = "Core Training"
    case flexibility = "Flexibility"
    case cooldown = "Cooldown"
    case elliptical = "Elliptical"
    case stairClimbing = "Stair Climbing"
    case stepTraining = "Step Training"
    case fitnessGaming = "Fitness Gaming"
    case other = "Other"
    
    init(from workoutType: String) {
        self = WorkoutActivityType(rawValue: workoutType) ?? .other
    }
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .strengthTraining, .functionalStrengthTraining, .traditionalStrengthTraining: return "dumbbell.fill"
        case .dance: return "figure.dance"
        case .hiking: return "figure.hiking"
        case .tennis: return "tennis.racket"
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .americanFootball: return "football.fill"
        case .baseball: return "baseball.fill"
        case .golf: return "figure.golf"
        case .rowing: return "figure.rowing"
        case .boxing, .martialArts: return "figure.boxing"
        case .pilates: return "figure.pilates"
        case .crossTraining: return "figure.cross.training"
        case .coreTraining: return "figure.core.training"
        case .flexibility: return "figure.flexibility"
        case .cooldown: return "figure.cooldown"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stair.stepper"
        case .stepTraining: return "figure.step.training"
        case .fitnessGaming: return "gamecontroller.fill"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .red
        case .walking: return .green
        case .cycling: return .blue
        case .swimming: return .cyan
        case .yoga: return .purple
        case .strengthTraining, .functionalStrengthTraining, .traditionalStrengthTraining: return .orange
        case .dance: return .pink
        case .hiking: return .brown
        case .tennis: return .yellow
        case .basketball: return .orange
        case .soccer: return .green
        case .americanFootball: return .brown
        case .baseball: return .blue
        case .golf: return .green
        case .rowing: return .blue
        case .boxing, .martialArts: return .red
        case .pilates: return .purple
        case .crossTraining: return .orange
        case .coreTraining: return .red
        case .flexibility: return .mint
        case .cooldown: return .blue
        case .elliptical: return .gray
        case .stairClimbing: return .yellow
        case .stepTraining: return .orange
        case .fitnessGaming: return .indigo
        case .other: return .gray
        }
    }
}