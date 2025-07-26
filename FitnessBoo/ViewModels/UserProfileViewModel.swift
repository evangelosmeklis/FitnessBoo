//
//  UserProfileViewModel.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import Foundation
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var weight: String = ""
    @Published var preferredUnits: UnitSystem = .metric
    
    @Published var weightError: String?
    
    // Stub properties for onboarding compatibility (not used)
    @Published var age: String = ""
    @Published var height: String = ""
    @Published var ageError: String?
    @Published var heightError: String?
    @Published var gender: Gender = .male
    @Published var activityLevel: ActivityLevel = .sedentary
    
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // Current user data
    @Published var currentUser: User?
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
        setupValidation()
    }
    
    private func setupValidation() {
        // Clear errors when user starts typing
        $weight
            .sink { [weak self] _ in
                self?.weightError = nil
            }
            .store(in: &cancellables)
    }
    
    func validateWeight() -> Bool {
        guard let weightValue = Double(weight), weightValue > 0, weightValue < 1000 else {
            let unit = preferredUnits == .metric ? "kg" : "lbs"
            weightError = "Weight must be between 1 and 999 \(unit)"
            return false
        }
        weightError = nil
        return true
    }
    
    // Stub methods for onboarding compatibility (not used)
    func validateAge() -> Bool { return true }
    func validateHeight() -> Bool { return true }
    
    func validateAllFields() -> Bool {
        return validateWeight()
    }
    
    func createUser() async -> User? {
        guard validateAllFields() else {
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let weightValue = Double(weight) else {
                throw ValidationError.invalidWeight
            }
            
            var user = User(
                weight: weightValue,
                preferredUnits: preferredUnits
            )
            
            try user.validate()
            
            return user
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            return nil
        }
    }
    
    func resetForm() {
        weight = ""
        preferredUnits = .metric
        
        weightError = nil
        
        isLoading = false
        showingError = false
        errorMessage = ""
    }
    
    func updateUserWeight(_ newWeight: Double) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let user = try await dataService.fetchUser() else {
                errorMessage = "User not found"
                showingError = true
                return false
            }
            
            var updatedUser = user
            updatedUser.weight = newWeight
            updatedUser.updatedAt = Date()
            
            try updatedUser.validate()
            try await dataService.saveUser(updatedUser)
            
            currentUser = updatedUser
            weight = String(newWeight)
            
            // Notify other components that weight has been updated
            NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            return false
        }
    }
    
    func loadCurrentUser() {
        Task {
            do {
                currentUser = try await dataService.fetchUser()
            } catch {
                errorMessage = "Failed to load user: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}