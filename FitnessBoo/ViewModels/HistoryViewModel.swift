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
    @Published var datesWithEntries: Set<Date> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
        
        $selectedDate
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] date in
                self?.loadFoodEntries(for: date)
            }
            .store(in: &cancellables)
    }
    
    func loadFoodEntries(for date: Date) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if let user = try await dataService.fetchUser() {
                    let entries = try await dataService.fetchFoodEntries(for: date, user: user)
                    self.foodEntries = entries
                } else {
                    self.foodEntries = []
                }
            } catch {
                self.errorMessage = "Failed to load food entries: \(error.localizedDescription)"
            }
            
            isLoading = false
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
