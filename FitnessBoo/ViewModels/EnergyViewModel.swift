//
//  EnergyViewModel.swift
//  FitnessBoo
//
//  Created by Kiro on 24/7/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class EnergyViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeEnergy: Double = 0
    @Published var restingEnergy: Double = 0
    @Published var totalEnergyExpended: Double = 0
    @Published var workoutCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let healthKitService: HealthKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var formattedActiveEnergy: String {
        return String(format: "%.0f", activeEnergy)
    }
    
    var formattedRestingEnergy: String {
        return String(format: "%.0f", restingEnergy)
    }
    
    var formattedTotalEnergy: String {
        return String(format: "%.0f", totalEnergyExpended)
    }
    
    var activeEnergyPercentage: Double {
        guard totalEnergyExpended > 0 else { return 0 }
        return activeEnergy / totalEnergyExpended
    }
    
    var restingEnergyPercentage: Double {
        guard totalEnergyExpended > 0 else { return 0 }
        return restingEnergy / totalEnergyExpended
    }
    
    // MARK: - Initialization
    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
        setupObservers()
    }
    
    // MARK: - Public Methods
    func loadTodaysEnergy() {
        Task {
            await fetchTodaysEnergyData()
        }
    }
    
    func refreshEnergyData() async {
        await fetchTodaysEnergyData()
    }
    
    func forceRefreshFromHealthKit() async {
        // Clear any cached data and force fresh fetch
        isLoading = true
        errorMessage = nil
        
        do {
            let today = Date()
            
            // Force fresh data from HealthKit
            async let activeEnergyTask = healthKitService.fetchActiveEnergy(for: today)
            async let restingEnergyTask = healthKitService.fetchRestingEnergy(for: today)
            
            let (fetchedActiveEnergy, fetchedRestingEnergy) = try await (activeEnergyTask, restingEnergyTask)
            
            updateEnergyData(resting: fetchedRestingEnergy, active: fetchedActiveEnergy)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Observe real-time energy changes
        healthKitService.observeEnergyChanges()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] energyData in
                self?.updateEnergyData(resting: energyData.resting, active: energyData.active)
            }
            .store(in: &cancellables)
    }
    
    private func fetchTodaysEnergyData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? today
            
            async let activeEnergyTask = healthKitService.fetchActiveEnergy(for: today)
            async let restingEnergyTask = healthKitService.fetchRestingEnergy(for: today)
            async let workoutsTask = healthKitService.fetchWorkouts(from: startOfDay, to: endOfDay)
            
            let (fetchedActiveEnergy, fetchedRestingEnergy, fetchedWorkouts) = try await (activeEnergyTask, restingEnergyTask, workoutsTask)
            
            updateEnergyData(resting: fetchedRestingEnergy, active: fetchedActiveEnergy)
            workoutCount = fetchedWorkouts.count
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateEnergyData(resting: Double, active: Double) {
        activeEnergy = active
        restingEnergy = resting
        totalEnergyExpended = active + resting
    }
}

// MARK: - Energy Data Model
struct EnergyData {
    let activeEnergy: Double
    let restingEnergy: Double
    let totalEnergy: Double
    let date: Date
    
    var formattedActiveEnergy: String {
        return String(format: "%.0f kcal", activeEnergy)
    }
    
    var formattedRestingEnergy: String {
        return String(format: "%.0f kcal", restingEnergy)
    }
    
    var formattedTotalEnergy: String {
        return String(format: "%.0f kcal", totalEnergy)
    }
    
    var activePercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return activeEnergy / totalEnergy
    }
    
    var restingPercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return restingEnergy / totalEnergy
    }
}