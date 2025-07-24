//
//  HistoryViewModel.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import Foundation
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var foodEntries: [FoodEntry] = []
    @Published var dailyNutrition: DailyNutrition?
    @Published var weeklyBalance: Double?
    @Published var datesWithEntries: Set<Date> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol = CalculationService()
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
        
        $selectedDate
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] date in
                self?.loadData(for: date)
            }
            .store(in: &cancellables)
    }
    
    func loadData(for date: Date) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch daily nutrition and stats
                let fetchedNutrition = try await dataService.fetchDailyNutrition(for: date)
                let dailyStats = try await dataService.fetchDailyStats(for: date)
                
                if var nutrition = fetchedNutrition {
                    // Update exercise calories and recalculate
                    nutrition.updateExerciseCalories(dailyStats?.caloriesFromExercise ?? 0)
                    self.dailyNutrition = nutrition
                    self.foodEntries = sortFoodEntries(nutrition.entries)
                } else {
                    self.dailyNutrition = nil
                    self.foodEntries = []
                }
                
                // Fetch weekly balance
                if let user = try await dataService.fetchUser() {
                    let week = Calendar.current.dateInterval(of: .weekOfYear, for: date)!
                    let weeklyStats = try await dataService.fetchDailyStats(for: week.start...week.end, user: user)
                    self.weeklyBalance = weeklyStats.reduce(0) { $0 + $1.netCalories }
                }
                
            } catch {
                self.errorMessage = "Failed to load history data: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func sortFoodEntries(_ entries: [FoodEntry]) -> [FoodEntry] {
        let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        return entries.sorted {
            let firstMealIndex = mealOrder.firstIndex(of: $0.mealType ?? .snack) ?? mealOrder.count
            let secondMealIndex = mealOrder.firstIndex(of: $1.mealType ?? .snack) ?? mealOrder.count
            return firstMealIndex < secondMealIndex
        }
    }
    
    func loadDatesWithEntries() {
        Task {
            // This is a placeholder. A more efficient implementation would
            // fetch this data from a pre-computed source.
            // For now, we'll just mark the current date if it has entries.
            if let user = try await dataService.fetchUser() {
                let entries = try await dataService.fetchFoodEntries(for: Date(), user: user)
                if !entries.isEmpty {
                    self.datesWithEntries.insert(Calendar.current.startOfDay(for: Date()))
                }
            }
        }
    }
}
