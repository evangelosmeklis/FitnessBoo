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
    @Published var age: String = ""
    @Published var weight: String = ""
    @Published var height: String = ""
    @Published var gender: Gender = .male
    @Published var activityLevel: ActivityLevel = .sedentary
    @Published var preferredUnits: UnitSystem = .metric
    
    @Published var ageError: String?
    @Published var weightError: String?
    @Published var heightError: String?
    
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
        $age
            .sink { [weak self] _ in
                self?.ageError = nil
            }
            .store(in: &cancellables)
        
        $weight
            .sink { [weak self] _ in
                self?.weightError = nil
            }
            .store(in: &cancellables)
        
        $height
            .sink { [weak self] _ in
                self?.heightError = nil
            }
            .store(in: &cancellables)
    }
    
    func validateAge() -> Bool {
        guard let ageValue = Int(age), ageValue > 0, ageValue < 150 else {
            ageError = "Age must be between 1 and 149 years"
            return false
        }
        ageError = nil
        return true
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
    
    func validateHeight() -> Bool {
        guard let heightValue = Double(height), heightValue > 0, heightValue < 300 else {
            let unit = preferredUnits == .metric ? "cm" : "inches"
            heightError = "Height must be between 1 and 299 \(unit)"
            return false
        }
        heightError = nil
        return true
    }
    
    func validateAllFields() -> Bool {
        let ageValid = validateAge()
        let weightValid = validateWeight()
        let heightValid = validateHeight()
        
        return ageValid && weightValid && heightValid
    }
    
    func createUser() async -> User? {
        guard validateAllFields() else {
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let ageValue = Int(age),
                  let weightValue = Double(weight),
                  let heightValue = Double(height) else {
                throw ValidationError.invalidAge
            }
            
            var user = User(
                age: ageValue,
                weight: weightValue,
                height: heightValue,
                gender: gender,
                activityLevel: activityLevel,
                preferredUnits: preferredUnits
            )
            
            user.calculateBMR()
            try user.validate()
            
            return user
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            return nil
        }
    }
    
    func resetForm() {
        age = ""
        weight = ""
        height = ""
        gender = .male
        activityLevel = .sedentary
        preferredUnits = .metric
        
        ageError = nil
        weightError = nil
        heightError = nil
        
        isLoading = false
        showingError = false
        errorMessage = ""
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