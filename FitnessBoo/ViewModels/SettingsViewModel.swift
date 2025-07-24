//
//  SettingsViewModel.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var unitSystem: UnitSystem = .metric
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
        
        $unitSystem
            .dropFirst()
            .sink { [weak self] newUnitSystem in
                self?.saveUnitSystem(newUnitSystem)
            }
            .store(in: &cancellables)
    }
    
    func loadSettings() {
        Task {
            if let user = try await dataService.fetchUser() {
                self.unitSystem = user.preferredUnits
            }
        }
    }
    
    private func saveUnitSystem(_ unitSystem: UnitSystem) {
        Task {
            if var user = try await dataService.fetchUser() {
                user.preferredUnits = unitSystem
                try await dataService.saveUser(user)
            }
        }
    }
}
